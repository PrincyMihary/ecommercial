import { Router } from 'express';
import { asyncHandler } from '../../middleware/errorHandler';
import { requireAuth } from '../../middleware/requireAuth';
import { listProductsByShop } from '../products/products.controller';
import {
  blockingOrdersForShop,
  createShop,
  deleteShopHandler,
  getMyShop,
  getShop,
  listShops,
  updateShopHandler,
} from './shops.controller';

export const shopsRouter = Router();

shopsRouter.get('/', asyncHandler(listShops));
shopsRouter.get('/me', requireAuth, asyncHandler(getMyShop));
shopsRouter.get('/:id/blocking-orders', asyncHandler(blockingOrdersForShop));
shopsRouter.get(
  '/:shopId/products',
  asyncHandler((req, res) => listProductsByShop(req, res)),
);
shopsRouter.get('/:id', asyncHandler(getShop));
shopsRouter.post('/', requireAuth, asyncHandler(createShop));
shopsRouter.put('/:id', requireAuth, asyncHandler(updateShopHandler));
shopsRouter.delete('/:id', requireAuth, asyncHandler(deleteShopHandler));
