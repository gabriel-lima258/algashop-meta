#!/bin/bash
# Init do Postgres do insights (reporting database).
#
# Tudo em /docker-entrypoint-initdb.d SO RODA COM O VOLUME VAZIO - na primeira subida.
# Se o volume algashop-insights-postgres ja existe, este script e ignorado em silencio;
# para aplicar uma mudanca aqui, rode o SQL na mao ou recrie o volume (e ai os
# conectores do CDC precisam refazer o snapshot).
#
# Por que um .sh chamando um .sql montado FORA do initdb.d: o .sql precisa rodar
# DEPOIS que o banco metabase existe e usa \connect para trocar de banco. Se ficasse
# dentro do initdb.d, o entrypoint rodaria os dois em ordem alfabetica, sem controle.
set -e
PSQL="psql -v ON_ERROR_STOP=1 --username ${POSTGRES_USER:-postgres} --dbname ${POSTGRES_DB:-postgres}"

# metabase = o banco INTERNO do Metabase (usuarios, perguntas, dashboards).
# Os dados dos relatorios continuam no banco insights.
# O REVOKE tira o CONNECT que o Postgres da ao PUBLIC por padrao: o leitor dos
# relatorios nao tem o que fazer no banco interno do Metabase.
$PSQL <<-EOSQL
    CREATE DATABASE metabase;
    REVOKE CONNECT ON DATABASE metabase FROM PUBLIC;
EOSQL

$PSQL -f /etc/postgres/metabase-readonly-user.sql
