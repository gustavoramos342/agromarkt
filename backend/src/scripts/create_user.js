require('dotenv').config();

const readline = require('readline');
const bcrypt = require('bcryptjs');
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

function askPassword(question) {
  return new Promise((resolve, reject) => {
    const stdin = process.stdin;

    if (!stdin.isTTY || typeof stdin.setRawMode !== 'function') {
      reject(new Error('Execute este script diretamente em um terminal.'));
      return;
    }

    let password = '';

    process.stdout.write(question);
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
          reject(new Error('Operação cancelada.'));
          return;
        }

        if (char === '\r' || char === '\n') {
          cleanup();
          resolve(password);
          return;
        }

        if (char === '\u007f' || char === '\b') {
          password = password.slice(0, -1);
        } else if (char >= ' ') {
          password += char;
        }
      }
    }

    stdin.on('data', onData);
  });
}

async function main() {
  try {
    const name = await ask('Nome: ');
    const email = (await ask('E-mail: ')).toLowerCase();
        const allowAdmin = process.env.ALLOW_ADMIN_BOOTSTRAP === 'true';

    const allowedRoles = allowAdmin
      ? ['produtor', 'fornecedor', 'admin']
      : ['produtor', 'fornecedor'];

    const role = (
      await ask(`Perfil (${allowedRoles.join('/')}): `)
    ).toLowerCase();

    if (
      !name ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
     !allowedRoles.includes(role)
    ) {
      throw new Error('Nome, e-mail ou perfil inválido.');
    }

    const password = await askPassword(
      'Senha (mínimo de 12 caracteres): ',
    );

    if (password.length < 12 || password.length > 72) {
      throw new Error('A senha deve ter entre 12 e 72 caracteres.');
    }

    const passwordHash = await bcrypt.hash(password, 12);

    const result = await pool.query(
      `INSERT INTO users (name, email, password_hash, role)
       VALUES ($1, $2, $3, $4)
       RETURNING id, name, email, role`,
      [name, email, passwordHash, role],
    );

    console.log('\nUsuário criado com sucesso:');
    console.log(result.rows[0]);
  } catch (error) {
    if (error.code === '23505') {
      console.error('Já existe um usuário com esse e-mail.');
      process.exitCode = 1;
    } else {
      console.error('Não foi possível criar o usuário:', error.message);
      process.exitCode = 1;
    }
  } finally {
    await pool.end().catch(() => {});
  }
}

main();
