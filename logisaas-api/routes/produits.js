const router = require('express').Router();
const db = require('../db');
const COMPANY_ID = process.env.COMPANY_ID;

// GET /api/produits
router.get('/', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT id, name, sku, category, unit, base_price,
             stock_quantity, stock_alert_threshold, is_active, has_variants
      FROM products
      WHERE company_id=$1
      ORDER BY name ASC
    `, [COMPANY_ID]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/produits
router.post('/', async (req, res) => {
  const { name, description, sku, category, unit, base_price,
          stock_quantity, stock_alert_threshold } = req.body;
  try {
    const result = await db.query(`
      INSERT INTO products (company_id, name, description, sku, category,
        unit, base_price, stock_quantity, stock_alert_threshold, is_active)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,true)
      RETURNING *
    `, [COMPANY_ID, name, description, sku, category,
        unit, base_price, stock_quantity || 0, stock_alert_threshold || 5]);
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PATCH /api/produits/:id
router.patch('/:id', async (req, res) => {
  const { name, base_price, stock_alert_threshold, is_active } = req.body;
  try {
    const result = await db.query(`
      UPDATE products SET name=$1, base_price=$2,
        stock_alert_threshold=$3, is_active=$4, updated_at=NOW()
      WHERE id=$5 AND company_id=$6 RETURNING *
    `, [name, base_price, stock_alert_threshold, is_active, req.params.id, COMPANY_ID]);
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
