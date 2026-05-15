# LogiSaaS — Guide de démarrage

## Structure des projets

```
logisaas-api/          ← Backend Node.js (port 4000)
logisaas-frontend/     ← Frontend React  (port 3000)
```

---

## ÉTAPE 1 — Démarrer le backend API

```bash
# Dans VS Code, ouvre un terminal et tape :
cd logisaas-api
npm install
```

Puis ouvre le fichier `.env` et remplace `TON_MOT_DE_PASSE_ICI` par
le mot de passe de ton PostgreSQL.

```bash
npm run dev
```

Tu dois voir : `API démarrée sur http://localhost:4000`

Teste dans ton navigateur : http://localhost:4000/api/dashboard
Tu dois voir des chiffres JSON.

---

## ÉTAPE 2 — Démarrer le frontend React

```bash
# Dans un 2ème terminal VS Code :
cd logisaas-frontend
npx create-react-app . --template minimal
# (si déjà créé, saute cette ligne)

npm install axios react-router-dom
npm start
```

Remplace ensuite le contenu de `src/App.js` par `src/App.jsx`
et copie tous les fichiers du dossier `src/`.

L'app s'ouvre sur http://localhost:3000

---

## Ce qui est connecté à la base

| Page            | Données réelles PostgreSQL |
|-----------------|---------------------------|
| Dashboard       | KPIs en temps réel         |
| Commandes       | Liste + changement statut  |
| Nouvelle commande | Formulaire → INSERT en base |
| Produits        | Liste + création produit   |

---

## En cas d'erreur CORS

Vérifie que le backend tourne sur le port 4000.
Le fichier `server.js` a déjà `app.use(cors())` configuré.

## En cas d'erreur de connexion PostgreSQL

Vérifie le fichier `.env` :
- DB_PASSWORD = ton mot de passe pgAdmin
- DB_NAME = bdtest
- DB_USER = postgres
