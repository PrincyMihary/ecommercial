import request from 'supertest';
import { app } from '../src/app';
import { pool } from '../src/db/pool';
import { resetDatabase } from './db-utils';

async function registerShopOwner(email: string): Promise<{ token: string; shopId: number }> {
  const registerRes = await request(app).post('/auth/register').send({
    fullName: 'Owner',
    email,
    password: 'secret123',
  });
  const token = registerRes.body.token as string;

  const shopRes = await request(app)
    .post('/shops')
    .set('Authorization', `Bearer ${token}`)
    .send({ name: 'Boutique', category: 'Alimentation' });

  return { token, shopId: shopRes.body.id as number };
}

describe('Products module', () => {
  beforeEach(async () => {
    await resetDatabase();
  });

  afterAll(async () => {
    await pool.end();
  });

  it('creates a product and returns JSON-number id and shopId', async () => {
    const { token, shopId } = await registerShopOwner('shopowner@example.com');

    const res = await request(app)
      .post('/products')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Riz local', price: 5000, stock: 20, category: 'Alimentation' });

    expect(res.status).toBe(201);
    expect(typeof res.body.id).toBe('number');
    expect(res.body.id).toBe(1);
    expect(typeof res.body.shopId).toBe('number');
    expect(res.body.shopId).toBe(shopId);
    expect(res.text).toContain('"id":1');
    expect(res.text).not.toContain('"id":"1"');
    expect(res.text).toContain(`"shopId":${shopId}`);
    expect(res.text).not.toContain(`"shopId":"${shopId}"`);
  });

  it('lists products with JSON-number ids', async () => {
    const { token } = await registerShopOwner('shopowner2@example.com');
    await request(app)
      .post('/products')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Huile', price: 3000, stock: 10, category: 'Alimentation' });

    const res = await request(app).get('/products');

    expect(res.status).toBe(200);
    expect(res.body.length).toBe(1);
    expect(typeof res.body[0].id).toBe('number');
    expect(typeof res.body[0].shopId).toBe('number');
  });

  it('fetches a single product by id with a JSON-number id', async () => {
    const { token } = await registerShopOwner('shopowner3@example.com');
    const created = await request(app)
      .post('/products')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Sucre', price: 2000, stock: 15, category: 'Alimentation' });

    const res = await request(app).get(`/products/${created.body.id}`);

    expect(res.status).toBe(200);
    expect(typeof res.body.id).toBe('number');
    expect(res.body.id).toBe(created.body.id);
  });
});
