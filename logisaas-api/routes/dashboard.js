const router = require('express').Router();
const db = require('../db');
const COMPANY_ID = process.env.COMPANY_ID;

// GET /api/dashboard
router.get('/', async (req, res) => {
  try {
    const [commandes, ca, livraisons, stock] = await Promise.all([
      db.query(`SELECT COUNT(*) FROM orders WHERE company_id=$1 AND DATE_TRUNC('month', created_at)=DATE_TRUNC('month', NOW())`, [COMPANY_ID]),
      db.query(`SELECT COALESCE(SUM(total_amount),0) AS total FROM orders WHERE company_id=$1 AND payment_status='paye' AND DATE_TRUNC('month', created_at)=DATE_TRUNC('month', NOW())`, [COMPANY_ID]),
      db.query(`SELECT COUNT(*) FROM deliveries WHERE company_id=$1 AND status='en_cours'`, [COMPANY_ID]),
      db.query(`SELECT COUNT(*) FROM products WHERE company_id=$1 AND stock_quantity <= stock_alert_threshold AND is_active=true`, [COMPANY_ID]),
    ]);
    res.json({
      commandes_mois:   parseInt(commandes.rows[0].count),
      chiffre_affaires: parseFloat(ca.rows[0].total),
      livraisons_cours: parseInt(livraisons.rows[0].count),
      stock_critique:   parseInt(stock.rows[0].count),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
