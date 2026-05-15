# Analyse & Documentation Technique — SaaS Logistique / E-Commerce
**Basé sur : Plan SaaS Logistique v2.0 — Mai 2026**

---

## Section 1 — Analyse du document

### 1.1 Entités identifiées (14 tables métier)

| Table | Rôle | Relations clés |
|---|---|---|
| `companies` | Tenant racine — chaque commerçant | 1-N avec toutes les tables |
| `users` | Utilisateurs multi-rôles | N-1 companies, N-N zones (livreurs) |
| `zones` | Zones géographiques de livraison | 1-N deliveries, N-N users |
| `products` | Catalogue produits | 1-N variants, 1-N order_items |
| `product_variants` | Déclinaisons produit | N-1 products |
| `orders` | Commandes clients | 1-N order_items, 1-N deliveries |
| `order_items` | Lignes de commande | N-1 orders, N-1 products |
| `order_events` | Journal événements commande | N-1 orders |
| `deliveries` | Livraisons + GPS + preuve | N-1 orders, N-1 users (livreur) |
| `driver_zones` | Affectation livreur ↔ zone | N-N (users × zones) |
| `stock_movements` | Mouvements de stock | N-1 products |
| `subscriptions` | Abonnements SaaS | N-1 companies |
| `invoices` | Factures | N-1 orders ou subscriptions |
| `notifications` | Notifications in-app | N-1 users |
| `webhooks` | Endpoints intégrations tierces | N-1 companies |
| `audit_logs` | Traçabilité légale | N-1 users, N-1 companies |

### 1.2 Relations identifiées

- **1-N dominantes** : companies → users, companies → products, companies → orders, orders → order_items
- **N-N** : users (livreurs) ↔ zones (table pivot `driver_zones`)
- **Polymorphe** : `audit_logs.resource_id` (peut référencer n'importe quelle table — pattern type/id)
- **Auto-référence** : `users.created_by` → `users.id` (UUID nullable)

### 1.3 Modèle multi-tenant retenu : Base partagée + `company_id` + RLS

**Décision** : modèle **Shared Database, Shared Schema** avec colonne `company_id` sur toutes les tables métier, renforcé par **Row Level Security (RLS) PostgreSQL 16**.

**Justification par rapport aux deux alternatives :**

| Critère | Base partagée + company_id ✅ | Schéma par tenant | Base par tenant |
|---|---|---|---|
| Nombre de tenants envisagé | Centaines à milliers | Dizaines | Quelques unités |
| Complexité opérationnelle | Faible | Moyenne | Haute |
| Isolation des données | RLS (robuste) | Schéma PostgreSQL (fort) | Maximale |
| Requêtes cross-tenant (super_admin) | Faciles | Complexes (`search_path`) | Très complexes |
| Migrations de schéma | 1 seule opération | N opérations | N opérations |
| Recommandé pour ce projet | **OUI** | Non | Non |

**Règle critique documentée** : `company_id` est obligatoire (NOT NULL) sur toutes les tables métier. Le middleware Express injecte `SET app.current_company_id = $uuid` à chaque requête pour activer le filtre RLS automatiquement.

### 1.4 Contraintes métier identifiées

| Contrainte | Implémentation |
|---|---|
| Cycle de vie commande (8 statuts) | ENUM `order_status` + transitions vérifiées en applicatif |
| Prix figés à la commande | `unit_price` et `product_name` copiés dans `order_items` |
| Stock ne peut pas être négatif | `CHECK (quantity_after >= 0)` sur `stock_movements` |
| Numérotation séquentielle factures | `UNIQUE (company_id, invoice_number)` + séquence applicative |
| Limites selon plan (commandes/mois, users) | `subscription_plans_config` + vérification middleware |
| Rétention factures 10 ans | Colonne `pdf_url` → S3 avec policy de rétention |
| Audit log immuable | Pas d'UPDATE/DELETE autorisé (politiques RLS + permissions DB) |

---

## Section 2 — Choix techniques justifiés

### 2.1 Normalisation

Le schéma est en **3NF** avec deux dérogations intentionnelles et documentées :

1. **`order_items.unit_price` et `product_name`** : dénormalisation comptable standard. Le prix d'un produit peut changer après la commande — figer le prix à la vente est une exigence légale et comptable, pas un défaut de conception.

2. **`orders.total_amount`** : dénormalisation pour performance (évite une agrégation des lignes à chaque lecture). Maintenu cohérent par trigger ou logique applicative.

### 2.2 Indexation

| Index | Type | Justification |
|---|---|---|
| `idx_orders_company_status` | B-tree | Filtre principal : "mes commandes en cours" |
| `idx_orders_active` | B-tree partiel | WHERE status NOT IN ('annulee', 'remboursee') — 80% des requêtes |
| `idx_products_name_trgm` | GIN (trigram) | Recherche floue "LIKE '%produit%'" sans Full Text Search lourd |
| `idx_users_locked` | B-tree partiel | Maintenance : comptes verrouillés uniquement |
| `idx_notifications_unread` | B-tree partiel | WHERE is_read = FALSE — cas d'usage le plus fréquent |
| `idx_subscriptions_active` | B-tree partiel | WHERE status = 'actif' — quota check à chaque requête |

### 2.3 Partitionnement

Trois tables en croissance illimitée sont partitionnées par **RANGE sur `created_at`** (mensuel) :

- `order_events` — événements append-only
- `stock_movements` — mouvements de stock
- `notifications` — centre de notifications
- `audit_logs` — traçabilité légale
- `webhook_deliveries` — historique appels webhook

**Avantage** : suppression des vieilles partitions sans `DELETE` (simple `DROP TABLE`) — performances de maintenance optimales.

### 2.4 Chiffrement des données sensibles

| Donnée | Méthode | Colonne |
|---|---|---|
| Email utilisateur | AES-256-GCM (applicatif) | `users.email` |
| Recherche par email | SHA-256 non-salé du email normalisé | `users.email_hash` |
| Secret webhook | Stocké hashé (HMAC-SHA256) | `webhooks.secret` |
| Mot de passe | bcrypt coût ≥ 12 | `users.password_hash` |
| Coordonnées bancaires | **Non stockées** — délégué opérateur (MTN/Orange) | — |

> **Note** : Les coordonnées bancaires ne sont jamais stockées. Les paiements Mobile Money sont délégués à l'opérateur (MTN Mobile Money, Orange Money) ou à l'agrégateur (CinetPay, Campay) qui fournit une référence de transaction stockée dans `orders.payment_reference`.

---

## Section 3 — Recommandations pour le passage en production

### 3.1 Infrastructure immédiate (Jour 1)

```bash
# 1. Créer un rôle PostgreSQL dédié à l'application (jamais le superuser)
CREATE ROLE app_user LOGIN PASSWORD '...' CONNECTION LIMIT 50;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_user;
REVOKE DELETE ON audit_logs, order_events, stock_movements FROM app_user;

# 2. Configurer pg_hba.conf : connexions uniquement depuis le réseau interne
# host  saas_db  app_user  10.0.0.0/8  scram-sha-256

# 3. Activer SSL obligatoire
# ssl = on dans postgresql.conf
```

### 3.2 Automatisation des partitions

Créer un job `pg_cron` (ou cron système) qui génère les partitions du mois suivant le 1er de chaque mois :

```sql
-- Extension pg_cron (à installer)
SELECT cron.schedule('create-partitions', '0 1 1 * *', $$
    -- Script de création des partitions du mois suivant
    -- pour order_events, stock_movements, notifications, audit_logs
$$);

-- Rafraîchissement de la vue matérialisée toutes les heures
SELECT cron.schedule('refresh-stats', '0 * * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_company_daily_stats');
```

### 3.3 Sauvegardes PostgreSQL

Conformément à la Phase 10 du document (rétention 30 jours, chiffrement AES-256) :

```bash
# Script quotidien via cron
pg_dump -Fc saas_db | \
  openssl enc -aes-256-cbc -pbkdf2 -pass env:BACKUP_KEY | \
  aws s3 cp - s3://saas-backups/$(date +%Y-%m-%d).dump.enc

# Rétention automatique S3 : lifecycle policy 30 jours
```

### 3.4 Monitoring et alertes

| Métrique | Seuil d'alerte | Outil |
|---|---|---|
| Connexions actives | > 80% du max | pg_stat_activity |
| Lock waits | > 5 secondes | pg_locks |
| Taille des tables | > 10 GB | pg_relation_size |
| Replication lag | > 60 secondes | pg_stat_replication |
| Index bloat | > 30% | pgstattuple |

### 3.5 Réplication lecture / écriture

Pour les rapports et l'analytics (Phase 11) sans impacter la production :

```
Écriture  →  Primaire (VPS principal)
Lecture   →  Réplica streaming (VPS secondaire)
              └── Dashboard analytics
              └── Exports Excel/CSV/PDF
              └── API publique (données agrégées)
```

Configuration minimale dans `postgresql.conf` primaire :
```ini
wal_level = replica
max_wal_senders = 3
synchronous_commit = on
```

### 3.6 Risques identifiés et mitigations

| Risque | Probabilité | Impact | Mitigation |
|---|---|---|---|
| **Oubli du `company_id` dans une requête** | Moyenne | Critique (fuite données) | RLS PostgreSQL comme filet de sécurité obligatoire |
| **Deadlock sur mise à jour stock concurrent** | Moyenne | Moyen | `SELECT FOR UPDATE SKIP LOCKED` + file BullMQ |
| **Partition non créée (mois suivant)** | Faible | Élevé (INSERT dans partition default) | pg_cron + alerte monitoring sur taille partition default |
| **Vue matérialisée obsolète** | Faible | Moyen | Rafraîchissement horaire CONCURRENT (pas de lock lecture) |
| **Croissance non contrôlée des audit_logs** | Certaine | Moyen | Archivage S3 + DROP PARTITION > 12 mois |
| **Email non chiffré exposé en dump** | Faible | Élevé | Chiffrement applicatif AES-256 avant INSERT |
| **Trop d'index → ralentissement INSERT** | Faible | Moyen | Audit trimestriel avec `pg_stat_user_indexes` |

### 3.7 Règles de rétention des données

| Table | Rétention active | Action après expiration |
|---|---|---|
| `order_events` | 24 mois | Archivage S3, DROP PARTITION |
| `stock_movements` | 24 mois | Archivage S3, DROP PARTITION |
| `audit_logs` | 12 mois min (légal) | Archivage S3, DROP PARTITION |
| `notifications` | 3 mois | DROP PARTITION |
| `webhook_deliveries` | 1 mois | DROP PARTITION |
| `invoices` (PDF S3) | **10 ans** (légal) | Conservation S3 obligatoire |
| `orders` | Indéfini (soft delete) | Archivage après 5 ans |

### 3.8 Checklist avant mise en production

- [ ] Rôle `app_user` créé, superuser non utilisé par l'application
- [ ] RLS activé et testé (vérifier cross-tenant impossible)
- [ ] SSL activé sur PostgreSQL
- [ ] pg_cron installé et job de partitions configuré
- [ ] Sauvegarde quotidienne testée + restauration validée
- [ ] Réplica de lecture configuré pour les rapports
- [ ] Variables d'environnement pour clés de chiffrement (jamais dans le code)
- [ ] `EXPLAIN ANALYZE` validé sur les requêtes les plus fréquentes
- [ ] Limites de connexion configurées (pgBouncer recommandé)
- [ ] Index bloat monitored (`pg_stat_user_indexes`)

---

*Document généré à partir de : SaaS_Logistique_Plan_Ameliore.docx v2.0 — Mai 2026*
