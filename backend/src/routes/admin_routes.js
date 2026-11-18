
const express = require('express');
const { pool } = require('../config/database');
const {
  authenticateToken,
  authorizeRoles,
} = require('../middleware/auth_middleware');

const router = express.Router();

router.use(authenticateToken, authorizeRoles('admin'));

const ADMIN_LOCK = [741852, 963];

// Lista usuários sem expor hashes de senha.
router.get('/users', async (req, res, next) => {
  try {
    const result = await pool.query(`
      SELECT id, name, email, role, is_active, created_at
      FROM users
      ORDER BY created_at DESC, id DESC
    `);

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

// Ativa ou desativa uma conta.
router.patch('/users/:id/status', async (req, res, next) => {
  const userId = Number(req.params.id);
  const { is_active: isActive } = req.body;

  if (!Number.isSafeInteger(userId) || userId < 1) {
    return res.status(400).json({ error: 'ID do usuário inválido.' });
  }

  if (typeof isActive !== 'boolean') {
    return res.status(400).json({
      error: 'O campo is_active deve ser verdadeiro ou falso.',
    });
  }

  if (!isActive && String(req.user.id) === String(userId)) {
    return res.status(403).json({
      error: 'Você não pode desativar sua própria conta.',
    });
  }

  let client;
  let transactionStarted = false;

  try {
    client = await pool.connect();
    await client.query('BEGIN');
    transactionStarted = true;

    await client.query('SELECT pg_advisory_xact_lock($1, $2)', ADMIN_LOCK);

    const targetResult = await client.query(
      `SELECT id, role, is_active
       FROM users
       WHERE id = $1
       FOR UPDATE`,
      [userId],
    );

    const target = targetResult.rows[0];

    if (!target) {
      await client.query('ROLLBACK');
      transactionStarted = false;
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }

    if (!isActive && target.role === 'admin' && target.is_active) {
      const adminsResult = await client.query(`
        SELECT COUNT(*) AS total
        FROM users
        WHERE role = 'admin' AND is_active = TRUE
      `);

      if (Number(adminsResult.rows[0].total) <= 1) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return res.status(409).json({
          error: 'Não é possível desativar o último administrador ativo.',
        });
      }
    }

    const result = await client.query(
      `UPDATE users
       SET is_active = $1
       WHERE id = $2
       RETURNING id, name, email, role, is_active, created_at`,
      [isActive, userId],
    );

    await client.query('COMMIT');
    transactionStarted = false;

    const user = result.rows[0];

    return res.status(200).json({
      message: isActive
        ? 'Usuário ativado com sucesso.'
        : 'Usuário desativado com sucesso.',
      user: { ...user, id: Number(user.id) },
    });
  } catch (error) {
    if (client && transactionStarted) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackError) {
        console.error('Erro ao desfazer transação:', rollbackError.message);
      }
    }
    return next(error);
  } finally {
    if (client) client.release();
  }
});

// Altera somente entre produtor e fornecedor.
router.patch('/users/:id/role', async (req, res, next) => {
  const userId = Number(req.params.id);
  const { role } = req.body;

  if (!Number.isSafeInteger(userId) || userId < 1) {
    return res.status(400).json({ error: 'ID do usuário inválido.' });
  }

  if (!['produtor', 'fornecedor'].includes(role)) {
    return res.status(400).json({
      error: 'O perfil deve ser produtor ou fornecedor.',
    });
  }

  if (String(req.user.id) === String(userId)) {
    return res.status(403).json({
      error: 'Você não pode alterar seu próprio perfil administrativo.',
    });
  }

  let client;
  let transactionStarted = false;

  try {
    client = await pool.connect();
    await client.query('BEGIN');
    transactionStarted = true;

    await client.query('SELECT pg_advisory_xact_lock($1, $2)', ADMIN_LOCK);

    const targetResult = await client.query(
      `SELECT id, role
       FROM users
       WHERE id = $1
       FOR UPDATE`,
      [userId],
    );

    const target = targetResult.rows[0];

    if (!target) {
      await client.query('ROLLBACK');
      transactionStarted = false;
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }

    if (target.role === 'admin') {
      await client.query('ROLLBACK');
      transactionStarted = false;
      return res.status(403).json({
        error: 'Não é permitido alterar o perfil de um administrador.',
      });
    }

    const result = await client.query(
      `UPDATE users
       SET role = $1
       WHERE id = $2
       RETURNING id, name, email, role, is_active, created_at`,
      [role, userId],
    );

    await client.query('COMMIT');
    transactionStarted = false;

    const user = result.rows[0];

    return res.status(200).json({
      message: 'Perfil atualizado com sucesso.',
      user: { ...user, id: Number(user.id) },
    });
  } catch (error) {
    if (client && transactionStarted) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackError) {
        console.error('Erro ao desfazer transação:', rollbackError.message);
      }
    }
    return next(error);
  } finally {
    if (client) client.release();
  }
});

module.exports = router;
