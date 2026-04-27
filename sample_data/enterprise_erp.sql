-- ============================================================================
-- Enterprise ERP System - Oracle SQL Schema
-- A comprehensive e-commerce and enterprise resource planning database
-- ============================================================================

-- ============================================================================
-- SECTION 1: SEQUENCES
-- ============================================================================

CREATE SEQUENCE seq_customer_id START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_employee_id START WITH 5000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_product_id START WITH 10000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_order_id START WITH 100000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_order_item_id START WITH 500000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_payment_id START WITH 200000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_shipment_id START WITH 300000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_address_id START WITH 400000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_category_id START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_warehouse_id START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_supplier_id START WITH 2000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_purchase_order_id START WITH 600000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_audit_id START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_notification_id START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_review_id START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_coupon_id START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_return_id START WITH 700000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_department_id START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_ticket_id START WITH 800000 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ============================================================================
-- SECTION 2: CUSTOM TYPES
-- ============================================================================

CREATE OR REPLACE TYPE address_type AS OBJECT (
    street_line1   VARCHAR2(200),
    street_line2   VARCHAR2(200),
    city           VARCHAR2(100),
    state_province VARCHAR2(100),
    postal_code    VARCHAR2(20),
    country_code   VARCHAR2(3)
);
/

CREATE OR REPLACE TYPE phone_list_type AS VARRAY(5) OF VARCHAR2(20);
/

CREATE OR REPLACE TYPE money_type AS OBJECT (
    amount        NUMBER(15,2),
    currency_code VARCHAR2(3),
    MEMBER FUNCTION to_string RETURN VARCHAR2
);
/

CREATE OR REPLACE TYPE BODY money_type AS
    MEMBER FUNCTION to_string RETURN VARCHAR2 IS
    BEGIN
        RETURN TO_CHAR(amount, '999,999,999.99') || ' ' || currency_code;
    END;
END;
/

-- ============================================================================
-- SECTION 3: LOOKUP / REFERENCE TABLES
-- ============================================================================

CREATE TABLE departments (
    department_id   NUMBER(10)    NOT NULL,
    department_name VARCHAR2(100) NOT NULL,
    department_code VARCHAR2(20)  NOT NULL,
    parent_dept_id  NUMBER(10),
    manager_id      NUMBER(10),
    budget          NUMBER(15,2),
    cost_center     VARCHAR2(20),
    is_active       CHAR(1)       DEFAULT 'Y' NOT NULL,
    created_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    modified_date   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_departments PRIMARY KEY (department_id),
    CONSTRAINT uk_dept_code UNIQUE (department_code),
    CONSTRAINT chk_dept_active CHECK (is_active IN ('Y','N'))
);

CREATE TABLE product_categories (
    category_id     NUMBER(10)    NOT NULL,
    category_name   VARCHAR2(200) NOT NULL,
    parent_id       NUMBER(10),
    description     CLOB,
    slug            VARCHAR2(200) NOT NULL,
    display_order   NUMBER(5)     DEFAULT 0,
    is_active       CHAR(1)       DEFAULT 'Y' NOT NULL,
    icon_url        VARCHAR2(500),
    meta_title      VARCHAR2(200),
    meta_description VARCHAR2(500),
    created_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    modified_date   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_product_categories PRIMARY KEY (category_id),
    CONSTRAINT uk_category_slug UNIQUE (slug),
    CONSTRAINT fk_category_parent FOREIGN KEY (parent_id) REFERENCES product_categories(category_id)
);

CREATE TABLE countries (
    country_code  VARCHAR2(3)   NOT NULL,
    country_name  VARCHAR2(100) NOT NULL,
    currency_code VARCHAR2(3),
    phone_prefix  VARCHAR2(5),
    is_active     CHAR(1)       DEFAULT 'Y',
    CONSTRAINT pk_countries PRIMARY KEY (country_code)
);

CREATE TABLE tax_rates (
    tax_rate_id   NUMBER(10)    NOT NULL,
    country_code  VARCHAR2(3)   NOT NULL,
    state_code    VARCHAR2(10),
    tax_type      VARCHAR2(50)  NOT NULL,
    rate_percent  NUMBER(5,4)   NOT NULL,
    effective_from DATE         NOT NULL,
    effective_to   DATE,
    is_active     CHAR(1)       DEFAULT 'Y',
    CONSTRAINT pk_tax_rates PRIMARY KEY (tax_rate_id),
    CONSTRAINT fk_tax_country FOREIGN KEY (country_code) REFERENCES countries(country_code)
);

CREATE TABLE currencies (
    currency_code VARCHAR2(3)   NOT NULL,
    currency_name VARCHAR2(50)  NOT NULL,
    symbol        VARCHAR2(5),
    decimal_places NUMBER(1)    DEFAULT 2,
    CONSTRAINT pk_currencies PRIMARY KEY (currency_code)
);

CREATE TABLE exchange_rates (
    from_currency VARCHAR2(3)   NOT NULL,
    to_currency   VARCHAR2(3)   NOT NULL,
    rate          NUMBER(15,6)  NOT NULL,
    effective_date DATE         NOT NULL,
    CONSTRAINT pk_exchange_rates PRIMARY KEY (from_currency, to_currency, effective_date),
    CONSTRAINT fk_exch_from FOREIGN KEY (from_currency) REFERENCES currencies(currency_code),
    CONSTRAINT fk_exch_to FOREIGN KEY (to_currency) REFERENCES currencies(currency_code)
);

CREATE TABLE shipping_methods (
    method_id     NUMBER(10)    NOT NULL,
    method_name   VARCHAR2(100) NOT NULL,
    carrier       VARCHAR2(100),
    base_cost     NUMBER(10,2)  DEFAULT 0,
    cost_per_kg   NUMBER(10,2)  DEFAULT 0,
    min_days      NUMBER(3),
    max_days      NUMBER(3),
    is_active     CHAR(1)       DEFAULT 'Y',
    CONSTRAINT pk_shipping_methods PRIMARY KEY (method_id)
);

CREATE TABLE payment_methods (
    method_id     NUMBER(10)    NOT NULL,
    method_name   VARCHAR2(100) NOT NULL,
    method_type   VARCHAR2(50)  NOT NULL,
    processor     VARCHAR2(100),
    is_active     CHAR(1)       DEFAULT 'Y',
    CONSTRAINT pk_payment_methods PRIMARY KEY (method_id),
    CONSTRAINT chk_pay_type CHECK (method_type IN ('CREDIT_CARD','DEBIT_CARD','BANK_TRANSFER','WALLET','COD','CRYPTO'))
);

-- ============================================================================
-- SECTION 4: CORE ENTITY TABLES
-- ============================================================================

CREATE TABLE addresses (
    address_id      NUMBER(10)    NOT NULL,
    address_type    VARCHAR2(20)  NOT NULL,
    street_line1    VARCHAR2(200) NOT NULL,
    street_line2    VARCHAR2(200),
    city            VARCHAR2(100) NOT NULL,
    state_province  VARCHAR2(100),
    postal_code     VARCHAR2(20),
    country_code    VARCHAR2(3)   NOT NULL,
    latitude        NUMBER(10,7),
    longitude       NUMBER(10,7),
    is_verified     CHAR(1)       DEFAULT 'N',
    created_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_addresses PRIMARY KEY (address_id),
    CONSTRAINT fk_addr_country FOREIGN KEY (country_code) REFERENCES countries(country_code),
    CONSTRAINT chk_addr_type CHECK (address_type IN ('BILLING','SHIPPING','OFFICE','WAREHOUSE','HOME'))
);

CREATE TABLE customers (
    customer_id     NUMBER(10)    NOT NULL,
    email           VARCHAR2(255) NOT NULL,
    password_hash   VARCHAR2(256) NOT NULL,
    first_name      VARCHAR2(100) NOT NULL,
    last_name       VARCHAR2(100) NOT NULL,
    phone           VARCHAR2(20),
    date_of_birth   DATE,
    gender          CHAR(1),
    customer_type   VARCHAR2(20)  DEFAULT 'INDIVIDUAL',
    company_name    VARCHAR2(200),
    tax_id          VARCHAR2(50),
    preferred_currency VARCHAR2(3) DEFAULT 'USD',
    preferred_language VARCHAR2(5) DEFAULT 'en',
    loyalty_points  NUMBER(10)    DEFAULT 0,
    loyalty_tier    VARCHAR2(20)  DEFAULT 'BRONZE',
    default_billing_addr  NUMBER(10),
    default_shipping_addr NUMBER(10),
    is_email_verified CHAR(1)     DEFAULT 'N',
    is_active       CHAR(1)       DEFAULT 'Y',
    last_login_date TIMESTAMP,
    registration_source VARCHAR2(50),
    referral_code   VARCHAR2(20),
    referred_by     NUMBER(10),
    created_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    modified_date   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_customers PRIMARY KEY (customer_id),
    CONSTRAINT uk_customer_email UNIQUE (email),
    CONSTRAINT fk_cust_billing FOREIGN KEY (default_billing_addr) REFERENCES addresses(address_id),
    CONSTRAINT fk_cust_shipping FOREIGN KEY (default_shipping_addr) REFERENCES addresses(address_id),
    CONSTRAINT fk_cust_referrer FOREIGN KEY (referred_by) REFERENCES customers(customer_id),
    CONSTRAINT chk_cust_type CHECK (customer_type IN ('INDIVIDUAL','BUSINESS','WHOLESALE')),
    CONSTRAINT chk_cust_tier CHECK (loyalty_tier IN ('BRONZE','SILVER','GOLD','PLATINUM','DIAMOND')),
    CONSTRAINT chk_cust_gender CHECK (gender IN ('M','F','O'))
);

CREATE TABLE customer_addresses (
    customer_id   NUMBER(10) NOT NULL,
    address_id    NUMBER(10) NOT NULL,
    is_default    CHAR(1)    DEFAULT 'N',
    label         VARCHAR2(50),
    CONSTRAINT pk_cust_addr PRIMARY KEY (customer_id, address_id),
    CONSTRAINT fk_ca_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_ca_address FOREIGN KEY (address_id) REFERENCES addresses(address_id)
);

CREATE TABLE employees (
    employee_id     NUMBER(10)    NOT NULL,
    email           VARCHAR2(255) NOT NULL,
    first_name      VARCHAR2(100) NOT NULL,
    last_name       VARCHAR2(100) NOT NULL,
    phone           VARCHAR2(20),
    hire_date       DATE          NOT NULL,
    termination_date DATE,
    department_id   NUMBER(10),
    manager_id      NUMBER(10),
    job_title       VARCHAR2(100),
    salary          NUMBER(12,2),
    commission_pct  NUMBER(5,2),
    employee_type   VARCHAR2(20)  DEFAULT 'FULL_TIME',
    is_active       CHAR(1)       DEFAULT 'Y',
    created_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    modified_date   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_employees PRIMARY KEY (employee_id),
    CONSTRAINT uk_emp_email UNIQUE (email),
    CONSTRAINT fk_emp_dept FOREIGN KEY (department_id) REFERENCES departments(department_id),
    CONSTRAINT fk_emp_manager FOREIGN KEY (manager_id) REFERENCES employees(employee_id),
    CONSTRAINT chk_emp_type CHECK (employee_type IN ('FULL_TIME','PART_TIME','CONTRACT','INTERN'))
);

ALTER TABLE departments ADD CONSTRAINT fk_dept_manager FOREIGN KEY (manager_id) REFERENCES employees(employee_id);

CREATE TABLE suppliers (
    supplier_id     NUMBER(10)    NOT NULL,
    supplier_name   VARCHAR2(200) NOT NULL,
    contact_name    VARCHAR2(100),
    contact_email   VARCHAR2(255),
    contact_phone   VARCHAR2(20),
    website         VARCHAR2(500),
    address_id      NUMBER(10),
    tax_id          VARCHAR2(50),
    payment_terms   VARCHAR2(50)  DEFAULT 'NET30',
    rating          NUMBER(3,1),
    is_active       CHAR(1)       DEFAULT 'Y',
    notes           CLOB,
    created_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    modified_date   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_suppliers PRIMARY KEY (supplier_id),
    CONSTRAINT fk_supp_addr FOREIGN KEY (address_id) REFERENCES addresses(address_id)
);

CREATE TABLE warehouses (
    warehouse_id    NUMBER(10)    NOT NULL,
    warehouse_name  VARCHAR2(100) NOT NULL,
    warehouse_code  VARCHAR2(20)  NOT NULL,
    address_id      NUMBER(10),
    manager_id      NUMBER(10),
    capacity_units  NUMBER(10),
    is_active       CHAR(1)       DEFAULT 'Y',
    CONSTRAINT pk_warehouses PRIMARY KEY (warehouse_id),
    CONSTRAINT uk_wh_code UNIQUE (warehouse_code),
    CONSTRAINT fk_wh_addr FOREIGN KEY (address_id) REFERENCES addresses(address_id),
    CONSTRAINT fk_wh_manager FOREIGN KEY (manager_id) REFERENCES employees(employee_id)
);

-- ============================================================================
-- SECTION 5: PRODUCT TABLES
-- ============================================================================

CREATE TABLE products (
    product_id      NUMBER(10)    NOT NULL,
    sku             VARCHAR2(50)  NOT NULL,
    product_name    VARCHAR2(300) NOT NULL,
    description     CLOB,
    short_description VARCHAR2(500),
    category_id     NUMBER(10),
    brand           VARCHAR2(100),
    manufacturer    VARCHAR2(200),
    model_number    VARCHAR2(100),
    unit_price      NUMBER(12,2)  NOT NULL,
    cost_price      NUMBER(12,2),
    compare_at_price NUMBER(12,2),
    currency_code   VARCHAR2(3)   DEFAULT 'USD',
    weight_kg       NUMBER(8,3),
    length_cm       NUMBER(8,2),
    width_cm        NUMBER(8,2),
    height_cm       NUMBER(8,2),
    is_digital      CHAR(1)       DEFAULT 'N',
    is_taxable      CHAR(1)       DEFAULT 'Y',
    tax_class       VARCHAR2(50),
    barcode         VARCHAR2(50),
    status          VARCHAR2(20)  DEFAULT 'DRAFT',
    visibility      VARCHAR2(20)  DEFAULT 'VISIBLE',
    slug            VARCHAR2(300) NOT NULL,
    meta_title      VARCHAR2(200),
    meta_description VARCHAR2(500),
    avg_rating      NUMBER(3,2)   DEFAULT 0,
    review_count    NUMBER(10)    DEFAULT 0,
    supplier_id     NUMBER(10),
    min_order_qty   NUMBER(10)    DEFAULT 1,
    max_order_qty   NUMBER(10),
    lead_time_days  NUMBER(5),
    created_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    modified_date   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    published_date  TIMESTAMP,
    CONSTRAINT pk_products PRIMARY KEY (product_id),
    CONSTRAINT uk_product_sku UNIQUE (sku),
    CONSTRAINT uk_product_slug UNIQUE (slug),
    CONSTRAINT fk_prod_category FOREIGN KEY (category_id) REFERENCES product_categories(category_id),
    CONSTRAINT fk_prod_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
    CONSTRAINT chk_prod_status CHECK (status IN ('DRAFT','ACTIVE','DISCONTINUED','OUT_OF_STOCK','ARCHIVED')),
    CONSTRAINT chk_prod_visibility CHECK (visibility IN ('VISIBLE','HIDDEN','SEARCH_ONLY'))
);

CREATE TABLE product_images (
    image_id        NUMBER(10)    NOT NULL,
    product_id      NUMBER(10)    NOT NULL,
    image_url       VARCHAR2(500) NOT NULL,
    alt_text        VARCHAR2(200),
    display_order   NUMBER(5)     DEFAULT 0,
    is_primary      CHAR(1)       DEFAULT 'N',
    CONSTRAINT pk_product_images PRIMARY KEY (image_id),
    CONSTRAINT fk_pimg_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

CREATE TABLE product_attributes (
    product_id      NUMBER(10)    NOT NULL,
    attribute_name  VARCHAR2(100) NOT NULL,
    attribute_value VARCHAR2(500) NOT NULL,
    display_order   NUMBER(5)     DEFAULT 0,
    CONSTRAINT pk_prod_attr PRIMARY KEY (product_id, attribute_name),
    CONSTRAINT fk_pattr_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

CREATE TABLE product_variants (
    variant_id      NUMBER(10)    NOT NULL,
    product_id      NUMBER(10)    NOT NULL,
    sku             VARCHAR2(50)  NOT NULL,
    variant_name    VARCHAR2(200),
    price_modifier  NUMBER(10,2)  DEFAULT 0,
    weight_modifier NUMBER(8,3)   DEFAULT 0,
    is_active       CHAR(1)       DEFAULT 'Y',
    CONSTRAINT pk_product_variants PRIMARY KEY (variant_id),
    CONSTRAINT uk_variant_sku UNIQUE (sku),
    CONSTRAINT fk_pvar_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

CREATE TABLE product_tags (
    product_id NUMBER(10)    NOT NULL,
    tag        VARCHAR2(100) NOT NULL,
    CONSTRAINT pk_product_tags PRIMARY KEY (product_id, tag),
    CONSTRAINT fk_ptag_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

CREATE TABLE product_related (
    product_id         NUMBER(10) NOT NULL,
    related_product_id NUMBER(10) NOT NULL,
    relation_type      VARCHAR2(20) DEFAULT 'RELATED',
    CONSTRAINT pk_product_related PRIMARY KEY (product_id, related_product_id),
    CONSTRAINT fk_prel_product FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_prel_related FOREIGN KEY (related_product_id) REFERENCES products(product_id),
    CONSTRAINT chk_prel_type CHECK (relation_type IN ('RELATED','UPSELL','CROSS_SELL','ACCESSORY'))
);

CREATE TABLE inventory (
    warehouse_id    NUMBER(10) NOT NULL,
    product_id      NUMBER(10) NOT NULL,
    variant_id      NUMBER(10),
    quantity_on_hand NUMBER(10) DEFAULT 0,
    quantity_reserved NUMBER(10) DEFAULT 0,
    quantity_available NUMBER(10) GENERATED ALWAYS AS (quantity_on_hand - quantity_reserved) VIRTUAL,
    reorder_point   NUMBER(10) DEFAULT 10,
    reorder_quantity NUMBER(10) DEFAULT 50,
    bin_location    VARCHAR2(50),
    last_counted_date DATE,
    last_received_date DATE,
    CONSTRAINT pk_inventory PRIMARY KEY (warehouse_id, product_id),
    CONSTRAINT fk_inv_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    CONSTRAINT fk_inv_product FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_inv_variant FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id)
);

CREATE TABLE inventory_transactions (
    transaction_id  NUMBER(15)    NOT NULL,
    warehouse_id    NUMBER(10)    NOT NULL,
    product_id      NUMBER(10)    NOT NULL,
    transaction_type VARCHAR2(20) NOT NULL,
    quantity        NUMBER(10)    NOT NULL,
    reference_type  VARCHAR2(50),
    reference_id    NUMBER(15),
    notes           VARCHAR2(500),
    performed_by    NUMBER(10),
    transaction_date TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_inv_trans PRIMARY KEY (transaction_id),
    CONSTRAINT fk_invt_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    CONSTRAINT fk_invt_product FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_invt_employee FOREIGN KEY (performed_by) REFERENCES employees(employee_id),
    CONSTRAINT chk_invt_type CHECK (transaction_type IN ('RECEIPT','SHIPMENT','ADJUSTMENT','TRANSFER','RETURN','DAMAGE'))
);

-- ============================================================================
-- SECTION 6: ORDER MANAGEMENT TABLES
-- ============================================================================

CREATE TABLE orders (
    order_id        NUMBER(15)    NOT NULL,
    order_number    VARCHAR2(30)  NOT NULL,
    customer_id     NUMBER(10)    NOT NULL,
    order_status    VARCHAR2(20)  DEFAULT 'PENDING',
    order_date      TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    billing_address_id  NUMBER(10),
    shipping_address_id NUMBER(10),
    shipping_method_id  NUMBER(10),
    subtotal        NUMBER(12,2)  NOT NULL,
    tax_amount      NUMBER(12,2)  DEFAULT 0,
    shipping_cost   NUMBER(10,2)  DEFAULT 0,
    discount_amount NUMBER(12,2)  DEFAULT 0,
    total_amount    NUMBER(12,2)  NOT NULL,
    currency_code   VARCHAR2(3)   DEFAULT 'USD',
    coupon_code     VARCHAR2(50),
    notes           CLOB,
    internal_notes  CLOB,
    ip_address      VARCHAR2(45),
    user_agent      VARCHAR2(500),
    channel         VARCHAR2(20)  DEFAULT 'WEB',
    assigned_employee NUMBER(10),
    estimated_delivery DATE,
    actual_delivery DATE,
    cancelled_date  TIMESTAMP,
    cancellation_reason VARCHAR2(500),
    created_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    modified_date   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_orders PRIMARY KEY (order_id),
    CONSTRAINT uk_order_number UNIQUE (order_number),
    CONSTRAINT fk_ord_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_ord_billing FOREIGN KEY (billing_address_id) REFERENCES addresses(address_id),
    CONSTRAINT fk_ord_shipping FOREIGN KEY (shipping_address_id) REFERENCES addresses(address_id),
    CONSTRAINT fk_ord_ship_method FOREIGN KEY (shipping_method_id) REFERENCES shipping_methods(method_id),
    CONSTRAINT fk_ord_employee FOREIGN KEY (assigned_employee) REFERENCES employees(employee_id),
    CONSTRAINT chk_ord_status CHECK (order_status IN ('PENDING','CONFIRMED','PROCESSING','SHIPPED','DELIVERED','CANCELLED','REFUNDED','ON_HOLD')),
    CONSTRAINT chk_ord_channel CHECK (channel IN ('WEB','MOBILE','API','POS','PHONE','EMAIL'))
);

CREATE TABLE order_items (
    order_item_id   NUMBER(15)    NOT NULL,
    order_id        NUMBER(15)    NOT NULL,
    product_id      NUMBER(10)    NOT NULL,
    variant_id      NUMBER(10),
    quantity        NUMBER(10)    NOT NULL,
    unit_price      NUMBER(12,2)  NOT NULL,
    discount_pct    NUMBER(5,2)   DEFAULT 0,
    discount_amount NUMBER(12,2)  DEFAULT 0,
    tax_amount      NUMBER(12,2)  DEFAULT 0,
    line_total      NUMBER(12,2)  NOT NULL,
    status          VARCHAR2(20)  DEFAULT 'PENDING',
    warehouse_id    NUMBER(10),
    notes           VARCHAR2(500),
    CONSTRAINT pk_order_items PRIMARY KEY (order_item_id),
    CONSTRAINT fk_oi_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_oi_product FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_oi_variant FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id),
    CONSTRAINT fk_oi_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);

CREATE TABLE order_status_history (
    history_id      NUMBER(15)    NOT NULL,
    order_id        NUMBER(15)    NOT NULL,
    old_status      VARCHAR2(20),
    new_status      VARCHAR2(20)  NOT NULL,
    changed_by      NUMBER(10),
    change_reason   VARCHAR2(500),
    changed_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_order_history PRIMARY KEY (history_id),
    CONSTRAINT fk_osh_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_osh_employee FOREIGN KEY (changed_by) REFERENCES employees(employee_id)
);

CREATE TABLE payments (
    payment_id      NUMBER(15)    NOT NULL,
    order_id        NUMBER(15)    NOT NULL,
    payment_method_id NUMBER(10),
    amount          NUMBER(12,2)  NOT NULL,
    currency_code   VARCHAR2(3)   DEFAULT 'USD',
    payment_status  VARCHAR2(20)  DEFAULT 'PENDING',
    transaction_ref VARCHAR2(100),
    gateway_response CLOB,
    payment_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    processed_date  TIMESTAMP,
    refund_amount   NUMBER(12,2)  DEFAULT 0,
    CONSTRAINT pk_payments PRIMARY KEY (payment_id),
    CONSTRAINT fk_pay_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_pay_method FOREIGN KEY (payment_method_id) REFERENCES payment_methods(method_id),
    CONSTRAINT chk_pay_status CHECK (payment_status IN ('PENDING','AUTHORIZED','CAPTURED','FAILED','REFUNDED','PARTIALLY_REFUNDED','VOIDED'))
);

CREATE TABLE shipments (
    shipment_id     NUMBER(15)    NOT NULL,
    order_id        NUMBER(15)    NOT NULL,
    warehouse_id    NUMBER(10),
    shipping_method_id NUMBER(10),
    tracking_number VARCHAR2(100),
    carrier         VARCHAR2(100),
    shipment_status VARCHAR2(20)  DEFAULT 'PENDING',
    shipped_date    TIMESTAMP,
    estimated_arrival DATE,
    actual_arrival  TIMESTAMP,
    weight_kg       NUMBER(8,3),
    shipping_cost   NUMBER(10,2),
    label_url       VARCHAR2(500),
    CONSTRAINT pk_shipments PRIMARY KEY (shipment_id),
    CONSTRAINT fk_ship_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_ship_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    CONSTRAINT fk_ship_method FOREIGN KEY (shipping_method_id) REFERENCES shipping_methods(method_id),
    CONSTRAINT chk_ship_status CHECK (shipment_status IN ('PENDING','PICKED','PACKED','SHIPPED','IN_TRANSIT','DELIVERED','RETURNED','LOST'))
);

CREATE TABLE shipment_items (
    shipment_id     NUMBER(15) NOT NULL,
    order_item_id   NUMBER(15) NOT NULL,
    quantity        NUMBER(10) NOT NULL,
    CONSTRAINT pk_shipment_items PRIMARY KEY (shipment_id, order_item_id),
    CONSTRAINT fk_si_shipment FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id),
    CONSTRAINT fk_si_order_item FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id)
);

CREATE TABLE returns (
    return_id       NUMBER(15)    NOT NULL,
    order_id        NUMBER(15)    NOT NULL,
    customer_id     NUMBER(10)    NOT NULL,
    return_status   VARCHAR2(20)  DEFAULT 'REQUESTED',
    return_reason   VARCHAR2(500),
    return_type     VARCHAR2(20)  DEFAULT 'REFUND',
    refund_amount   NUMBER(12,2),
    restocking_fee  NUMBER(12,2)  DEFAULT 0,
    approved_by     NUMBER(10),
    requested_date  TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    approved_date   TIMESTAMP,
    received_date   TIMESTAMP,
    completed_date  TIMESTAMP,
    CONSTRAINT pk_returns PRIMARY KEY (return_id),
    CONSTRAINT fk_ret_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_ret_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_ret_approver FOREIGN KEY (approved_by) REFERENCES employees(employee_id),
    CONSTRAINT chk_ret_status CHECK (return_status IN ('REQUESTED','APPROVED','REJECTED','RECEIVED','INSPECTED','COMPLETED','CANCELLED')),
    CONSTRAINT chk_ret_type CHECK (return_type IN ('REFUND','EXCHANGE','STORE_CREDIT'))
);

CREATE TABLE return_items (
    return_id       NUMBER(15)    NOT NULL,
    order_item_id   NUMBER(15)    NOT NULL,
    quantity        NUMBER(10)    NOT NULL,
    reason          VARCHAR2(200),
    condition       VARCHAR2(20),
    CONSTRAINT pk_return_items PRIMARY KEY (return_id, order_item_id),
    CONSTRAINT fk_ri_return FOREIGN KEY (return_id) REFERENCES returns(return_id),
    CONSTRAINT fk_ri_order_item FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id)
);

-- ============================================================================
-- SECTION 7: MARKETING & ENGAGEMENT TABLES
-- ============================================================================

CREATE TABLE coupons (
    coupon_id       NUMBER(10)    NOT NULL,
    coupon_code     VARCHAR2(50)  NOT NULL,
    description     VARCHAR2(500),
    discount_type   VARCHAR2(20)  NOT NULL,
    discount_value  NUMBER(12,2)  NOT NULL,
    min_order_amount NUMBER(12,2),
    max_discount    NUMBER(12,2),
    usage_limit     NUMBER(10),
    usage_count     NUMBER(10)    DEFAULT 0,
    per_customer_limit NUMBER(5)  DEFAULT 1,
    valid_from      TIMESTAMP     NOT NULL,
    valid_to        TIMESTAMP     NOT NULL,
    is_active       CHAR(1)       DEFAULT 'Y',
    created_by      NUMBER(10),
    CONSTRAINT pk_coupons PRIMARY KEY (coupon_id),
    CONSTRAINT uk_coupon_code UNIQUE (coupon_code),
    CONSTRAINT fk_coup_creator FOREIGN KEY (created_by) REFERENCES employees(employee_id),
    CONSTRAINT chk_coup_type CHECK (discount_type IN ('PERCENTAGE','FIXED_AMOUNT','FREE_SHIPPING','BUY_X_GET_Y'))
);

CREATE TABLE product_reviews (
    review_id       NUMBER(10)    NOT NULL,
    product_id      NUMBER(10)    NOT NULL,
    customer_id     NUMBER(10)    NOT NULL,
    order_id        NUMBER(15),
    rating          NUMBER(1)     NOT NULL,
    title           VARCHAR2(200),
    review_text     CLOB,
    is_verified     CHAR(1)       DEFAULT 'N',
    is_approved     CHAR(1)       DEFAULT 'N',
    helpful_count   NUMBER(10)    DEFAULT 0,
    reported_count  NUMBER(10)    DEFAULT 0,
    admin_response  CLOB,
    created_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    modified_date   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_reviews PRIMARY KEY (review_id),
    CONSTRAINT fk_rev_product FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_rev_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_rev_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT chk_rev_rating CHECK (rating BETWEEN 1 AND 5)
);

CREATE TABLE wishlists (
    customer_id     NUMBER(10)    NOT NULL,
    product_id      NUMBER(10)    NOT NULL,
    added_date      TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    notes           VARCHAR2(500),
    CONSTRAINT pk_wishlists PRIMARY KEY (customer_id, product_id),
    CONSTRAINT fk_wl_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_wl_product FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE cart_items (
    customer_id     NUMBER(10)    NOT NULL,
    product_id      NUMBER(10)    NOT NULL,
    variant_id      NUMBER(10),
    quantity        NUMBER(10)    DEFAULT 1,
    added_date      TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_cart_items PRIMARY KEY (customer_id, product_id),
    CONSTRAINT fk_cart_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_cart_product FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_cart_variant FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id)
);

CREATE TABLE notifications (
    notification_id NUMBER(15)    NOT NULL,
    customer_id     NUMBER(10),
    employee_id     NUMBER(10),
    notification_type VARCHAR2(50) NOT NULL,
    channel         VARCHAR2(20)  DEFAULT 'EMAIL',
    subject         VARCHAR2(200),
    body            CLOB,
    is_read         CHAR(1)       DEFAULT 'N',
    sent_date       TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    read_date       TIMESTAMP,
    CONSTRAINT pk_notifications PRIMARY KEY (notification_id),
    CONSTRAINT fk_notif_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_notif_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);

CREATE TABLE support_tickets (
    ticket_id       NUMBER(15)    NOT NULL,
    ticket_number   VARCHAR2(20)  NOT NULL,
    customer_id     NUMBER(10)    NOT NULL,
    order_id        NUMBER(15),
    assigned_to     NUMBER(10),
    category        VARCHAR2(50),
    priority        VARCHAR2(10)  DEFAULT 'MEDIUM',
    status          VARCHAR2(20)  DEFAULT 'OPEN',
    subject         VARCHAR2(300) NOT NULL,
    description     CLOB,
    resolution      CLOB,
    created_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    updated_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    resolved_date   TIMESTAMP,
    closed_date     TIMESTAMP,
    satisfaction_rating NUMBER(1),
    CONSTRAINT pk_tickets PRIMARY KEY (ticket_id),
    CONSTRAINT uk_ticket_number UNIQUE (ticket_number),
    CONSTRAINT fk_tkt_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_tkt_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_tkt_assignee FOREIGN KEY (assigned_to) REFERENCES employees(employee_id),
    CONSTRAINT chk_tkt_priority CHECK (priority IN ('LOW','MEDIUM','HIGH','URGENT')),
    CONSTRAINT chk_tkt_status CHECK (status IN ('OPEN','IN_PROGRESS','WAITING_CUSTOMER','RESOLVED','CLOSED','ESCALATED'))
);

CREATE TABLE ticket_messages (
    message_id      NUMBER(15)    NOT NULL,
    ticket_id       NUMBER(15)    NOT NULL,
    sender_type     VARCHAR2(10)  NOT NULL,
    sender_id       NUMBER(10)    NOT NULL,
    message_text    CLOB          NOT NULL,
    is_internal     CHAR(1)       DEFAULT 'N',
    created_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_ticket_messages PRIMARY KEY (message_id),
    CONSTRAINT fk_tmsg_ticket FOREIGN KEY (ticket_id) REFERENCES support_tickets(ticket_id),
    CONSTRAINT chk_tmsg_sender CHECK (sender_type IN ('CUSTOMER','EMPLOYEE','SYSTEM'))
);

-- ============================================================================
-- SECTION 8: PURCHASE ORDER / PROCUREMENT TABLES
-- ============================================================================

CREATE TABLE purchase_orders (
    po_id           NUMBER(15)    NOT NULL,
    po_number       VARCHAR2(30)  NOT NULL,
    supplier_id     NUMBER(10)    NOT NULL,
    warehouse_id    NUMBER(10)    NOT NULL,
    status          VARCHAR2(20)  DEFAULT 'DRAFT',
    order_date      DATE,
    expected_date   DATE,
    received_date   DATE,
    subtotal        NUMBER(12,2),
    tax_amount      NUMBER(12,2)  DEFAULT 0,
    shipping_cost   NUMBER(10,2)  DEFAULT 0,
    total_amount    NUMBER(12,2),
    currency_code   VARCHAR2(3)   DEFAULT 'USD',
    payment_terms   VARCHAR2(50),
    notes           CLOB,
    created_by      NUMBER(10),
    approved_by     NUMBER(10),
    created_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    modified_date   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_purchase_orders PRIMARY KEY (po_id),
    CONSTRAINT uk_po_number UNIQUE (po_number),
    CONSTRAINT fk_po_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
    CONSTRAINT fk_po_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    CONSTRAINT fk_po_creator FOREIGN KEY (created_by) REFERENCES employees(employee_id),
    CONSTRAINT fk_po_approver FOREIGN KEY (approved_by) REFERENCES employees(employee_id),
    CONSTRAINT chk_po_status CHECK (status IN ('DRAFT','SUBMITTED','APPROVED','ORDERED','PARTIALLY_RECEIVED','RECEIVED','CANCELLED'))
);

CREATE TABLE purchase_order_items (
    po_item_id      NUMBER(15)    NOT NULL,
    po_id           NUMBER(15)    NOT NULL,
    product_id      NUMBER(10)    NOT NULL,
    quantity_ordered NUMBER(10)   NOT NULL,
    quantity_received NUMBER(10)  DEFAULT 0,
    unit_cost       NUMBER(12,2)  NOT NULL,
    line_total      NUMBER(12,2)  NOT NULL,
    CONSTRAINT pk_po_items PRIMARY KEY (po_item_id),
    CONSTRAINT fk_poi_po FOREIGN KEY (po_id) REFERENCES purchase_orders(po_id),
    CONSTRAINT fk_poi_product FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- ============================================================================
-- SECTION 9: AUDIT & LOGGING TABLES
-- ============================================================================

CREATE TABLE audit_log (
    audit_id        NUMBER(15)    NOT NULL,
    table_name      VARCHAR2(100) NOT NULL,
    record_id       VARCHAR2(100) NOT NULL,
    action          VARCHAR2(10)  NOT NULL,
    old_values      CLOB,
    new_values      CLOB,
    performed_by    VARCHAR2(100),
    performed_date  TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    ip_address      VARCHAR2(45),
    session_id      VARCHAR2(100),
    CONSTRAINT pk_audit_log PRIMARY KEY (audit_id),
    CONSTRAINT chk_audit_action CHECK (action IN ('INSERT','UPDATE','DELETE'))
);

CREATE TABLE system_config (
    config_key      VARCHAR2(100) NOT NULL,
    config_value    CLOB,
    config_type     VARCHAR2(20)  DEFAULT 'STRING',
    description     VARCHAR2(500),
    is_encrypted    CHAR(1)       DEFAULT 'N',
    modified_by     NUMBER(10),
    modified_date   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_system_config PRIMARY KEY (config_key)
);

CREATE TABLE scheduled_jobs (
    job_id          NUMBER(10)    NOT NULL,
    job_name        VARCHAR2(100) NOT NULL,
    job_type        VARCHAR2(50)  NOT NULL,
    cron_expression VARCHAR2(50),
    procedure_name  VARCHAR2(200),
    is_active       CHAR(1)       DEFAULT 'Y',
    last_run_date   TIMESTAMP,
    last_run_status VARCHAR2(20),
    last_run_duration NUMBER(10),
    next_run_date   TIMESTAMP,
    CONSTRAINT pk_scheduled_jobs PRIMARY KEY (job_id)
);

CREATE TABLE email_templates (
    template_id     NUMBER(10)    NOT NULL,
    template_code   VARCHAR2(50)  NOT NULL,
    template_name   VARCHAR2(200) NOT NULL,
    subject         VARCHAR2(300),
    body_html       CLOB,
    body_text       CLOB,
    variables       VARCHAR2(1000),
    is_active       CHAR(1)       DEFAULT 'Y',
    CONSTRAINT pk_email_templates PRIMARY KEY (template_id),
    CONSTRAINT uk_template_code UNIQUE (template_code)
);

-- ============================================================================
-- SECTION 10: INDEXES
-- ============================================================================

CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_name ON customers(last_name, first_name);
CREATE INDEX idx_customers_loyalty ON customers(loyalty_tier);
CREATE INDEX idx_customers_created ON customers(created_date);

CREATE INDEX idx_employees_dept ON employees(department_id);
CREATE INDEX idx_employees_manager ON employees(manager_id);
CREATE INDEX idx_employees_name ON employees(last_name, first_name);

CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_status ON products(status);
CREATE INDEX idx_products_brand ON products(brand);
CREATE INDEX idx_products_supplier ON products(supplier_id);
CREATE INDEX idx_products_price ON products(unit_price);
CREATE INDEX idx_products_created ON products(created_date);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(order_status);
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_orders_channel ON orders(channel);

CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);

CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_status ON payments(payment_status);
CREATE INDEX idx_payments_date ON payments(payment_date);

CREATE INDEX idx_shipments_order ON shipments(order_id);
CREATE INDEX idx_shipments_status ON shipments(shipment_status);
CREATE INDEX idx_shipments_tracking ON shipments(tracking_number);

CREATE INDEX idx_inventory_product ON inventory(product_id);
CREATE INDEX idx_inv_trans_product ON inventory_transactions(product_id);
CREATE INDEX idx_inv_trans_date ON inventory_transactions(transaction_date);

CREATE INDEX idx_reviews_product ON product_reviews(product_id);
CREATE INDEX idx_reviews_customer ON product_reviews(customer_id);
CREATE INDEX idx_reviews_rating ON product_reviews(rating);

CREATE INDEX idx_tickets_customer ON support_tickets(customer_id);
CREATE INDEX idx_tickets_status ON support_tickets(status);
CREATE INDEX idx_tickets_assignee ON support_tickets(assigned_to);

CREATE INDEX idx_audit_table ON audit_log(table_name);
CREATE INDEX idx_audit_date ON audit_log(performed_date);
CREATE INDEX idx_audit_action ON audit_log(action);

CREATE INDEX idx_po_supplier ON purchase_orders(supplier_id);
CREATE INDEX idx_po_status ON purchase_orders(status);

CREATE INDEX idx_returns_order ON returns(order_id);
CREATE INDEX idx_returns_customer ON returns(customer_id);
CREATE INDEX idx_returns_status ON returns(return_status);

CREATE INDEX idx_notif_customer ON notifications(customer_id);
CREATE INDEX idx_notif_read ON notifications(is_read);

-- ============================================================================
-- SECTION 11: VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW vw_customer_summary AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS full_name,
    c.email,
    c.loyalty_tier,
    c.loyalty_points,
    COUNT(DISTINCT o.order_id) AS total_orders,
    NVL(SUM(o.total_amount), 0) AS total_spent,
    NVL(AVG(o.total_amount), 0) AS avg_order_value,
    MAX(o.order_date) AS last_order_date,
    MONTHS_BETWEEN(SYSDATE, c.created_date) AS months_as_customer
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.order_status NOT IN ('CANCELLED','REFUNDED')
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.loyalty_tier, c.loyalty_points, c.created_date;

CREATE OR REPLACE VIEW vw_product_performance AS
SELECT
    p.product_id,
    p.sku,
    p.product_name,
    p.brand,
    pc.category_name,
    p.unit_price,
    p.cost_price,
    (p.unit_price - NVL(p.cost_price, 0)) AS margin,
    p.avg_rating,
    p.review_count,
    NVL(SUM(oi.quantity), 0) AS total_units_sold,
    NVL(SUM(oi.line_total), 0) AS total_revenue,
    COUNT(DISTINCT oi.order_id) AS order_count,
    NVL(SUM(inv.quantity_on_hand), 0) AS total_stock
FROM products p
LEFT JOIN product_categories pc ON p.category_id = pc.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN inventory inv ON p.product_id = inv.product_id
GROUP BY p.product_id, p.sku, p.product_name, p.brand, pc.category_name,
         p.unit_price, p.cost_price, p.avg_rating, p.review_count;

CREATE OR REPLACE VIEW vw_order_details AS
SELECT
    o.order_id,
    o.order_number,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email AS customer_email,
    o.order_status,
    o.order_date,
    o.subtotal,
    o.tax_amount,
    o.shipping_cost,
    o.discount_amount,
    o.total_amount,
    o.channel,
    sm.method_name AS shipping_method,
    COUNT(oi.order_item_id) AS item_count,
    SUM(oi.quantity) AS total_units
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN shipping_methods sm ON o.shipping_method_id = sm.method_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.order_number, c.first_name, c.last_name, c.email,
         o.order_status, o.order_date, o.subtotal, o.tax_amount, o.shipping_cost,
         o.discount_amount, o.total_amount, o.channel, sm.method_name;

CREATE OR REPLACE VIEW vw_inventory_alerts AS
SELECT
    w.warehouse_name,
    p.sku,
    p.product_name,
    inv.quantity_on_hand,
    inv.quantity_reserved,
    inv.quantity_available,
    inv.reorder_point,
    inv.reorder_quantity,
    CASE
        WHEN inv.quantity_available <= 0 THEN 'OUT_OF_STOCK'
        WHEN inv.quantity_available <= inv.reorder_point THEN 'LOW_STOCK'
        ELSE 'IN_STOCK'
    END AS stock_status,
    s.supplier_name,
    p.lead_time_days
FROM inventory inv
JOIN warehouses w ON inv.warehouse_id = w.warehouse_id
JOIN products p ON inv.product_id = p.product_id
LEFT JOIN suppliers s ON p.supplier_id = s.supplier_id
WHERE inv.quantity_available <= inv.reorder_point;

CREATE OR REPLACE VIEW vw_daily_sales_summary AS
SELECT
    TRUNC(o.order_date) AS sale_date,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    SUM(o.total_amount) AS total_revenue,
    AVG(o.total_amount) AS avg_order_value,
    SUM(o.discount_amount) AS total_discounts,
    SUM(o.shipping_cost) AS total_shipping,
    SUM(o.tax_amount) AS total_tax
FROM orders o
WHERE o.order_status NOT IN ('CANCELLED','REFUNDED')
GROUP BY TRUNC(o.order_date);

CREATE OR REPLACE VIEW vw_employee_performance AS
SELECT
    e.employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    d.department_name,
    e.job_title,
    COUNT(DISTINCT o.order_id) AS orders_handled,
    NVL(SUM(o.total_amount), 0) AS revenue_generated,
    COUNT(DISTINCT t.ticket_id) AS tickets_assigned,
    COUNT(DISTINCT CASE WHEN t.status = 'CLOSED' THEN t.ticket_id END) AS tickets_resolved,
    AVG(t.satisfaction_rating) AS avg_satisfaction
FROM employees e
LEFT JOIN departments d ON e.department_id = d.department_id
LEFT JOIN orders o ON e.employee_id = o.assigned_employee
LEFT JOIN support_tickets t ON e.employee_id = t.assigned_to
GROUP BY e.employee_id, e.first_name, e.last_name, d.department_name, e.job_title;

-- Materialized view for monthly revenue reporting
CREATE MATERIALIZED VIEW mv_monthly_revenue
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    TO_CHAR(o.order_date, 'YYYY-MM') AS month,
    o.channel,
    pc.category_name,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.line_total) AS revenue,
    SUM(oi.line_total - (NVL(p.cost_price, 0) * oi.quantity)) AS gross_profit
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_categories pc ON p.category_id = pc.category_id
WHERE o.order_status NOT IN ('CANCELLED','REFUNDED')
GROUP BY TO_CHAR(o.order_date, 'YYYY-MM'), o.channel, pc.category_name;

-- ============================================================================
-- SECTION 12: PL/SQL PACKAGES
-- ============================================================================

CREATE OR REPLACE PACKAGE pkg_order_management AS
    -- Order lifecycle management
    PROCEDURE create_order(
        p_customer_id   IN NUMBER,
        p_billing_addr  IN NUMBER,
        p_shipping_addr IN NUMBER,
        p_shipping_method IN NUMBER,
        p_channel       IN VARCHAR2 DEFAULT 'WEB',
        p_coupon_code   IN VARCHAR2 DEFAULT NULL,
        p_order_id      OUT NUMBER
    );

    PROCEDURE add_order_item(
        p_order_id   IN NUMBER,
        p_product_id IN NUMBER,
        p_variant_id IN NUMBER DEFAULT NULL,
        p_quantity   IN NUMBER,
        p_unit_price IN NUMBER DEFAULT NULL
    );

    PROCEDURE confirm_order(p_order_id IN NUMBER);
    PROCEDURE cancel_order(p_order_id IN NUMBER, p_reason IN VARCHAR2);
    PROCEDURE update_order_status(p_order_id IN NUMBER, p_new_status IN VARCHAR2, p_employee_id IN NUMBER DEFAULT NULL);

    FUNCTION calculate_order_total(p_order_id IN NUMBER) RETURN NUMBER;
    FUNCTION get_order_status(p_order_id IN NUMBER) RETURN VARCHAR2;
    FUNCTION validate_coupon(p_coupon_code IN VARCHAR2, p_customer_id IN NUMBER, p_order_total IN NUMBER) RETURN NUMBER;
END pkg_order_management;
/

CREATE OR REPLACE PACKAGE BODY pkg_order_management AS

    PROCEDURE create_order(
        p_customer_id   IN NUMBER,
        p_billing_addr  IN NUMBER,
        p_shipping_addr IN NUMBER,
        p_shipping_method IN NUMBER,
        p_channel       IN VARCHAR2 DEFAULT 'WEB',
        p_coupon_code   IN VARCHAR2 DEFAULT NULL,
        p_order_id      OUT NUMBER
    ) IS
        v_order_number VARCHAR2(30);
    BEGIN
        p_order_id := seq_order_id.NEXTVAL;
        v_order_number := 'ORD-' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '-' || LPAD(p_order_id, 8, '0');

        INSERT INTO orders (
            order_id, order_number, customer_id, order_status,
            billing_address_id, shipping_address_id, shipping_method_id,
            subtotal, total_amount, channel, coupon_code
        ) VALUES (
            p_order_id, v_order_number, p_customer_id, 'PENDING',
            p_billing_addr, p_shipping_addr, p_shipping_method,
            0, 0, p_channel, p_coupon_code
        );

        INSERT INTO order_status_history (history_id, order_id, new_status, change_reason)
        VALUES (seq_audit_id.NEXTVAL, p_order_id, 'PENDING', 'Order created');

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END create_order;

    PROCEDURE add_order_item(
        p_order_id   IN NUMBER,
        p_product_id IN NUMBER,
        p_variant_id IN NUMBER DEFAULT NULL,
        p_quantity   IN NUMBER,
        p_unit_price IN NUMBER DEFAULT NULL
    ) IS
        v_price NUMBER(12,2);
        v_tax_rate NUMBER(5,4) := 0;
        v_tax_amount NUMBER(12,2);
        v_line_total NUMBER(12,2);
    BEGIN
        IF p_unit_price IS NOT NULL THEN
            v_price := p_unit_price;
        ELSE
            SELECT unit_price INTO v_price FROM products WHERE product_id = p_product_id;
        END IF;

        IF p_variant_id IS NOT NULL THEN
            SELECT v_price + NVL(price_modifier, 0) INTO v_price
            FROM product_variants WHERE variant_id = p_variant_id;
        END IF;

        v_tax_amount := ROUND(v_price * p_quantity * v_tax_rate, 2);
        v_line_total := ROUND(v_price * p_quantity + v_tax_amount, 2);

        INSERT INTO order_items (
            order_item_id, order_id, product_id, variant_id,
            quantity, unit_price, tax_amount, line_total
        ) VALUES (
            seq_order_item_id.NEXTVAL, p_order_id, p_product_id, p_variant_id,
            p_quantity, v_price, v_tax_amount, v_line_total
        );

        -- Update order totals
        UPDATE orders SET
            subtotal = (SELECT SUM(line_total) FROM order_items WHERE order_id = p_order_id),
            tax_amount = (SELECT SUM(tax_amount) FROM order_items WHERE order_id = p_order_id),
            total_amount = (SELECT SUM(line_total) FROM order_items WHERE order_id = p_order_id),
            modified_date = SYSTIMESTAMP
        WHERE order_id = p_order_id;

        COMMIT;
    END add_order_item;

    PROCEDURE confirm_order(p_order_id IN NUMBER) IS
        v_status VARCHAR2(20);
    BEGIN
        SELECT order_status INTO v_status FROM orders WHERE order_id = p_order_id;
        IF v_status != 'PENDING' THEN
            RAISE_APPLICATION_ERROR(-20001, 'Order must be in PENDING status to confirm');
        END IF;
        update_order_status(p_order_id, 'CONFIRMED');
    END confirm_order;

    PROCEDURE cancel_order(p_order_id IN NUMBER, p_reason IN VARCHAR2) IS
        v_status VARCHAR2(20);
    BEGIN
        SELECT order_status INTO v_status FROM orders WHERE order_id = p_order_id;
        IF v_status IN ('SHIPPED','DELIVERED') THEN
            RAISE_APPLICATION_ERROR(-20002, 'Cannot cancel shipped or delivered orders');
        END IF;

        UPDATE orders SET
            order_status = 'CANCELLED',
            cancelled_date = SYSTIMESTAMP,
            cancellation_reason = p_reason,
            modified_date = SYSTIMESTAMP
        WHERE order_id = p_order_id;

        INSERT INTO order_status_history (history_id, order_id, old_status, new_status, change_reason)
        VALUES (seq_audit_id.NEXTVAL, p_order_id, v_status, 'CANCELLED', p_reason);

        -- Release reserved inventory
        FOR item IN (SELECT product_id, quantity, warehouse_id FROM order_items WHERE order_id = p_order_id) LOOP
            UPDATE inventory SET
                quantity_reserved = quantity_reserved - item.quantity
            WHERE product_id = item.product_id AND warehouse_id = NVL(item.warehouse_id, warehouse_id);
        END LOOP;

        COMMIT;
    END cancel_order;

    PROCEDURE update_order_status(p_order_id IN NUMBER, p_new_status IN VARCHAR2, p_employee_id IN NUMBER DEFAULT NULL) IS
        v_old_status VARCHAR2(20);
    BEGIN
        SELECT order_status INTO v_old_status FROM orders WHERE order_id = p_order_id FOR UPDATE;

        UPDATE orders SET order_status = p_new_status, modified_date = SYSTIMESTAMP
        WHERE order_id = p_order_id;

        INSERT INTO order_status_history (history_id, order_id, old_status, new_status, changed_by)
        VALUES (seq_audit_id.NEXTVAL, p_order_id, v_old_status, p_new_status, p_employee_id);

        COMMIT;
    END update_order_status;

    FUNCTION calculate_order_total(p_order_id IN NUMBER) RETURN NUMBER IS
        v_total NUMBER(12,2);
    BEGIN
        SELECT NVL(SUM(line_total), 0) INTO v_total
        FROM order_items WHERE order_id = p_order_id;
        RETURN v_total;
    END calculate_order_total;

    FUNCTION get_order_status(p_order_id IN NUMBER) RETURN VARCHAR2 IS
        v_status VARCHAR2(20);
    BEGIN
        SELECT order_status INTO v_status FROM orders WHERE order_id = p_order_id;
        RETURN v_status;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN NULL;
    END get_order_status;

    FUNCTION validate_coupon(p_coupon_code IN VARCHAR2, p_customer_id IN NUMBER, p_order_total IN NUMBER) RETURN NUMBER IS
        v_discount NUMBER(12,2) := 0;
        v_coupon coupons%ROWTYPE;
        v_customer_usage NUMBER;
    BEGIN
        SELECT * INTO v_coupon FROM coupons
        WHERE coupon_code = p_coupon_code AND is_active = 'Y'
        AND SYSTIMESTAMP BETWEEN valid_from AND valid_to;

        IF v_coupon.usage_limit IS NOT NULL AND v_coupon.usage_count >= v_coupon.usage_limit THEN
            RETURN 0;
        END IF;

        SELECT COUNT(*) INTO v_customer_usage FROM orders
        WHERE customer_id = p_customer_id AND coupon_code = p_coupon_code
        AND order_status NOT IN ('CANCELLED','REFUNDED');

        IF v_customer_usage >= v_coupon.per_customer_limit THEN
            RETURN 0;
        END IF;

        IF v_coupon.min_order_amount IS NOT NULL AND p_order_total < v_coupon.min_order_amount THEN
            RETURN 0;
        END IF;

        IF v_coupon.discount_type = 'PERCENTAGE' THEN
            v_discount := ROUND(p_order_total * v_coupon.discount_value / 100, 2);
        ELSIF v_coupon.discount_type = 'FIXED_AMOUNT' THEN
            v_discount := v_coupon.discount_value;
        END IF;

        IF v_coupon.max_discount IS NOT NULL AND v_discount > v_coupon.max_discount THEN
            v_discount := v_coupon.max_discount;
        END IF;

        RETURN v_discount;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 0;
    END validate_coupon;

END pkg_order_management;
/

-- ============================================================================
-- SECTION 13: MORE PL/SQL - INVENTORY & CUSTOMER PACKAGES
-- ============================================================================

CREATE OR REPLACE PACKAGE pkg_inventory_management AS
    PROCEDURE receive_stock(p_warehouse_id IN NUMBER, p_product_id IN NUMBER, p_quantity IN NUMBER, p_employee_id IN NUMBER);
    PROCEDURE reserve_stock(p_warehouse_id IN NUMBER, p_product_id IN NUMBER, p_quantity IN NUMBER);
    PROCEDURE release_reservation(p_warehouse_id IN NUMBER, p_product_id IN NUMBER, p_quantity IN NUMBER);
    PROCEDURE transfer_stock(p_from_warehouse IN NUMBER, p_to_warehouse IN NUMBER, p_product_id IN NUMBER, p_quantity IN NUMBER, p_employee_id IN NUMBER);
    PROCEDURE adjust_stock(p_warehouse_id IN NUMBER, p_product_id IN NUMBER, p_new_quantity IN NUMBER, p_reason IN VARCHAR2, p_employee_id IN NUMBER);
    FUNCTION get_available_stock(p_product_id IN NUMBER, p_warehouse_id IN NUMBER DEFAULT NULL) RETURN NUMBER;
    FUNCTION check_reorder_needed(p_product_id IN NUMBER, p_warehouse_id IN NUMBER) RETURN BOOLEAN;
END pkg_inventory_management;
/

CREATE OR REPLACE PACKAGE BODY pkg_inventory_management AS

    PROCEDURE receive_stock(p_warehouse_id IN NUMBER, p_product_id IN NUMBER, p_quantity IN NUMBER, p_employee_id IN NUMBER) IS
    BEGIN
        MERGE INTO inventory inv
        USING (SELECT p_warehouse_id AS wid, p_product_id AS pid FROM dual) src
        ON (inv.warehouse_id = src.wid AND inv.product_id = src.pid)
        WHEN MATCHED THEN
            UPDATE SET quantity_on_hand = quantity_on_hand + p_quantity, last_received_date = SYSDATE
        WHEN NOT MATCHED THEN
            INSERT (warehouse_id, product_id, quantity_on_hand, last_received_date)
            VALUES (p_warehouse_id, p_product_id, p_quantity, SYSDATE);

        INSERT INTO inventory_transactions (transaction_id, warehouse_id, product_id, transaction_type, quantity, performed_by)
        VALUES (seq_audit_id.NEXTVAL, p_warehouse_id, p_product_id, 'RECEIPT', p_quantity, p_employee_id);

        COMMIT;
    END receive_stock;

    PROCEDURE reserve_stock(p_warehouse_id IN NUMBER, p_product_id IN NUMBER, p_quantity IN NUMBER) IS
        v_available NUMBER;
    BEGIN
        SELECT quantity_on_hand - quantity_reserved INTO v_available
        FROM inventory WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id FOR UPDATE;

        IF v_available < p_quantity THEN
            RAISE_APPLICATION_ERROR(-20010, 'Insufficient stock. Available: ' || v_available || ', Requested: ' || p_quantity);
        END IF;

        UPDATE inventory SET quantity_reserved = quantity_reserved + p_quantity
        WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;

        COMMIT;
    END reserve_stock;

    PROCEDURE release_reservation(p_warehouse_id IN NUMBER, p_product_id IN NUMBER, p_quantity IN NUMBER) IS
    BEGIN
        UPDATE inventory SET quantity_reserved = GREATEST(quantity_reserved - p_quantity, 0)
        WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
        COMMIT;
    END release_reservation;

    PROCEDURE transfer_stock(p_from_warehouse IN NUMBER, p_to_warehouse IN NUMBER, p_product_id IN NUMBER, p_quantity IN NUMBER, p_employee_id IN NUMBER) IS
    BEGIN
        UPDATE inventory SET quantity_on_hand = quantity_on_hand - p_quantity
        WHERE warehouse_id = p_from_warehouse AND product_id = p_product_id;

        MERGE INTO inventory inv
        USING (SELECT p_to_warehouse AS wid, p_product_id AS pid FROM dual) src
        ON (inv.warehouse_id = src.wid AND inv.product_id = src.pid)
        WHEN MATCHED THEN UPDATE SET quantity_on_hand = quantity_on_hand + p_quantity
        WHEN NOT MATCHED THEN INSERT (warehouse_id, product_id, quantity_on_hand) VALUES (p_to_warehouse, p_product_id, p_quantity);

        INSERT INTO inventory_transactions (transaction_id, warehouse_id, product_id, transaction_type, quantity, reference_type, reference_id, performed_by)
        VALUES (seq_audit_id.NEXTVAL, p_from_warehouse, p_product_id, 'TRANSFER', -p_quantity, 'WAREHOUSE', p_to_warehouse, p_employee_id);

        INSERT INTO inventory_transactions (transaction_id, warehouse_id, product_id, transaction_type, quantity, reference_type, reference_id, performed_by)
        VALUES (seq_audit_id.NEXTVAL, p_to_warehouse, p_product_id, 'TRANSFER', p_quantity, 'WAREHOUSE', p_from_warehouse, p_employee_id);

        COMMIT;
    END transfer_stock;

    PROCEDURE adjust_stock(p_warehouse_id IN NUMBER, p_product_id IN NUMBER, p_new_quantity IN NUMBER, p_reason IN VARCHAR2, p_employee_id IN NUMBER) IS
        v_old_qty NUMBER;
    BEGIN
        SELECT quantity_on_hand INTO v_old_qty FROM inventory
        WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id FOR UPDATE;

        UPDATE inventory SET quantity_on_hand = p_new_quantity, last_counted_date = SYSDATE
        WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;

        INSERT INTO inventory_transactions (transaction_id, warehouse_id, product_id, transaction_type, quantity, notes, performed_by)
        VALUES (seq_audit_id.NEXTVAL, p_warehouse_id, p_product_id, 'ADJUSTMENT', p_new_quantity - v_old_qty, p_reason, p_employee_id);

        COMMIT;
    END adjust_stock;

    FUNCTION get_available_stock(p_product_id IN NUMBER, p_warehouse_id IN NUMBER DEFAULT NULL) RETURN NUMBER IS
        v_available NUMBER := 0;
    BEGIN
        IF p_warehouse_id IS NOT NULL THEN
            SELECT NVL(quantity_on_hand - quantity_reserved, 0) INTO v_available
            FROM inventory WHERE product_id = p_product_id AND warehouse_id = p_warehouse_id;
        ELSE
            SELECT NVL(SUM(quantity_on_hand - quantity_reserved), 0) INTO v_available
            FROM inventory WHERE product_id = p_product_id;
        END IF;
        RETURN v_available;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 0;
    END get_available_stock;

    FUNCTION check_reorder_needed(p_product_id IN NUMBER, p_warehouse_id IN NUMBER) RETURN BOOLEAN IS
        v_available NUMBER;
        v_reorder_point NUMBER;
    BEGIN
        SELECT quantity_on_hand - quantity_reserved, reorder_point INTO v_available, v_reorder_point
        FROM inventory WHERE product_id = p_product_id AND warehouse_id = p_warehouse_id;
        RETURN v_available <= v_reorder_point;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN FALSE;
    END check_reorder_needed;

END pkg_inventory_management;
/

CREATE OR REPLACE PACKAGE pkg_customer_management AS
    PROCEDURE register_customer(p_email IN VARCHAR2, p_password IN VARCHAR2, p_first_name IN VARCHAR2, p_last_name IN VARCHAR2, p_source IN VARCHAR2 DEFAULT 'WEB', p_customer_id OUT NUMBER);
    PROCEDURE update_loyalty_tier(p_customer_id IN NUMBER);
    PROCEDURE add_loyalty_points(p_customer_id IN NUMBER, p_points IN NUMBER, p_reason IN VARCHAR2);
    FUNCTION get_customer_lifetime_value(p_customer_id IN NUMBER) RETURN NUMBER;
    FUNCTION get_recommended_products(p_customer_id IN NUMBER, p_limit IN NUMBER DEFAULT 10) RETURN SYS_REFCURSOR;
END pkg_customer_management;
/

CREATE OR REPLACE PACKAGE BODY pkg_customer_management AS

    PROCEDURE register_customer(p_email IN VARCHAR2, p_password IN VARCHAR2, p_first_name IN VARCHAR2, p_last_name IN VARCHAR2, p_source IN VARCHAR2 DEFAULT 'WEB', p_customer_id OUT NUMBER) IS
    BEGIN
        p_customer_id := seq_customer_id.NEXTVAL;
        INSERT INTO customers (customer_id, email, password_hash, first_name, last_name, registration_source)
        VALUES (p_customer_id, LOWER(p_email), DBMS_CRYPTO.HASH(UTL_RAW.CAST_TO_RAW(p_password), DBMS_CRYPTO.HASH_SH256), p_first_name, p_last_name, p_source);

        INSERT INTO notifications (notification_id, customer_id, notification_type, subject, body)
        VALUES (seq_notification_id.NEXTVAL, p_customer_id, 'WELCOME', 'Welcome!', 'Thank you for registering.');

        COMMIT;
    END register_customer;

    PROCEDURE update_loyalty_tier(p_customer_id IN NUMBER) IS
        v_total_spent NUMBER;
        v_new_tier VARCHAR2(20);
    BEGIN
        SELECT NVL(SUM(total_amount), 0) INTO v_total_spent
        FROM orders WHERE customer_id = p_customer_id AND order_status NOT IN ('CANCELLED','REFUNDED');

        v_new_tier := CASE
            WHEN v_total_spent >= 10000 THEN 'DIAMOND'
            WHEN v_total_spent >= 5000  THEN 'PLATINUM'
            WHEN v_total_spent >= 2000  THEN 'GOLD'
            WHEN v_total_spent >= 500   THEN 'SILVER'
            ELSE 'BRONZE'
        END;

        UPDATE customers SET loyalty_tier = v_new_tier, modified_date = SYSTIMESTAMP
        WHERE customer_id = p_customer_id;

        COMMIT;
    END update_loyalty_tier;

    PROCEDURE add_loyalty_points(p_customer_id IN NUMBER, p_points IN NUMBER, p_reason IN VARCHAR2) IS
    BEGIN
        UPDATE customers SET loyalty_points = loyalty_points + p_points, modified_date = SYSTIMESTAMP
        WHERE customer_id = p_customer_id;
        COMMIT;
    END add_loyalty_points;

    FUNCTION get_customer_lifetime_value(p_customer_id IN NUMBER) RETURN NUMBER IS
        v_clv NUMBER;
    BEGIN
        SELECT NVL(SUM(total_amount), 0) INTO v_clv
        FROM orders WHERE customer_id = p_customer_id AND order_status NOT IN ('CANCELLED','REFUNDED');
        RETURN v_clv;
    END get_customer_lifetime_value;

    FUNCTION get_recommended_products(p_customer_id IN NUMBER, p_limit IN NUMBER DEFAULT 10) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT p.product_id, p.product_name, p.unit_price, p.avg_rating
            FROM products p
            WHERE p.status = 'ACTIVE'
            AND p.category_id IN (
                SELECT DISTINCT p2.category_id FROM order_items oi
                JOIN orders o ON oi.order_id = o.order_id
                JOIN products p2 ON oi.product_id = p2.product_id
                WHERE o.customer_id = p_customer_id
            )
            AND p.product_id NOT IN (
                SELECT oi.product_id FROM order_items oi
                JOIN orders o ON oi.order_id = o.order_id
                WHERE o.customer_id = p_customer_id
            )
            ORDER BY p.avg_rating DESC, p.review_count DESC
            FETCH FIRST p_limit ROWS ONLY;
        RETURN v_cursor;
    END get_recommended_products;

END pkg_customer_management;
/

-- ============================================================================
-- SECTION 14: STANDALONE PROCEDURES AND FUNCTIONS
-- ============================================================================

CREATE OR REPLACE PROCEDURE proc_process_payment(
    p_order_id        IN NUMBER,
    p_payment_method  IN NUMBER,
    p_amount          IN NUMBER,
    p_transaction_ref IN VARCHAR2,
    p_payment_id      OUT NUMBER
) AS
    v_order_total NUMBER;
    v_paid_total NUMBER;
BEGIN
    SELECT total_amount INTO v_order_total FROM orders WHERE order_id = p_order_id;

    SELECT NVL(SUM(amount), 0) INTO v_paid_total FROM payments
    WHERE order_id = p_order_id AND payment_status IN ('AUTHORIZED','CAPTURED');

    IF v_paid_total + p_amount > v_order_total THEN
        RAISE_APPLICATION_ERROR(-20020, 'Payment exceeds order total');
    END IF;

    p_payment_id := seq_payment_id.NEXTVAL;
    INSERT INTO payments (payment_id, order_id, payment_method_id, amount, payment_status, transaction_ref)
    VALUES (p_payment_id, p_order_id, p_payment_method, p_amount, 'CAPTURED', p_transaction_ref);

    IF v_paid_total + p_amount >= v_order_total THEN
        UPDATE orders SET order_status = 'CONFIRMED', modified_date = SYSTIMESTAMP WHERE order_id = p_order_id;
    END IF;

    COMMIT;
END proc_process_payment;
/

CREATE OR REPLACE PROCEDURE proc_create_shipment(
    p_order_id        IN NUMBER,
    p_warehouse_id    IN NUMBER,
    p_tracking_number IN VARCHAR2,
    p_carrier         IN VARCHAR2,
    p_shipment_id     OUT NUMBER
) AS
BEGIN
    p_shipment_id := seq_shipment_id.NEXTVAL;
    INSERT INTO shipments (shipment_id, order_id, warehouse_id, tracking_number, carrier, shipment_status, shipped_date)
    VALUES (p_shipment_id, p_order_id, p_warehouse_id, p_tracking_number, p_carrier, 'SHIPPED', SYSTIMESTAMP);

    -- Add all order items to shipment
    INSERT INTO shipment_items (shipment_id, order_item_id, quantity)
    SELECT p_shipment_id, order_item_id, quantity FROM order_items WHERE order_id = p_order_id;

    UPDATE orders SET order_status = 'SHIPPED', modified_date = SYSTIMESTAMP WHERE order_id = p_order_id;

    -- Deduct from inventory
    FOR item IN (SELECT product_id, quantity, warehouse_id FROM order_items WHERE order_id = p_order_id) LOOP
        UPDATE inventory SET
            quantity_on_hand = quantity_on_hand - item.quantity,
            quantity_reserved = GREATEST(quantity_reserved - item.quantity, 0)
        WHERE product_id = item.product_id AND warehouse_id = p_warehouse_id;

        INSERT INTO inventory_transactions (transaction_id, warehouse_id, product_id, transaction_type, quantity, reference_type, reference_id)
        VALUES (seq_audit_id.NEXTVAL, p_warehouse_id, item.product_id, 'SHIPMENT', -item.quantity, 'ORDER', p_order_id);
    END LOOP;

    COMMIT;
END proc_create_shipment;
/

CREATE OR REPLACE PROCEDURE proc_process_return(
    p_return_id IN NUMBER,
    p_action    IN VARCHAR2  -- 'APPROVE' or 'REJECT'
) AS
    v_return returns%ROWTYPE;
BEGIN
    SELECT * INTO v_return FROM returns WHERE return_id = p_return_id FOR UPDATE;

    IF v_return.return_status != 'REQUESTED' THEN
        RAISE_APPLICATION_ERROR(-20030, 'Return is not in REQUESTED status');
    END IF;

    IF p_action = 'APPROVE' THEN
        UPDATE returns SET return_status = 'APPROVED', approved_date = SYSTIMESTAMP WHERE return_id = p_return_id;
    ELSIF p_action = 'REJECT' THEN
        UPDATE returns SET return_status = 'REJECTED' WHERE return_id = p_return_id;
    END IF;

    COMMIT;
END proc_process_return;
/

CREATE OR REPLACE PROCEDURE proc_complete_return(p_return_id IN NUMBER) AS
    v_return returns%ROWTYPE;
BEGIN
    SELECT * INTO v_return FROM returns WHERE return_id = p_return_id;

    IF v_return.return_status != 'RECEIVED' THEN
        RAISE_APPLICATION_ERROR(-20031, 'Return must be in RECEIVED status');
    END IF;

    -- Process refund
    IF v_return.return_type = 'REFUND' THEN
        INSERT INTO payments (payment_id, order_id, amount, payment_status, transaction_ref)
        VALUES (seq_payment_id.NEXTVAL, v_return.order_id, -v_return.refund_amount, 'REFUNDED', 'RET-' || p_return_id);
    ELSIF v_return.return_type = 'STORE_CREDIT' THEN
        UPDATE customers SET loyalty_points = loyalty_points + ROUND(v_return.refund_amount)
        WHERE customer_id = v_return.customer_id;
    END IF;

    -- Return items to inventory
    FOR item IN (
        SELECT oi.product_id, ri.quantity
        FROM return_items ri JOIN order_items oi ON ri.order_item_id = oi.order_item_id
        WHERE ri.return_id = p_return_id AND ri.condition != 'DAMAGED'
    ) LOOP
        UPDATE inventory SET quantity_on_hand = quantity_on_hand + item.quantity
        WHERE product_id = item.product_id AND ROWNUM = 1;
    END LOOP;

    UPDATE returns SET return_status = 'COMPLETED', completed_date = SYSTIMESTAMP WHERE return_id = p_return_id;
    COMMIT;
END proc_complete_return;
/

CREATE OR REPLACE FUNCTION fn_calculate_shipping_cost(
    p_shipping_method IN NUMBER,
    p_weight_kg       IN NUMBER,
    p_country_code    IN VARCHAR2
) RETURN NUMBER IS
    v_base_cost NUMBER;
    v_per_kg    NUMBER;
    v_total     NUMBER;
BEGIN
    SELECT base_cost, cost_per_kg INTO v_base_cost, v_per_kg
    FROM shipping_methods WHERE method_id = p_shipping_method;

    v_total := v_base_cost + (v_per_kg * p_weight_kg);

    -- International surcharge
    IF p_country_code != 'US' THEN
        v_total := v_total * 1.5;
    END IF;

    RETURN ROUND(v_total, 2);
END fn_calculate_shipping_cost;
/

CREATE OR REPLACE FUNCTION fn_get_product_availability(
    p_product_id IN NUMBER
) RETURN VARCHAR2 IS
    v_total_available NUMBER;
BEGIN
    SELECT NVL(SUM(quantity_on_hand - quantity_reserved), 0) INTO v_total_available
    FROM inventory WHERE product_id = p_product_id;

    RETURN CASE
        WHEN v_total_available > 50 THEN 'IN_STOCK'
        WHEN v_total_available > 0  THEN 'LOW_STOCK'
        ELSE 'OUT_OF_STOCK'
    END;
END fn_get_product_availability;
/

CREATE OR REPLACE FUNCTION fn_customer_segment(p_customer_id IN NUMBER) RETURN VARCHAR2 IS
    v_order_count NUMBER;
    v_total_spent NUMBER;
    v_last_order DATE;
    v_recency NUMBER;
BEGIN
    SELECT COUNT(*), NVL(SUM(total_amount), 0), MAX(order_date)
    INTO v_order_count, v_total_spent, v_last_order
    FROM orders WHERE customer_id = p_customer_id AND order_status NOT IN ('CANCELLED','REFUNDED');

    v_recency := NVL(TRUNC(SYSDATE) - TRUNC(v_last_order), 9999);

    RETURN CASE
        WHEN v_order_count = 0 THEN 'PROSPECT'
        WHEN v_recency > 365 THEN 'LAPSED'
        WHEN v_recency > 180 THEN 'AT_RISK'
        WHEN v_total_spent > 5000 AND v_order_count > 10 THEN 'VIP'
        WHEN v_order_count > 5 THEN 'LOYAL'
        WHEN v_order_count > 1 THEN 'REPEAT'
        ELSE 'NEW'
    END;
END fn_customer_segment;
/

-- ============================================================================
-- SECTION 15: TRIGGERS
-- ============================================================================

CREATE OR REPLACE TRIGGER trg_customers_audit
AFTER INSERT OR UPDATE OR DELETE ON customers
FOR EACH ROW
DECLARE
    v_action VARCHAR2(10);
BEGIN
    IF INSERTING THEN v_action := 'INSERT';
    ELSIF UPDATING THEN v_action := 'UPDATE';
    ELSE v_action := 'DELETE';
    END IF;

    INSERT INTO audit_log (audit_id, table_name, record_id, action, performed_date)
    VALUES (seq_audit_id.NEXTVAL, 'CUSTOMERS', NVL(:NEW.customer_id, :OLD.customer_id), v_action, SYSTIMESTAMP);
END;
/

CREATE OR REPLACE TRIGGER trg_orders_audit
AFTER INSERT OR UPDATE OR DELETE ON orders
FOR EACH ROW
DECLARE
    v_action VARCHAR2(10);
BEGIN
    IF INSERTING THEN v_action := 'INSERT';
    ELSIF UPDATING THEN v_action := 'UPDATE';
    ELSE v_action := 'DELETE';
    END IF;

    INSERT INTO audit_log (audit_id, table_name, record_id, action, performed_date)
    VALUES (seq_audit_id.NEXTVAL, 'ORDERS', NVL(:NEW.order_id, :OLD.order_id), v_action, SYSTIMESTAMP);
END;
/

CREATE OR REPLACE TRIGGER trg_order_status_change
AFTER UPDATE OF order_status ON orders
FOR EACH ROW
BEGIN
    IF :OLD.order_status != :NEW.order_status THEN
        -- Send notification to customer
        INSERT INTO notifications (notification_id, customer_id, notification_type, subject, body)
        VALUES (seq_notification_id.NEXTVAL, :NEW.customer_id, 'ORDER_STATUS',
                'Order ' || :NEW.order_number || ' Status Update',
                'Your order status changed from ' || :OLD.order_status || ' to ' || :NEW.order_status);
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_inventory_low_stock
AFTER UPDATE OF quantity_on_hand ON inventory
FOR EACH ROW
BEGIN
    IF :NEW.quantity_on_hand - :NEW.quantity_reserved <= :NEW.reorder_point
       AND :OLD.quantity_on_hand - :OLD.quantity_reserved > :OLD.reorder_point THEN
        INSERT INTO notifications (notification_id, notification_type, subject, body)
        VALUES (seq_notification_id.NEXTVAL, 'LOW_STOCK_ALERT',
                'Low Stock Alert - Product ' || :NEW.product_id,
                'Product ' || :NEW.product_id || ' in warehouse ' || :NEW.warehouse_id ||
                ' has fallen below reorder point. Available: ' || (:NEW.quantity_on_hand - :NEW.quantity_reserved));
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_product_review_stats
AFTER INSERT OR DELETE ON product_reviews
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        UPDATE products SET
            avg_rating = (SELECT AVG(rating) FROM product_reviews WHERE product_id = :NEW.product_id AND is_approved = 'Y'),
            review_count = (SELECT COUNT(*) FROM product_reviews WHERE product_id = :NEW.product_id AND is_approved = 'Y'),
            modified_date = SYSTIMESTAMP
        WHERE product_id = :NEW.product_id;
    ELSIF DELETING THEN
        UPDATE products SET
            avg_rating = NVL((SELECT AVG(rating) FROM product_reviews WHERE product_id = :OLD.product_id AND is_approved = 'Y'), 0),
            review_count = (SELECT COUNT(*) FROM product_reviews WHERE product_id = :OLD.product_id AND is_approved = 'Y'),
            modified_date = SYSTIMESTAMP
        WHERE product_id = :OLD.product_id;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_payment_order_update
AFTER INSERT ON payments
FOR EACH ROW
DECLARE
    v_order_total NUMBER;
    v_paid_total NUMBER;
BEGIN
    IF :NEW.payment_status = 'CAPTURED' THEN
        SELECT total_amount INTO v_order_total FROM orders WHERE order_id = :NEW.order_id;
        SELECT NVL(SUM(amount), 0) INTO v_paid_total FROM payments
        WHERE order_id = :NEW.order_id AND payment_status = 'CAPTURED';

        IF v_paid_total >= v_order_total THEN
            UPDATE orders SET order_status = 'PROCESSING', modified_date = SYSTIMESTAMP
            WHERE order_id = :NEW.order_id AND order_status = 'CONFIRMED';
        END IF;
    END IF;
END;
/

-- ============================================================================
-- SECTION 16: SAMPLE DATA
-- ============================================================================

-- Countries
INSERT INTO countries VALUES ('US', 'United States', 'USD', '+1', 'Y');
INSERT INTO countries VALUES ('GB', 'United Kingdom', 'GBP', '+44', 'Y');
INSERT INTO countries VALUES ('DE', 'Germany', 'EUR', '+49', 'Y');
INSERT INTO countries VALUES ('FR', 'France', 'EUR', '+33', 'Y');
INSERT INTO countries VALUES ('JP', 'Japan', 'JPY', '+81', 'Y');
INSERT INTO countries VALUES ('AU', 'Australia', 'AUD', '+61', 'Y');
INSERT INTO countries VALUES ('CA', 'Canada', 'CAD', '+1', 'Y');
INSERT INTO countries VALUES ('IN', 'India', 'INR', '+91', 'Y');
INSERT INTO countries VALUES ('BR', 'Brazil', 'BRL', '+55', 'Y');
INSERT INTO countries VALUES ('SG', 'Singapore', 'SGD', '+65', 'Y');

-- Currencies
INSERT INTO currencies VALUES ('USD', 'US Dollar', '$', 2);
INSERT INTO currencies VALUES ('EUR', 'Euro', '€', 2);
INSERT INTO currencies VALUES ('GBP', 'British Pound', '£', 2);
INSERT INTO currencies VALUES ('JPY', 'Japanese Yen', '¥', 0);
INSERT INTO currencies VALUES ('AUD', 'Australian Dollar', 'A$', 2);
INSERT INTO currencies VALUES ('CAD', 'Canadian Dollar', 'C$', 2);
INSERT INTO currencies VALUES ('INR', 'Indian Rupee', '₹', 2);

-- Departments
INSERT INTO departments (department_id, department_name, department_code, budget) VALUES (seq_department_id.NEXTVAL, 'Executive', 'EXEC', 500000);
INSERT INTO departments (department_id, department_name, department_code, budget) VALUES (seq_department_id.NEXTVAL, 'Engineering', 'ENG', 2000000);
INSERT INTO departments (department_id, department_name, department_code, budget) VALUES (seq_department_id.NEXTVAL, 'Sales', 'SALES', 1500000);
INSERT INTO departments (department_id, department_name, department_code, budget) VALUES (seq_department_id.NEXTVAL, 'Marketing', 'MKT', 800000);
INSERT INTO departments (department_id, department_name, department_code, budget) VALUES (seq_department_id.NEXTVAL, 'Customer Support', 'CS', 600000);
INSERT INTO departments (department_id, department_name, department_code, budget) VALUES (seq_department_id.NEXTVAL, 'Warehouse Operations', 'WH', 400000);
INSERT INTO departments (department_id, department_name, department_code, budget) VALUES (seq_department_id.NEXTVAL, 'Finance', 'FIN', 700000);
INSERT INTO departments (department_id, department_name, department_code, budget) VALUES (seq_department_id.NEXTVAL, 'Human Resources', 'HR', 350000);

-- Product Categories
INSERT INTO product_categories (category_id, category_name, slug, display_order) VALUES (seq_category_id.NEXTVAL, 'Electronics', 'electronics', 1);
INSERT INTO product_categories (category_id, category_name, slug, display_order) VALUES (seq_category_id.NEXTVAL, 'Clothing', 'clothing', 2);
INSERT INTO product_categories (category_id, category_name, slug, display_order) VALUES (seq_category_id.NEXTVAL, 'Home & Garden', 'home-garden', 3);
INSERT INTO product_categories (category_id, category_name, slug, display_order) VALUES (seq_category_id.NEXTVAL, 'Books', 'books', 4);
INSERT INTO product_categories (category_id, category_name, slug, display_order) VALUES (seq_category_id.NEXTVAL, 'Sports & Outdoors', 'sports-outdoors', 5);
INSERT INTO product_categories (category_id, category_name, slug, parent_id, display_order) VALUES (seq_category_id.NEXTVAL, 'Laptops', 'laptops', 1, 1);
INSERT INTO product_categories (category_id, category_name, slug, parent_id, display_order) VALUES (seq_category_id.NEXTVAL, 'Smartphones', 'smartphones', 1, 2);
INSERT INTO product_categories (category_id, category_name, slug, parent_id, display_order) VALUES (seq_category_id.NEXTVAL, 'Audio', 'audio', 1, 3);
INSERT INTO product_categories (category_id, category_name, slug, parent_id, display_order) VALUES (seq_category_id.NEXTVAL, 'Men''s Clothing', 'mens-clothing', 2, 1);
INSERT INTO product_categories (category_id, category_name, slug, parent_id, display_order) VALUES (seq_category_id.NEXTVAL, 'Women''s Clothing', 'womens-clothing', 2, 2);

-- Shipping Methods
INSERT INTO shipping_methods VALUES (1, 'Standard Shipping', 'USPS', 5.99, 0.50, 5, 10, 'Y');
INSERT INTO shipping_methods VALUES (2, 'Express Shipping', 'FedEx', 12.99, 1.00, 2, 4, 'Y');
INSERT INTO shipping_methods VALUES (3, 'Overnight Shipping', 'UPS', 24.99, 2.00, 1, 1, 'Y');
INSERT INTO shipping_methods VALUES (4, 'Economy Shipping', 'USPS', 3.99, 0.25, 7, 14, 'Y');
INSERT INTO shipping_methods VALUES (5, 'International Standard', 'DHL', 19.99, 3.00, 10, 21, 'Y');

-- Payment Methods
INSERT INTO payment_methods VALUES (1, 'Visa', 'CREDIT_CARD', 'Stripe', 'Y');
INSERT INTO payment_methods VALUES (2, 'Mastercard', 'CREDIT_CARD', 'Stripe', 'Y');
INSERT INTO payment_methods VALUES (3, 'PayPal', 'WALLET', 'PayPal', 'Y');
INSERT INTO payment_methods VALUES (4, 'Bank Transfer', 'BANK_TRANSFER', NULL, 'Y');
INSERT INTO payment_methods VALUES (5, 'Apple Pay', 'WALLET', 'Stripe', 'Y');
INSERT INTO payment_methods VALUES (6, 'Cash on Delivery', 'COD', NULL, 'Y');

-- Tax Rates
INSERT INTO tax_rates VALUES (1, 'US', 'CA', 'STATE_SALES', 0.0725, DATE '2024-01-01', NULL, 'Y');
INSERT INTO tax_rates VALUES (2, 'US', 'NY', 'STATE_SALES', 0.0800, DATE '2024-01-01', NULL, 'Y');
INSERT INTO tax_rates VALUES (3, 'US', 'TX', 'STATE_SALES', 0.0625, DATE '2024-01-01', NULL, 'Y');
INSERT INTO tax_rates VALUES (4, 'GB', NULL, 'VAT', 0.2000, DATE '2024-01-01', NULL, 'Y');
INSERT INTO tax_rates VALUES (5, 'DE', NULL, 'VAT', 0.1900, DATE '2024-01-01', NULL, 'Y');

-- Email Templates
INSERT INTO email_templates (template_id, template_code, template_name, subject, body_html)
VALUES (1, 'WELCOME', 'Welcome Email', 'Welcome to Our Store!', '<h1>Welcome {{first_name}}!</h1><p>Thank you for joining us.</p>');
INSERT INTO email_templates (template_id, template_code, template_name, subject, body_html)
VALUES (2, 'ORDER_CONFIRM', 'Order Confirmation', 'Order {{order_number}} Confirmed', '<h1>Order Confirmed</h1><p>Your order {{order_number}} has been confirmed.</p>');
INSERT INTO email_templates (template_id, template_code, template_name, subject, body_html)
VALUES (3, 'SHIP_NOTIFY', 'Shipping Notification', 'Your Order Has Shipped!', '<h1>Shipped!</h1><p>Tracking: {{tracking_number}}</p>');
INSERT INTO email_templates (template_id, template_code, template_name, subject, body_html)
VALUES (4, 'PASSWORD_RESET', 'Password Reset', 'Reset Your Password', '<h1>Password Reset</h1><p>Click <a href="{{reset_link}}">here</a> to reset.</p>');
INSERT INTO email_templates (template_id, template_code, template_name, subject, body_html)
VALUES (5, 'REVIEW_REQUEST', 'Review Request', 'How Was Your Purchase?', '<h1>Leave a Review</h1><p>Tell us about {{product_name}}.</p>');

-- System Config
INSERT INTO system_config (config_key, config_value, config_type, description) VALUES ('site.name', 'Enterprise ERP Store', 'STRING', 'Site display name');
INSERT INTO system_config (config_key, config_value, config_type, description) VALUES ('site.currency', 'USD', 'STRING', 'Default currency');
INSERT INTO system_config (config_key, config_value, config_type, description) VALUES ('order.auto_cancel_hours', '48', 'NUMBER', 'Hours before unpaid orders auto-cancel');
INSERT INTO system_config (config_key, config_value, config_type, description) VALUES ('inventory.low_stock_threshold', '10', 'NUMBER', 'Default low stock alert threshold');
INSERT INTO system_config (config_key, config_value, config_type, description) VALUES ('loyalty.points_per_dollar', '10', 'NUMBER', 'Loyalty points earned per dollar spent');
INSERT INTO system_config (config_key, config_value, config_type, description) VALUES ('shipping.free_threshold', '75.00', 'NUMBER', 'Order amount for free shipping');
INSERT INTO system_config (config_key, config_value, config_type, description) VALUES ('review.auto_approve', 'N', 'BOOLEAN', 'Auto-approve product reviews');
INSERT INTO system_config (config_key, config_value, config_type, description) VALUES ('email.from_address', 'noreply@erp-store.com', 'STRING', 'Default from email');

-- Scheduled Jobs
INSERT INTO scheduled_jobs (job_id, job_name, job_type, cron_expression, procedure_name) VALUES (1, 'Auto Cancel Stale Orders', 'PLSQL', '0 */2 * * *', 'proc_auto_cancel_stale_orders');
INSERT INTO scheduled_jobs (job_id, job_name, job_type, cron_expression, procedure_name) VALUES (2, 'Update Loyalty Tiers', 'PLSQL', '0 1 * * *', 'proc_batch_update_loyalty_tiers');
INSERT INTO scheduled_jobs (job_id, job_name, job_type, cron_expression, procedure_name) VALUES (3, 'Refresh MV Monthly Revenue', 'PLSQL', '0 3 1 * *', 'DBMS_MVIEW.REFRESH(''mv_monthly_revenue'')');
INSERT INTO scheduled_jobs (job_id, job_name, job_type, cron_expression, procedure_name) VALUES (4, 'Purge Old Audit Logs', 'PLSQL', '0 4 1 * *', 'proc_purge_audit_logs');
INSERT INTO scheduled_jobs (job_id, job_name, job_type, cron_expression, procedure_name) VALUES (5, 'Send Review Requests', 'PLSQL', '0 10 * * *', 'proc_send_review_requests');
INSERT INTO scheduled_jobs (job_id, job_name, job_type, cron_expression, procedure_name) VALUES (6, 'Inventory Reorder Check', 'PLSQL', '0 6 * * *', 'proc_check_reorder_levels');

COMMIT;

-- ============================================================================
-- SECTION 17: GRANTS
-- ============================================================================

GRANT SELECT ON vw_customer_summary TO report_role;
GRANT SELECT ON vw_product_performance TO report_role;
GRANT SELECT ON vw_order_details TO report_role;
GRANT SELECT ON vw_daily_sales_summary TO report_role;
GRANT SELECT ON vw_inventory_alerts TO warehouse_role;
GRANT SELECT ON vw_employee_performance TO hr_role;

GRANT EXECUTE ON pkg_order_management TO app_role;
GRANT EXECUTE ON pkg_inventory_management TO warehouse_role;
GRANT EXECUTE ON pkg_customer_management TO app_role;
GRANT EXECUTE ON proc_process_payment TO app_role;
GRANT EXECUTE ON proc_create_shipment TO warehouse_role;
GRANT EXECUTE ON proc_process_return TO cs_role;
GRANT EXECUTE ON fn_calculate_shipping_cost TO app_role;
GRANT EXECUTE ON fn_get_product_availability TO app_role;
GRANT EXECUTE ON fn_customer_segment TO report_role;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
