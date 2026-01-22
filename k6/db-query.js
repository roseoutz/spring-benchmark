import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';

// Custom metrics
const dbQueryDuration = new Trend('db_query_duration', true);
const dbQueryErrors = new Counter('db_query_errors');

// Adapter 포트 매핑
const adapterTargets = {
  'spring_vt': 'http://localhost:8080',
  'spring_platform': 'http://localhost:8081',
  'spring_webflux_java': 'http://localhost:8082',
  'spring_webflux_coroutine': 'http://localhost:8083',
};

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: 20 },  // Ramp-up to 20 VUs
    { duration: '2m', target: 20 },   // Stay at 20 VUs for 2 minutes
    { duration: '30s', target: 0 },   // Ramp-down to 0
  ],
  thresholds: {
    'http_req_duration': ['p(95)<5000', 'p(99)<8000'],  // 95% < 5s, 99% < 8s (10M records)
    'http_req_failed': ['rate<0.05'],                    // Error rate < 5%
    'db_query_duration': ['p(95)<5000'],
  },
};

export default function () {
  // Get adapter from environment variable
  const adapterKey = (__ENV.ADAPTER || 'spring_vt').toLowerCase();
  const baseUrl = adapterTargets[adapterKey];

  if (!baseUrl) {
    throw new Error(`Unknown adapter: ${adapterKey}`);
  }

  // Random parameters
  const page = Math.floor(Math.random() * 10);  // 0-9
  const size = 100;
  const daysAgo = 30;
  const status = 'DELIVERED';

  const url = `${baseUrl}/api/orders?status=${status}&daysAgo=${daysAgo}&page=${page}&size=${size}`;

  const params = {
    headers: {
      'Accept': 'application/json',
    },
    timeout: '10s',
  };

  const res = http.get(url, params);

  // Record custom metric
  dbQueryDuration.add(res.timings.duration);

  // Validation
  const checkResult = check(res, {
    'status is 200': (r) => r.status === 200,
    'response has content': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.content && Array.isArray(body.content);
      } catch (e) {
        return false;
      }
    },
    'response time < 3s': (r) => r.timings.duration < 3000,
  });

  if (!checkResult) {
    dbQueryErrors.add(1);
  }

  // Think time
  sleep(1);
}

export function handleSummary(data) {
  return {
    'stdout': JSON.stringify(data, null, 2),
  };
}
