const router = require('express').Router();
const db = require('../db');
const COMPANY_ID = process.env.COMPANY_ID;

// GET /api/livraisons
router.get('/', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT d.*, o.order_number, o.customer_name,
             u.first_name || ' ' || u.last_name AS driver_name,
             z.name AS zone_name
      FROM deliveries d
      JOIN orders o ON o.id = d.order_id
      LEFT JOIN users u ON u.id = d.driver_id
      LEFT JOIN zones z ON z.id = d.zone_id
      WHERE d.company_id=$1
      ORDER BY d.created_at DESC
    `, [COMPANY_ID]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/livraisons
router.post('/', async (req, res) => {
  const { order_id, driver_id, zone_id } = req.body;
  try {
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const result = await db.query(`
      INSERT INTO deliveries (company_id, order_id, driver_id, zone_id,
        status, confirmation_code)
      VALUES ($1,$2,$3,$4,'assignee',$5) RETURNING *
    `, [COMPANY_ID, order_id, driver_id, zone_id, code]);

    await db.query(
      `UPDATE orders SET status='expediee', updated_at=NOW() WHERE id=$1`,
      [order_id]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
