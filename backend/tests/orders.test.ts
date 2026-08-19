import request from 'supertest';
import { app } from '../src/app';
import { pool } from '../src/db/pool';
import { resetDatabase } from './db-utils';

describe('Cart / Orders non-regression (BIGINT serialization)', () => {
  beforeEach(async () => {
    await resetDatabase();
  });

  afterAll(async () => {
    await pool.end();
  });

  it('lets a buyer add a product to cart with a JSON-number productId', async () => {
    const ownerRes = await request(app).post('/auth/register').send({
      fullName: 'Owner',
      email: 'owner@example.com',
      password: 'secret123',
    });
    const ownerToken = ownerRes.body.token as string;

    await request(app)
      .post('/shops')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ name: 'Boutique', category: 'Alimentation' });

    const productRes = await request(app)
      .post('/products')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ name: 'Riz local', price: 5000, stock: 20, category: 'Alimentation' });
    const productId = productRes.body.id as number;

    const buyerRes = await request(app).post('/auth/register').send({
      fullName: 'Buyer',
      email: 'buyer@example.com',
      password: 'secret123',
    });
    const buyerToken = buyerRes.body.token as string;

    const addRes = await request(app)
      .post('/cart/items')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ productId, quantity: 2 });

    expect(addRes.status).toBe(201);
    expect(addRes.body.added).toBe(2);
    expect(typeof addRes.body.items[0].productId).toBe('number');
    expect(addRes.body.items[0].productId).toBe(productId);
  });

  it('checks out a cart and returns order/order_item with JSON-number ids', async () => {
    const ownerRes = await request(app).post('/auth/register').send({
      fullName: 'Owner',
      email: 'owner2@example.com',
      password: 'secret123',
    });
    const ownerToken = ownerRes.body.token as string;

    await request(app)
      .post('/shops')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ name: 'Boutique 2', category: 'Alimentation' });

    const productRes = await request(app)
      .post('/products')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ name: 'Huile', price: 3000, stock: 10, category: 'Alimentation' });
    const productId = productRes.body.id as number;

    const buyerRes = await request(app).post('/auth/register').send({
      fullName: 'Buyer 2',
      email: 'buyer2@example.com',
      password: 'secret123',
    });
    const buyerToken = buyerRes.body.token as string;

    await request(app)
      .post('/cart/items')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ productId, quantity: 1 });

    const checkoutRes = await request(app)
      .post('/orders/checkout')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ paymentMethod: 'orange_money' });

    expect(checkoutRes.status).toBe(201);

    const { order, items } = checkoutRes.body;
    expect(typeof order.id).toBe('number');
    expect(typeof order.userId).toBe('number');
    expect(checkoutRes.text).toContain(`"id":${order.id}`);
    expect(checkoutRes.text).not.toContain(`"id":"${order.id}"`);

    expect(items.length).toBe(1);
    expect(typeof items[0].id).toBe('number');
    expect(typeof items[0].orderId).toBe('number');
    expect(typeof items[0].productId).toBe('number');
    expect(items[0].orderId).toBe(order.id);
    expect(items[0].productId).toBe(productId);

    const detailRes = await request(app)
      .get(`/orders/${order.id}`)
      .set('Authorization', `Bearer ${buyerToken}`);

    expect(detailRes.status).toBe(200);
    expect(typeof detailRes.body.order.id).toBe('number');
    expect(detailRes.body.isBuyer).toBe(true);
  });
});
