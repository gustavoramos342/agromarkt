ALTER TABLE products
ADD COLUMN IF NOT EXISTS package_quantity NUMERIC(12, 3);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'products_package_quantity_positive'
    ) THEN
        ALTER TABLE products
        ADD CONSTRAINT products_package_quantity_positive
        CHECK (
            package_quantity IS NULL
            OR package_quantity > 0
        );
    END IF;
END
$$;
