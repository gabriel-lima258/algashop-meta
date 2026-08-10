import http from 'k6/http';
import { sleep, check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8083';

// Listagem de produtos do catalogo: leitura pura, servida pelo cache do Redis.
// E o cenario mais barato do sistema - serve de piso de comparacao para o buy-now.
//
// Perfis, escolhidos por __ENV.PROFILE. Duas armadilhas de uma vez:
//   1. NAO usar o prefixo K6_ no nome: variaveis K6_* sao consumidas pelo proprio
//      k6 como opcoes de configuracao e nunca chegam em __ENV.
//   2. Passar com -e, nao pelo ambiente do shell: no k6 v2 as variaveis do sistema
//      nao entram em __ENV por padrao, e "PROFILE=volume k6 run ..." roda o perfil
//      default calado, sem erro nenhum.
//
//   default -> smoke (1 VU) e depois load (taxa constante). E o que roda no dia a dia.
//   volume  -> rampa ate 1000 VUs para descobrir ONDE quebra. Nao roda junto.
//
//   k6 run etc/k6/get-product-loadTest-k6.js
//   k6 run -e PROFILE=volume etc/k6/get-product-loadTest-k6.js

const PROFILE = __ENV.PROFILE || 'default';

// constant-vus: N usuarios em loop. VU e CONCORRENCIA, nao taxa - se a API ficar
// lenta, cada VU faz menos requisicoes e a carga cai sozinha. Bom para smoke,
// ruim para medir capacidade, porque o teste alivia justamente quando aperta.
const smokeScenario = {
  executor: 'constant-vus',
  vus: 1,
  duration: '5s',
  exec: 'browseProductsWithThinkTime',
};

// constant-arrival-rate: N requisicoes por segundo, doa a quem doer. A carga NAO
// cai quando a API fica lenta - o k6 aloca mais VUs para sustentar a taxa. E o
// unico executor que mede capacidade de verdade.
//
// Dimensionamento: VUs necessarios = taxa x duracao_da_iteracao.
// A 100/s, com o p(95) que estamos exigindo (800ms), o pior caso pede
// 100 x 0,8 = 80 VUs. maxVUs: 200 da folga para a API degradar sem que o teste
// pare de aplicar a carga - e o dropped_iterations abaixo denuncia se faltar.
const loadScenario = {
  executor: 'constant-arrival-rate',
  rate: 100,
  timeUnit: '1s',
  duration: '1m',
  startTime: '5s', // comeca quando o smoke termina; os dois nunca se sobrepoem
  preAllocatedVus: 80,
  maxVUs: 200,
  exec: 'browseProducts',
};

// ramping-vus: sobe a concorrencia em degraus ate o sistema doer. Nao e teste de
// carga (nao ha alvo a cumprir) - e teste de VOLUME: a pergunta nao e "aguenta?",
// e "aguenta ate onde?". Por isso ele nao herda os thresholds dos outros dois:
// falhar faz parte do resultado.
const volumeScenario = {
  executor: 'ramping-vus',
  startVUs: 0,
  stages: [
    { duration: '5s', target: 50 },
    { duration: '5s', target: 300 },
    { duration: '5s', target: 500 },
    { duration: '10s', target: 1000 },
    { duration: '5s', target: 300 },
    { duration: '3s', target: 0 },
  ],
  exec: 'browseProductsWithThinkTime',
};

export const options = {
  scenarios: PROFILE === 'volume'
    ? { get_product_volume: volumeScenario }
    : { get_product_smoke: smokeScenario, get_product_load: loadScenario },

  // Threshold e o unico mecanismo que REPROVA o teste. check() so conta acertos e
  // erros no relatorio: um script cheio de checks vermelhos ainda sai com exit 0.
  //
  // Os limites levam {scenario:...} de proposito. Sem o filtro, os 5 segundos de
  // 1 VU do smoke entram na mesma amostra do minuto a 100/s e puxam o p(95) para
  // baixo - o teste passaria por diluicao.
  thresholds: PROFILE === 'volume' ? {} : {
    'http_req_duration{scenario:get_product_load}': ['p(95) < 800'],
    'http_req_failed{scenario:get_product_load}': ['rate < 0.01'],
    'checks{scenario:get_product_load}': ['rate > 0.99'],
    // Se o k6 nao conseguir sustentar a taxa com os maxVUs disponiveis, ele
    // DESCARTA iteracoes - e o teste "passa" tendo aplicado menos carga do que
    // declarou. Esta linha transforma esse silencio em falha.
    dropped_iterations: ['count < 1'],
  },
};

export function browseProducts() {
  const res = http.get(`${BASE_URL}/api/v1/products`);
  check(res, { 'status is 200': (r) => r.status === 200 });
}

// Mesma requisicao, com tempo de leitura. Duas funcoes em vez de um if la dentro
// porque o sleep nao e detalhe do request - e o que separa os dois executores.
export function browseProductsWithThinkTime() {
  browseProducts();
  sleep(1);
}
