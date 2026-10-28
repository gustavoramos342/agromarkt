const { Pool } = require('pg');

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('A variável DATABASE_URL não foi configurada.');
}

const pool = new Pool({
  connectionString,
  connectionTimeoutMillis: 10000,
  max: 10,
  idleTimeoutMillis: 30000,
});

pool.on('error', (error) => {
  console.error(
    'Erro inesperado no pool do PostgreSQL:',
    error.message,
  );
});

async function testConnection() {
  const result = await pool.query(
    'SELECT current_database() AS banco',
  );

  return result.rows[0].banco;
}

module.exports = {
  pool,
  testConnection,
};
