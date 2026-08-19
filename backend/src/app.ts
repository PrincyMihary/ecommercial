import cors from 'cors';
import express from 'express';
import path from 'path';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';

import { authRouter, usersRouter } from './modules/auth/auth.routes';
import { shopsRouter } from './modules/shops/shops.routes';
import { productsRouter } from './modules/products/products.routes';
import { cartRouter } from './modules/cart/cart.routes';
import { ordersRouter } from './modules/orders/orders.routes';
import { uploadsRouter } from './modules/uploads/uploads.routes';

export const app = express();

app.use(cors());
app.use(express.json());

// Fichiers uploadés (images, modèles .glb), servis statiquement sous
// /files/... — voir migration_plan.md §14.
app.use('/files', express.static(path.join(__dirname, '..', 'uploads')));

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// AUTH
app.use('/auth', authRouter);
app.use('/users', usersRouter);

// SHOPS
app.use('/shops', shopsRouter);

// PRODUCTS
app.use('/products', productsRouter);

// CART
app.use('/cart', cartRouter);

// ORDERS
app.use('/orders', ordersRouter);

// UPLOADS
app.use('/uploads', uploadsRouter);

app.use(notFoundHandler);
app.use(errorHandler);
