const router = require('express').Router();
const db = require('../db');
const COMPANY_ID = process.env.COMPANY_ID;

// GET /api/commandes
router.get('/', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT o.id, o.order_number, o.status, o.customer_name,
             o.customer_phone, o.customer_email, o.delivery_address,
             o.total_amount, o.payment_status, o.payment_method, o.created_at,
             z.name AS zone_name, z.id AS delivery_zone_id
      FROM orders o
      LEFT JOIN zones z ON z.id = o.delivery_zone_id
      WHERE o.company_id = $1
      ORDER BY o.created_at DESC
    `, [COMPANY_ID]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/commandes/:id
router.get('/:id', async (req, res) => {
  try {
    const order = await db.query(
      `SELECT o.*, z.name AS zone_name FROM orders o
       LEFT JOIN zones z ON z.id = o.delivery_zone_id
       WHERE o.id=$1 AND o.company_id=$2`,
      [req.params.id, COMPANY_ID]
    );
    const items = await db.query(
      `SELECT * FROM order_items WHERE order_id=$1 AND company_id=$2`,
      [req.params.id, COMPANY_ID]
    );
    if (!order.rows[0]) return res.status(404).json({ error: 'Commande introuvable' });
    res.json({ ...order.rows[0], items: items.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/commandes
router.post('/', async (req, res) => {
  const {
    customer_name, customer_phone, customer_email,
    delivery_address, delivery_zone_id,
    payment_method, items
  } = req.body;

  const client = await db.connect();
  try {
    await client.query('BEGIN');

    let subtotal = 0;
    for (const item of items) subtotal += item.unit_price * item.quantity;

    const zone = await client.query('SELECT delivery_fee FROM zones WHERE id=$1', [delivery_zone_id]);
    const delivery_fee = zone.rows[0]?.delivery_fee || 0;
    const total_amount = subtotal + delivery_fee;

    const count = await client.query('SELECT COUNT(*) FROM orders WHERE company_id=$1', [COMPANY_ID]);
    const order_number = `ORD-${new Date().getFullYear()}-${String(parseInt(count.rows[0].count) + 1).padStart(6, '0')}`;

    const order = await client.query(`
      INSERT INTO orders (company_id, order_number, status, customer_name,
        customer_phone, customer_email, delivery_address, delivery_zone_id,
        subtotal, delivery_fee, total_amount, payment_method, payment_status)
      VALUES ($1,$2,'en_attente',$3,$4,$5,$6,$7,$8,$9,$10,$11,'en_attente')
      RETURNING *
    `, [COMPANY_ID, order_number, customer_name, customer_phone,
        customer_email, delivery_address, delivery_zone_id,
        subtotal, delivery_fee, total_amount, payment_method]);

    const orderId = order.rows[0].id;

    for (const item of items) {
      await client.query(`
        INSERT INTO order_items (company_id, order_id, product_id, product_name,
          product_sku, quantity, unit_price, line_total)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
      `, [COMPANY_ID, orderId, item.product_id, item.product_name,
          item.product_sku, item.quantity, item.unit_price,
          item.unit_price * item.quantity]);
    }

    await client.query('COMMIT');
    res.status(201).json(order.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// PATCH /api/commandes/:id/statut
router.patch('/:id/statut', async (req, res) => {
  const { status } = req.body;
  const validStatuts = ['en-attente', 'en_cours', 'livree', 'annulee'];
  if (!validStatuts.includes(status))
    return res.status(400).json({ error: 'Statut invalide.' });
  try {
    const result = await db.query(
      `UPDATE orders SET status=$1, updated_at=NOW() WHERE id=$2 AND company_id=$3 RETURNING *`,
      [status, req.params.id, COMPANY_ID]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
