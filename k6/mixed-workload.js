import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

// Custom metrics
const dbQueryDuration = new Trend('db_query_duration', true);
const cpuWorkloadDuration = new Trend('cpu_workload_duration', true);

// Adapter 포트 매핑
const adapterTargets = {
  'spring_vt': 'http://localhost:8080',
  'spring_platform': 'http://localhost:8081',
  'spring_webflux_java': 'http://localhost:8082',
  'spring_webflux_coroutine': 'http://localhost:8083',
};

// Test configuration
export const options = {
  scenarios: {
    db_queries: {
      executor: 'constant-vus',
      exec: 'dbQueryScenario',
      vus: 15,
      duration: '3m',
    },
    cpu_workload: {
      executor: 'constant-vus',
      exec: 'cpuWorkloadScenario',
      vus: 5,
      duration: '3m',
    },
  },
  thresholds: {
    'http_req_duration': ['p(95)<2500'],
    'http_req_failed': ['rate<0.01'],
  },
};

export function dbQueryScenario() {
  const adapterKey = (__ENV.ADAPTER || 'spring_vt').toLowerCase();
  const baseUrl = adapterTargets[adapterKey];

  const page = Math.floor(Math.random() * 10);
  const url = `${baseUrl}/api/orders?status=DELIVERED&daysAgo=30&page=${page}&size=100`;

  const res = http.get(url);
  dbQueryDuration.add(res.timings.duration);

  check(res, {
    'db query status 200': (r) => r.status === 200,
  });

  sleep(1);
}

export function cpuWorkloadScenario() {
  const adapterKey = (__ENV.ADAPTER || 'spring_vt').toLowerCase();
  const baseUrl = adapterTargets[adapterKey];

  const tasks = Math.floor(Math.random() * 20) + 10;  // 10-30
  const workMs = Math.floor(Math.random() * 30) + 20; // 20-50

  const url = `${baseUrl}/api/workload?tasks=${tasks}&workMs=${workMs}`;

  const res = http.get(url);
  cpuWorkloadDuration.add(res.timings.duration);

  check(res, {
    'cpu workload status 200': (r) => r.status === 200,
  });

  sleep(1);
}

export function handleSummary(data) {
  return {
    'stdout': JSON.stringify(data, null, 2),
  };
}
