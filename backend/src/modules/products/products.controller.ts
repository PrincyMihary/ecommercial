import { Request, Response } from 'express';
import { toSafeApiId } from '../../api/serialization';
import { BlockingOrdersException, NotFoundException, ValidationException } from '../../errors';
import { orderDto } from '../orders/orders.mapper';
import { getBlockingOrdersForProduct } from '../orders/orders.repository';
import {
  assertProductOwnership,
  createProductForOwner,
  deleteProductById,
  getAllProducts,
  getProductById,
  getProductsByOwner,
  getProductsByShop,
  ProductInput,
  ProductRow,
  searchProducts,
  updateProductForOwner,
} from './products.repository';

function toDto(product: ProductRow | null) {
  if (!product) return null;
  return {
    id: toSafeApiId(product.id, 'product.id'),
    shopId: toSafeApiId(product.shop_id, 'product.shopId'),
    name: product.name,
    description: product.description,
    price: Number(product.price),
    stock: product.stock,
    category: product.category,
    image: product.image,
    model3d: product.model_3d,
    createdAt: product.created_at,
    updatedAt: product.updated_at,
  };
}

function parseProductInput(body: any, partial: boolean): Partial<ProductInput> {
  const input: Partial<ProductInput> = {};

  if (!partial || body.name !== undefined) {
    const name = String(body.name ?? '').trim();
    if (name.length === 0) throw new ValidationException('Le nom du produit est obligatoire.');
    input.name = name;
  }
  if (!partial || body.price !== undefined) {
    const price = Number(body.price);
    if (!Number.isFinite(price) || price < 0) {
      throw new ValidationException('Le prix doit être un nombre positif.');
    }
    input.price = price;
  }
  if (!partial || body.stock !== undefined) {
    const stock = Number(body.stock ?? 0);
    if (!Number.isInteger(stock) || stock < 0) {
      throw new ValidationException('Le stock doit être un entier positif ou nul.');
    }
    input.stock = stock;
  }
  if (body.description !== undefined) input.description = body.description;
  if (body.category !== undefined) input.category = body.category;
  if (body.image !== undefined) input.image = body.image;
  if (body.model3d !== undefined) input.model3d = body.model3d;

  return input;
}

export async function listProducts(_req: Request, res: Response) {
  const products = await getAllProducts();
  res.json(products.map(toDto));
}

export async function listProductsByShop(req: Request, res: Response) {
  const shopId = Number(req.params.shopId);
  const products = await getProductsByShop(shopId);
  res.json(products.map(toDto));
}

export async function search(req: Request, res: Response) {
  const q = typeof req.query.q === 'string' ? req.query.q : undefined;
  const category = typeof req.query.category === 'string' ? req.query.category : undefined;
  const products = await searchProducts(q, category);
  res.json(products.map(toDto));
}

export async function myProducts(req: Request, res: Response) {
  const products = await getProductsByOwner(req.user!.id);
  res.json(products.map(toDto));
}

export async function getProduct(req: Request, res: Response) {
  const id = Number(req.params.id);
  const product = await getProductById(id);
  if (!product) throw new NotFoundException('Produit introuvable.');
  res.json(toDto(product));
}

export async function createProduct(req: Request, res: Response) {
  const input = parseProductInput(req.body ?? {}, false) as ProductInput;
  const product = await createProductForOwner(req.user!.id, input);
  res.status(201).json(toDto(product));
}

export async function updateProductHandler(req: Request, res: Response) {
  const id = Number(req.params.id);
  const input = parseProductInput(req.body ?? {}, true);
  const product = await updateProductForOwner(req.user!.id, id, input);
  res.json(toDto(product));
}

export async function deleteProductHandler(req: Request, res: Response) {
  const id = Number(req.params.id);
  await assertProductOwnership(req.user!.id, id);

  const blocking = await getBlockingOrdersForProduct(id);
  if (blocking.length > 0) {
    throw new BlockingOrdersException(
      `Ce produit apparaît dans ${blocking.length} commande(s) non finalisée(s).`,
      blocking.map(orderDto),
    );
  }

  await deleteProductById(id);
  res.status(204).send();
}

export async function blockingOrdersForProduct(req: Request, res: Response) {
  const id = Number(req.params.id);
  const blocking = await getBlockingOrdersForProduct(id);
  res.json(blocking.map(orderDto));
}
