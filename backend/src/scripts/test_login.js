require('dotenv').config();

const readline = require('readline');
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

function askPassword(question) {
  return new Promise((resolve, reject) => {
    const stdin = process.stdin;

    if (!stdin.isTTY || typeof stdin.setRawMode !== 'function') {
      reject(new Error('Execute o teste diretamente em um terminal.'));
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
          reject(new Error('Teste cancelado.'));
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
    const email = await ask('E-mail cadastrado: ');
    const password = await askPassword('Senha: ');

    const result = await login(email, password);

    console.log('\nLogin realizado com sucesso!');
    console.log('Usuário:', result.user.name);
    console.log('Perfil:', result.user.role);
    console.log('Tipo de token:', result.tokenType);
    console.log('Validade:', result.expiresIn);
    console.log('Token recebido: sim (não exibido)');
  } catch (error) {
    console.error('\nFalha no teste:', error.message);
    process.exitCode = 1;
  } finally {
    await pool.end().catch(() => {});
  }
}

main();
