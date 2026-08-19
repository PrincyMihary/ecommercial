import request from 'supertest';
import { app } from '../src/app';
import { pool } from '../src/db/pool';
import { resetDatabase } from './db-utils';

describe('Auth module', () => {
  beforeEach(async () => {
    await resetDatabase();
  });

  afterAll(async () => {
    await pool.end();
  });

  describe('POST /auth/register', () => {
    it('creates a user and returns a JSON-number id (not a string)', async () => {
      const res = await request(app).post('/auth/register').send({
        fullName: 'Alice Rasoa',
        email: 'alice@example.com',
        phone: '0341234567',
        password: 'secret123',
      });

      expect(res.status).toBe(201);
      expect(res.body.token).toEqual(expect.any(String));
      expect(res.body.user).toMatchObject({
        fullName: 'Alice Rasoa',
        email: 'alice@example.com',
        phone: '0341234567',
      });
      expect(typeof res.body.user.id).toBe('number');
      expect(res.body.user.id).toBe(1);
      // Le JSON brut doit contenir "id":1, jamais "id":"1" — c'est le
      // coeur de la convention BIGINT/BIGSERIAL -> number JSON.
      expect(res.text).toContain('"id":1');
      expect(res.text).not.toContain('"id":"1"');
      expect(res.body.user.password_hash).toBeUndefined();
      expect(res.body.user.password).toBeUndefined();
    });

    it('does not convert other numeric strings (phone) to a number', async () => {
      const res = await request(app).post('/auth/register').send({
        fullName: 'Numeric String',
        email: 'numeric@example.com',
        phone: '123456',
        password: 'secret123',
      });

      expect(res.status).toBe(201);
      expect(typeof res.body.user.id).toBe('number');
      expect(res.body.user.phone).toBe('123456');
      expect(typeof res.body.user.phone).toBe('string');
    });

    it('rejects an already-used email with 409', async () => {
      await request(app).post('/auth/register').send({
        fullName: 'Alice',
        email: 'dup@example.com',
        password: 'secret123',
      });

      const res = await request(app).post('/auth/register').send({
        fullName: 'Alice bis',
        email: 'dup@example.com',
        password: 'secret123',
      });

      expect(res.status).toBe(409);
      expect(res.body.message).toBe('Cet email est déjà utilisé.');
    });

    it('rejects a too-short password', async () => {
      const res = await request(app).post('/auth/register').send({
        fullName: 'Bob',
        email: 'bob@example.com',
        password: '123',
      });

      expect(res.status).toBe(400);
      expect(res.body.code).toBe('AUTH_ERROR');
    });
  });

  describe('POST /auth/login', () => {
    beforeEach(async () => {
      await request(app).post('/auth/register').send({
        fullName: 'Carol',
        email: 'carol@example.com',
        password: 'secret123',
      });
    });

    it('logs in with valid credentials and returns a JSON-number id', async () => {
      const res = await request(app).post('/auth/login').send({
        email: 'carol@example.com',
        password: 'secret123',
      });

      expect(res.status).toBe(200);
      expect(res.body.token).toEqual(expect.any(String));
      expect(res.body.user.email).toBe('carol@example.com');
      expect(typeof res.body.user.id).toBe('number');
      expect(res.text).toContain('"id":1');
    });

    it('rejects a wrong password with a generic message', async () => {
      const res = await request(app).post('/auth/login').send({
        email: 'carol@example.com',
        password: 'wrongpassword',
      });

      expect(res.status).toBe(400);
      expect(res.body.message).toBe('Email ou mot de passe incorrect.');
    });
  });

  describe('GET /users/me', () => {
    it('refuses without a token', async () => {
      const res = await request(app).get('/users/me');
      expect(res.status).toBe(401);
    });

    it('refuses with an invalid token', async () => {
      const res = await request(app).get('/users/me').set('Authorization', 'Bearer not-a-real-token');
      expect(res.status).toBe(401);
    });

    it('returns the current user with a JSON-number id when the token is valid', async () => {
      const registerRes = await request(app).post('/auth/register').send({
        fullName: 'Dina',
        email: 'dina@example.com',
        password: 'secret123',
      });
      const token = registerRes.body.token as string;

      const res = await request(app).get('/users/me').set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.email).toBe('dina@example.com');
      expect(res.body.password_hash).toBeUndefined();
      expect(typeof res.body.id).toBe('number');
      expect(res.body.id).toBe(1);
      expect(res.text).toContain('"id":1');
      expect(res.text).not.toContain('"id":"1"');
    });
  });
});
