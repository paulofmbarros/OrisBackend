#!/bin/bash
set -e

# Verifica se a API Key existe
if [ -z "$OPENAI_API_KEY" ]; then
  echo "Error: OPENAI_API_KEY is not set."
  exit 1
fi

# Captura o argumento (o prompt completo)
FULL_PROMPT="$1"

# Escapa o prompt para JSON usando jq (garante que quebras de linha/aspas não partam o JSON)
JSON_PAYLOAD=$(jq -n \
                --arg model "gpt-4o" \
                --arg content "$FULL_PROMPT" \
                '{model: $model, messages: [{role: "user", content: $content}]}')

# Faz a chamada à API da OpenAI
RESPONSE=$(curl -s -X POST https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "$JSON_PAYLOAD")

# Verifica se houve erro no curl ou na resposta
if [ $? -ne 0 ]; then
  echo "Error making API request."
  exit 1
fi

# Extrai apenas a mensagem de resposta usando jq
# Se a resposta contiver um erro da API, imprime o erro
ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // empty')

if [ -n "$ERROR_MSG" ]; then
  echo "OpenAI API Error: $ERROR_MSG"
  exit 1
fi

# Imprime o conteúdo final (limpo)
echo "$RESPONSE" | jq -r '.choices[0].message.content'