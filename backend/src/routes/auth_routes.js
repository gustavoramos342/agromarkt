const express = require('express');
const { login } = require('../services/auth_service');
const {
  authenticateToken,
} = require('../middleware/auth_middleware');
const { pool } = require('../config/database');

const router = express.Router();

router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body || {};
    const result = await login(email, password);

    return res.status(200).json(result);
  } catch (error) {
    if (error.status === 400 || error.status === 401) {
      return res.status(error.status).json({
        error: error.message,
      });
    }

    return next(error);
  }
});

router.get('/me', authenticateToken, async (req, res, next) => {
  try {
    const result = await pool.query(
      `SELECT id, name, email, role, is_active
       FROM users
       WHERE id = $1
       LIMIT 1`,
      [req.user.id],
    );

    const user = result.rows[0];

    if (!user || !user.is_active) {
      return res.status(401).json({
        error: 'Usuário inexistente ou inativo.',
      });
    }

    return res.status(200).json({
      user: {
        id: String(user.id),
        name: user.name,
        email: user.email,
        role: user.role,
      },
    });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;
