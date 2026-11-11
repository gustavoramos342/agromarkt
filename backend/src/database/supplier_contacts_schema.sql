CREATE TABLE IF NOT EXISTS supplier_contacts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_id BIGINT NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,
    contact_type VARCHAR(30) NOT NULL
        CHECK (
            contact_type IN (
                'telefone',
                'whatsapp',
                'email',
                'site',
                'instagram',
                'outro'
            )
        ),
    label VARCHAR(60),
    contact_value VARCHAR(254) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_supplier_contacts_supplier_id
    ON supplier_contacts (supplier_id);
