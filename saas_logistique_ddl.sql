-- =============================================================================
-- PLATEFORME SAAS LOGISTIQUE / E-COMMERCE — DDL PostgreSQL 16
-- Version 2.0 — Mai 2026
-- Modèle multi-tenant : base partagée avec colonne company_id + Row Level Security
-- Normalisation : 3NF (avec dérogation justifiée pour prix figés sur order_items)
-- =============================================================================

-- =============================================================================
-- EXTENSIONS POSTGRESQL
-- =============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- UUID v4
CREATE EXTENSION IF NOT EXISTS "pgcrypto";       -- chiffrement des données sensibles
CREATE EXTENSION IF NOT EXISTS "postgis";        -- coordonnées GPS (optionnel, peut être remplacé par POINT)
CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- recherche textuelle floue (noms produits, clients)

-- =============================================================================
-- TYPES ÉNUMÉRÉS (ENUM)
-- Avantage : contrainte CHECK implicite + documentation du domaine de valeurs
-- =============================================================================

CREATE TYPE subscription_plan AS ENUM ('gratuit', 'starter', 'pro', 'enterprise');
CREATE TYPE subscription_status AS ENUM ('actif', 'suspendu', 'expire', 'annule');
CREATE TYPE user_role AS ENUM ('super_admin', 'admin', 'vendeur', 'stock_manager', 'livreur', 'client');
CREATE TYPE order_status AS ENUM (
    'brouillon', 'confirmee', 'preparee', 'expediee',
    'livree', 'echec_livraison', 'annulee', 'remboursee'
);
CREATE TYPE payment_method AS ENUM ('cash_livraison', 'mobile_money', 'virement', 'carte');
CREATE TYPE payment_status AS ENUM ('en_attente', 'paye', 'echoue', 'rembourse');
CREATE TYPE delivery_status AS ENUM (
    'en_attente', 'assignee', 'en_cours', 'livree', 'echec', 'retournee'
);
CREATE TYPE stock_movement_type AS ENUM ('entree', 'sortie', 'ajustement', 'retour', 'inventaire');
CREATE TYPE notification_type AS ENUM (
    'commande', 'stock', 'livraison', 'paiement', 'systeme', 'alerte'
);
CREATE TYPE invoice_status AS ENUM ('brouillon', 'emise', 'payee', 'annulee');
CREATE TYPE webhook_event AS ENUM (
    'order.created', 'order.updated', 'order.delivered', 'order.cancelled',
    'stock.low', 'payment.received', 'delivery.updated'
);
CREATE TYPE audit_action AS ENUM (
    'CREATE', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'LOGIN_FAILED',
    'PASSWORD_RESET', 'EXPORT', 'IMPERSONATE'
);

-- =============================================================================
-- SCHÉMA : companies (tenants)
-- Entité racine du modèle multi-tenant. Chaque entreprise cliente est un tenant.
-- Le modèle retenu est "base partagée + company_id" pour minimiser l'overhead
-- d'administration (pas besoin de créer un schéma/base par client).
-- Row Level Security (RLS) PostgreSQL renforce l'isolation côté moteur.
-- =============================================================================

CREATE TABLE companies (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                VARCHAR(200) NOT NULL,
    slug                VARCHAR(100) NOT NULL UNIQUE,          -- sous-domaine : monentreprise.app.com
    email               VARCHAR(255) NOT NULL UNIQUE,
    phone               VARCHAR(30),
    address             TEXT,
    country             VARCHAR(100) DEFAULT 'Cameroun',
    logo_url            VARCHAR(500),
    subscription_plan   subscription_plan NOT NULL DEFAULT 'gratuit',
    subscription_status subscription_status NOT NULL DEFAULT 'actif',
    subscription_expires_at TIMESTAMPTZ,
    -- Limites selon le plan (snapshot figé pour comparaison rapide)
    max_orders_per_month    INTEGER NOT NULL DEFAULT 50,
    max_users               INTEGER NOT NULL DEFAULT 2,
    max_products            INTEGER NOT NULL DEFAULT 100,
    max_drivers             INTEGER NOT NULL DEFAULT 0,
    -- Paramètres d'onboarding
    onboarding_completed    BOOLEAN NOT NULL DEFAULT FALSE,
    timezone                VARCHAR(50) NOT NULL DEFAULT 'Africa/Douala',
    currency                CHAR(3) NOT NULL DEFAULT 'XAF',
    -- Soft delete
    deleted_at          TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE companies IS 'Tenants de la plateforme SaaS. Chaque entreprise cliente est isolée via company_id + RLS.';
COMMENT ON COLUMN companies.slug IS 'Identifiant URL unique utilisé pour le routage multi-tenant (sous-domaine ou path prefix).';

CREATE INDEX idx_companies_slug ON companies (slug) WHERE deleted_at IS NULL;
CREATE INDEX idx_companies_plan ON companies (subscription_plan) WHERE deleted_at IS NULL;

-- =============================================================================
-- SCHÉMA : users
-- Utilisateurs de la plateforme. Un utilisateur appartient à une seule entreprise
-- (sauf super_admin qui a company_id NULL).
-- Données sensibles : email chiffré au niveau applicatif + hash du mot de passe.
-- =============================================================================

CREATE TABLE users (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id              UUID REFERENCES companies(id) ON DELETE CASCADE,  -- NULL pour super_admin
    role                    user_role NOT NULL DEFAULT 'vendeur',
    first_name              VARCHAR(100) NOT NULL,
    last_name               VARCHAR(100) NOT NULL,
    email                   VARCHAR(255) NOT NULL,              -- chiffré au niveau applicatif (AES-256)
    email_hash              VARCHAR(64) NOT NULL,               -- SHA-256 pour recherche rapide sans déchiffrement
    phone                   VARCHAR(30),
    password_hash           VARCHAR(255) NOT NULL,              -- bcrypt, coût ≥ 12
    -- Sécurité
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    failed_login_attempts   SMALLINT NOT NULL DEFAULT 0,
    locked_until            TIMESTAMPTZ,
    last_login_at           TIMESTAMPTZ,
    last_login_ip           INET,
    -- Tokens
    refresh_token_hash      VARCHAR(64),                        -- SHA-256 du refresh token courant
    refresh_token_expires_at TIMESTAMPTZ,
    reset_token_hash        VARCHAR(64),
    reset_token_expires_at  TIMESTAMPTZ,
    -- Préférences
    language                CHAR(2) NOT NULL DEFAULT 'fr',
    avatar_url              VARCHAR(500),
    -- Soft delete + audit
    deleted_at              TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID REFERENCES users(id),
    updated_by              UUID REFERENCES users(id)
);

COMMENT ON TABLE users IS 'Utilisateurs multi-rôles. company_id NULL = super_admin plateforme.';
COMMENT ON COLUMN users.email IS 'Email chiffré AES-256-GCM côté application avant insertion.';
COMMENT ON COLUMN users.email_hash IS 'SHA-256 non-salé de email en minuscules — permet la recherche par email sans déchiffrement.';

-- Unicité email par tenant (deux tenants peuvent avoir le même email)
CREATE UNIQUE INDEX idx_users_email_company ON users (email_hash, company_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX idx_users_email_superadmin ON users (email_hash) WHERE company_id IS NULL AND deleted_at IS NULL;
CREATE INDEX idx_users_company ON users (company_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_role ON users (company_id, role) WHERE deleted_at IS NULL;
-- Index partiel pour recherche des comptes verrouillés (maintenance)
CREATE INDEX idx_users_locked ON users (locked_until) WHERE locked_until IS NOT NULL;

-- =============================================================================
-- SCHÉMA : zones
-- Zones géographiques de livraison avec tarification par zone.
-- Permet l'assignation automatique de livreurs par zone.
-- =============================================================================

CREATE TABLE zones (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    -- Représentation géographique simplifiée (polygone en GeoJSON si PostGIS, sinon description textuelle)
    geojson         JSONB,                                      -- polygon PostGIS optionnel
    delivery_fee    NUMERIC(10, 2) NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, name)
);

COMMENT ON TABLE zones IS 'Zones géographiques de livraison avec tarification. Livreurs assignés via driver_zones.';

CREATE INDEX idx_zones_company ON zones (company_id) WHERE is_active = TRUE;

-- =============================================================================
-- SCHÉMA : products
-- Catalogue produits du tenant. Un produit peut avoir des variantes (taille, couleur).
-- La table products stocke la fiche principale, product_variants les déclinaisons.
-- =============================================================================

CREATE TABLE products (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id          UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name                VARCHAR(300) NOT NULL,
    description         TEXT,
    sku                 VARCHAR(100),                           -- référence interne
    barcode             VARCHAR(50),                           -- EAN-13 ou QR code
    category            VARCHAR(100),
    unit                VARCHAR(30) NOT NULL DEFAULT 'unité',  -- kg, litre, pièce...
    base_price          NUMERIC(15, 2) NOT NULL DEFAULT 0,
    -- Stock (valeurs agrégées des variantes si variantes existent, sinon direct)
    stock_quantity      INTEGER NOT NULL DEFAULT 0,
    stock_alert_threshold INTEGER NOT NULL DEFAULT 5,          -- seuil d'alerte
    -- Prix par palier (JSONB : [{min_qty: 1, price: 1000}, {min_qty: 10, price: 900}])
    tiered_prices       JSONB,
    image_url           VARCHAR(500),
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    has_variants        BOOLEAN NOT NULL DEFAULT FALSE,
    -- Soft delete
    deleted_at          TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID REFERENCES users(id),
    updated_by          UUID REFERENCES users(id),
    UNIQUE (company_id, sku)
);

COMMENT ON TABLE products IS 'Catalogue produits par tenant. Stock agrégé ici, détail par variante dans product_variants.';

CREATE INDEX idx_products_company ON products (company_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_barcode ON products (company_id, barcode) WHERE barcode IS NOT NULL;
-- Recherche textuelle floue sur le nom
CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);
-- Alerte stock : index partiel sur les produits en rupture
CREATE INDEX idx_products_low_stock ON products (company_id, stock_quantity, stock_alert_threshold)
    WHERE deleted_at IS NULL AND is_active = TRUE;

-- =============================================================================
-- SCHÉMA : product_variants
-- Déclinaisons d'un produit (taille S/M/L, couleur rouge/bleu...).
-- Chaque variante a son propre stock et peut avoir son propre code-barres.
-- =============================================================================

CREATE TABLE product_variants (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    name            VARCHAR(200) NOT NULL,                     -- ex: "Taille L - Rouge"
    sku             VARCHAR(100),
    barcode         VARCHAR(50),
    attributes      JSONB NOT NULL DEFAULT '{}',               -- {"taille": "L", "couleur": "rouge"}
    price_adjustment NUMERIC(10, 2) NOT NULL DEFAULT 0,        -- delta par rapport au prix de base
    stock_quantity  INTEGER NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, product_id, sku)
);

CREATE INDEX idx_variants_product ON product_variants (product_id) WHERE is_active = TRUE;
CREATE INDEX idx_variants_barcode ON product_variants (company_id, barcode) WHERE barcode IS NOT NULL;

-- =============================================================================
-- SCHÉMA : orders
-- Commandes clients. Point central du modèle métier.
-- Les montants sont dénormalisés volontairement (prix figés à la commande).
-- =============================================================================

CREATE TABLE orders (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id          UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    order_number        VARCHAR(50) NOT NULL,                  -- numéro lisible : ORD-2026-001234
    status              order_status NOT NULL DEFAULT 'brouillon',
    -- Client
    customer_name       VARCHAR(200) NOT NULL,
    customer_phone      VARCHAR(30) NOT NULL,
    customer_email      VARCHAR(255),
    -- Adresse de livraison
    delivery_address    TEXT NOT NULL,
    delivery_zone_id    UUID REFERENCES zones(id),
    delivery_notes      TEXT,
    -- Coordonnées GPS de l'adresse (latitude, longitude)
    delivery_lat        NUMERIC(10, 8),
    delivery_lng        NUMERIC(11, 8),
    -- Montants figés à la commande (dénormalisation justifiée : évite recalcul)
    subtotal            NUMERIC(15, 2) NOT NULL DEFAULT 0,
    delivery_fee        NUMERIC(10, 2) NOT NULL DEFAULT 0,
    discount_amount     NUMERIC(10, 2) NOT NULL DEFAULT 0,
    tax_amount          NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_amount        NUMERIC(15, 2) NOT NULL DEFAULT 0,
    -- Paiement
    payment_method      payment_method,
    payment_status      payment_status NOT NULL DEFAULT 'en_attente',
    paid_at             TIMESTAMPTZ,
    -- Canal de vente
    sale_channel        VARCHAR(50) DEFAULT 'manuel',          -- 'web', 'mobile', 'whatsapp', 'manuel'
    -- Dates clés
    confirmed_at        TIMESTAMPTZ,
    prepared_at         TIMESTAMPTZ,
    shipped_at          TIMESTAMPTZ,
    delivered_at        TIMESTAMPTZ,
    cancelled_at        TIMESTAMPTZ,
    -- Notes internes
    internal_notes      TEXT,
    -- Soft delete
    deleted_at          TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID REFERENCES users(id),
    updated_by          UUID REFERENCES users(id),
    UNIQUE (company_id, order_number),
    -- Contrainte métier : total_amount cohérent
    CONSTRAINT chk_order_total CHECK (total_amount >= 0 AND subtotal >= 0)
);

COMMENT ON TABLE orders IS 'Commandes clients. Montants figés à la création pour traçabilité comptable.';

CREATE INDEX idx_orders_company_status ON orders (company_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_orders_company_created ON orders (company_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_orders_customer_phone ON orders (company_id, customer_phone);
-- Index partiel pour commandes actives (les plus consultées)
CREATE INDEX idx_orders_active ON orders (company_id, created_at DESC)
    WHERE status NOT IN ('annulee', 'remboursee') AND deleted_at IS NULL;

-- =============================================================================
-- SCHÉMA : order_items
-- Lignes de commande. Prix figés au moment de la commande (dénormalisation
-- intentionnelle et documentée — règle comptable standard).
-- =============================================================================

CREATE TABLE order_items (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id          UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    order_id            UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id          UUID NOT NULL REFERENCES products(id),
    variant_id          UUID REFERENCES product_variants(id),
    product_name        VARCHAR(300) NOT NULL,                 -- snapshot du nom au moment de la commande
    product_sku         VARCHAR(100),
    quantity            INTEGER NOT NULL CHECK (quantity > 0),
    unit_price          NUMERIC(15, 2) NOT NULL,               -- prix figé à la commande
    discount_rate       NUMERIC(5, 2) NOT NULL DEFAULT 0,      -- remise en % appliquée
    line_total          NUMERIC(15, 2) NOT NULL,               -- quantity * unit_price * (1 - discount_rate/100)
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE order_items IS 'Lignes de commande. unit_price et product_name sont figés au moment de la commande — dénormalisation comptable intentionnelle.';

CREATE INDEX idx_order_items_order ON order_items (order_id);
CREATE INDEX idx_order_items_product ON order_items (company_id, product_id);

-- =============================================================================
-- SCHÉMA : order_events
-- Journal d'événements (append-only) pour la traçabilité complète de chaque commande.
-- Ce tableau ne doit JAMAIS être mis à jour — uniquement des INSERT.
-- =============================================================================

CREATE TABLE order_events (
    id              UUID NOT NULL DEFAULT uuid_generate_v4(),
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    order_id        UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    event_type      VARCHAR(100) NOT NULL,                     -- ex: 'status_changed', 'payment_received'
    old_status      order_status,
    new_status      order_status,
    description     TEXT,
    metadata        JSONB DEFAULT '{}',                        -- données contextuelles libres
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)                               -- created_at requis : colonne de partition
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE order_events IS 'Journal append-only des événements sur les commandes. Partitionné par mois.';

-- Partitions mensuelles (à créer via script automatisé en production)
CREATE TABLE order_events_2026_05 PARTITION OF order_events
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE order_events_2026_06 PARTITION OF order_events
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE order_events_2026_07 PARTITION OF order_events
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE order_events_default PARTITION OF order_events DEFAULT;

CREATE INDEX idx_order_events_order ON order_events (order_id, created_at DESC);
CREATE INDEX idx_order_events_company ON order_events (company_id, created_at DESC);

-- =============================================================================
-- SCHÉMA : deliveries
-- Livraisons associées aux commandes. Un livreur est un utilisateur de rôle 'livreur'.
-- Stocke la preuve de livraison (photo URL, signature, code de confirmation).
-- =============================================================================

CREATE TABLE deliveries (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id              UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    order_id                UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    driver_id               UUID REFERENCES users(id),         -- livreur assigné
    zone_id                 UUID REFERENCES zones(id),
    status                  delivery_status NOT NULL DEFAULT 'en_attente',
    -- Position GPS du livreur (dernière connue)
    driver_lat              NUMERIC(10, 8),
    driver_lng              NUMERIC(11, 8),
    position_updated_at     TIMESTAMPTZ,
    -- ETA
    estimated_arrival_at    TIMESTAMPTZ,
    -- Preuve de livraison
    proof_photo_url         VARCHAR(500),
    proof_signature_url     VARCHAR(500),
    confirmation_code       CHAR(6),                           -- code à 6 chiffres pour confirmation client
    geolocation_at_delivery JSONB,                             -- {lat, lng, accuracy, timestamp}
    -- Résultats
    delivered_at            TIMESTAMPTZ,
    failure_reason          TEXT,
    -- Retour
    is_return               BOOLEAN NOT NULL DEFAULT FALSE,
    return_reason           TEXT,
    return_item_condition   VARCHAR(50),                       -- 'bon', 'abime', 'detruit'
    -- Rapport de tournée
    distance_km             NUMERIC(8, 2),
    notes                   TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE deliveries IS 'Livraisons avec suivi GPS, preuve de livraison et gestion des retours.';

CREATE INDEX idx_deliveries_order ON deliveries (order_id);
CREATE INDEX idx_deliveries_driver ON deliveries (driver_id, status) WHERE status NOT IN ('livree', 'retournee');
CREATE INDEX idx_deliveries_company_status ON deliveries (company_id, status, created_at DESC);

-- =============================================================================
-- SCHÉMA : driver_zones
-- Table de jointure N-N entre livreurs (users) et zones de livraison.
-- Un livreur peut couvrir plusieurs zones.
-- =============================================================================

CREATE TABLE driver_zones (
    driver_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    zone_id     UUID NOT NULL REFERENCES zones(id) ON DELETE CASCADE,
    company_id  UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_primary  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (driver_id, zone_id)
);

CREATE INDEX idx_driver_zones_zone ON driver_zones (zone_id, company_id);

-- =============================================================================
-- SCHÉMA : stock_movements
-- Journal de tous les mouvements de stock. Append-only pour audit complet.
-- Partitionné par mois pour performance sur les gros volumes.
-- =============================================================================

CREATE TABLE stock_movements (
    id              UUID NOT NULL DEFAULT uuid_generate_v4(),
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES products(id),
    variant_id      UUID REFERENCES product_variants(id),
    movement_type   stock_movement_type NOT NULL,
    quantity_delta  INTEGER NOT NULL,                          -- positif = entrée, négatif = sortie
    quantity_before INTEGER NOT NULL,
    quantity_after  INTEGER NOT NULL,
    reference_type  VARCHAR(50),                               -- 'order', 'inventory', 'manual'
    reference_id    UUID,                                      -- order_id ou autre
    reason          TEXT,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at),                              -- created_at requis : colonne de partition
    CONSTRAINT chk_stock_quantity_after CHECK (quantity_after >= 0)
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE stock_movements IS 'Journal append-only des mouvements de stock. Partitionné par mois.';

CREATE TABLE stock_movements_2026_05 PARTITION OF stock_movements
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE stock_movements_2026_06 PARTITION OF stock_movements
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE stock_movements_default PARTITION OF stock_movements DEFAULT;

CREATE INDEX idx_stock_movements_product ON stock_movements (product_id, created_at DESC);
CREATE INDEX idx_stock_movements_company ON stock_movements (company_id, created_at DESC);

-- =============================================================================
-- SCHÉMA : subscriptions
-- Abonnements SaaS des commerçants à la plateforme.
-- Historique complet des changements de plan.
-- =============================================================================

CREATE TABLE subscriptions (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id          UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    plan                subscription_plan NOT NULL,
    status              subscription_status NOT NULL DEFAULT 'actif',
    billing_cycle       VARCHAR(20) NOT NULL DEFAULT 'monthly' CHECK (billing_cycle IN ('monthly', 'annual')),
    amount              NUMERIC(12, 2) NOT NULL,
    currency            CHAR(3) NOT NULL DEFAULT 'XAF',
    started_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ NOT NULL,
    cancelled_at        TIMESTAMPTZ,
    -- Paiement Mobile Money / virement
    payment_method      payment_method,
    payment_reference   VARCHAR(200),                          -- référence opérateur Mobile Money
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE subscriptions IS 'Historique complet des abonnements SaaS par tenant.';

CREATE INDEX idx_subscriptions_company ON subscriptions (company_id, status);
-- Index partiel pour abonnements actifs (les plus consultés)
CREATE INDEX idx_subscriptions_active ON subscriptions (expires_at)
    WHERE status = 'actif';

-- =============================================================================
-- SCHÉMA : invoices
-- Factures générées automatiquement (commandes livrées + abonnements SaaS).
-- Numérotation séquentielle par tenant. PDF archivé 10 ans (URL S3).
-- =============================================================================

CREATE TABLE invoices (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id          UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    invoice_number      VARCHAR(50) NOT NULL,                  -- FACT-2026-001234
    status              invoice_status NOT NULL DEFAULT 'brouillon',
    invoice_type        VARCHAR(30) NOT NULL DEFAULT 'commande' CHECK (invoice_type IN ('commande', 'abonnement', 'avoir')),
    -- Référence source
    order_id            UUID REFERENCES orders(id),
    subscription_id     UUID REFERENCES subscriptions(id),
    -- Destinataire
    client_name         VARCHAR(200) NOT NULL,
    client_email        VARCHAR(255),
    client_phone        VARCHAR(30),
    client_address      TEXT,
    -- Montants
    subtotal            NUMERIC(15, 2) NOT NULL,
    tax_rate            NUMERIC(5, 2) NOT NULL DEFAULT 0,
    tax_amount          NUMERIC(15, 2) NOT NULL DEFAULT 0,
    total_amount        NUMERIC(15, 2) NOT NULL,
    -- Fichier
    pdf_url             VARCHAR(500),                          -- URL S3 — archivage 10 ans
    issued_at           TIMESTAMPTZ,
    due_at              TIMESTAMPTZ,
    paid_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, invoice_number)
);

COMMENT ON TABLE invoices IS 'Factures avec PDF archivé sur S3. Numérotation séquentielle par tenant. Rétention 10 ans.';

CREATE INDEX idx_invoices_company ON invoices (company_id, status, issued_at DESC);
CREATE INDEX idx_invoices_order ON invoices (order_id) WHERE order_id IS NOT NULL;

-- =============================================================================
-- SCHÉMA : notifications
-- Centre de notifications in-app. Chaque notification est liée à un utilisateur.
-- Lecture = soft update (is_read = TRUE). Jamais de suppression physique.
-- =============================================================================

CREATE TABLE notifications (
    id              UUID NOT NULL DEFAULT uuid_generate_v4(),
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type            notification_type NOT NULL,
    title           VARCHAR(200) NOT NULL,
    body            TEXT,
    context_url     VARCHAR(500),                              -- lien de contexte dans l'app
    reference_id    UUID,                                      -- order_id, product_id, etc.
    is_read         BOOLEAN NOT NULL DEFAULT FALSE,
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)                               -- created_at requis : colonne de partition
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE notifications IS 'Notifications in-app par utilisateur. Partitionné par mois, rétention 90 jours.';

CREATE TABLE notifications_2026_05 PARTITION OF notifications
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE notifications_2026_06 PARTITION OF notifications
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE notifications_default PARTITION OF notifications DEFAULT;

-- Index partiel : notifications non lues (requête la plus fréquente)
CREATE INDEX idx_notifications_unread ON notifications (user_id, created_at DESC)
    WHERE is_read = FALSE;
CREATE INDEX idx_notifications_user ON notifications (user_id, created_at DESC);

-- =============================================================================
-- SCHÉMA : webhooks
-- Endpoints configurables pour intégrations tierces (ERP, CRM, e-commerce).
-- Chaque tenant peut configurer plusieurs webhooks sur différents événements.
-- =============================================================================

CREATE TABLE webhooks (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name            VARCHAR(100) NOT NULL,
    url             VARCHAR(500) NOT NULL,
    secret          VARCHAR(255) NOT NULL,                     -- HMAC-SHA256 pour vérification signature
    events          webhook_event[] NOT NULL,                  -- tableau d'événements souscrits
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    -- Statistiques de fiabilité
    last_triggered_at   TIMESTAMPTZ,
    last_success_at     TIMESTAMPTZ,
    last_failure_at     TIMESTAMPTZ,
    failure_count       INTEGER NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE webhooks IS 'Webhooks sortants configurables par tenant pour intégrations tierces.';

CREATE INDEX idx_webhooks_company ON webhooks (company_id) WHERE is_active = TRUE;

-- =============================================================================
-- SCHÉMA : webhook_deliveries
-- Journal des appels webhook (tentatives, réponses). Rétention 30 jours.
-- Permet le rejeu manuel et le diagnostic.
-- =============================================================================

CREATE TABLE webhook_deliveries (
    id              UUID NOT NULL DEFAULT uuid_generate_v4(),
    webhook_id      UUID NOT NULL REFERENCES webhooks(id) ON DELETE CASCADE,
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    event_type      webhook_event NOT NULL,
    payload         JSONB NOT NULL,
    http_status     SMALLINT,
    response_body   TEXT,
    attempt_count   SMALLINT NOT NULL DEFAULT 1,
    next_retry_at   TIMESTAMPTZ,
    delivered_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)                               -- created_at requis : colonne de partition
) PARTITION BY RANGE (created_at);

CREATE TABLE webhook_deliveries_default PARTITION OF webhook_deliveries DEFAULT;
CREATE INDEX idx_webhook_deliveries_webhook ON webhook_deliveries (webhook_id, created_at DESC);

-- =============================================================================
-- SCHÉMA : audit_logs
-- Traçabilité légale : qui a fait quoi, quand, depuis quelle IP.
-- Append-only absolu — aucune UPDATE ni DELETE autorisée sur cette table.
-- Partitionné par mois, rétention 12 mois minimum.
-- =============================================================================

CREATE TABLE audit_logs (
    id              UUID NOT NULL DEFAULT uuid_generate_v4(),
    company_id      UUID REFERENCES companies(id),             -- NULL pour actions super_admin
    user_id         UUID REFERENCES users(id),
    action          audit_action NOT NULL,
    resource_type   VARCHAR(100),                              -- 'order', 'product', 'user'...
    resource_id     UUID,
    old_values      JSONB,
    new_values      JSONB,
    ip_address      INET,
    user_agent      VARCHAR(500),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)                               -- created_at requis : colonne de partition
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE audit_logs IS 'Journal légal immuable. Aucun UPDATE/DELETE autorisé. Rétention ≥ 12 mois.';

CREATE TABLE audit_logs_2026_05 PARTITION OF audit_logs
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE audit_logs_2026_06 PARTITION OF audit_logs
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE audit_logs_default PARTITION OF audit_logs DEFAULT;

CREATE INDEX idx_audit_logs_company ON audit_logs (company_id, created_at DESC);
CREATE INDEX idx_audit_logs_user ON audit_logs (user_id, created_at DESC);
CREATE INDEX idx_audit_logs_resource ON audit_logs (resource_type, resource_id, created_at DESC);

-- =============================================================================
-- TRIGGERS : updated_at automatique
-- =============================================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_companies_updated_at    BEFORE UPDATE ON companies    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_users_updated_at        BEFORE UPDATE ON users        FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_products_updated_at     BEFORE UPDATE ON products     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_variants_updated_at     BEFORE UPDATE ON product_variants FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_zones_updated_at        BEFORE UPDATE ON zones        FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_orders_updated_at       BEFORE UPDATE ON orders       FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_deliveries_updated_at   BEFORE UPDATE ON deliveries   FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_subscriptions_updated   BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_invoices_updated_at     BEFORE UPDATE ON invoices     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_webhooks_updated_at     BEFORE UPDATE ON webhooks     FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- ROW LEVEL SECURITY (RLS) — ISOLATION MULTI-TENANT
-- Le middleware applicatif injecte le company_id courant dans la variable de session.
-- Exemple : SET app.current_company_id = 'uuid-du-tenant';
-- =============================================================================

ALTER TABLE companies         ENABLE ROW LEVEL SECURITY;
ALTER TABLE users             ENABLE ROW LEVEL SECURITY;
ALTER TABLE products          ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_variants  ENABLE ROW LEVEL SECURITY;
ALTER TABLE zones             ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders            ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items       ENABLE ROW LEVEL SECURITY;
ALTER TABLE deliveries        ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements   ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices          ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications     ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhooks          ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs        ENABLE ROW LEVEL SECURITY;

-- Politique générique : chaque tenant ne voit que ses propres données
-- Le rôle applicatif (app_user) doit être utilisé — jamais le superuser
CREATE POLICY tenant_isolation ON orders
    USING (company_id = current_setting('app.current_company_id', TRUE)::UUID);

CREATE POLICY tenant_isolation ON products
    USING (company_id = current_setting('app.current_company_id', TRUE)::UUID);

-- Note : dupliquer cette politique pour toutes les tables avec company_id
-- En production, utiliser une fonction helper pour générer les politiques

-- =============================================================================
-- VUES MATÉRIALISÉES — AGRÉGATIONS FRÉQUENTES
-- =============================================================================

-- Vue : KPIs commerçant (CA, commandes) — rafraîchie toutes les heures
CREATE MATERIALIZED VIEW mv_company_daily_stats AS
SELECT
    o.company_id,
    DATE(o.created_at AT TIME ZONE 'Africa/Douala') AS order_date,
    COUNT(*)                                        AS total_orders,
    COUNT(*) FILTER (WHERE o.status = 'livree')     AS delivered_orders,
    COUNT(*) FILTER (WHERE o.status = 'annulee')    AS cancelled_orders,
    SUM(o.total_amount) FILTER (WHERE o.status = 'livree') AS revenue,
    AVG(o.total_amount) FILTER (WHERE o.status = 'livree') AS avg_order_value
FROM orders o
WHERE o.deleted_at IS NULL
GROUP BY o.company_id, DATE(o.created_at AT TIME ZONE 'Africa/Douala')
WITH DATA;

CREATE UNIQUE INDEX ON mv_company_daily_stats (company_id, order_date);

COMMENT ON MATERIALIZED VIEW mv_company_daily_stats IS
    'KPIs quotidiens par tenant. Rafraîchir via pg_cron toutes les heures : REFRESH MATERIALIZED VIEW CONCURRENTLY mv_company_daily_stats';

-- Vue : stocks critiques (produits sous le seuil d'alerte)
CREATE MATERIALIZED VIEW mv_low_stock_products AS
SELECT
    p.company_id,
    p.id AS product_id,
    p.name,
    p.sku,
    p.stock_quantity,
    p.stock_alert_threshold
FROM products p
WHERE p.stock_quantity <= p.stock_alert_threshold
  AND p.is_active = TRUE
  AND p.deleted_at IS NULL
WITH DATA;

CREATE INDEX ON mv_low_stock_products (company_id);

-- =============================================================================
-- DONNÉES DE RÉFÉRENCE : plans d'abonnement
-- =============================================================================

-- Table de configuration des plans (séparée pour éviter les ENUMs rigides)
CREATE TABLE subscription_plans_config (
    plan                subscription_plan PRIMARY KEY,
    max_orders_month    INTEGER NOT NULL,
    max_users           INTEGER NOT NULL,
    max_products        INTEGER NOT NULL,
    max_drivers         INTEGER NOT NULL,
    has_analytics       BOOLEAN NOT NULL DEFAULT FALSE,
    has_api_access      BOOLEAN NOT NULL DEFAULT FALSE,
    has_dedicated_support BOOLEAN NOT NULL DEFAULT FALSE,
    price_monthly_xaf   INTEGER NOT NULL,
    price_annual_xaf    INTEGER NOT NULL
);

INSERT INTO subscription_plans_config VALUES
    ('gratuit',    50,    2,   100,  0,  FALSE, FALSE, FALSE,       0,       0),
    ('starter',   500,    5,  1000,  3,  FALSE, FALSE, FALSE,   15000,  150000),
    ('pro',      5000,   20,    -1, -1,  TRUE,  TRUE,  FALSE,   45000,  450000),
    ('enterprise',  -1,  -1,    -1, -1,  TRUE,  TRUE,  TRUE,  150000, 1500000);
-- -1 = illimité

COMMENT ON TABLE subscription_plans_config IS 'Configuration des limites par plan. -1 = illimité.';
