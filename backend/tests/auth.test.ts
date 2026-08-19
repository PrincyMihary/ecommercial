import request from 'supertest';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';

/**
 * Tests d'intégration du module Auth.
 *
 * IMPORTANT : ces tests nécessitent une base PostgreSQL de test réelle
 * (DATABASE_URL, voir tests/setup-env.ts) avec le schéma déjà appliqué
 * (`psql "$DATABASE_URL" -f database/schema.sql`). Cet environnement
 * d'exécution ne dispose pas d'accès réseau ni de PostgreSQL installé :
 * ces tests n'ont donc PAS été exécutés ici, conformément à la consigne
 * de ne jamais prétendre le contraire. Ils sont prêts à être lancés par
 * l'équipe via `npm test` une fois une base de test configurée.
 */
const app = createApp();

async function resetUsersTable() {
  await pool.query('TRUNCATE TABLE order_items, orders, cart_items, carts, products, shops, users RESTART IDENTITY CASCADE');
}

describe('Auth module', () => {
  beforeEach(async () => {
    await resetUsersTable();
  });

  afterAll(async () => {
    await pool.end();
  });

  describe('POST /auth/register', () => {
    it('crée un utilisateur et renvoie user + token', async () => {
      const res = await request(app).post('/auth/register').send({
        full_name: 'Alice Rasoa',
        email: 'alice@example.com',
        phone: '0341234567',
        password: 'secret123',
      });

      expect(res.status).toBe(201);
      expect(res.body.token).toEqual(expect.any(String));
      expect(res.body.user).toMatchObject({
        full_name: 'Alice Rasoa',
        email: 'alice@example.com',
        phone: '0341234567',
      });
      expect(res.body.user.password_hash).toBeUndefined();
      expect(res.body.user.password).toBeUndefined();
    });

    it('refuse un email déjà utilisé avec un 409 et le message existant', async () => {
      await request(app).post('/auth/register').send({
        full_name: 'Alice',
        email: 'dup@example.com',
        password: 'secret123',
      });

      const res = await request(app).post('/auth/register').send({
        full_name: 'Alice bis',
        email: 'dup@example.com',
        password: 'secret123',
      });

      expect(res.status).toBe(409);
      expect(res.body.message).toBe('Email déjà utilisé.');
    });

    it('refuse un mot de passe trop court', async () => {
      const res = await request(app).post('/auth/register').send({
        full_name: 'Bob',
        email: 'bob@example.com',
        password: '123',
      });

      expect(res.status).toBe(400);
      expect(res.body.code).toBe('AUTH_PASSWORD_TOO_SHORT');
    });
  });

  describe('POST /auth/login', () => {
    beforeEach(async () => {
      await request(app).post('/auth/register').send({
        full_name: 'Carol',
        email: 'carol@example.com',
        password: 'secret123',
      });
    });

    it('connecte avec des identifiants valides', async () => {
      const res = await request(app).post('/auth/login').send({
        email: 'carol@example.com',
        password: 'secret123',
      });

      expect(res.status).toBe(200);
      expect(res.body.token).toEqual(expect.any(String));
      expect(res.body.user.email).toBe('carol@example.com');
    });

    it('refuse un mauvais mot de passe sans révéler la cause', async () => {
      const res = await request(app).post('/auth/login').send({
        email: 'carol@example.com',
        password: 'wrongpassword',
      });

      expect(res.status).toBe(401);
      expect(res.body.message).toBe('Email ou mot de passe incorrect.');
    });

    it('refuse un email inconnu avec le même message générique', async () => {
      const res = await request(app).post('/auth/login').send({
        email: 'unknown@example.com',
        password: 'secret123',
      });

      expect(res.status).toBe(401);
      expect(res.body.message).toBe('Email ou mot de passe incorrect.');
    });
  });

  describe('GET /users/me', () => {
    it('refuse sans token', async () => {
      const res = await request(app).get('/users/me');
      expect(res.status).toBe(401);
    });

    it('refuse avec un token invalide', async () => {
      const res = await request(app)
        .get('/users/me')
        .set('Authorization', 'Bearer not-a-real-token');
      expect(res.status).toBe(401);
    });

    it("renvoie l'utilisateur courant avec un token valide", async () => {
      const registerRes = await request(app).post('/auth/register').send({
        full_name: 'Dina',
        email: 'dina@example.com',
        password: 'secret123',
      });
      const token = registerRes.body.token as string;

      const res = await request(app)
        .get('/users/me')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.user.email).toBe('dina@example.com');
      expect(res.body.user.password_hash).toBeUndefined();
    });
  });
});
