#!/bin/sh
# Aplica no Kafka Connect todos os conectores desta pasta (um JSON plano por conector).
# PUT /connectors/{nome}/config cria o conector ou atualiza a configuracao: pode rodar quantas vezes quiser.
#
# Uso (host):      ./apply-connectors.sh   (API REST do Connect na 8087 do host)
# Uso (conteiner): docker compose -f docker-compose.tools.yml up algashop-kafka-connect-init

CONNECT_URL=${CONNECT_URL:-http://localhost:8087}
DIR=$(cd "$(dirname "$0")" && pwd)

echo "Aguardando o Kafka Connect em $CONNECT_URL ..."
until curl -sf "$CONNECT_URL/connectors" > /dev/null; do
  sleep 3
done

# Primeiro os source (criam os topicos), depois os sink
for file in "$DIR"/cdc.source.*.json "$DIR"/cdc.sink.*.json; do
  [ -f "$file" ] || continue # glob sem arquivo (ex.: nenhum sink ainda) fica literal: pula
  name=$(basename "$file" .json)
  code=$(curl -s -o /dev/null -w '%{http_code}' -X PUT -H 'Content-Type: application/json' \
    --data @"$file" "$CONNECT_URL/connectors/$name/config")
  echo "$name -> HTTP $code"
done

# Se as tabelas ainda nao existiam quando o conector foi criado, a task fica FAILED.
# Rode o script de novo depois que os servicos subirem: ele reinicia so as tasks com falha.
for file in "$DIR"/cdc.source.*.json "$DIR"/cdc.sink.*.json; do
  [ -f "$file" ] || continue
  name=$(basename "$file" .json)
  curl -s -o /dev/null -X POST "$CONNECT_URL/connectors/$name/restart?includeTasks=true&onlyFailed=true"
done