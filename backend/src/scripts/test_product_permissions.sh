
#!/usr/bin/env bash
set -euo pipefail

BASE_URL="http://localhost:3000"

read -r -p "E-mail cadastrado: " EMAIL
read -r -s -p "Senha: " PASSWORD
echo

LOGIN_RESPONSE=$(
  EMAIL="$EMAIL" PASSWORD="$PASSWORD" node -e '
    process.stdout.write(JSON.stringify({
      email: process.env.EMAIL,
      password: process.env.PASSWORD
    }));
  ' |
  curl -sS -X POST "$BASE_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    --data-binary @-
)

unset PASSWORD

TOKEN=$(
  printf '%s' "$LOGIN_RESPONSE" |
    node -e '
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
    '
) || exit 1

unset LOGIN_RESPONSE

test_payload='{
  "name": "Produto temporário de teste",
  "category": "Fertilizante NPK",
  "unit": "kg",
  "price": 9.99,
  "location": "Cáceres - MT"
}'

echo
echo "Teste 1: sem token (esperado HTTP 401)"
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' \
  -X POST "$BASE_URL/api/products" \
  -H "Content-Type: application/json" \
  -d "$test_payload"

echo
echo "Teste 2: token do usuário autenticado"
echo "Este teste depende do perfil da conta informada."
RESULT=$(
  curl -sS -w '\n%{http_code}' \
    -X POST "$BASE_URL/api/products" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$test_payload"
)

STATUS=$(printf '%s' "$RESULT" | tail -n 1)
BODY=$(printf '%s' "$RESULT" | sed '$d')

printf 'HTTP: %s\nResposta: %s\n' "$STATUS" "$BODY"

unset TOKEN

echo
echo "Teste finalizado."
echo "Para verificar o bloqueio de produtor, execute novamente usando uma conta produtora."
