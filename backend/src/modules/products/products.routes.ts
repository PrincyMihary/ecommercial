import { Router } from 'express';
import { asyncHandler } from '../../middleware/errorHandler';
import { requireAuth } from '../../middleware/requireAuth';
import {
  blockingOrdersForProduct,
  createProduct,
  deleteProductHandler,
  getProduct,
  listProducts,
  myProducts,
  search,
  updateProductHandler,
} from './products.controller';

export const productsRouter = Router();

productsRouter.get('/', asyncHandler(listProducts));
productsRouter.get('/search', asyncHandler(search));
productsRouter.get('/mine', requireAuth, asyncHandler(myProducts));
productsRouter.get('/:id/blocking-orders', asyncHandler(blockingOrdersForProduct));
productsRouter.get('/:id', asyncHandler(getProduct));
productsRouter.post('/', requireAuth, asyncHandler(createProduct));
productsRouter.put('/:id', requireAuth, asyncHandler(updateProductHandler));
productsRouter.delete('/:id', requireAuth, asyncHandler(deleteProductHandler));
