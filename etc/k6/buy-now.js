import http from 'k6/http';
import { sleep, check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8081';

// Compra instantanea: o caminho mais caro do sistema. Uma requisicao aqui abre
// transacao no Postgres, busca o cliente, chama o product-catalog por HTTP, chama
// a Rapidex por HTTP e so entao grava o pedido - tudo dentro da mesma transacao.
// E por isso que ele mede coisa diferente do get-product: ali o gargalo e CPU e
// cache; aqui e pool de conexao e thread parada esperando rede.
//
// Perfis, escolhidos por __ENV.PROFILE. Duas armadilhas de uma vez:
//   1. NAO usar o prefixo K6_ no nome: variaveis K6_* sao consumidas pelo proprio
//      k6 como opcoes de configuracao e nunca chegam em __ENV.
//   2. Passar com -e, nao pelo ambiente do shell: no k6 v2 as variaveis do sistema
//      nao entram em __ENV por padrao, e "PROFILE=volume k6 run ..." roda o perfil
//      default calado, sem erro nenhum.
//
//   default -> smoke (1 VU) e depois load (taxa constante)
//   volume  -> rampa ate 500 VUs para achar o ponto de quebra
//
//   k6 run etc/k6/buy-now.js
//   k6 run -e PROFILE=volume etc/k6/buy-now.js

const PROFILE = __ENV.PROFILE || 'default';

const smokeScenario = {
  executor: 'constant-vus',
  vus: 1,
  duration: '5s',
  exec: 'buyNowWithThinkTime',
};

// Dimensionamento: VUs = taxa x duracao_da_iteracao. A 80/s com o p(95) exigido
// (1200ms), o pior caso pede 80 x 1,2 = 96 VUs. maxVUs: 250 porque este caminho
// pode degradar muito alem do alvo quando o pool de conexoes satura - e sem folga
// o k6 para de aplicar a carga justamente na hora interessante.
const loadScenario = {
  executor: 'constant-arrival-rate',
  rate: 80,
  timeUnit: '1s',
  duration: '1m',
  startTime: '5s',
  preAllocatedVus: 96,
  maxVUs: 250,
  exec: 'buyNow',
};

const volumeScenario = {
  executor: 'ramping-vus',
  startVUs: 0,
  stages: [
    { duration: '10s', target: 50 },
    { duration: '10s', target: 200 },
    { duration: '15s', target: 500 },
    { duration: '10s', target: 0 },
  ],
  exec: 'buyNowWithThinkTime',
};

export const options = {
  scenarios: PROFILE === 'volume'
    ? { buy_now_volume: volumeScenario }
    : { buy_now_smoke: smokeScenario, buy_now_load: loadScenario },

  thresholds: PROFILE === 'volume' ? {} : {
    'http_req_duration{scenario:buy_now_load}': ['p(95) < 1200'],
    // Sem esta linha o teste passava com a API devolvendo 422 em 100% das
    // requisicoes: check() nao reprova nada, e um erro rapido e mais rapido que
    // um sucesso. Falhar depressa nao e passar.
    'http_req_failed{scenario:buy_now_load}': ['rate < 0.01'],
    'checks{scenario:buy_now_load}': ['rate > 0.99'],
    dropped_iterations: ['count < 1'],
  },
};

// Cliente e produto vem carregados: o cliente pelo afterMigrate.sql do Flyway
// (perfil docker) e o produto pelo products.json do DataLoader do catalogo.
// Sao ids FIXOS - todo VU compra o mesmo produto para o mesmo cliente, o que
// concentra contencao no mesmo registro. E deliberado: e o pior caso.
const CUSTOMER_ID = __ENV.CUSTOMER_ID || '41cdc65c-6158-48b0-a8e6-34c0ff8fd74e';
const PRODUCT_ID = __ENV.PRODUCT_ID || '2eea613a-3a11-46dd-95ee-2678c295559e';

const params = {
  headers: {
    Accept: 'application/json',
    // O endpoint tem duas assinaturas no mesmo POST /api/v1/orders, separadas
    // por media type versionado. Errar o Content-Type aqui da 415, nao 400.
    'Content-Type': 'application/vnd.order-with-product.v1+json',
  },
};

const payload = {
  paymentMethod: 'GATEWAY_BALANCE',
  shipping: {
    recipient: {
      firstName: 'John',
      lastName: 'Doe',
      document: '255-08-0578',
      phone: '478-256-2604',
    },
    address: {
      street: 'Elm Street',
      number: '456',
      complement: 'House A',
      neighborhood: 'Central Park',
      city: 'Springfield',
      state: 'Illinois',
      zipCode: '62704',
    },
  },
  billing: {
    firstName: 'Matt',
    lastName: 'Damon',
    phone: '123-321-1112',
    document: '123-45-6789',
    email: 'matt.damon@email.com',
    address: {
      street: 'Amphitheatre Parkway',
      number: '1600',
      complement: '',
      neighborhood: 'Mountain View',
      city: 'Mountain View',
      state: 'California',
      zipCode: '94043',
    },
  },
  customerId: CUSTOMER_ID,
  productId: PRODUCT_ID,
  quantity: 2,
};

const body = JSON.stringify(payload);

export function buyNow() {
  // A assinatura e http.post(url, body, params): corpo primeiro, opcoes depois.
  // Trocar a ordem faz o k6 serializar o objeto params como form-urlencoded e
  // envia-lo como corpo - os headers nunca sao aplicados e a API responde 415.
  const res = http.post(`${BASE_URL}/api/v1/orders`, body, params);
  check(res, { 'status is 201': (r) => r.status === 201 });
}

export function buyNowWithThinkTime() {
  buyNow();
  sleep(1);
}
