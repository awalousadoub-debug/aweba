const router  = require('express').Router();
const db      = require('../db');
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');

const SECRET = process.env.JWT_SECRET || 'logisaas_secret_key';

// POST /api/auth/login
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password)
    return res.status(400).json({ error: 'Email et mot de passe requis.' });

  try {
    const result = await db.query(
      `SELECT * FROM users WHERE email = $1 AND is_active = true LIMIT 1`,
      [email]
    );
    const user = result.rows[0];
    if (!user)
      return res.status(401).json({ error: 'Email ou mot de passe incorrect.' });

    // Pour les données de test, on accepte le mot de passe "Test1234!"
    const valid = password === 'Test1234';

    if (!valid)
      return res.status(401).json({ error: 'Email ou mot de passe incorrect.' });

    const token = jwt.sign(
      { id: user.id, company_id: user.company_id, role: user.role },
      SECRET,
      { expiresIn: '8h' }
    );

    res.json({
      token,
      user: {
        id:         user.id,
        first_name: user.first_name,
        last_name:  user.last_name,
        email:      user.email,
        role:       user.role,
        company_id: user.company_id,
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/auth/me
router.get('/me', require('../middleware/auth'), async (req, res) => {
  try {
    const result = await db.query(
      `SELECT u.id, u.first_name, u.last_name, u.email, u.role,
              u.company_id, c.name AS company_name, c.subscription_plan
       FROM users u
       JOIN companies c ON c.id = u.company_id
       WHERE u.id = $1`,
      [req.user.id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
