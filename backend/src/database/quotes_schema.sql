CREATE TABLE IF NOT EXISTS quote_requests (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    producer_id BIGINT NOT NULL
        REFERENCES users(id),

    product_id BIGINT
        REFERENCES products(id)
        ON DELETE SET NULL,

    product_name VARCHAR(180) NOT NULL,
    category VARCHAR(80) NOT NULL,

    quantity NUMERIC(12, 2) NOT NULL
        CHECK (quantity > 0),

    unit VARCHAR(10) NOT NULL
        CHECK (unit IN ('kg', 'L', 'unidade')),

    location VARCHAR(180) NOT NULL,

    deadline TIMESTAMPTZ NOT NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'aberta'
        CHECK (
            status IN (
                'aberta',
                'em_negociacao',
                'concluida',
                'cancelada'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quote_requests_producer
    ON quote_requests (producer_id);

CREATE INDEX IF NOT EXISTS idx_quote_requests_status
    ON quote_requests (status);

CREATE INDEX IF NOT EXISTS idx_quote_requests_deadline
    ON quote_requests (deadline);


CREATE TABLE IF NOT EXISTS quote_proposals (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    request_id BIGINT NOT NULL
        REFERENCES quote_requests(id),

    supplier_id BIGINT NOT NULL
        REFERENCES users(id),

    price NUMERIC(12, 2) NOT NULL
        CHECK (price >= 0),

    notes VARCHAR(1000) NOT NULL DEFAULT '',

    status VARCHAR(20) NOT NULL DEFAULT 'enviada'
        CHECK (
            status IN (
                'enviada',
                'aceita',
                'recusada'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unique_supplier_proposal
        UNIQUE (request_id, supplier_id)
);

CREATE INDEX IF NOT EXISTS idx_quote_proposals_request
    ON quote_proposals (request_id);

CREATE INDEX IF NOT EXISTS idx_quote_proposals_supplier
    ON quote_proposals (supplier_id);

CREATE INDEX IF NOT EXISTS idx_quote_proposals_status
    ON quote_proposals (status);
