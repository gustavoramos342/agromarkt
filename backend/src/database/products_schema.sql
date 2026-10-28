CREATE TABLE IF NOT EXISTS products (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(180) NOT NULL,
    category VARCHAR(80) NOT NULL,
    unit VARCHAR(10) NOT NULL,
    price NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
    supplier_id BIGINT NOT NULL REFERENCES users(id),
    location VARCHAR(180) NOT NULL DEFAULT '',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_name
    ON products (name);

CREATE INDEX IF NOT EXISTS idx_products_category
    ON products (category);

CREATE INDEX IF NOT EXISTS idx_products_supplier
    ON products (supplier_id);

CREATE INDEX IF NOT EXISTS idx_products_active
    ON products (is_active);
