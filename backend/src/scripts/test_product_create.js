
require('dotenv').config();

const readline = require('node:readline');
const { login } = require('../services/auth_service');
const { pool } = require('../config/database');

function ask(question) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

async function main() {
  let server;

  try {
    const email = await ask('E-mail do fornecedor: ');

    const password = await new Promise((resolve, reject) => {
      const stdin = process.stdin;

      if (!stdin.isTTY || typeof stdin.setRawMode !== 'function') {
        reject(new Error('Execute o teste diretamente no terminal.'));
        return;
      }

      let value = '';
      process.stdout.write('Senha (não será exibida): ');
      stdin.setRawMode(true);
      stdin.resume();

      function cleanup() {
        stdin.removeListener('data', onData);
        stdin.setRawMode(false);
        stdin.pause();
        process.stdout.write('\n');
      }

      function onData(data) {
        for (const char of data.toString()) {
          if (char === '\u0003') {
            cleanup();
            reject(new Error('Teste cancelado.'));
            return;
          }

          if (char === '\r' || char === '\n') {
            cleanup();
            resolve(value);
            return;
          }

          if (char === '\u007f' || char === '\b') {
            value = value.slice(0, -1);
          } else if (char >= ' ') {
            value += char;
          }
        }
      }

      stdin.on('data', onData);
    });

    const authenticated = await login(email, password);

    if (authenticated.user.role !== 'fornecedor') {
      throw new Error('Use uma conta com perfil fornecedor.');
    }

    const token = authenticated.token;
    const baseUrl = `http://127.0.0.1:${process.env.PORT || 3000}`;

    const product = {
      name: `Produto de teste ${Date.now()}`,
      category: 'Fertilizante NPK',
      unit: 'kg',
      price: 12.34,
      location: 'Cáceres - MT',
    };

    const response = await fetch(`${baseUrl}/api/products`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(product),
    });

    const body = await response.json();

    console.log('Status do cadastro:', response.status);
    console.log('Resposta:', body);

    if (response.status !== 201) {
      throw new Error('O cadastro não retornou HTTP 201.');
    }

    const createdId = body.product?.id;

    if (!createdId) {
      throw new Error('A API não retornou o ID do produto criado.');
    }

    const check = await pool.query(
      `SELECT p.id, p.name, p.supplier_id, u.role
       FROM products p
       JOIN users u ON u.id = p.supplier_id
       WHERE p.id = $1`,
      [createdId],
    );

    if (
      check.rows.length !== 1 ||
      check.rows[0].role !== 'fornecedor' ||
      String(check.rows[0].supplier_id) !== String(authenticated.user.id)
    ) {
      throw new Error('O produto não está associado ao fornecedor autenticado.');
    }

    console.log('Vínculo com fornecedor autenticado: confirmado.');
    console.log('Teste de cadastro concluído com sucesso.');
   } catch (error) {
    console.error('Falha no teste:', error.message);
    process.exitCode = 1;
  }
 finally {
    await pool.end().catch(() => {});
  }
}

main();
