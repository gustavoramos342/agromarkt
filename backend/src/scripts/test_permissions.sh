#!/usr/bin/env bash

set -e

read -r -p "E-mail cadastrado: " EMAIL
read -r -s -p "Senha: " PASSWORD
echo

LOGIN_RESPONSE=$(EMAIL="$EMAIL" PASSWORD="$PASSWORD" node -e '
  process.stdout.write(JSON.stringify({
    email: process.env.EMAIL,
    password: process.env.PASSWORD
  }));
' | curl -sS -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  --data-binary @-)

unset PASSWORD

TOKEN=$(printf '%s' "$LOGIN_RESPONSE" | node -e '
  let data = "";
  process.stdin.on("data", chunk => data += chunk);
  process.stdin.on("end", () => {
    try {
      const result = JSON.parse(data);
      if (!result.token) {
        console.error("Falha no login:", result.error || "resposta inválida");
        process.exitCode = 1;
        return;
      }
      process.stdout.write(result.token);
    } catch {
      console.error("Resposta inválida da API.");
      process.exitCode = 1;
    }
  });
') || exit 1

unset LOGIN_RESPONSE

for PROFILE in produtor fornecedor admin; do
  RESULT=$(curl -sS -w '\n%{http_code}' \
    "http://localhost:3000/api/profile/$PROFILE" \
    -H "Authorization: Bearer $TOKEN")

  STATUS=$(printf '%s' "$RESULT" | tail -n 1)
  BODY=$(printf '%s' "$RESULT" | sed '$d')

  printf '\nPerfil testado: %s\nHTTP: %s\nResposta: %s\n' \
    "$PROFILE" "$STATUS" "$BODY"
done

unset TOKEN
