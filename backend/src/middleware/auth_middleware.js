
const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');

const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET || JWT_SECRET.length < 64) {
  throw new Error('JWT_SECRET ausente ou muito curta.');
}

async function authenticateToken(req, res, next) {
  const authorization = req.headers.authorization;

  if (!authorization || !authorization.startsWith('Bearer ')) {
    return res.status(401).json({
      error: 'Token de autenticação não informado.',
    });
  }

  const token = authorization.slice(7).trim();

  if (!token) {
    return res.status(401).json({
      error: 'Token de autenticação inválido.',
    });
  }

  let payload;

  try {
    payload = jwt.verify(token, JWT_SECRET, {
      issuer: 'agromarkt-api',
      audience: 'agromarkt-app',
      algorithms: ['HS256'],
    });
  } catch {
    return res.status(401).json({
      error: 'Token expirado ou inválido.',
    });
  }

  if (
    typeof payload.sub !== 'string' ||
    !['produtor', 'fornecedor', 'admin'].includes(payload.role)
  ) {
    return res.status(401).json({
      error: 'Token de autenticação inválido.',
    });
  }

  try {
    const result = await pool.query(
      `SELECT id, role, is_active
       FROM users
       WHERE id = $1
       LIMIT 1`,
      [payload.sub],
    );

    const user = result.rows[0];

    if (
      !user ||
      !user.is_active ||
      user.role !== payload.role
    ) {
      return res.status(401).json({
        error: 'Usuário inexistente, inativo ou com perfil alterado.',
      });
    }

    req.user = {
      id: String(user.id),
      role: user.role,
    };

    return next();
  } catch (error) {
    return next(error);
  }
}

function authorizeRoles(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'Autenticação necessária.',
      });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        error: 'Você não tem permissão para acessar este recurso.',
      });
    }

    return next();
  };
}

module.exports = {
  authenticateToken,
  authorizeRoles,
};

