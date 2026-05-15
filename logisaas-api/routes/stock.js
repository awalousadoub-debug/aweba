const router = require('express').Router();
const db = require('../db');
const COMPANY_ID = process.env.COMPANY_ID;

// GET /api/stock — mouvements récents
router.get('/', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT sm.*, p.name AS product_name
      FROM stock_movements sm
      JOIN products p ON p.id = sm.product_id
      WHERE sm.company_id=$1
      ORDER BY sm.created_at DESC
      LIMIT 50
    `, [COMPANY_ID]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/stock/entree
router.post('/entree', async (req, res) => {
  const { product_id, quantity, reason } = req.body;
  const client = await db.connect();
  try {
    await client.query('BEGIN');
    const prod = await client.query(
      'SELECT stock_quantity FROM products WHERE id=$1 AND company_id=$2',
      [product_id, COMPANY_ID]
    );
    if (!prod.rows[0]) throw new Error('Produit introuvable');
    const before = prod.rows[0].stock_quantity;
    const after  = before + parseInt(quantity);

    await client.query(
      'UPDATE products SET stock_quantity=$1, updated_at=NOW() WHERE id=$2',
      [after, product_id]
    );
    const mvt = await client.query(`
      INSERT INTO stock_movements (company_id, product_id, movement_type,
        quantity_delta, quantity_before, quantity_after, reason)
      VALUES ($1,$2,'entree',$3,$4,$5,$6) RETURNING *
    `, [COMPANY_ID, product_id, quantity, before, after, reason]);

    await client.query('COMMIT');
    res.status(201).json(mvt.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

module.exports = router;
