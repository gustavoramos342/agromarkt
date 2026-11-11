const express = require('express');
const { pool } = require('../config/database');
const {
  authenticateToken,
  authorizeRoles,
} = require('../middleware/auth_middleware');

const router = express.Router();

const allowedContactTypes = [
  'telefone',
  'whatsapp',
  'email',
  'site',
  'instagram',
  'outro',
];

const MAX_CONTACTS = 10;

function validateContact(data) {
  const {
    contact_type,
    label = '',
    contact_value,
  } = data || {};

  if (
    typeof contact_type !== 'string' ||
    !allowedContactTypes.includes(contact_type) ||
    typeof label !== 'string' ||
    label.trim().length > 60 ||
    typeof contact_value !== 'string' ||
    !contact_value.trim() ||
    contact_value.trim().length > 254
  ) {
    return {
      error: 'Informe um tipo válido e um contato de até 254 caracteres. O rótulo pode ter até 60 caracteres.',
    };
  }

  if (
    contact_type === 'email' &&
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contact_value.trim())
  ) {
    return {
      error: 'Informe um endereço de e-mail válido.',
    };
  }

  return {
    value: {
      contact_type,
      label: label.trim(),
      contact_value: contact_value.trim(),
    },
  };
}

// Todas as rotas exigem autenticação e perfil de fornecedor.
router.use(authenticateToken, authorizeRoles('fornecedor'));

// Lista somente os contatos do fornecedor autenticado.
router.get('/', async (req, res, next) => {
  try {
    const result = await pool.query(
      `
      SELECT id, contact_type, label, contact_value, created_at, updated_at
      FROM supplier_contacts
      WHERE supplier_id = $1
      ORDER BY id ASC
      `,
      [req.user.id],
    );

    return res.status(200).json({
      contacts: result.rows.map((contact) => ({
        ...contact,
        id: Number(contact.id),
      })),
    });
  } catch (error) {
    return next(error);
  }
});

// Cadastra um contato para o fornecedor autenticado.
router.post('/', async (req, res, next) => {
  try {
    const validation = validateContact(req.body);

    if (validation.error) {
      return res.status(400).json({ error: validation.error });
    }

    const countResult = await pool.query(
      'SELECT COUNT(*)::int AS total FROM supplier_contacts WHERE supplier_id = $1',
      [req.user.id],
    );

    if (countResult.rows[0].total >= MAX_CONTACTS) {
      return res.status(409).json({
        error: `O limite de ${MAX_CONTACTS} contatos foi atingido.`,
      });
    }

    const { contact_type, label, contact_value } = validation.value;

    const result = await pool.query(
      `
      INSERT INTO supplier_contacts
        (supplier_id, contact_type, label, contact_value)
      VALUES ($1, $2, $3, $4)
      RETURNING id, contact_type, label, contact_value, created_at, updated_at
      `,
      [req.user.id, contact_type, label || null, contact_value],
    );

    return res.status(201).json({
      message: 'Contato cadastrado com sucesso.',
      contact: {
        ...result.rows[0],
        id: Number(result.rows[0].id),
      },
    });
  } catch (error) {
    return next(error);
  }
});

// Edita somente um contato pertencente ao fornecedor autenticado.
router.put('/:id', async (req, res, next) => {
  try {
    const id = req.params.id;

    if (!/^\d+$/.test(id) || Number(id) < 1) {
      return res.status(400).json({ error: 'ID do contato inválido.' });
    }

    const validation = validateContact(req.body);

    if (validation.error) {
      return res.status(400).json({ error: validation.error });
    }

    const { contact_type, label, contact_value } = validation.value;

    const result = await pool.query(
      `
      UPDATE supplier_contacts
      SET
        contact_type = $1,
        label = $2,
        contact_value = $3,
        updated_at = NOW()
      WHERE id = $4
        AND supplier_id = $5
      RETURNING id, contact_type, label, contact_value, created_at, updated_at
      `,
      [contact_type, label || null, contact_value, id, req.user.id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        error: 'Contato não encontrado ou sem permissão para editá-lo.',
      });
    }

    return res.status(200).json({
      message: 'Contato atualizado com sucesso.',
      contact: {
        ...result.rows[0],
        id: Number(result.rows[0].id),
      },
    });
  } catch (error) {
    return next(error);
  }
});

// Exclui somente um contato pertencente ao fornecedor autenticado.
router.delete('/:id', async (req, res, next) => {
  try {
    const id = req.params.id;

    if (!/^\d+$/.test(id) || Number(id) < 1) {
      return res.status(400).json({ error: 'ID do contato inválido.' });
    }

    const result = await pool.query(
      `
      DELETE FROM supplier_contacts
      WHERE id = $1
        AND supplier_id = $2
      RETURNING id
      `,
      [id, req.user.id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        error: 'Contato não encontrado ou sem permissão para excluí-lo.',
      });
    }

    return res.status(200).json({
      message: 'Contato excluído com sucesso.',
    });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;
