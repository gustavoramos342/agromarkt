require('dotenv').config();

const fs = require('node:fs');
const path = require('node:path');
const { pool } = require('../config/database');

async function main() {
  const schemaPath = path.join(
    __dirname,
    '../database/products_schema.sql',
  );

  const sql = fs.readFileSync(schemaPath, 'utf8');

  await pool.query(sql);

  console.log('Tabela products e índices criados/verificados.');
}

main()
  .catch((error) => {
    console.error('Erro ao aplicar o esquema:', error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });
