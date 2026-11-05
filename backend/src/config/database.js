
const dns = require('dns').promises;
const { Pool } = require('pg');

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('A variável DATABASE_URL não foi configurada.');
}

const databaseUrl = new URL(connectionString);
const hostname = databaseUrl.hostname;

const pool = new Pool({
  connectionString,
  connectionTimeoutMillis: 15000,
  max: 10,
  idleTimeoutMillis: 30000,

  // Prioriza IPv4 na resolução de endereços.
  // A conexão mantém os parâmetros SSL da URL.
  lookup: (host, options, callback) => {
    dns.lookup(host, {
      family: 4,
      all: false,
    }).then(
      (result) => callback(null, result.address, 4),
      (error) => callback(error),
    );
  },
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
