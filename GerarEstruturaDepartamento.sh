#!/bin/bash

# ===================================================
# Gerador de Arquivo departamento.json a partir da API
# ===================================================
# Este script consulta a API Microsoft Graph e gera um
# arquivo JSON com dados dos colaboradores, incluindo
# cargo, departamento, email e gestor imediato.
#
# Pré-requisitos:
# - jq instalado
# - cliente_id, tenant_id e client_secret válidos
# ===================================================

# Carregar variáveis do .env se existir
if [ -f .env ]; then
  export $(grep -v '^#' .env | sed 's/\r$//' | xargs)
fi

# Exibir variáveis carregadas para debug
echo "Variáveis carregadas do .env:"
echo "TENANT_ID=$TENANT_ID"
echo "CLIENT_ID=$CLIENT_ID"
echo "CLIENT_SECRET=${CLIENT_SECRET:0:5}... (oculto)"



# Configuração
output_file="departamento.json"
tenant_id="${TENANT_ID}"
client_id="${CLIENT_ID}"
client_secret="${CLIENT_SECRET}"
scope="https://graph.microsoft.com/.default"
authority="https://login.microsoftonline.com/$tenant_id/oauth2/v2.0/token"

# Obter token de acesso
echo "Obtendo token..."
payload="client_id=$(printf %s "$client_id" | jq -s -R -r @uri)&scope=$(printf %s "$scope" | jq -s -R -r @uri)&client_secret=$(printf %s "$client_secret" | jq -s -R -r @uri)&grant_type=client_credentials"

auth_response=$(curl -s -X POST "$authority" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "$payload")

# Exibir resposta para debug
echo "Resposta bruta da API:"  # ajuda a identificar se é JSON mesmo
echo "$auth_response"

# Verificar se a resposta é um JSON válido antes de usar jq
if ! echo "$auth_response" | jq . >/dev/null 2>&1; then
  echo "❌ Erro: resposta não é JSON válido."
  exit 1
fi

# Extrair o token corretamente
access_token=$(echo "$auth_response" | jq -r '.access_token')

if [ -z "$access_token" ] || [ "$access_token" == "null" ]; then
  echo "Erro ao obter token."
  exit 1
fi

echo "Token obtido com sucesso. Buscando usuários..."

# Obter usuários
users_url="https://graph.microsoft.com/v1.0/users?\$select=id,displayName,mail"
users_response=$(curl -s -X GET "$users_url" \
  -H "Authorization: Bearer $access_token" \
  -H "Content-Type: application/json")

user_ids=$(echo "$users_response" | jq -r '.value[].id')
echo "Total de usuários: $(echo "$user_ids" | wc -l)"

echo "[" > "$output_file"
first=true
for user_id in $user_ids; do
  user_info=$(curl -s -X GET "https://graph.microsoft.com/v1.0/users/$user_id?\$select=jobTitle,department,employeeId,employeeType,mail" \
    -H "Authorization: Bearer $access_token")

  manager_info=$(curl -s -X GET "https://graph.microsoft.com/v1.0/users/$user_id/manager" \
    -H "Authorization: Bearer $access_token")

  manager_name=$(echo "$manager_info" | jq -r '.displayName // "Não atribuído"')
  manager_mail=$(echo "$manager_info" | jq -r '.mail // "Não informado"')

  final_user=$(echo "$user_info" | jq --arg mgr "$manager_name" --arg m_mail "$manager_mail" \
    '. + {manager: $mgr, manager_mail: $m_mail}')

  if [ "$(echo "$final_user" | jq -r '.employeeId')" != "null" ]; then
    if [ "$first" = true ]; then
      echo "$final_user" >> "$output_file"
      first=false
    else
      echo ",$final_user" >> "$output_file"
    fi
  fi
done
echo "]" >> "$output_file"

echo "Arquivo $output_file gerado com sucesso."
