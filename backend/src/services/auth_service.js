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

async function register(name, email, password, role) {
  if (
    typeof name !== 'string' ||
    typeof email !== 'string' ||
    typeof password !== 'string' ||
    typeof role !== 'string'
  ) {
    const error = new Error('Dados de cadastro inválidos.');
    error.status = 400;
    throw error;
  }

  const normalizedName = name.trim();
  const normalizedEmail = email.trim().toLowerCase();

  if (normalizedName.length < 2 || normalizedName.length > 120) {
    const error = new Error('O nome deve ter entre 2 e 120 caracteres.');
    error.status = 400;
    throw error;
  }

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
    const error = new Error('Informe um e-mail válido.');
    error.status = 400;
    throw error;
  }

  if (password.length < 12 || password.length > 72) {
    const error = new Error('A senha deve ter entre 12 e 72 caracteres.');
    error.status = 400;
    throw error;
  }

  if (!['produtor', 'fornecedor'].includes(role)) {
    const error = new Error('Perfil de cadastro inválido.');
    error.status = 400;
    throw error;
  }

  const passwordHash = await bcrypt.hash(password, 12);

  let result;

  try {
    result = await pool.query(
      `INSERT INTO users (name, email, password_hash, role)
       VALUES ($1, $2, $3, $4)
       RETURNING id, name, email, role`,
      [normalizedName, normalizedEmail, passwordHash, role],
    );
  } catch (databaseError) {
    if (databaseError.code === '23505') {
      const error = new Error('Já existe uma conta com esse e-mail.');
      error.status = 409;
      throw error;
    }

    throw databaseError;
  }

  const user = result.rows[0];

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
module.exports = { login, register };
