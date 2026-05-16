-- =============================================================================
-- SEED DATA — PLATEFORME SAAS LOGISTIQUE
-- Données de test fictives — Contexte Cameroun
-- Ordre d'insertion respectant les contraintes FK
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. COMPANIES (3 tenants fictifs)
-- =============================================================================

INSERT INTO companies (id, name, slug, email, phone, address, country,
    subscription_plan, subscription_status, subscription_expires_at,
    max_orders_per_month, max_users, max_products, max_drivers,
    onboarding_completed, timezone, currency)
VALUES
    (
        'aaaaaaaa-0000-4000-a000-000000000001',
        'Douala Express Shop',
        'douala-express',
        'contact@douala-express.cm',
        '+237 699 001 001',
        'Rue de la Joie, Akwa, Douala',
        'Cameroun',
        'pro', 'actif',
        NOW() + INTERVAL '11 months',
        5000, 20, -1, -1,
        TRUE, 'Africa/Douala', 'XAF'
    ),
    (
        'aaaaaaaa-0000-4000-a000-000000000002',
        'Yaoundé Market',
        'yaounde-market',
        'info@yaounde-market.cm',
        '+237 677 002 002',
        'Avenue Kennedy, Centre-ville, Yaoundé',
        'Cameroun',
        'starter', 'actif',
        NOW() + INTERVAL '6 months',
        500, 5, 1000, 3,
        TRUE, 'Africa/Douala', 'XAF'
    ),
    (
        'aaaaaaaa-0000-4000-a000-000000000003',
        'Bafoussam Bio',
        'bafoussam-bio',
        'hello@bafoussam-bio.cm',
        '+237 655 003 003',
        'Quartier Commercial, Bafoussam',
        'Cameroun',
        'gratuit', 'actif',
        NULL,
        50, 2, 100, 0,
        FALSE, 'Africa/Douala', 'XAF'
    );

-- =============================================================================
-- 2. USERS (admin + vendeur + livreur par tenant)
-- Mot de passe fictif : "Test1234!" — bcrypt hash simulé
-- =============================================================================

INSERT INTO users (id, company_id, role, first_name, last_name,
    email, email_hash, phone, password_hash, is_active, language)
VALUES
    -- Tenant 1 : Douala Express
    (
        'bbbbbbbb-0000-4000-b000-000000000001',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'admin', 'Jean-Paul', 'Mbarga',
        'jp.mbarga@douala-express.cm',
        encode(digest('jp.mbarga@douala-express.cm', 'sha256'), 'hex'),
        '+237 699 101 001',
        '$2b$12$simulatedhashforjeanpaulmbarga00001',
        TRUE, 'fr'
    ),
    (
        'bbbbbbbb-0000-4000-b000-000000000002',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'vendeur', 'Carine', 'Fotso',
        'c.fotso@douala-express.cm',
        encode(digest('c.fotso@douala-express.cm', 'sha256'), 'hex'),
        '+237 699 101 002',
        '$2b$12$simulatedhashforcarinefotso0000002',
        TRUE, 'fr'
    ),
    (
        'bbbbbbbb-0000-4000-b000-000000000003',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'livreur', 'Alain', 'Nguema',
        'a.nguema@douala-express.cm',
        encode(digest('a.nguema@douala-express.cm', 'sha256'), 'hex'),
        '+237 699 101 003',
        '$2b$12$simulatedhashforalainguema00000003',
        TRUE, 'fr'
    ),
    (
        'bbbbbbbb-0000-4000-b000-000000000004',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'stock_manager', 'Brigitte', 'Ekwalla',
        'b.ekwalla@douala-express.cm',
        encode(digest('b.ekwalla@douala-express.cm', 'sha256'), 'hex'),
        '+237 699 101 004',
        '$2b$12$simulatedhashforbrigitteekwalla0004',
        TRUE, 'fr'
    ),
    -- Tenant 2 : Yaoundé Market
    (
        'bbbbbbbb-0000-4000-b000-000000000005',
        'aaaaaaaa-0000-4000-a000-000000000002',
        'admin', 'Paul', 'Atangana',
        'p.atangana@yaounde-market.cm',
        encode(digest('p.atangana@yaounde-market.cm', 'sha256'), 'hex'),
        '+237 677 102 001',
        '$2b$12$simulatedhashforpaulatangana000005',
        TRUE, 'fr'
    ),
    (
        'bbbbbbbb-0000-4000-b000-000000000006',
        'aaaaaaaa-0000-4000-a000-000000000002',
        'livreur', 'Samuel', 'Nkomo',
        's.nkomo@yaounde-market.cm',
        encode(digest('s.nkomo@yaounde-market.cm', 'sha256'), 'hex'),
        '+237 677 102 002',
        '$2b$12$simulatedhashforsamuelnkomo000006',
        TRUE, 'fr'
    ),
    -- Tenant 3 : Bafoussam Bio
    (
        'bbbbbbbb-0000-4000-b000-000000000007',
        'aaaaaaaa-0000-4000-a000-000000000003',
        'admin', 'Marie', 'Tchwenko',
        'm.tchwenko@bafoussam-bio.cm',
        encode(digest('m.tchwenko@bafoussam-bio.cm', 'sha256'), 'hex'),
        '+237 655 103 001',
        '$2b$12$simulatedhashformarietchwenko00007',
        TRUE, 'fr'
    );

-- =============================================================================
-- 3. ZONES (zones de livraison par tenant)
-- =============================================================================

INSERT INTO zones (id, company_id, name, description, delivery_fee, is_active)
VALUES
    -- Douala Express
    ('cccccccc-0000-4000-c000-000000000001', 'aaaaaaaa-0000-4000-a000-000000000001',
     'Akwa', 'Centre commercial Akwa et environs', 500, TRUE),
    ('cccccccc-0000-4000-c000-000000000002', 'aaaaaaaa-0000-4000-a000-000000000001',
     'Bonanjo', 'Quartier administratif Bonanjo', 700, TRUE),
    ('cccccccc-0000-4000-c000-000000000003', 'aaaaaaaa-0000-4000-a000-000000000001',
     'Bonapriso', 'Résidentiel Bonapriso', 800, TRUE),
    ('cccccccc-0000-4000-c000-000000000004', 'aaaaaaaa-0000-4000-a000-000000000001',
     'Makepe', 'Makepe et Kotto', 1200, TRUE),
    -- Yaoundé Market
    ('cccccccc-0000-4000-c000-000000000005', 'aaaaaaaa-0000-4000-a000-000000000002',
     'Centre-ville', 'Nlongkak, Mvog-Ada', 600, TRUE),
    ('cccccccc-0000-4000-c000-000000000006', 'aaaaaaaa-0000-4000-a000-000000000002',
     'Bastos', 'Quartier diplomatique Bastos', 1000, TRUE);

-- =============================================================================
-- 4. DRIVER_ZONES (livreurs assignés aux zones)
-- =============================================================================

INSERT INTO driver_zones (driver_id, zone_id, company_id, is_primary)
VALUES
    ('bbbbbbbb-0000-4000-b000-000000000003', 'cccccccc-0000-4000-c000-000000000001',
     'aaaaaaaa-0000-4000-a000-000000000001', TRUE),
    ('bbbbbbbb-0000-4000-b000-000000000003', 'cccccccc-0000-4000-c000-000000000002',
     'aaaaaaaa-0000-4000-a000-000000000001', FALSE),
    ('bbbbbbbb-0000-4000-b000-000000000006', 'cccccccc-0000-4000-c000-000000000005',
     'aaaaaaaa-0000-4000-a000-000000000002', TRUE),
    ('bbbbbbbb-0000-4000-b000-000000000006', 'cccccccc-0000-4000-c000-000000000006',
     'aaaaaaaa-0000-4000-a000-000000000002', FALSE);

-- =============================================================================
-- 5. PRODUCTS (catalogue Douala Express)
-- =============================================================================

INSERT INTO products (id, company_id, name, description, sku, category,
    unit, base_price, stock_quantity, stock_alert_threshold,
    is_active, has_variants, created_by)
VALUES
    (
        'dddddddd-0000-4000-d000-000000000001',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'Huile de palme raffinée 1L',
        'Huile de palme de qualité supérieure, conditionnée en bouteille 1 litre.',
        'HUI-PALM-1L', 'Alimentation', 'bouteille',
        1500, 200, 20, TRUE, FALSE,
        'bbbbbbbb-0000-4000-b000-000000000001'
    ),
    (
        'dddddddd-0000-4000-d000-000000000002',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'Savon de ménage 400g',
        'Savon de lessive artisanal, parfum naturel.',
        'SAV-MEN-400', 'Hygiène', 'pièce',
        350, 500, 50, TRUE, TRUE,
        'bbbbbbbb-0000-4000-b000-000000000001'
    ),
    (
        'dddddddd-0000-4000-d000-000000000003',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'Riz local 5kg',
        'Riz paddy décortiqué, production locale Ndop.',
        'RIZ-LOC-5KG', 'Alimentation', 'sac',
        4500, 80, 10, TRUE, FALSE,
        'bbbbbbbb-0000-4000-b000-000000000001'
    ),
    (
        'dddddddd-0000-4000-d000-000000000004',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'Tomate fraîche (cagette)',
        'Tomates fraîches de Bafoussam, cagette de 10kg.',
        'TOM-FRA-CAG', 'Légumes', 'cagette',
        3500, 30, 5, TRUE, FALSE,
        'bbbbbbbb-0000-4000-b000-000000000001'
    ),
    (
        'dddddddd-0000-4000-d000-000000000005',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'Poulet fermier entier',
        'Poulet élevé en plein air, poids moyen 1,5kg.',
        'POU-FER-ENT', 'Viande & Poisson', 'pièce',
        5500, 3, 5, TRUE, FALSE,
        'bbbbbbbb-0000-4000-b000-000000000001'
    ),
    -- Produits Yaoundé Market
    (
        'dddddddd-0000-4000-d000-000000000006',
        'aaaaaaaa-0000-4000-a000-000000000002',
        'Café arabica moulu 250g',
        'Café des hauts plateaux de l\'Ouest, torréfaction artisanale.',
        'CAF-ARA-250', 'Boissons', 'paquet',
        2800, 60, 10, TRUE, FALSE,
        'bbbbbbbb-0000-4000-b000-000000000005'
    ),
    (
        'dddddddd-0000-4000-d000-000000000007',
        'aaaaaaaa-0000-4000-a000-000000000002',
        'Miel pur de forêt 500g',
        'Miel récolté en forêt équatoriale, non traité.',
        'MIE-FOR-500', 'Alimentation', 'pot',
        4200, 25, 5, TRUE, FALSE,
        'bbbbbbbb-0000-4000-b000-000000000005'
    );

-- =============================================================================
-- 6. PRODUCT_VARIANTS (variantes du savon)
-- =============================================================================

INSERT INTO product_variants (id, company_id, product_id, name, sku,
    attributes, price_adjustment, stock_quantity, is_active)
VALUES
    (
        'eeeeeeee-0000-4000-e000-000000000001',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'dddddddd-0000-4000-d000-000000000002',
        'Savon citron 400g',
        'SAV-MEN-400-CIT',
        '{"parfum": "citron"}',
        0, 200, TRUE
    ),
    (
        'eeeeeeee-0000-4000-e000-000000000002',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'dddddddd-0000-4000-d000-000000000002',
        'Savon lavande 400g',
        'SAV-MEN-400-LAV',
        '{"parfum": "lavande"}',
        50, 300, TRUE
    );

-- =============================================================================
-- 7. ORDERS (commandes Douala Express)
-- =============================================================================

INSERT INTO orders (id, company_id, order_number, status,
    customer_name, customer_phone, customer_email,
    delivery_address, delivery_zone_id, delivery_lat, delivery_lng,
    subtotal, delivery_fee, discount_amount, tax_amount, total_amount,
    payment_method, payment_status, paid_at,
    sale_channel, confirmed_at, delivered_at, created_by)
VALUES
    (
        'ffffffff-0000-4000-f000-000000000001',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'ORD-2026-000001', 'livree',
        'Ngono Béatrice', '+237 699 200 001', 'b.ngono@gmail.com',
        '12 Rue des Flamboyants, Akwa, Douala',
        'cccccccc-0000-4000-c000-000000000001',
        4.05660, 9.72490,
        7500, 500, 0, 0, 8000,
        'mobile_money', 'paye', NOW() - INTERVAL '5 days',
        'mobile', NOW() - INTERVAL '6 days', NOW() - INTERVAL '5 days',
        'bbbbbbbb-0000-4000-b000-000000000002'
    ),
    (
        'ffffffff-0000-4000-f000-000000000002',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'ORD-2026-000002', 'expediee',
        'Tchamba Roger', '+237 699 200 002', NULL,
        'Avenue de la Liberté, Bonanjo, Douala',
        'cccccccc-0000-4000-c000-000000000002',
        4.04820, 9.71560,
        9000, 700, 500, 0, 9200,
        'cash_livraison', 'en_attente', NULL,
        'manuel', NOW() - INTERVAL '1 day', NULL,
        'bbbbbbbb-0000-4000-b000-000000000002'
    ),
    (
        'ffffffff-0000-4000-f000-000000000003',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'ORD-2026-000003', 'confirmee',
        'Essomba Clarisse', '+237 699 200 003', 'c.essomba@yahoo.fr',
        'Résidence Les Bougainvilliers, Bonapriso, Douala',
        'cccccccc-0000-4000-c000-000000000003',
        4.03940, 9.70810,
        5500, 800, 0, 0, 6300,
        'mobile_money', 'paye', NOW() - INTERVAL '2 hours',
        'web', NOW() - INTERVAL '2 hours', NULL,
        'bbbbbbbb-0000-4000-b000-000000000002'
    ),
    (
        'ffffffff-0000-4000-f000-000000000004',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'ORD-2026-000004', 'brouillon',
        'Manga Eric', '+237 699 200 004', NULL,
        'Rue Joss, Akwa, Douala',
        'cccccccc-0000-4000-c000-000000000001',
        4.05100, 9.72100,
        4500, 500, 0, 0, 5000,
        NULL, 'en_attente', NULL,
        'manuel', NULL, NULL,
        'bbbbbbbb-0000-4000-b000-000000000002'
    ),
    -- Tenant 2
    (
        'ffffffff-0000-4000-f000-000000000005',
        'aaaaaaaa-0000-4000-a000-000000000002',
        'ORD-2026-000001', 'livree',
        'Owona Sylvie', '+237 677 300 001', 's.owona@gmail.com',
        'Rue Nachtigal, Centre-ville, Yaoundé',
        'cccccccc-0000-4000-c000-000000000005',
        3.86600, 11.51720,
        7000, 600, 0, 0, 7600,
        'mobile_money', 'paye', NOW() - INTERVAL '3 days',
        'web', NOW() - INTERVAL '4 days', NOW() - INTERVAL '3 days',
        'bbbbbbbb-0000-4000-b000-000000000005'
    );

-- =============================================================================
-- 8. ORDER_ITEMS
-- =============================================================================

INSERT INTO order_items (id, company_id, order_id, product_id, variant_id,
    product_name, product_sku, quantity, unit_price, discount_rate, line_total)
VALUES
    -- Commande 1
    ('11111111-0000-4000-1000-000000000001', 'aaaaaaaa-0000-4000-a000-000000000001',
     'ffffffff-0000-4000-f000-000000000001', 'dddddddd-0000-4000-d000-000000000001', NULL,
     'Huile de palme raffinée 1L', 'HUI-PALM-1L', 3, 1500, 0, 4500),
    ('11111111-0000-4000-1000-000000000002', 'aaaaaaaa-0000-4000-a000-000000000001',
     'ffffffff-0000-4000-f000-000000000001', 'dddddddd-0000-4000-d000-000000000002',
     'eeeeeeee-0000-4000-e000-000000000001',
     'Savon citron 400g', 'SAV-MEN-400-CIT', 9, 350, 0, 3150),
    -- Commande 2
    ('11111111-0000-4000-1000-000000000003', 'aaaaaaaa-0000-4000-a000-000000000001',
     'ffffffff-0000-4000-f000-000000000002', 'dddddddd-0000-4000-d000-000000000003', NULL,
     'Riz local 5kg', 'RIZ-LOC-5KG', 2, 4500, 0, 9000),
    -- Commande 3
    ('11111111-0000-4000-1000-000000000004', 'aaaaaaaa-0000-4000-a000-000000000001',
     'ffffffff-0000-4000-f000-000000000003', 'dddddddd-0000-4000-d000-000000000005', NULL,
     'Poulet fermier entier', 'POU-FER-ENT', 1, 5500, 0, 5500),
    -- Commande 4
    ('11111111-0000-4000-1000-000000000005', 'aaaaaaaa-0000-4000-a000-000000000001',
     'ffffffff-0000-4000-f000-000000000004', 'dddddddd-0000-4000-d000-000000000004', NULL,
     'Tomate fraîche (cagette)', 'TOM-FRA-CAG', 1, 3500, 0, 3500),
    -- Commande 5 (Tenant 2)
    ('11111111-0000-4000-1000-000000000006', 'aaaaaaaa-0000-4000-a000-000000000002',
     'ffffffff-0000-4000-f000-000000000005', 'dddddddd-0000-4000-d000-000000000006', NULL,
     'Café arabica moulu 250g', 'CAF-ARA-250', 1, 2800, 0, 2800),
    ('11111111-0000-4000-1000-000000000007', 'aaaaaaaa-0000-4000-a000-000000000002',
     'ffffffff-0000-4000-f000-000000000005', 'dddddddd-0000-4000-d000-000000000007', NULL,
     'Miel pur de forêt 500g', 'MIE-FOR-500', 1, 4200, 0, 4200);

-- =============================================================================
-- 9. DELIVERIES
-- =============================================================================

INSERT INTO deliveries (id, company_id, order_id, driver_id, zone_id, status,
    confirmation_code, delivered_at, created_at)
VALUES
    (
        '22222222-0000-4000-2000-000000000001',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'ffffffff-0000-4000-f000-000000000001',
        'bbbbbbbb-0000-4000-b000-000000000003',
        'cccccccc-0000-4000-c000-000000000001',
        'livree', '482916',
        NOW() - INTERVAL '5 days',
        NOW() - INTERVAL '6 days'
    ),
    (
        '22222222-0000-4000-2000-000000000002',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'ffffffff-0000-4000-f000-000000000002',
        'bbbbbbbb-0000-4000-b000-000000000003',
        'cccccccc-0000-4000-c000-000000000002',
        'en_cours', '739201',
        NULL,
        NOW() - INTERVAL '4 hours'
    );

-- =============================================================================
-- 10. STOCK_MOVEMENTS (mouvements liés aux commandes livrées)
-- =============================================================================

INSERT INTO stock_movements (id, company_id, product_id, movement_type,
    quantity_delta, quantity_before, quantity_after,
    reference_type, reference_id, reason, created_by, created_at)
VALUES
    (
        '33333333-0000-4000-3000-000000000001',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'dddddddd-0000-4000-d000-000000000001',
        'entree', 300, 0, 300,
        'inventory', NULL, 'Stock initial — mise en place',
        'bbbbbbbb-0000-4000-b000-000000000004',
        NOW() - INTERVAL '30 days'
    ),
    (
        '33333333-0000-4000-3000-000000000002',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'dddddddd-0000-4000-d000-000000000001',
        'sortie', -3, 203, 200,
        'order', 'ffffffff-0000-4000-f000-000000000001',
        'Vente commande ORD-2026-000001',
        'bbbbbbbb-0000-4000-b000-000000000004',
        NOW() - INTERVAL '5 days'
    ),
    (
        '33333333-0000-4000-3000-000000000003',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'dddddddd-0000-4000-d000-000000000005',
        'entree', 10, 0, 10,
        'inventory', NULL, 'Stock initial poulets',
        'bbbbbbbb-0000-4000-b000-000000000004',
        NOW() - INTERVAL '7 days'
    ),
    (
        '33333333-0000-4000-3000-000000000004',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'dddddddd-0000-4000-d000-000000000005',
        'sortie', -7, 10, 3,
        'order', NULL, 'Ventes de la semaine',
        'bbbbbbbb-0000-4000-b000-000000000004',
        NOW() - INTERVAL '2 days'
    );

-- =============================================================================
-- 11. SUBSCRIPTIONS
-- =============================================================================

INSERT INTO subscriptions (id, company_id, plan, status, billing_cycle,
    amount, currency, started_at, expires_at, payment_method, payment_reference)
VALUES
    (
        '44444444-0000-4000-4000-000000000001',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'pro', 'actif', 'annual',
        450000, 'XAF',
        NOW() - INTERVAL '1 month',
        NOW() + INTERVAL '11 months',
        'mobile_money', 'MOMO-2026-04-REF00001'
    ),
    (
        '44444444-0000-4000-4000-000000000002',
        'aaaaaaaa-0000-4000-a000-000000000002',
        'starter', 'actif', 'monthly',
        15000, 'XAF',
        NOW() - INTERVAL '15 days',
        NOW() + INTERVAL '15 days',
        'mobile_money', 'MOMO-2026-04-REF00002'
    );

-- =============================================================================
-- 12. INVOICES
-- =============================================================================

INSERT INTO invoices (id, company_id, invoice_number, status, invoice_type,
    order_id, client_name, client_email, client_phone,
    subtotal, tax_rate, tax_amount, total_amount,
    issued_at, paid_at)
VALUES
    (
        '55555555-0000-4000-5000-000000000001',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'FACT-2026-000001', 'payee', 'commande',
        'ffffffff-0000-4000-f000-000000000001',
        'Ngono Béatrice', 'b.ngono@gmail.com', '+237 699 200 001',
        7500, 0, 0, 8000,
        NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days'
    ),
    (
        '55555555-0000-4000-5000-000000000002',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'FACT-2026-000002', 'emise', 'commande',
        'ffffffff-0000-4000-f000-000000000002',
        'Tchamba Roger', NULL, '+237 699 200 002',
        9000, 0, 0, 9200,
        NOW() - INTERVAL '1 day', NULL
    );

-- =============================================================================
-- 13. NOTIFICATIONS
-- =============================================================================

INSERT INTO notifications (id, company_id, user_id, type, title, body,
    reference_id, is_read, created_at)
VALUES
    (
        '66666666-0000-4000-6000-000000000001',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'bbbbbbbb-0000-4000-b000-000000000001',
        'commande', 'Nouvelle commande reçue',
        'La commande ORD-2026-000003 vient d''être confirmée.',
        'ffffffff-0000-4000-f000-000000000003',
        FALSE, NOW() - INTERVAL '2 hours'
    ),
    (
        '66666666-0000-4000-6000-000000000002',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'bbbbbbbb-0000-4000-b000-000000000004',
        'stock', 'Stock critique : Poulet fermier',
        'Le produit "Poulet fermier entier" est sous le seuil d''alerte (3 restants).',
        'dddddddd-0000-4000-d000-000000000005',
        FALSE, NOW() - INTERVAL '2 days'
    ),
    (
        '66666666-0000-4000-6000-000000000003',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'bbbbbbbb-0000-4000-b000-000000000003',
        'livraison', 'Livraison assignée',
        'La commande ORD-2026-000002 vous a été assignée pour livraison.',
        'ffffffff-0000-4000-f000-000000000002',
        TRUE, NOW() - INTERVAL '1 day'
    );

-- =============================================================================
-- 14. AUDIT_LOGS
-- =============================================================================

INSERT INTO audit_logs (id, company_id, user_id, action, resource_type,
    resource_id, new_values, ip_address, created_at)
VALUES
    (
        '77777777-0000-4000-7000-000000000001',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'bbbbbbbb-0000-4000-b000-000000000001',
        'LOGIN', 'session', NULL,
        '{"success": true}',
        '197.159.45.12',
        NOW() - INTERVAL '6 hours'
    ),
    (
        '77777777-0000-4000-7000-000000000002',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'bbbbbbbb-0000-4000-b000-000000000002',
        'CREATE', 'order',
        'ffffffff-0000-4000-f000-000000000003',
        '{"order_number": "ORD-2026-000003", "status": "confirmee"}',
        '41.202.207.88',
        NOW() - INTERVAL '2 hours'
    ),
    (
        '77777777-0000-4000-7000-000000000003',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'bbbbbbbb-0000-4000-b000-000000000004',
        'UPDATE', 'product',
        'dddddddd-0000-4000-d000-000000000005',
        '{"stock_quantity": 3}',
        '41.202.207.90',
        NOW() - INTERVAL '2 days'
    );

-- =============================================================================
-- 15. WEBHOOKS
-- =============================================================================

INSERT INTO webhooks (id, company_id, name, url, secret, events, is_active)
VALUES
    (
        '88888888-0000-4000-8000-000000000001',
        'aaaaaaaa-0000-4000-a000-000000000001',
        'ERP Douala Express',
        'https://erp.douala-express.cm/webhooks/commandes',
        'wh_secret_doex_abc123xyz789',
        ARRAY['order.created', 'order.delivered', 'order.cancelled']::webhook_event[],
        TRUE
    );

COMMIT;

-- =============================================================================
-- VÉRIFICATION RAPIDE
-- =============================================================================
SELECT 'companies'      AS table_name, COUNT(*) AS lignes FROM companies
UNION ALL SELECT 'users',           COUNT(*) FROM users
UNION ALL SELECT 'zones',           COUNT(*) FROM zones
UNION ALL SELECT 'products',        COUNT(*) FROM products
UNION ALL SELECT 'product_variants',COUNT(*) FROM product_variants
UNION ALL SELECT 'orders',          COUNT(*) FROM orders
UNION ALL SELECT 'order_items',     COUNT(*) FROM order_items
UNION ALL SELECT 'deliveries',      COUNT(*) FROM deliveries
UNION ALL SELECT 'stock_movements', COUNT(*) FROM stock_movements
UNION ALL SELECT 'subscriptions',   COUNT(*) FROM subscriptions
UNION ALL SELECT 'invoices',        COUNT(*) FROM invoices
UNION ALL SELECT 'notifications',   COUNT(*) FROM notifications
UNION ALL SELECT 'audit_logs',      COUNT(*) FROM audit_logs
UNION ALL SELECT 'webhooks',        COUNT(*) FROM webhooks
ORDER BY table_name;
