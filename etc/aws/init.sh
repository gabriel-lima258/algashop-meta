#!/bin/bash
#
# Roda UMA vez, quando o localstack fica pronto. O gancho e o diretorio onde o arquivo
# esta montado: /etc/localstack/init/ready.d - o localstack executa tudo que houver ali
# depois que os servicos sobem. Nao ha "docker exec" na mao nem passo manual no README.
#
# awslocal e o wrapper do awscli que ja aponta para o endpoint do proprio container;
# usar "aws" puro aqui tentaria falar com a AWS de verdade.

export AWS_ACCESS_KEY_ID="${LS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${LS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="${LS_REGION:-us-east-1}"

# gere uma chave privado e armazena em uma pasta temporária
openssl genpkey -algorithm RSA -out /tmp/algashop-private-key.pem -pkeyopt rsa_keygen_bits:2048

# transforma a chave em base64 para melhor transporte e facilita o armazenamento
PRIVATE_KEY_B64=$(base64 -w 0 /tmp/algashop-private-key.pem)

# gera uma chave privada
PRIVATE_KEY_ID=$(openssl rand -hex 16)

# monta o json no temp
printf '{"privateKeyId":"%s","privateKey":"%s"}' \
  "$PRIVATE_KEY_ID" "$PRIVATE_KEY_B64" > /tmp/secret.json

# importa o json da chave privada para o secretsmanager
awslocal secretsmanager create-secret \
  --name /config/algashop/authorization-server/rsa-key \
  --secret-string file:///tmp/secret.json

# configuração para evitar a consulta de url no parameter url
awslocal configure set cli_follow_urlparam false

# CSV Script

# Parâmetros do SSM
{
  read -r _header                       # descarta o cabeçalho
  while IFS=',' read -r name type value || [ -n "$name" ]; do  # robusto a arquivo sem \n final
    [ -z "$name" ] && continue          # pula linha em branco
    case "$name" in \#*) continue ;; esac   # pula comentário
    value=${value%$'\r'}                # remove \r se foi salvo no Windows
    awslocal ssm put-parameter --name "$name" --type "$type" --value "$value" --overwrite
  done
} < /etc/aws/parameters.csv

# Segredos do Secrets Manager
{
  read -r _header
  while IFS=',' read -r name value || [ -n "$name" ]; do
    [ -z "$name" ] && continue
    case "$name" in \#*) continue ;; esac
    value=${value%$'\r'}
    awslocal secretsmanager create-secret --name "$name" --secret-string "$value"
  done
} < /etc/aws/secrets.csv

# Buckets e arquivos do S3

# || true porque o script roda de novo a cada recriacao do container: criar um bucket
# que ja existe e erro, e um erro aqui aborta o resto do arquivo.
awslocal s3 mb s3://algashop-product-image || true

# CORS e o que autoriza o NAVEGADOR a fazer o PUT direto no bucket. Sem esta regra o
# upload falha no preflight, antes de sair um byte - e a mensagem no console do browser
# nao menciona S3 nenhum, o que torna o sintoma dificil de ligar a causa.
awslocal s3api put-bucket-cors --bucket algashop-product-image --cors-configuration file:///etc/aws/cors.json

BUCKET=algashop-product-image

# S3
{
  read -r _header                                # descarta o cabeçalho
  while IFS=',' read -r key ct || [ -n "$key" ]; do  # robusto a arquivo sem \n final
    [ -z "$key" ] && continue                    # pula linha em branco
    case "$key" in \#*) continue ;; esac         # pula comentário
    ct=${ct%$'\r'}                               # remove \r se salvo no Windows
    awslocal s3api put-object \
      --bucket "$BUCKET" --key "$key" --content-type "$ct" --body "/etc/images/$key"
  done
} < /etc/aws/s3.csv






