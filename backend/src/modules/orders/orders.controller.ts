import { Request, Response } from 'express';
import { OrderException, PermissionException, ValidationException } from '../../errors';
import { getShopByOwnerId } from '../shops/shops.repository';
import { availableTransitions } from './order-status';
import { orderDto, orderItemDto as itemDto } from './orders.mapper';
import {
  advanceOrderStatusForShop,
  createOrderCheckout,
  getOrderById,
  getOrderItems,
  getOrderItemsForShop,
  getOrdersByUser,
  getOrdersForShopOwner,
  refundOrderForShop,
} from './orders.repository';

const VALID_PAYMENT_METHODS = ['orange_money', 'yas', 'visa'];

/**
 * POST /orders/checkout — équivalent createOrder + markOrderAsPaid
 * fusionnés (voir migration_plan.md §12/§13). Le paiement mocké réussit
 * toujours (MockPaymentService côté Flutter), donc la commande passe
 * directement à `paid` dans la même transaction.
 */
export async function checkout(req: Request, res: Response) {
  const paymentMethod = String(req.body?.paymentMethod ?? payment_method ?? paymentmethod ?? '');
  if (!VALID_PAYMENT_METHODS.includes(paymentMethod)) {
    throw new ValidationException('Moyen de paiement invalide.');
  }

  const orderId = await createOrderCheckout(req.user!.id, paymentMethod);
  const order = await getOrderById(orderId);
  const items = await getOrderItems(orderId);
  res.status(201).json({ order: orderDto(order!), items: items.map(itemDto) });
}

export async function myOrders(req: Request, res: Response) {
  const orders = await getOrdersByUser(req.user!.id);
  res.json(orders.map(orderDto));
}

export async function ordersForMyShop(req: Request, res: Response) {
  const shop = await getShopByOwnerId(req.user!.id);
  if (!shop) return res.json([]);
  const orders = await getOrdersForShopOwner(shop.id);
  res.json(orders.map(orderDto));
}

/**
 * GET /orders/:id — durcissement décrit en migration_plan.md §10 :
 * la règle d'accès (acheteur voit tout ; commerçant ne voit que ses
 * propres lignes ; ni l'un ni l'autre = rien) était calculée côté
 * client dans order_detail_screen.dart. Elle est désormais appliquée
 * ICI, avant l'envoi des données.
 */
export async function getOrderDetail(req: Request, res: Response) {
  const id = Number(req.params.id);
  const order = await getOrderById(id);
  if (!order) throw new OrderException('Commande introuvable.');

  const userId = req.user!.id;
  const isBuyer = order.user_id === userId;

  const shop = await getShopByOwnerId(userId);
  const merchantItems = shop ? await getOrderItemsForShop(id, shop.id) : [];
  const isMerchantHere = merchantItems.length > 0;

  if (!isBuyer && !isMerchantHere) {
    throw new PermissionException("Vous n'avez pas accès à cette commande.");
  }

  const items = isBuyer ? await getOrderItems(id) : merchantItems;

  res.json({
    order: orderDto(order),
    items: items.map(itemDto),
    isBuyer,
    isMerchant: isMerchantHere,
  });
}

export async function orderItemsForShop(req: Request, res: Response) {
  const id = Number(req.params.id);
  const shop = await getShopByOwnerId(req.user!.id);
  if (!shop) throw new PermissionException('Vous ne possédez pas de commerce.');
  const items = await getOrderItemsForShop(id, shop.id);
  res.json(items.map(itemDto));
}

export async function advanceStatus(req: Request, res: Response) {
  const id = Number(req.params.id);
  const newStatus = String(req.body?.status ?? '');
  if (newStatus.length === 0) {
    throw new ValidationException('Le nouveau statut est obligatoire.');
  }
  await advanceOrderStatusForShop(req.user!.id, id, newStatus);
  const order = await getOrderById(id);
  res.json({ order: orderDto(order!), availableTransitions: availableTransitions(order!.status) });
}

export async function refund(req: Request, res: Response) {
  const id = Number(req.params.id);
  await refundOrderForShop(req.user!.id, id);
  const order = await getOrderById(id);
  res.json(orderDto(order!));
}

// NOTE : les endpoints GET /shops/:id/blocking-orders et
// GET /products/:id/blocking-orders (voir migration_plan.md §9) sont
// exposés depuis les modules shops/products respectifs (plus naturel
// pour leurs routers), mais consomment les mêmes fonctions du
// orders.repository et le même orderDto que ce module.
