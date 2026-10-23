'use strict';
const request = require('supertest');
const { app } = require('../src/app');

describe('refresh-token lifecycle', () => {
  const email = `refresh-${Date.now()}@example.test`;
  const password = 'a-long-test-password';

  async function register() {
    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({ email, password });
    expect(response.status).toBe(201);
    return response.body;
  }

  test('rotation returns a different refresh token', async () => {
    const initial = await register();
    const response = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: initial.refreshToken });
    expect(response.status).toBe(200);
    expect(response.body.refreshToken).not.toBe(initial.refreshToken);
  });

  test('reuse of an old token revokes the newer token family token', async () => {
    const initial = await register();
    const rotated = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: initial.refreshToken });
    expect(rotated.status).toBe(200);

    const reuse = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: initial.refreshToken });
    expect(reuse.status).toBe(401);

    const newer = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: rotated.body.refreshToken });
    expect(newer.status).toBe(401);
  });

  test('logout makes the refresh token unusable', async () => {
    const tokens = await register();
    const logout = await request(app)
      .post('/api/v1/auth/logout')
      .send({ refreshToken: tokens.refreshToken });
    expect(logout.status).toBe(204);

    const refresh = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: tokens.refreshToken });
    expect(refresh.status).toBe(401);
  });
});
