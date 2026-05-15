const jwt    = require('jsonwebtoken');
const SECRET = process.env.JWT_SECRET || 'logisaas_secret_key';

module.exports = (req, res, next) => {
  const header = req.headers['authorization'];
  if (!header)
    return res.status(401).json({ error: 'Token manquant.' });

  const token = header.split(' ')[1]; // "Bearer <token>"
  if (!token)
    return res.status(401).json({ error: 'Token invalide.' });

  try {
    req.user = jwt.verify(token, SECRET);
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Token expiré ou invalide.' });
  }
};
