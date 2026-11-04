// k6 load test run by the Harness Test stage against the image under test.
// Thresholds are the pass/fail rule; the JUnit file is attested to Kosli as `load-test`.
//
//   k6 run -e BASE_URL=http://127.0.0.1:8080 tests/load/ai-app.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { jUnit, textSummary } from 'https://jslib.k6.io/k6-summary/0.0.1/index.js';

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:8080';
const OUT = __ENV.RESULTS_FILE || 'load.xml';

export const options = {
  vus: 5,
  duration: '20s',
  thresholds: {
    http_req_failed: ['rate<0.01'],   // under 1% errors
    http_req_duration: ['p(95)<500'], // 95% of requests under 500 ms
    checks: ['rate>0.99'],
  },
};

export default function () {
  check(http.get(`${BASE_URL}/`), { 'home page 200': (r) => r.status === 200 });
  check(http.get(`${BASE_URL}/healthz`), { 'healthz ok': (r) => r.body.trim() === 'ok' });
  check(http.get(`${BASE_URL}/version`), { 'version served': (r) => r.status === 200 && r.body.trim().length > 0 });
  sleep(0.2); // ~5 iterations per user per second: a steady load, not a flood
}

export function handleSummary(data) {
  return {
    stdout: textSummary(data, { indent: ' ', enableColors: false }),
    [OUT]: jUnit(data),
  };
}
