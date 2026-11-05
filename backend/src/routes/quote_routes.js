
const express = require('express');
const { pool } = require('../config/database');
const {
  authenticateToken,
  authorizeRoles,
} = require('../middleware/auth_middleware');

const router = express.Router();

const allowedUnits = ['kg', 'L', 'unidade'];

function validId(value) {
  return /^\d+$/.test(String(value)) && Number(value) > 0;
}

function validateRequest(data) {
  const {
    productId = null,
    productName,
    category,
    quantity,
    unit,
    location,
    deadline,
  } = data || {};

  const numericQuantity = Number(quantity);
  const deadlineDate = new Date(deadline);

  if (
    productId !== null &&
    productId !== '' &&
    !validId(productId)
  ) {
    return { error: 'Produto inválido.' };
  }

  if (
    typeof productName !== 'string' ||
    !productName.trim() ||
    productName.trim().length > 180 ||
    typeof category !== 'string' ||
    !category.trim() ||
    category.trim().length > 80 ||
    !Number.isFinite(numericQuantity) ||
    numericQuantity <= 0 ||
    !/^\d+(\.\d{1,2})?$/.test(String(quantity)) ||
    !allowedUnits.includes(unit) ||
    typeof location !== 'string' ||
    !location.trim() ||
    location.trim().length > 180 ||
    !deadline ||
    Number.isNaN(deadlineDate.getTime()) ||
    deadlineDate <= new Date()
  ) {
    return {
      error: 'Confira produto, categoria, quantidade, unidade, localização e prazo.',
    };
  }

  return {
    value: {
      productId: productId ? Number(productId) : null,
      productName: productName.trim(),
      category: category.trim(),
      quantity: numericQuantity,
      unit,
      location: location.trim(),
      deadline: deadlineDate,
    },
  };
}

function validateProposal(data) {
  const { price, notes = '' } = data || {};
  const numericPrice = Number(price);

  if (
    !Number.isFinite(numericPrice) ||
    numericPrice < 0 ||
    !/^\d+(\.\d{1,2})?$/.test(String(price)) ||
    typeof notes !== 'string' ||
    notes.length > 1000
  ) {
    return {
      error: 'Informe um preço válido e observações com até 1000 caracteres.',
    };
  }

  return {
    value: {
      price: numericPrice,
      notes: notes.trim(),
    },
  };
}

// Produtor cria uma solicitação.
router.post(
  '/',
  authenticateToken,
  authorizeRoles('produtor'),
  async (req, res, next) => {
    try {
      const validation = validateRequest(req.body);

      if (validation.error) {
        return res.status(400).json({ error: validation.error });
      }

      const data = validation.value;

      if (data.productId !== null) {
        const product = await pool.query(
          `SELECT id, name, category, unit
           FROM products
           WHERE id = $1 AND is_active = TRUE`,
          [data.productId],
        );

        if (product.rowCount === 0) {
          return res.status(400).json({
            error: 'Produto não encontrado ou inativo.',
          });
        }
      }

      const result = await pool.query(
        `INSERT INTO quote_requests
          (producer_id, product_id, product_name, category,
           quantity, unit, location, deadline)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING *`,
        [
          req.user.id,
          data.productId,
          data.productName,
          data.category,
          data.quantity,
          data.unit,
          data.location,
          data.deadline,
        ],
      );

      return res.status(201).json({
        message: 'Solicitação de cotação criada com sucesso.',
        request: result.rows[0],
      });
    } catch (error) {
      return next(error);
    }
  },
);

// Produtor consulta suas solicitações.
router.get(
  '/mine',
  authenticateToken,
  authorizeRoles('produtor'),
  async (req, res, next) => {
    try {
      const result = await pool.query(
        `SELECT *
         FROM quote_requests
         WHERE producer_id = $1
         ORDER BY created_at DESC`,
        [req.user.id],
      );

      return res.status(200).json({ requests: result.rows });
    } catch (error) {
      return next(error);
    }
  },
);

// Fornecedor consulta solicitações abertas e dentro do prazo.
router.get(
  '/open',
  authenticateToken,
  authorizeRoles('fornecedor'),
  async (req, res, next) => {
    try {
      const result = await pool.query(
        `SELECT
           qr.id,
           qr.product_name,
           qr.category,
           qr.quantity,
           qr.unit,
           qr.location,
           qr.deadline,
           qr.created_at
         FROM quote_requests qr
         WHERE qr.status IN ('aberta', 'em_negociacao')
           AND qr.deadline > NOW()
           AND NOT EXISTS (
             SELECT 1
             FROM quote_proposals qp
             WHERE qp.request_id = qr.id
               AND qp.supplier_id = $1
           )
         ORDER BY qr.created_at DESC
         LIMIT 100`,
        [req.user.id],
      );

      return res.status(200).json({ requests: result.rows });
    } catch (error) {
      return next(error);
    }
  },
);

// Fornecedor envia uma proposta.
router.post(
  '/:id/proposals',
  authenticateToken,
  authorizeRoles('fornecedor'),
  async (req, res, next) => {
    try {
      const requestId = req.params.id;

      if (!validId(requestId)) {
        return res.status(400).json({
          error: 'ID da solicitação inválido.',
        });
      }

      const validation = validateProposal(req.body);

      if (validation.error) {
        return res.status(400).json({ error: validation.error });
      }

      const request = await pool.query(
        `SELECT id
         FROM quote_requests
         WHERE id = $1
           AND status IN ('aberta', 'em_negociacao')
           AND deadline > NOW()`,
        [requestId],
      );

      if (request.rowCount === 0) {
        return res.status(404).json({
          error: 'Solicitação não encontrada, encerrada ou fora do prazo.',
        });
      }

      const proposal = await pool.query(
        `INSERT INTO quote_proposals
          (request_id, supplier_id, price, notes)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (request_id, supplier_id) DO NOTHING
         RETURNING *`,
        [
          requestId,
          req.user.id,
          validation.value.price,
          validation.value.notes,
        ],
      );

      if (proposal.rowCount === 0) {
        return res.status(409).json({
          error: 'Você já enviou uma proposta para esta solicitação.',
        });
      }

      await pool.query(
        `UPDATE quote_requests
         SET status = 'em_negociacao', updated_at = NOW()
         WHERE id = $1 AND status = 'aberta'`,
        [requestId],
      );

      return res.status(201).json({
        message: 'Proposta enviada com sucesso.',
        proposal: proposal.rows[0],
      });
    } catch (error) {
      return next(error);
    }
  },
);

// Produtor consulta propostas de uma solicitação própria.
router.get(
  '/:id/proposals',
  authenticateToken,
  authorizeRoles('produtor'),
  async (req, res, next) => {
    try {
      const requestId = req.params.id;

      if (!validId(requestId)) {
        return res.status(400).json({
          error: 'ID da solicitação inválido.',
        });
      }

      const result = await pool.query(
        `SELECT
           qp.id,
           qp.request_id,
           qp.price,
           qp.notes,
           qp.status,
           qp.created_at,
           u.name AS supplier
         FROM quote_proposals qp
         INNER JOIN quote_requests qr ON qr.id = qp.request_id
         INNER JOIN users u ON u.id = qp.supplier_id
         WHERE qr.id = $1
           AND qr.producer_id = $2
         ORDER BY qp.created_at DESC`,
        [requestId, req.user.id],
      );

      const ownership = await pool.query(
        `SELECT id FROM quote_requests
         WHERE id = $1 AND producer_id = $2`,
        [requestId, req.user.id],
      );

      if (ownership.rowCount === 0) {
        return res.status(404).json({
          error: 'Solicitação não encontrada.',
        });
      }

      return res.status(200).json({
        proposals: result.rows.map((proposal) => ({
          ...proposal,
          price: Number(proposal.price),
        })),
      });
    } catch (error) {
      return next(error);
    }
  },
);

// Produtor aceita ou recusa uma proposta.
router.patch(
  '/:id/proposals/:proposalId',
  authenticateToken,
  authorizeRoles('produtor'),
  async (req, res, next) => {
    const client = await pool.connect();

    try {
      const { id, proposalId } = req.params;
      const { status } = req.body || {};

      if (!validId(id) || !validId(proposalId)) {
        return res.status(400).json({
          error: 'ID da solicitação ou da proposta inválido.',
        });
      }

      if (!['aceita', 'recusada'].includes(status)) {
        return res.status(400).json({
          error: 'A situação deve ser aceita ou recusada.',
        });
      }

      await client.query('BEGIN');

      const request = await client.query(
        `SELECT id, status
         FROM quote_requests
         WHERE id = $1 AND producer_id = $2
         FOR UPDATE`,
        [id, req.user.id],
      );

      if (request.rowCount === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({
          error: 'Solicitação não encontrada.',
        });
      }

      if (
        request.rows[0].status === 'concluida' ||
        request.rows[0].status === 'cancelada'
      ) {
        await client.query('ROLLBACK');
        return res.status(409).json({
          error: 'Esta solicitação já foi encerrada.',
        });
      }

      const proposal = await client.query(
        `UPDATE quote_proposals
         SET status = $1, updated_at = NOW()
         WHERE id = $2
           AND request_id = $3
           AND status = 'enviada'
         RETURNING id`,
        [status, proposalId, id],
      );

      if (proposal.rowCount === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({
          error: 'Proposta não encontrada ou já respondida.',
        });
      }

      if (status === 'aceita') {
        await client.query(
          `UPDATE quote_proposals
           SET status = 'recusada', updated_at = NOW()
           WHERE request_id = $1
             AND id <> $2
             AND status = 'enviada'`,
          [id, proposalId],
        );

        await client.query(
          `UPDATE quote_requests
           SET status = 'concluida', updated_at = NOW()
           WHERE id = $1`,
          [id],
        );
      }

      await client.query('COMMIT');

      return res.status(200).json({
        message: status === 'aceita'
          ? 'Proposta aceita. As demais propostas pendentes foram recusadas.'
          : 'Proposta recusada com sucesso.',
      });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      return next(error);
    } finally {
      client.release();
    }
  },
);
// Histórico comercial do produtor.
router.get(
  '/history/producer',
  authenticateToken,
  authorizeRoles('produtor'),
  async (req, res, next) => {
    try {
      const result = await pool.query(
        `SELECT
           qr.id,
           qr.product_name,
           qr.category,
           qr.quantity,
           qr.unit,
           qr.location,
           qr.deadline,
           qr.status,
           qr.created_at,
           COUNT(qp.id)::int AS proposals_count,
           accepted.price AS accepted_price,
           supplier.name AS accepted_supplier
         FROM quote_requests qr
         LEFT JOIN quote_proposals qp
           ON qp.request_id = qr.id
         LEFT JOIN quote_proposals accepted
           ON accepted.request_id = qr.id
           AND accepted.status = 'aceita'
         LEFT JOIN users supplier
           ON supplier.id = accepted.supplier_id
         WHERE qr.producer_id = $1
         GROUP BY qr.id, accepted.price, supplier.name
         ORDER BY qr.created_at DESC`,
        [req.user.id],
      );

      return res.status(200).json({
        history: result.rows.map((item) => ({
          ...item,
          accepted_price: item.accepted_price === null
            ? null
            : Number(item.accepted_price),
        })),
      });
    } catch (error) {
      return next(error);
    }
  },
);

// Histórico comercial do fornecedor.
router.get(
  '/history/supplier',
  authenticateToken,
  authorizeRoles('fornecedor'),
  async (req, res, next) => {
    try {
      const result = await pool.query(
        `SELECT
           qp.id AS proposal_id,
           qp.request_id,
           qp.price,
           qp.notes,
           qp.status AS proposal_status,
           qp.created_at AS proposal_created_at,
           qr.product_name,
           qr.category,
           qr.quantity,
           qr.unit,
           qr.location,
           qr.deadline,
           qr.status AS request_status,
           producer.name AS producer
         FROM quote_proposals qp
         INNER JOIN quote_requests qr
           ON qr.id = qp.request_id
         INNER JOIN users producer
           ON producer.id = qr.producer_id
         WHERE qp.supplier_id = $1
         ORDER BY qp.created_at DESC`,
        [req.user.id],
      );

      return res.status(200).json({
        history: result.rows.map((item) => ({
          ...item,
          price: Number(item.price),
        })),
      });
    } catch (error) {
      return next(error);
    }
  },
);
module.exports = router;
