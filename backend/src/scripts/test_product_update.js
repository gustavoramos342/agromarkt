
require('dotenv').config();

const { pool } = require('../config/database');
const { login } = require('../services/auth_service');

async function main() {
  try {
    const email = process.env.TEST_SUPPLIER_EMAIL;
    const password = process.env.TEST_SUPPLIER_PASSWORD;

    if (!email || !password) {
      throw new Error(
        'Defina TEST_SUPPLIER_EMAIL e TEST_SUPPLIER_PASSWORD no ambiente.',
      );
    }

    const auth = await login(email, password);

    if (auth.user.role !== 'fornecedor') {
      throw new Error('A conta de teste precisa ser fornecedora.');
    }

    const productId = 6;

    const ownedProduct = await pool.query(
      `SELECT id FROM products
       WHERE id = $1 AND supplier_id = $2 AND is_active = TRUE`,
      [productId, auth.user.id],
    );

    if (ownedProduct.rowCount !== 1) {
      throw new Error(
        'O produto 6 não pertence a esta fornecedora ou não está ativo.',
      );
    }

    const response = await fetch(
      `http://localhost:${process.env.PORT || 3000}/api/products/${productId}`,
      {
        method: 'PUT',
        headers: {
          Authorization: `Bearer ${auth.token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name: 'Produto temporário de teste atualizado',
          category: 'Fertilizante NPK',
          unit: 'kg',
          price: 10.25,
          location: 'Cáceres - MT',
        }),
      },
    );

    const body = await response.json();

    console.log('HTTP:', response.status);
    console.log('Resposta:', body);

    if (response.status !== 200) {
      throw new Error('A API não confirmou a edição.');
    }

    const check = await pool.query(
      `SELECT name, price FROM products
       WHERE id = $1 AND supplier_id = $2`,
      [productId, auth.user.id],
    );

    if (
      check.rowCount !== 1 ||
      check.rows[0].name !== 'Produto temporário de teste atualizado' ||
      Number(check.rows[0].price) !== 10.25
    ) {
      throw new Error('A conferência no banco falhou.');
    }

    console.log('Teste aprovado: edição confirmada no banco.');
  } catch (error) {
    console.error('Falha no teste:', error.message || error);
    if (error.stack) {
      console.error(error.stack);
    }
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}


main();
