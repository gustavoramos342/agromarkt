const express = require('express');
const { pool } = require('../config/database');
const {
  authenticateToken,
  authorizeRoles,
} = require('../middleware/auth_middleware');

const router = express.Router();

// Todas as rotas deste arquivo exigem autenticação de administrador.
router.use(authenticateToken, authorizeRoles('admin'));

// Lista usuários sem expor hashes de senha.
router.get('/users', async (req, res, next) => {
  try {
    const result = await pool.query(
      `
      SELECT id, name, email, role, is_active, created_at
      FROM users
      ORDER BY created_at DESC, id DESC
      `,
    );

    return res.status(200).json({
      users: result.rows.map((user) => ({
        ...user,
        id: Number(user.id),
      })),
    });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;
