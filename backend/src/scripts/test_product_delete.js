
require('dotenv').config();

const { pool } = require('../config/database');
const { login } = require('../services/auth_service');

async function main() {
  try {
    const auth = await login(
      process.env.TEST_SUPPLIER_EMAIL,
      process.env.TEST_SUPPLIER_PASSWORD,
    );

    if (auth.user.role !== 'fornecedor') {
      throw new Error('A conta precisa ser de fornecedor.');
    }

    const id = 6;

    const response = await fetch(
      `http://localhost:${process.env.PORT || 3000}/api/products/${id}`,
      {
        method: 'DELETE',
        headers: {
          Authorization: `Bearer ${auth.token}`,
        },
      },
    );

    const body = await response.json();
    console.log('HTTP:', response.status);
    console.log('Resposta:', body);

    if (response.status !== 200) {
      throw new Error('A API não confirmou a exclusão lógica.');
    }

    const check = await pool.query(
      'SELECT id, is_active FROM products WHERE id = $1',
      [id],
    );

    if (check.rowCount !== 1 || check.rows[0].is_active !== false) {
      throw new Error('A exclusão lógica não foi confirmada no banco.');
    }

    console.log('Teste aprovado: produto desativado e registro preservado.');

    const catalog = await pool.query(
      'SELECT id FROM products WHERE id = $1 AND is_active = TRUE',
      [id],
    );

    console.log(
      catalog.rowCount === 0
        ? 'Catálogo: produto não aparece mais como ativo.'
        : 'Atenção: produto ainda aparece como ativo.',
    );
  } catch (error) {
    console.error('Falha no teste:', error.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

main();
