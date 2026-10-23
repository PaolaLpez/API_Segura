'use strict';
/**
 * Automation script for Section 19a Hands-on exercise:
 * Tests rotation, reuse detection, logout, and logout-all against the running API.
 */
const http = require('http');

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:3000/api/v1';

async function request(path, options = {}) {
  const url = new URL(path, BASE_URL);
  const body = options.body ? JSON.stringify(options.body) : null;
  const headers = {
    'Content-Type': 'application/json',
    ...(options.headers || {}),
  };
  if (body) {
    headers['Content-Length'] = Buffer.byteLength(body);
  }

  return new Promise((resolve, reject) => {
    const req = http.request(
      url,
      {
        method: options.method || 'GET',
        headers,
      },
      (res) => {
        let rawData = '';
        res.on('data', (chunk) => {
          rawData += chunk;
        });
        res.on('end', () => {
          let data = null;
          try {
            if (rawData) data = JSON.parse(rawData);
          } catch (_) {
            data = rawData;
          }
          resolve({ status: res.statusCode, headers: res.headers, data });
        });
      }
    );
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function runExercise() {
  console.log('--- 19a. Hands-on Exercise: Starting Tests ---');
  const randomSuffix = Math.floor(Math.random() * 100000);
  const email = `student-${randomSuffix}@example.test`;
  const password = 'a-long-local-test-password-for-this-exercise';

  console.log(`\n[Setup] Registering user: ${email}`);
  const regRes = await request('/auth/register', {
    method: 'POST',
    body: { email, password },
  });

  if (regRes.status !== 201) {
    console.error('Registration failed:', regRes.status, regRes.data);
    process.exit(1);
  }

  let accessToken = regRes.data.accessToken;
  let refreshToken = regRes.data.refreshToken;
  console.log('✓ Registration successful (tokens issued)');

  // Task 1: Rotation
  console.log('\n[Task 1 — Rotation]');
  const oldRefresh = refreshToken;
  const rotateRes = await request('/auth/refresh', {
    method: 'POST',
    body: { refreshToken: oldRefresh },
  });

  console.log(`Refresh status: ${rotateRes.status} (Expected: 200)`);
  const newRefresh = rotateRes.data?.refreshToken;
  console.log(`Token comparison: ${newRefresh !== oldRefresh ? 'different' : 'same'} (Expected: different)`);

  // Task 2: Reuse detection
  console.log('\n[Task 2 — Reuse detection]');
  const reuseOldRes = await request('/auth/refresh', {
    method: 'POST',
    body: { refreshToken: oldRefresh },
  });
  console.log(`Reuse old token status: ${reuseOldRes.status} (Expected: 401)`);

  const reuseNewRes = await request('/auth/refresh', {
    method: 'POST',
    body: { refreshToken: newRefresh },
  });
  console.log(`Attempt newest token status: ${reuseNewRes.status} (Expected: 401)`);

  // Task 3: Logout
  console.log('\n[Task 3 — Logout]');
  const loginRes = await request('/auth/login', {
    method: 'POST',
    body: { email, password },
  });
  const logoutRefresh = loginRes.data.refreshToken;

  const logoutRes = await request('/auth/logout', {
    method: 'POST',
    body: { refreshToken: logoutRefresh },
  });
  console.log(`Logout status: ${logoutRes.status} (Expected: 204)`);

  const refreshAfterLogout = await request('/auth/refresh', {
    method: 'POST',
    body: { refreshToken: logoutRefresh },
  });
  console.log(`Refresh after logout status: ${refreshAfterLogout.status} (Expected: 401)`);

  // Task 4: Logout-all
  console.log('\n[Task 4 — Logout-all]');
  const s1 = await request('/auth/login', { method: 'POST', body: { email, password } });
  const s2 = await request('/auth/login', { method: 'POST', body: { email, password } });

  const logoutAllRes = await request('/auth/logout-all', {
    method: 'POST',
    headers: { Authorization: `Bearer ${s1.data.accessToken}` },
  });
  console.log(`Logout-all status: ${logoutAllRes.status} (Expected: 204)`);

  const r1 = await request('/auth/refresh', { method: 'POST', body: { refreshToken: s1.data.refreshToken } });
  const r2 = await request('/auth/refresh', { method: 'POST', body: { refreshToken: s2.data.refreshToken } });
  console.log(`Session 1 refresh status: ${r1.status} (Expected: 401)`);
  console.log(`Session 2 refresh status: ${r2.status} (Expected: 401)`);

  console.log('\n--- All Section 19a Tests Completed! ---');
}

if (require.main === module) {
  runExercise().catch((err) => {
    console.error('Error running exercise:', err);
    process.exit(1);
  });
}

module.exports = { runExercise };
