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

# || true porque o script roda de novo a cada recriacao do container: criar um bucket
# que ja existe e erro, e um erro aqui aborta o resto do arquivo.
awslocal s3 mb s3://algashop-product-image || true

# CORS e o que autoriza o NAVEGADOR a fazer o PUT direto no bucket. Sem esta regra o
# upload falha no preflight, antes de sair um byte - e a mensagem no console do browser
# nao menciona S3 nenhum, o que torna o sintoma dificil de ligar a causa.
awslocal s3api put-bucket-cors --bucket algashop-product-image --cors-configuration file:///etc/aws/cors.json

# um unico processo para todos os uploads: 23 processos em paralelo estouravam
# o limite de memoria do container e o OOM killer derrubava o localstack.
# o content-type é inferido pela extensão do arquivo (.jpg -> image/jpeg, .png -> image/png)
awslocal s3 sync /etc/images s3://algashop-product-image
