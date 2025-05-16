#!/bin/bash

# Configuração
data_file="departamento.json" # Arquivo de entrada
api_url="https://register-api.xonecloud.com/departments/api/v1/" # URL da API
api_token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiSW50ZWdyYcOnw6NvIGNvbSBBenVyZSBBZCAoZGVwYXJ0bWVudCkiLCJkZXNjcmlwdGlvbiI6IiIsImV4cGlyZV9kYXRlIjoiOTBkIiwicGVybWlzc2lvbiI6MiwiYXBpcyI6WyJkZXBhcnRtZW50c19hcGkiXSwiY29tcGFueV9pZCI6MzYsImNyZWF0ZWRfYnkiOjEzNCwiY3JlYXRlZF9hdCI6IjIwMjQtMTItMDJUMTg6MjA6MDUuODA4WiIsImlhdCI6MTczNDc0Mjk2NCwiZXhwIjoxNzQyNTE4OTY0fQ.VH8We6KkzAA2T57N2r_aCzyeAbCrrmc-CIb41YSIAUw" # Insira o token da API

# Validar se o arquivo de dados existe
if [ ! -f "$data_file" ]; then
  echo "Erro: Arquivo $data_file não encontrado."
  exit 1
fi

# Construir o corpo da requisição com base no arquivo JSON
departments_body=$(jq -c '[.[] | {name: .department, manager: .manager, manager_email: .manager_mail, workingday_name: "Jornada de trabalho Padrão", user_name: .employeeId}]' "$data_file")

# Validar se há departamentos no arquivo
if [ -z "$departments_body" ] || [ "$departments_body" == "null" ]; then
  echo "Erro: Nenhum departamento encontrado no arquivo $data_file."
  exit 1
fi

# Criar o payload completo
payload=$(jq -n --argjson departments "$departments_body" '{lang: "pt-BR", departments: $departments}')

# Exibir o payload gerado
echo "Payload gerado:"
echo "$payload" | jq .

# Confirmar execução
echo "Deseja continuar com a execução? (s/n)"
read -r confirm
if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
  echo "Execução cancelada pelo usuário."
  exit 0
fi

# Fazer a requisição para a API
response=$(curl -s -X POST "$api_url" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $api_token" \
  -d "$payload")

# Verificar o sucesso da operação
success=$(echo "$response" | jq -r '.success')
message=$(echo "$response" | jq -r '.message')

if [ "$success" == "true" ]; then
  echo "Atualização concluída com sucesso."
  echo "Mensagem: $message"
else
  echo "Erro ao atualizar departamentos."
  echo "Resposta da API: $response"
fi
