# algashop-meta

E-commerce em microsserviços com **Java 25 + Spring Boot 4**, construído como projeto de estudo de arquitetura de software.

Este repositório não contém código: ele **agrega os doze repositórios** do projeto como submódulos Git, e guarda a infraestrutura local compartilhada por todos.

---

## Os repositórios

| Repositório | Papel |
|---|---|
| [`algashop-ordering`](https://github.com/gabriel-lima258/algashop-ordering) | Pedidos, carrinho e checkout — DDD tático, hexagonal e cache client-side |
| [`algashop-billing`](https://github.com/gabriel-lima258/algashop-billing) | Faturamento e integração com gateway de pagamento |
| [`algashop-product-catalog`](https://github.com/gabriel-lima258/algashop-product-catalog) | Catálogo de produtos e categorias, em MongoDB, com cache server-side |
| [`algashop-billing-scheduler`](https://github.com/gabriel-lima258/algashop-billing-scheduler) | Job que cancela faturas vencidas |
| [`algashop-authorization-server`](https://github.com/gabriel-lima258/algashop-authorization-server) | Emite os tokens OAuth 2.1 e gerencia usuários |
| [`algashop-service-registry`](https://github.com/gabriel-lima258/algashop-service-registry) | Eureka Server — registro e descoberta de serviços |
| [`algashop-api-gateway-ecommerce`](https://github.com/gabriel-lima258/algashop-api-gateway-ecommerce) | Borda do e-commerce (9999) — rotas por service ID, token na borda, cache local, API composition e resiliência |
| [`algashop-api-gateway-admin`](https://github.com/gabriel-lima258/algashop-api-gateway-admin) | Borda do admin (9998) — CORS da SPA, JSON enxuto na listagem, rate limit |
| [`algashop-ecommerce-app`](https://github.com/gabriel-lima258/algashop-ecommerce-app) | O BFF — app server-side Spring + Thymeleaf, token em sessão no Redis |
| [`algashop-admin-app`](https://github.com/gabriel-lima258/algashop-admin-app) | SPA Angular 17 de administração, com PKCE |
| [`algashop-docs`](https://github.com/gabriel-lima258/algashop-docs) | **O caderno de estudos** — 52 documentos sobre o que foi aplicado e por quê |
| [`algashop-template-inicial`](https://github.com/gabriel-lima258/algashop-template-inicial) | Esqueleto para começar um serviço novo |

> **Comece pelo [`algashop-docs`](https://github.com/gabriel-lima258/algashop-docs).** Cada documento registra um conceito, o problema que ele resolve, o código real onde aparece e as armadilhas encontradas — inclusive as que continuam abertas.

---

## Clonando

```bash
git clone --recurse-submodules https://github.com/gabriel-lima258/algashop-meta.git
cd algashop-meta
```

Se já clonou sem os submódulos (as pastas aparecem vazias):

```bash
git submodule update --init --recursive
```

## Adicionando submodulos ao meta

```bash
git submodule add https://github.com/gabriel-lima258/algashop-authorization-server.git microservices/authorization-server
```

```
algashop-meta/
├── docs/                              → algashop-docs
├── template/                          → algashop-template-inicial
├── etc/                               configuração da infraestrutura local
├── docker-compose.tools.yml           bancos e serviços de apoio
├── docker-compose.services.yml        os microsserviços empacotados
└── microservices/
    ├── algashop-ordering/
    ├── algashop-billing/
    ├── billing-scheduler/
    └── product-catalog/
```

---

## Subindo a infraestrutura

São três arquivos, encadeados por `include` em dois saltos:

```
docker-compose.yml  ->  docker-compose.services.yml  ->  docker-compose.tools.yml
```

| Arquivo | Contém |
|---|---|
| `docker-compose.tools.yml` | bancos e serviços de apoio — **é o que se usa no dia a dia** |
| `docker-compose.services.yml` | os quatro microsserviços em container (e inclui o `tools`) |
| `docker-compose.yml` | só o `include` — `docker compose up -d` sobe **tudo** |

### Desenvolvimento — o caso comum

Sobe só a infraestrutura; os serviços você roda pela IDE ou por `./gradlew bootRun`:

```bash
docker compose -f docker-compose.tools.yml up -d
```

| Serviço | Porta | O que é |
|---|---|---|
| PostgreSQL | **5433** | bancos de `ordering` e `billing` |
| MongoDB nó 1 | **27017** | primário do replica set `rs0` |
| MongoDB nó 2 | **27018** | secundário |
| MongoDB nó 3 | **27019** | secundário |
| Redis | **6379** | cache do catálogo (db 0) e do `ordering` (db 1) |
| WireMock | **8787** | finge ser as APIs externas |
| LocalStack | **4566** | a AWS emulada — S3, Secrets Manager e Parameter Store (config e segredos dos serviços) |
| FastPay | **9995** | gateway de pagamento simulado |

E as portas dos serviços, quando você os sobe:

| Serviço | Porta |
|---|---|
| `api-gateway-ecommerce` | **9999** — borda do e-commerce |
| `api-gateway-admin` | **9998** — borda do admin |
| `ecommerce-app` | **9080** — o BFF server-side |
| `admin-app` | **4200** — a SPA (nginx no container) |
| `algashop-ordering` | 8081 |
| `algashop-billing` | 8082 |
| `product-catalog` | 8083 |
| `authorization-server` | 9000 — no compose desde a Fase 26, responde por `auth.algashop.local` |
| `service-registry` | 8761 — dashboard Eureka |
| `billing-scheduler` | — (não expõe HTTP) |

> ⚠️ **A porta 5433 não é engano.** O Postgres é exposto em `5433` no host justamente para não conflitar com uma instalação nativa, que ocupa a `5432`. Dentro da rede Docker os containers continuam falando na `5432`.

> ⚠️ **O `.env` na raiz é obrigatório.** É de lá que o Compose lê `REDIS_PASSWORD` para montar o `--requirepass` do Redis. Sem ele, a variável vira string vazia, o Redis sobe **sem senha**, e as aplicações são recusadas — com o agravante de que nada quebra: o serviço responde certo, sempre indo ao banco.

### Um passo a mais para o MongoDB

Os três nós se anunciam no replica set pelos nomes internos do Docker. Como as aplicações rodam **fora** dessa rede, sua máquina precisa saber resolvê-los — acrescente ao arquivo `hosts`:

```
127.0.0.1       algashop-mongodb-1
127.0.0.1       algashop-mongodb-2
127.0.0.1       algashop-mongodb-3
```

O mesmo arquivo traz três linhas para o LocalStack, e elas **não são opcionais**: a URL pré-assinada que o catálogo devolve aponta para `algashop-localstack:4566` e é usada **pelo navegador**, que precisa resolver o mesmo nome que o servidor usou para assinar.

O conteúdo está em `etc/hostnames/hostnames`, e o passo a passo por sistema operacional em `etc/hostnames/editando-arquivo-hosts.md`.

### Comandos úteis

```bash
docker compose -f docker-compose.tools.yml ps
docker compose -f docker-compose.tools.yml logs algashop-mongodb-init
docker compose -f docker-compose.tools.yml down       # para, mantendo os dados
docker compose -f docker-compose.tools.yml down -v    # para E APAGA os volumes
```

---

## A pasta `etc/`

| Pasta | O que faz |
|---|---|
| `etc/postgres/` | `init-user-db.sh`, que cria os cinco bancos na primeira subida do volume |
| `etc/wiremock/` | respostas fixas para as APIs externas — catálogo, FastPay e Rapidex |
| `etc/stub-runner/` | alternativa ao WireMock: consome os stubs gerados pelos contract tests do `product-catalog` |
| `etc/hostnames/` | as entradas de `hosts` do cluster MongoDB, e como editá-las em cada sistema |
| `etc/k6/` | os testes de carga — smoke, load e volume, contra o catálogo e contra a compra |
| `etc/aws/` | `init.sh` + `parameters.csv`/`secrets.csv` — o seed completo do LocalStack: parâmetros, segredos, chave RSA, bucket, CORS e imagens |
| `etc/images/` | as imagens de exemplo sincronizadas para o bucket na subida |

O diretório do WireMock é montado como volume, então **editar um JSON e reiniciar o container** já aplica a mudança.

---

## Teste de carga

Precisa do [k6](https://grafana.com/docs/k6/latest/set-up/install-k6/) e do ambiente de pé (`docker compose up -d`):

```bash
k6 run etc/k6/get-product-loadTest-k6.js
k6 run etc/k6/buy-now.js
k6 run -e PROFILE=volume etc/k6/buy-now.js
```

O `ordering` sobe com o Tomcat limitado a **10 threads** de propósito — sem apertar isso, uma máquina de desenvolvimento não chega perto de um gargalo. Para virar a chave das threads virtuais:

```bash
VIRTUAL_THREADS=true docker compose up -d --force-recreate algashop-ordering
```

> ⚠️ Sob carga alta essa configuração **trava o serviço de forma permanente** neste projeto — a medição está documentada, com thread dump e números.

- [Testes de carga com k6](https://github.com/gabriel-lima258/algashop-docs/blob/main/03-testes-integracao/testes-de-carga-k6.md)
- [Threads e concorrência](https://github.com/gabriel-lima258/algashop-docs/blob/main/04-infraestrutura/threads-e-concorrencia.md)

---

## Trabalhando com os submódulos

| Situação | Comando |
|---|---|
| Ver o estado de todos de uma vez | `git submodule foreach 'git status --short'` |
| Puxar as atualizações de todos | `git submodule update --remote --merge` |
| Adicionar um submódulo novo | `git submodule add <url> microservices/<nome>` |
| Fixar o submódulo numa branch | `git submodule set-branch -b main microservices/<nome>` |

> ⚠️ **Cuidado com `git submodule update` sem `--remote`.** Ele joga o submódulo no commit registrado aqui e **descarta trabalho local não commitado**. Cheque o status antes, sempre.

### Commitar é sempre em duas etapas

O repositório meta guarda apenas um **ponteiro** — o SHA do commit de cada submódulo. Alterar o código de um serviço exige commitar duas vezes:

```bash
cd microservices/product-catalog
git commit -m "feat: ..."
git push

cd ../..
git add microservices/product-catalog
git commit -m "chore: atualizar submodulo product-catalog"
git push
```

Esquecer a segunda etapa é o erro mais comum do fluxo: o código está no GitHub, e quem clonar o meta continua recebendo a versão antiga.

---

## Por onde começar a estudar

1. [Arquitetura](https://github.com/gabriel-lima258/algashop-docs/blob/main/00-visao-geral/arquitetura.md) — o mapa dos serviços e como conversam
2. [Linha do tempo](https://github.com/gabriel-lima258/algashop-docs/blob/main/00-visao-geral/linha-do-tempo.md) — a jornada em 37 fases, e por que nessa ordem
3. [Ambiente local](https://github.com/gabriel-lima258/algashop-docs/blob/main/04-infraestrutura/ambiente-local.md) — do clone aos serviços rodando, com os problemas comuns

O índice completo dos 52 documentos está no [`algashop-docs`](https://github.com/gabriel-lima258/algashop-docs).

---

## Stack

**Java 25** · **Spring Boot 4.0** · Spring Data JPA · Spring Data MongoDB · PostgreSQL 17 · MongoDB 8 em replica set · Redis 8 · Flyway · Gradle 9 · Spring Cloud Contract · WireMock · Testcontainers · JUnit 5 · AssertJ · ModelMapper · Lombok · Docker Compose
