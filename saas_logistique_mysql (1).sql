-- ============================================================
-- PLATEFORME SAAS LOGISTIQUE / E-COMMERCE
-- MySQL 8.0 — Compatible WampServer
-- Multi-tenant : base partagée + company_id sur chaque table
-- ============================================================

SET NAMES utf8;
SET FOREIGN_KEY_CHECKS = 0;
SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';

CREATE DATABASE IF NOT EXISTS saas_logistique
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE saas_logistique;

-- ============================================================
-- companies — tenants de la plateforme
-- ============================================================

CREATE TABLE companies (
    id                      CHAR(36)        NOT NULL DEFAULT (UUID()),
    name                    VARCHAR(200)    NOT NULL,
    slug                    VARCHAR(100)    NOT NULL,
    email                   VARCHAR(255)    NOT NULL,
    phone                   VARCHAR(30),
    address                 TEXT,
    country                 VARCHAR(100)    NOT NULL DEFAULT 'Cameroun',
    logo_url                VARCHAR(500),
    subscription_plan       ENUM('gratuit','starter','pro','enterprise') NOT NULL DEFAULT 'gratuit',
    subscription_status     ENUM('actif','suspendu','expire','annule')   NOT NULL DEFAULT 'actif',
    subscription_expires_at DATETIME,
    max_orders_per_month    INT             NOT NULL DEFAULT 50,
    max_users               INT             NOT NULL DEFAULT 2,
    max_products            INT             NOT NULL DEFAULT 100,
    max_drivers             INT             NOT NULL DEFAULT 0,
    onboarding_completed    TINYINT(1)      NOT NULL DEFAULT 0,
    timezone                VARCHAR(50)     NOT NULL DEFAULT 'Africa/Douala',
    currency                CHAR(3)         NOT NULL DEFAULT 'XAF',
    deleted_at              DATETIME,
    created_at              DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_companies_slug  (slug),
    UNIQUE KEY uq_companies_email (email),
    KEY idx_companies_plan (subscription_plan)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- users — utilisateurs multi-rôles
-- ============================================================

CREATE TABLE users (
    id                       CHAR(36)     NOT NULL DEFAULT (UUID()),
    company_id               CHAR(36),
    role                     ENUM('super_admin','admin','vendeur','stock_manager','livreur','client')
                                          NOT NULL DEFAULT 'vendeur',
    first_name               VARCHAR(100) NOT NULL,
    last_name                VARCHAR(100) NOT NULL,
    email                    VARCHAR(255) NOT NULL,
    email_hash               CHAR(64)     NOT NULL,
    phone                    VARCHAR(30),
    password_hash            VARCHAR(255) NOT NULL,
    is_active                TINYINT(1)   NOT NULL DEFAULT 1,
    failed_login_attempts    TINYINT      NOT NULL DEFAULT 0,
    locked_until             DATETIME,
    last_login_at            DATETIME,
    last_login_ip            VARCHAR(45),
    refresh_token_hash       CHAR(64),
    refresh_token_expires_at DATETIME,
    reset_token_hash         CHAR(64),
    reset_token_expires_at   DATETIME,
    language                 CHAR(2)      NOT NULL DEFAULT 'fr',
    avatar_url               VARCHAR(500),
    deleted_at               DATETIME,
    created_at               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by               CHAR(36),
    updated_by               CHAR(36),
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_email_company (email_hash, company_id),
    KEY idx_users_company (company_id),
    KEY idx_users_role    (company_id, role),
    KEY idx_users_locked  (locked_until),
    CONSTRAINT fk_users_company    FOREIGN KEY (company_id)  REFERENCES companies(id) ON DELETE CASCADE,
    CONSTRAINT fk_users_created_by FOREIGN KEY (created_by)  REFERENCES users(id),
    CONSTRAINT fk_users_updated_by FOREIGN KEY (updated_by)  REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- zones — zones géographiques de livraison
-- ============================================================

CREATE TABLE zones (
    id            CHAR(36)       NOT NULL DEFAULT (UUID()),
    company_id    CHAR(36)       NOT NULL,
    name          VARCHAR(100)   NOT NULL,
    description   TEXT,
    geojson       JSON,
    delivery_fee  DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
    is_active     TINYINT(1)     NOT NULL DEFAULT 1,
    created_at    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_zones_company_name (company_id, name),
    KEY idx_zones_company (company_id),
    CONSTRAINT fk_zones_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- products — catalogue produits
-- ============================================================

CREATE TABLE products (
    id                    CHAR(36)      NOT NULL DEFAULT (UUID()),
    company_id            CHAR(36)      NOT NULL,
    name                  VARCHAR(300)  NOT NULL,
    description           TEXT,
    sku                   VARCHAR(100),
    barcode               VARCHAR(50),
    category              VARCHAR(100),
    unit                  VARCHAR(30)   NOT NULL DEFAULT 'unité',
    base_price            DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    stock_quantity        INT           NOT NULL DEFAULT 0,
    stock_alert_threshold INT           NOT NULL DEFAULT 5,
    tiered_prices         JSON,
    image_url             VARCHAR(500),
    is_active             TINYINT(1)    NOT NULL DEFAULT 1,
    has_variants          TINYINT(1)    NOT NULL DEFAULT 0,
    deleted_at            DATETIME,
    created_at            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by            CHAR(36),
    updated_by            CHAR(36),
    PRIMARY KEY (id),
    UNIQUE KEY uq_products_company_sku (company_id, sku),
    KEY idx_products_company  (company_id),
    KEY idx_products_barcode  (company_id, barcode),
    KEY idx_products_stock    (company_id, stock_quantity),
    FULLTEXT KEY ft_products_name (name),
    CONSTRAINT fk_products_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- product_variants — déclinaisons (taille, couleur, etc.)
-- ============================================================

CREATE TABLE product_variants (
    id               CHAR(36)      NOT NULL DEFAULT (UUID()),
    company_id       CHAR(36)      NOT NULL,
    product_id       CHAR(36)      NOT NULL,
    name             VARCHAR(200)  NOT NULL,
    sku              VARCHAR(100),
    barcode          VARCHAR(50),
    attributes       JSON          NOT NULL,
    price_adjustment DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    stock_quantity   INT           NOT NULL DEFAULT 0,
    is_active        TINYINT(1)    NOT NULL DEFAULT 1,
    created_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_variants_product (product_id),
    KEY idx_variants_barcode (company_id, barcode),
    CONSTRAINT fk_variants_product FOREIGN KEY (product_id)  REFERENCES products(id)  ON DELETE CASCADE,
    CONSTRAINT fk_variants_company FOREIGN KEY (company_id)  REFERENCES companies(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- orders — commandes clients
-- ============================================================

CREATE TABLE orders (
    id               CHAR(36)     NOT NULL DEFAULT (UUID()),
    company_id       CHAR(36)     NOT NULL,
    order_number     VARCHAR(50)  NOT NULL,
    status           ENUM('brouillon','confirmee','preparee','expediee',
                          'livree','echec_livraison','annulee','remboursee')
                                  NOT NULL DEFAULT 'brouillon',
    customer_name    VARCHAR(200) NOT NULL,
    customer_phone   VARCHAR(30)  NOT NULL,
    customer_email   VARCHAR(255),
    delivery_address TEXT         NOT NULL,
    delivery_zone_id CHAR(36),
    delivery_notes   TEXT,
    delivery_lat     DECIMAL(10,8),
    delivery_lng     DECIMAL(11,8),
    subtotal         DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    delivery_fee     DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    discount_amount  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    tax_amount       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_amount     DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    payment_method   ENUM('cash_livraison','mobile_money','virement','carte'),
    payment_status   ENUM('en_attente','paye','echoue','rembourse') NOT NULL DEFAULT 'en_attente',
    paid_at          DATETIME,
    sale_channel     VARCHAR(50)  NOT NULL DEFAULT 'manuel',
    confirmed_at     DATETIME,
    prepared_at      DATETIME,
    shipped_at       DATETIME,
    delivered_at     DATETIME,
    cancelled_at     DATETIME,
    internal_notes   TEXT,
    deleted_at       DATETIME,
    created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by       CHAR(36),
    updated_by       CHAR(36),
    PRIMARY KEY (id),
    UNIQUE KEY uq_orders_number (company_id, order_number),
    KEY idx_orders_company_status  (company_id, status),
    KEY idx_orders_company_created (company_id, created_at),
    KEY idx_orders_customer_phone  (company_id, customer_phone),
    CONSTRAINT fk_orders_company  FOREIGN KEY (company_id)       REFERENCES companies(id) ON DELETE CASCADE,
    CONSTRAINT fk_orders_zone     FOREIGN KEY (delivery_zone_id) REFERENCES zones(id),
    CONSTRAINT chk_orders_total   CHECK (total_amount >= 0 AND subtotal >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- order_items — lignes de commande (prix figés à la vente)
-- ============================================================

CREATE TABLE order_items (
    id           CHAR(36)      NOT NULL DEFAULT (UUID()),
    company_id   CHAR(36)      NOT NULL,
    order_id     CHAR(36)      NOT NULL,
    product_id   CHAR(36)      NOT NULL,
    variant_id   CHAR(36),
    product_name VARCHAR(300)  NOT NULL,
    product_sku  VARCHAR(100),
    quantity     INT           NOT NULL,
    unit_price   DECIMAL(15,2) NOT NULL,
    discount_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    line_total   DECIMAL(15,2) NOT NULL,
    created_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_order_items_order   (order_id),
    KEY idx_order_items_product (company_id, product_id),
    CONSTRAINT fk_items_order   FOREIGN KEY (order_id)   REFERENCES orders(id)           ON DELETE CASCADE,
    CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products(id),
    CONSTRAINT fk_items_variant FOREIGN KEY (variant_id) REFERENCES product_variants(id),
    CONSTRAINT fk_items_company FOREIGN KEY (company_id) REFERENCES companies(id)         ON DELETE CASCADE,
    CONSTRAINT chk_items_qty    CHECK (quantity > 0),
    CONSTRAINT chk_items_price  CHECK (unit_price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- order_events — journal append-only des événements commande
-- ============================================================

CREATE TABLE order_events (
    id          CHAR(36)     NOT NULL DEFAULT (UUID()),
    company_id  CHAR(36)     NOT NULL,
    order_id    CHAR(36)     NOT NULL,
    event_type  VARCHAR(100) NOT NULL,
    old_status  ENUM('brouillon','confirmee','preparee','expediee',
                     'livree','echec_livraison','annulee','remboursee'),
    new_status  ENUM('brouillon','confirmee','preparee','expediee',
                     'livree','echec_livraison','annulee','remboursee'),
    description TEXT,
    metadata    JSON,
    created_by  CHAR(36),
    created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_order_events_order   (order_id, created_at),
    KEY idx_order_events_company (company_id, created_at),
    CONSTRAINT fk_events_order   FOREIGN KEY (order_id)   REFERENCES orders(id)    ON DELETE CASCADE,
    CONSTRAINT fk_events_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
    CONSTRAINT fk_events_user    FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- deliveries — livraisons avec GPS et preuve de livraison
-- ============================================================

CREATE TABLE deliveries (
    id                      CHAR(36)     NOT NULL DEFAULT (UUID()),
    company_id              CHAR(36)     NOT NULL,
    order_id                CHAR(36)     NOT NULL,
    driver_id               CHAR(36),
    zone_id                 CHAR(36),
    status                  ENUM('en_attente','assignee','en_cours','livree','echec','retournee')
                                         NOT NULL DEFAULT 'en_attente',
    driver_lat              DECIMAL(10,8),
    driver_lng              DECIMAL(11,8),
    position_updated_at     DATETIME,
    estimated_arrival_at    DATETIME,
    proof_photo_url         VARCHAR(500),
    proof_signature_url     VARCHAR(500),
    confirmation_code       CHAR(6),
    geolocation_at_delivery JSON,
    delivered_at            DATETIME,
    failure_reason          TEXT,
    is_return               TINYINT(1)   NOT NULL DEFAULT 0,
    return_reason           TEXT,
    return_item_condition   ENUM('bon','abime','detruit'),
    distance_km             DECIMAL(8,2),
    notes                   TEXT,
    created_at              DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_deliveries_order          (order_id),
    KEY idx_deliveries_driver_status  (driver_id, status),
    KEY idx_deliveries_company_status (company_id, status, created_at),
    CONSTRAINT fk_deliveries_order   FOREIGN KEY (order_id)   REFERENCES orders(id)    ON DELETE CASCADE,
    CONSTRAINT fk_deliveries_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
    CONSTRAINT fk_deliveries_driver  FOREIGN KEY (driver_id)  REFERENCES users(id),
    CONSTRAINT fk_deliveries_zone    FOREIGN KEY (zone_id)    REFERENCES zones(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- driver_zones — affectation livreur ↔ zone (N-N)
-- ============================================================

CREATE TABLE driver_zones (
    driver_id  CHAR(36)   NOT NULL,
    zone_id    CHAR(36)   NOT NULL,
    company_id CHAR(36)   NOT NULL,
    is_primary TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (driver_id, zone_id),
    KEY idx_driver_zones_zone (zone_id, company_id),
    CONSTRAINT fk_dz_driver  FOREIGN KEY (driver_id)  REFERENCES users(id)      ON DELETE CASCADE,
    CONSTRAINT fk_dz_zone    FOREIGN KEY (zone_id)    REFERENCES zones(id)      ON DELETE CASCADE,
    CONSTRAINT fk_dz_company FOREIGN KEY (company_id) REFERENCES companies(id)  ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- stock_movements — journal des mouvements de stock
-- ============================================================

CREATE TABLE stock_movements (
    id              CHAR(36)     NOT NULL DEFAULT (UUID()),
    company_id      CHAR(36)     NOT NULL,
    product_id      CHAR(36)     NOT NULL,
    variant_id      CHAR(36),
    movement_type   ENUM('entree','sortie','ajustement','retour','inventaire') NOT NULL,
    quantity_delta  INT          NOT NULL,
    quantity_before INT          NOT NULL,
    quantity_after  INT          NOT NULL,
    reference_type  VARCHAR(50),
    reference_id    CHAR(36),
    reason          TEXT,
    created_by      CHAR(36),
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_stock_product (product_id, created_at),
    KEY idx_stock_company (company_id, created_at),
    CONSTRAINT fk_stock_product FOREIGN KEY (product_id) REFERENCES products(id),
    CONSTRAINT fk_stock_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
    CONSTRAINT fk_stock_variant FOREIGN KEY (variant_id) REFERENCES product_variants(id),
    CONSTRAINT fk_stock_user    FOREIGN KEY (created_by) REFERENCES users(id),
    CONSTRAINT chk_stock_after  CHECK (quantity_after >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- subscriptions — abonnements SaaS des commerçants
-- ============================================================

CREATE TABLE subscriptions (
    id                CHAR(36)      NOT NULL DEFAULT (UUID()),
    company_id        CHAR(36)      NOT NULL,
    plan              ENUM('gratuit','starter','pro','enterprise') NOT NULL,
    status            ENUM('actif','suspendu','expire','annule')   NOT NULL DEFAULT 'actif',
    billing_cycle     ENUM('monthly','annual')                     NOT NULL DEFAULT 'monthly',
    amount            DECIMAL(12,2) NOT NULL,
    currency          CHAR(3)       NOT NULL DEFAULT 'XAF',
    started_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at        DATETIME      NOT NULL,
    cancelled_at      DATETIME,
    payment_method    ENUM('cash_livraison','mobile_money','virement','carte'),
    payment_reference VARCHAR(200),
    created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_subscriptions_company (company_id, status),
    KEY idx_subscriptions_expires (expires_at),
    CONSTRAINT fk_subscriptions_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- invoices — factures (commandes + abonnements)
-- ============================================================

CREATE TABLE invoices (
    id              CHAR(36)      NOT NULL DEFAULT (UUID()),
    company_id      CHAR(36)      NOT NULL,
    invoice_number  VARCHAR(50)   NOT NULL,
    status          ENUM('brouillon','emise','payee','annulee') NOT NULL DEFAULT 'brouillon',
    invoice_type    ENUM('commande','abonnement','avoir')       NOT NULL DEFAULT 'commande',
    order_id        CHAR(36),
    subscription_id CHAR(36),
    client_name     VARCHAR(200)  NOT NULL,
    client_email    VARCHAR(255),
    client_phone    VARCHAR(30),
    client_address  TEXT,
    subtotal        DECIMAL(15,2) NOT NULL,
    tax_rate        DECIMAL(5,2)  NOT NULL DEFAULT 0.00,
    tax_amount      DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    total_amount    DECIMAL(15,2) NOT NULL,
    pdf_url         VARCHAR(500),
    issued_at       DATETIME,
    due_at          DATETIME,
    paid_at         DATETIME,
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_invoices_number (company_id, invoice_number),
    KEY idx_invoices_company (company_id, status, issued_at),
    KEY idx_invoices_order   (order_id),
    CONSTRAINT fk_invoices_company      FOREIGN KEY (company_id)      REFERENCES companies(id)     ON DELETE CASCADE,
    CONSTRAINT fk_invoices_order        FOREIGN KEY (order_id)        REFERENCES orders(id),
    CONSTRAINT fk_invoices_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- notifications — centre de notifications in-app
-- ============================================================

CREATE TABLE notifications (
    id           CHAR(36)     NOT NULL DEFAULT (UUID()),
    company_id   CHAR(36)     NOT NULL,
    user_id      CHAR(36)     NOT NULL,
    type         ENUM('commande','stock','livraison','paiement','systeme','alerte') NOT NULL,
    title        VARCHAR(200) NOT NULL,
    body         TEXT,
    context_url  VARCHAR(500),
    reference_id CHAR(36),
    is_read      TINYINT(1)   NOT NULL DEFAULT 0,
    read_at      DATETIME,
    created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_notifications_unread (user_id, is_read, created_at),
    KEY idx_notifications_user   (user_id, created_at),
    CONSTRAINT fk_notifications_user    FOREIGN KEY (user_id)    REFERENCES users(id)      ON DELETE CASCADE,
    CONSTRAINT fk_notifications_company FOREIGN KEY (company_id) REFERENCES companies(id)  ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- webhooks — endpoints d'intégration tierces
-- ============================================================

CREATE TABLE webhooks (
    id                 CHAR(36)     NOT NULL DEFAULT (UUID()),
    company_id         CHAR(36)     NOT NULL,
    name               VARCHAR(100) NOT NULL,
    url                VARCHAR(500) NOT NULL,
    secret             VARCHAR(255) NOT NULL,
    events             JSON         NOT NULL,
    is_active          TINYINT(1)   NOT NULL DEFAULT 1,
    last_triggered_at  DATETIME,
    last_success_at    DATETIME,
    last_failure_at    DATETIME,
    failure_count      INT          NOT NULL DEFAULT 0,
    created_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_webhooks_company (company_id, is_active),
    CONSTRAINT fk_webhooks_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- webhook_deliveries — journal des appels webhook
-- ============================================================

CREATE TABLE webhook_deliveries (
    id            CHAR(36)     NOT NULL DEFAULT (UUID()),
    webhook_id    CHAR(36)     NOT NULL,
    company_id    CHAR(36)     NOT NULL,
    event_type    VARCHAR(100) NOT NULL,
    payload       JSON         NOT NULL,
    http_status   SMALLINT,
    response_body TEXT,
    attempt_count TINYINT      NOT NULL DEFAULT 1,
    next_retry_at DATETIME,
    delivered_at  DATETIME,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_wh_deliveries_webhook (webhook_id, created_at),
    CONSTRAINT fk_whd_webhook  FOREIGN KEY (webhook_id) REFERENCES webhooks(id)  ON DELETE CASCADE,
    CONSTRAINT fk_whd_company  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- audit_logs — traçabilité légale (append-only)
-- ============================================================

CREATE TABLE audit_logs (
    id            CHAR(36)     NOT NULL DEFAULT (UUID()),
    company_id    CHAR(36),
    user_id       CHAR(36),
    action        ENUM('CREATE','UPDATE','DELETE','LOGIN','LOGOUT',
                       'LOGIN_FAILED','PASSWORD_RESET','EXPORT','IMPERSONATE') NOT NULL,
    resource_type VARCHAR(100),
    resource_id   CHAR(36),
    old_values    JSON,
    new_values    JSON,
    ip_address    VARCHAR(45),
    user_agent    VARCHAR(500),
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_audit_company  (company_id, created_at),
    KEY idx_audit_user     (user_id, created_at),
    KEY idx_audit_resource (resource_type, resource_id, created_at),
    CONSTRAINT fk_audit_company FOREIGN KEY (company_id) REFERENCES companies(id),
    CONSTRAINT fk_audit_user    FOREIGN KEY (user_id)    REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- subscription_plans_config — configuration des plans
-- ============================================================

CREATE TABLE subscription_plans_config (
    plan                  ENUM('gratuit','starter','pro','enterprise') NOT NULL,
    max_orders_month      INT         NOT NULL,
    max_users             INT         NOT NULL,
    max_products          INT         NOT NULL,
    max_drivers           INT         NOT NULL,
    has_analytics         TINYINT(1)  NOT NULL DEFAULT 0,
    has_api_access        TINYINT(1)  NOT NULL DEFAULT 0,
    has_dedicated_support TINYINT(1)  NOT NULL DEFAULT 0,
    price_monthly_xaf     INT         NOT NULL,
    price_annual_xaf      INT         NOT NULL,
    PRIMARY KEY (plan)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO subscription_plans_config VALUES
    ('gratuit',     50,    2,   100,   0, 0, 0, 0,      0,       0),
    ('starter',    500,    5,  1000,   3, 0, 0, 0,  15000,  150000),
    ('pro',       5000,   20,    -1,  -1, 1, 1, 0,  45000,  450000),
    ('enterprise',  -1,   -1,    -1,  -1, 1, 1, 1, 150000, 1500000);

-- ============================================================
-- TRIGGERS — updated_at automatique sur order_events (read-at)
-- et cohérence stock
-- ============================================================

DELIMITER $$

-- Marque read_at quand une notification passe à is_read = 1
CREATE TRIGGER trg_notifications_read
BEFORE UPDATE ON notifications
FOR EACH ROW
BEGIN
    IF NEW.is_read = 1 AND OLD.is_read = 0 THEN
        SET NEW.read_at = NOW();
    END IF;
END$$

-- Bloque un stock négatif au niveau base de données
CREATE TRIGGER trg_stock_movement_check
BEFORE INSERT ON stock_movements
FOR EACH ROW
BEGIN
    IF NEW.quantity_after < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Le stock ne peut pas être négatif.';
    END IF;
END$$

-- Met à jour stock_quantity sur products après chaque mouvement
CREATE TRIGGER trg_update_product_stock
AFTER INSERT ON stock_movements
FOR EACH ROW
BEGIN
    IF NEW.variant_id IS NULL THEN
        UPDATE products
        SET stock_quantity = NEW.quantity_after,
            updated_at     = NOW()
        WHERE id = NEW.product_id;
    ELSE
        UPDATE product_variants
        SET stock_quantity = NEW.quantity_after,
            updated_at     = NOW()
        WHERE id = NEW.variant_id;
    END IF;
END$$

-- Interdit toute modification des audit_logs (journal immuable)
CREATE TRIGGER trg_audit_no_update
BEFORE UPDATE ON audit_logs
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Les audit_logs sont immuables — aucune mise à jour autorisée.';
END$$

CREATE TRIGGER trg_audit_no_delete
BEFORE DELETE ON audit_logs
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Les audit_logs sont immuables — aucune suppression autorisée.';
END$$

DELIMITER ;

-- ============================================================
-- VUE : commandes actives avec infos livreur
-- ============================================================

CREATE VIEW v_active_orders AS
SELECT
    o.id,
    o.company_id,
    o.order_number,
    o.status,
    o.customer_name,
    o.customer_phone,
    o.total_amount,
    o.payment_status,
    o.created_at,
    d.id          AS delivery_id,
    d.status      AS delivery_status,
    CONCAT(u.first_name, ' ', u.last_name) AS driver_name,
    u.phone       AS driver_phone
FROM orders o
LEFT JOIN deliveries d ON d.order_id = o.id
LEFT JOIN users u      ON u.id = d.driver_id
WHERE o.status NOT IN ('annulee', 'remboursee')
  AND o.deleted_at IS NULL;

-- ============================================================
-- VUE : produits en alerte de stock
-- ============================================================

CREATE VIEW v_low_stock AS
SELECT
    p.company_id,
    p.id          AS product_id,
    p.name,
    p.sku,
    p.stock_quantity,
    p.stock_alert_threshold,
    (p.stock_alert_threshold - p.stock_quantity) AS shortage
FROM products p
WHERE p.stock_quantity <= p.stock_alert_threshold
  AND p.is_active = 1
  AND p.deleted_at IS NULL;

-- ============================================================
-- VUE : KPIs journaliers par tenant
-- ============================================================

CREATE VIEW v_daily_stats AS
SELECT
    company_id,
    DATE(created_at)                                           AS order_date,
    COUNT(*)                                                   AS total_orders,
    SUM(status = 'livree')                                     AS delivered_orders,
    SUM(status = 'annulee')                                    AS cancelled_orders,
    COALESCE(SUM(CASE WHEN status = 'livree' THEN total_amount END), 0) AS revenue,
    COALESCE(AVG(CASE WHEN status = 'livree' THEN total_amount END), 0) AS avg_order_value
FROM orders
WHERE deleted_at IS NULL
GROUP BY company_id, DATE(created_at);

SET FOREIGN_KEY_CHECKS = 1;
