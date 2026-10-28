const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');

const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET || JWT_SECRET.length < 64) {
  throw new Error('JWT_SECRET ausente ou muito curta.');
}

const TOKEN_EXPIRES_IN = '1h';

async function login(email, password) {
  if (
    typeof email !== 'string' ||
    typeof password !== 'string' ||
    !email.trim() ||
    !password
  ) {
    const error = new Error('E-mail e senha são obrigatórios.');
    error.status = 400;
    throw error;
  }

  const normalizedEmail = email.trim().toLowerCase();

  const result = await pool.query(
    `SELECT id, name, email, password_hash, role, is_active
     FROM users
     WHERE email = $1
     LIMIT 1`,
    [normalizedEmail],
  );

  const user = result.rows[0];

  if (
    !user ||
    !user.is_active ||
    !(await bcrypt.compare(password, user.password_hash))
  ) {
    const error = new Error('E-mail ou senha inválidos.');
    error.status = 401;
    throw error;
  }

  const token = jwt.sign(
    {
      sub: String(user.id),
      role: user.role,
    },
    JWT_SECRET,
    {
      expiresIn: TOKEN_EXPIRES_IN,
      issuer: 'agromarkt-api',
      audience: 'agromarkt-app',
    },
  );

  return {
    token,
    tokenType: 'Bearer',
    expiresIn: TOKEN_EXPIRES_IN,
    user: {
      id: String(user.id),
      name: user.name,
      email: user.email,
      role: user.role,
    },
  };
}

module.exports = { login };
