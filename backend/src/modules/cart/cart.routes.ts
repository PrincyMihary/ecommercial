import { Router } from 'express';
import { asyncHandler } from '../../middleware/errorHandler';
import { requireAuth } from '../../middleware/requireAuth';
import { addItem, clear, getCart, getCartCount, removeItem, updateItem } from './cart.controller';

export const cartRouter = Router();
cartRouter.use(requireAuth);

cartRouter.get('/', asyncHandler(getCart));
cartRouter.get('/count', asyncHandler(getCartCount));
cartRouter.post('/items', asyncHandler(addItem));
cartRouter.put('/items/:productId', asyncHandler(updateItem));
cartRouter.delete('/items/:productId', asyncHandler(removeItem));
cartRouter.delete('/', asyncHandler(clear));
