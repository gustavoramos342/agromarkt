const express = require('express');
const { pool } = require('../config/database');
const {
  authenticateToken,
  authorizeRoles,
} = require('../middleware/auth_middleware');

const router = express.Router();

// Permite que apenas produtores autenticados consultem contatos.
router.use(authenticateToken, authorizeRoles('produtor'));

router.get('/:supplierId/contatos', async (req, res, next) => {
  try {
    const supplierId = req.params.supplierId;

    if (!/^\d+$/.test(supplierId) || Number(supplierId) < 1) {
      return res.status(400).json({
        error: 'ID do fornecedor inválido.',
      });
    }

    const supplierResult = await pool.query(
      `
      SELECT id
      FROM users
      WHERE id = $1
        AND role = 'fornecedor'
        AND is_active = TRUE
      `,
      [supplierId],
    );

    if (supplierResult.rowCount === 0) {
      return res.status(404).json({
        error: 'Fornecedor não encontrado.',
      });
    }

    const result = await pool.query(
      `
      SELECT id, contact_type, label, contact_value
      FROM supplier_contacts
      WHERE supplier_id = $1
      ORDER BY id ASC
      `,
      [supplierId],
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

module.exports = router;
