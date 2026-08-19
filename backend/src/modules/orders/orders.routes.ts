import { Router } from 'express';
import { asyncHandler } from '../../middleware/errorHandler';
import { requireAuth } from '../../middleware/requireAuth';
import {
  advanceStatus,
  checkout,
  getOrderDetail,
  myOrders,
  orderItemsForShop,
  ordersForMyShop,
  refund,
} from './orders.controller';

export const ordersRouter = Router();
ordersRouter.use(requireAuth);

ordersRouter.post('/checkout', asyncHandler(checkout));
ordersRouter.get('/', asyncHandler(myOrders));
ordersRouter.get('/shop', asyncHandler(ordersForMyShop));
ordersRouter.get('/:id/items/shop', asyncHandler(orderItemsForShop));
ordersRouter.get('/:id', asyncHandler(getOrderDetail));
ordersRouter.patch('/:id/status', asyncHandler(advanceStatus));
ordersRouter.post('/:id/refund', asyncHandler(refund));
