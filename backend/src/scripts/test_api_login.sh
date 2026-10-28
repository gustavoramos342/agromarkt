#!/usr/bin/env bash

set -e

read -r -p "E-mail cadastrado: " EMAIL
read -r -s -p "Senha: " PASSWORD
echo

LOGIN_RESPONSE=$(curl -sS -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d "$(EMAIL="$EMAIL" PASSWORD="$PASSWORD" node -e '
    process.stdout.write(JSON.stringify({
      email: process.env.EMAIL,
      password: process.env.PASSWORD
    }));
  ')")

unset PASSWORD

TOKEN=$(printf '%s' "$LOGIN_RESPONSE" | node -e '
  let data = "";
  process.stdin.on("data", chunk => data += chunk);
  process.stdin.on("end", () => {
    try {
      const result = JSON.parse(data);
      if (!result.token) {
        console.error("Login recusado:", result.error || "resposta inválida");
        process.exitCode = 1;
        return;
      }
      process.stdout.write(result.token);
    } catch {
      console.error("Não foi possível interpretar a resposta da API.");
      process.exitCode = 1;
    }
  });
') || exit 1

unset LOGIN_RESPONSE

PROFILE_RESPONSE=$(curl -sS -w '\n%{http_code}' \
  http://localhost:3000/api/auth/me \
  -H "Authorization: Bearer $TOKEN")

unset TOKEN

HTTP_CODE=$(printf '%s' "$PROFILE_RESPONSE" | tail -n 1)
BODY=$(printf '%s' "$PROFILE_RESPONSE" | sed '$d')

echo
echo "HTTP da rota protegida: $HTTP_CODE"
printf '%s\n' "$BODY"
