const express = require('express');
const cors    = require('cors');
require('dotenv').config();

const app = express();
app.use(cors({
  origin: 'https://aweba.netlify.app',
  credentials: true
}));
app.use(express.json());

const auth = require('./middleware/auth');

// Route publique
app.use('/api/auth', require('./routes/auth'));

// Routes protégées
app.use('/api/commandes',  auth, require('./routes/commandes'));
app.use('/api/produits',   auth, require('./routes/produits'));
app.use('/api/livraisons', auth, require('./routes/livraisons'));
app.use('/api/stock',      auth, require('./routes/stock'));
app.use('/api/dashboard',  auth, require('./routes/dashboard'));

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log(`API démarrée sur http://localhost:${PORT}`));
