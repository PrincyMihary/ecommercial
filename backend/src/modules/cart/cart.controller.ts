import { Request, Response } from 'express';
import { toSafeApiId } from '../../api/serialization';
import { ValidationException } from '../../errors';
import {
  addCartItem,
  clearCart,
  getCartItemCount,
  getCartItems,
  removeCartItem,
  updateCartItemQuantity,
} from './cart.repository';

function toDto(row: { product_id: number; product_name: string; price: string; image: string | null; stock: number; quantity: number }) {
  return {
    productId: toSafeApiId(row.product_id, 'cart_item.productId'),
    productName: row.product_name,
    price: Number(row.price),
    image: row.image,
    stock: row.stock,
    quantity: row.quantity,
  };
}

export async function getCart(req: Request, res: Response) {
  const items = await getCartItems(req.user!.id);
  res.json(items.map(toDto));
}

export async function getCartCount(req: Request, res: Response) {
  const count = await getCartItemCount(req.user!.id);
  res.json({ count });
}

export async function addItem(req: Request, res: Response) {
  const productId = Number(req.body?.productId);
  const quantity = Number(req.body?.quantity ?? 1);
  if (!Number.isInteger(productId) || productId <= 0) {
    throw new ValidationException('productId invalide.');
  }
  const added = await addCartItem(req.user!.id, productId, quantity);
  const items = await getCartItems(req.user!.id);
  res.status(201).json({ added, items: items.map(toDto) });
}

export async function updateItem(req: Request, res: Response) {
  const productId = Number(req.params.productId);
  const quantity = Number(req.body?.quantity);
  if (!Number.isInteger(quantity)) {
    throw new ValidationException('quantity invalide.');
  }
  await updateCartItemQuantity(req.user!.id, productId, quantity);
  const items = await getCartItems(req.user!.id);
  res.json(items.map(toDto));
}

export async function removeItem(req: Request, res: Response) {
  const productId = Number(req.params.productId);
  await removeCartItem(req.user!.id, productId);
  const items = await getCartItems(req.user!.id);
  res.json(items.map(toDto));
}

export async function clear(req: Request, res: Response) {
  await clearCart(req.user!.id);
  res.status(204).send();
}
