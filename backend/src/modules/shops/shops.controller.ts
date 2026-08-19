import { Request, Response } from 'express';
import { toSafeApiId } from '../../api/serialization';
import { BlockingOrdersException, NotFoundException, ValidationException } from '../../errors';
import { orderDto } from '../orders/orders.mapper';
import { getBlockingOrdersForShop } from '../orders/orders.repository';
import {
  assertShopOwnership,
  createShopForOwner,
  deleteShopById,
  getAllShops,
  getShopByOwnerId,
  getShopById,
  ShopInput,
  updateShop,
} from './shops.repository';

function toDto(shop: Awaited<ReturnType<typeof getShopById>>) {
  if (!shop) return null;
  return {
    id: toSafeApiId(shop.id, 'shop.id'),
    ownerId: toSafeApiId(shop.owner_id, 'shop.ownerId'),
    name: shop.name,
    description: shop.description,
    address: shop.address,
    latitude: shop.latitude,
    longitude: shop.longitude,
    googlePlaceId: shop.google_place_id,
    category: shop.category,
    image: shop.image,
    createdAt: shop.created_at,
    updatedAt: shop.updated_at,
  };
}

function parseShopInput(body: any): ShopInput {
  const name = String(body.name ?? '').trim();
  const category = String(body.category ?? '').trim();
  if (name.length === 0) {
    throw new ValidationException('Le nom du commerce est obligatoire.');
  }
  if (category.length === 0) {
    throw new ValidationException('La catégorie du commerce est obligatoire.');
  }
  return {
    name,
    category,
    description: body.description ?? null,
    address: body.address ?? null,
    latitude: body.latitude ?? null,
    longitude: body.longitude ?? null,
    googlePlaceId: body.googlePlaceId ?? null,
    image: body.image ?? null,
  };
}

export async function listShops(_req: Request, res: Response) {
  const shops = await getAllShops();
  res.json(shops.map(toDto));
}

export async function getShop(req: Request, res: Response) {
  const id = Number(req.params.id);
  const shop = await getShopById(id);
  if (!shop) throw new NotFoundException('Commerce introuvable.');
  res.json(toDto(shop));
}

export async function getMyShop(req: Request, res: Response) {
  const shop = await getShopByOwnerId(req.user!.id);
  if (!shop) throw new NotFoundException("Vous n'avez pas encore de commerce.");
  res.json(toDto(shop));
}

export async function createShop(req: Request, res: Response) {
  const input = parseShopInput(req.body ?? {});
  const shop = await createShopForOwner(req.user!.id, input);
  res.status(201).json(toDto(shop));
}

export async function updateShopHandler(req: Request, res: Response) {
  const id = Number(req.params.id);
  await assertShopOwnership(req.user!.id, id);

  const body = req.body ?? {};
  const shop = await updateShop(id, {
    name: body.name !== undefined ? String(body.name).trim() : undefined,
    category: body.category !== undefined ? String(body.category).trim() : undefined,
    description: body.description,
    address: body.address,
    latitude: body.latitude,
    longitude: body.longitude,
    googlePlaceId: body.googlePlaceId,
    image: body.image,
  });
  res.json(toDto(shop));
}

export async function deleteShopHandler(req: Request, res: Response) {
  const id = Number(req.params.id);
  await assertShopOwnership(req.user!.id, id);

  const blocking = await getBlockingOrdersForShop(id);
  if (blocking.length > 0) {
    throw new BlockingOrdersException(
      `Ce commerce est concerné par ${blocking.length} commande(s) non finalisée(s).`,
      blocking.map(orderDto),
    );
  }

  await deleteShopById(id);
  res.status(204).send();
}

export async function blockingOrdersForShop(req: Request, res: Response) {
  const id = Number(req.params.id);
  const blocking = await getBlockingOrdersForShop(id);
  res.json(blocking.map(orderDto));
}
