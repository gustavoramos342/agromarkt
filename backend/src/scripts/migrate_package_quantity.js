require('dotenv').config();

const fs = require('node:fs');
const path = require('node:path');
const { pool } = require('../config/database');

async function main() {
  const migrationPath = path.join(
    __dirname,
    '../database/migrations/001_add_package_quantity.sql',
  );

  const sql = fs.readFileSync(migrationPath, 'utf8');
  const client = await pool.connect();

  try {
    await client.query('BEGIN');
    await client.query(sql);
    await client.query('COMMIT');

    console.log('Migração package_quantity aplicada com sucesso.');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

main()
  .catch((error) => {
    console.error('Erro ao aplicar migração:', error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });
