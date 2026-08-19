import request from 'supertest';
import { app } from '../src/app';
import { pool } from '../src/db/pool';
import { resetDatabase } from './db-utils';

async function registerAndGetToken(email: string): Promise<string> {
  const res = await request(app).post('/auth/register').send({
    fullName: 'Owner',
    email,
    password: 'secret123',
  });
  return res.body.token as string;
}

describe('Shops module', () => {
  beforeEach(async () => {
    await resetDatabase();
  });

  afterAll(async () => {
    await pool.end();
  });

  it('creates a shop and returns JSON-number id and ownerId', async () => {
    const token = await registerAndGetToken('owner@example.com');

    const res = await request(app)
      .post('/shops')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Epicerie Rasoa', category: 'Alimentation' });

    expect(res.status).toBe(201);
    expect(typeof res.body.id).toBe('number');
    expect(res.body.id).toBe(1);
    expect(typeof res.body.ownerId).toBe('number');
    expect(res.body.ownerId).toBe(1);
    expect(res.text).toContain('"id":1');
    expect(res.text).not.toContain('"id":"1"');
    expect(res.text).toContain('"ownerId":1');
    expect(res.text).not.toContain('"ownerId":"1"');
  });

  it('lists shops with JSON-number ids', async () => {
    const token = await registerAndGetToken('owner2@example.com');
    await request(app)
      .post('/shops')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Boutique', category: 'Mode' });

    const res = await request(app).get('/shops');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBe(1);
    expect(typeof res.body[0].id).toBe('number');
    expect(typeof res.body[0].ownerId).toBe('number');
  });

  it('fetches a single shop by id with a JSON-number id', async () => {
    const token = await registerAndGetToken('owner3@example.com');
    const created = await request(app)
      .post('/shops')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Marché Central', category: 'Alimentation' });

    const res = await request(app).get(`/shops/${created.body.id}`);

    expect(res.status).toBe(200);
    expect(typeof res.body.id).toBe('number');
    expect(res.body.id).toBe(created.body.id);
  });

  it('returns 404 with a JSON body for an unknown shop id', async () => {
    const res = await request(app).get('/shops/999999');
    expect(res.status).toBe(404);
    expect(res.body.code).toBe('NOT_FOUND');
  });
});
