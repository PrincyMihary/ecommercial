import { pool } from '../../db/pool';
import { PermissionException, ShopException } from '../../errors';
import { getShopByOwnerId } from '../shops/shops.repository';

export interface ProductRow {
  id: number;
  shop_id: number;
  name: string;
  description: string | null;
  price: string;
  stock: number;
  category: string | null;
  image: string | null;
  model_3d: string | null;
  created_at: string;
  updated_at: string;
}

export interface ProductInput {
  name: string;
  description?: string | null;
  price: number;
  stock: number;
  category?: string | null;
  image?: string | null;
  model3d?: string | null;
}

export async function getAllProducts(): Promise<ProductRow[]> {
  const { rows } = await pool.query<ProductRow>('SELECT * FROM products ORDER BY id DESC');
  return rows;
}

export async function getProductsByShop(shopId: number): Promise<ProductRow[]> {
  const { rows } = await pool.query<ProductRow>(
    'SELECT * FROM products WHERE shop_id = $1 ORDER BY name ASC',
    [shopId],
  );
  return rows;
}

export async function getProductById(id: number): Promise<ProductRow | null> {
  const { rows } = await pool.query<ProductRow>('SELECT * FROM products WHERE id = $1 LIMIT 1', [id]);
  return rows[0] ?? null;
}

/**
 * Transposition de DatabaseHelper.searchProducts : recherche texte sur
 * nom/description/catégorie produit + nom du commerce, filtre catégorie
 * optionnel ('Tout' = pas de filtre).
 */
export async function searchProducts(query?: string, category?: string): Promise<ProductRow[]> {
  const conditions: string[] = [];
  const args: unknown[] = [];

  const trimmedQuery = (query ?? '').trim();
  if (trimmedQuery.length > 0) {
    const likePattern = `%${trimmedQuery}%`;
    args.push(likePattern, likePattern, likePattern, likePattern);
    conditions.push(
      `(products.name ILIKE $${args.length - 3} OR products.description ILIKE $${args.length - 2} OR products.category ILIKE $${args.length - 1} OR shops.name ILIKE $${args.length})`,
    );
  }

  const trimmedCategory = (category ?? '').trim();
  if (trimmedCategory.length > 0 && trimmedCategory !== 'Tout') {
    args.push(trimmedCategory);
    conditions.push(`products.category = $${args.length}`);
  }

  const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const { rows } = await pool.query<ProductRow>(
    `SELECT products.*
     FROM products
     INNER JOIN shops ON products.shop_id = shops.id
     ${whereClause}
     ORDER BY products.name ASC`,
    args,
  );
  return rows;
}

export async function getProductsByOwner(ownerId: number): Promise<ProductRow[]> {
  const shop = await getShopByOwnerId(ownerId);
  if (!shop) return [];
  return getProductsByShop(shop.id);
}

export async function createProductForOwner(ownerId: number, data: ProductInput): Promise<ProductRow> {
  const shop = await getShopByOwnerId(ownerId);
  if (!shop) {
    throw new ShopException("Vous devez d'abord créer votre commerce avant d'ajouter un produit.");
  }
  const { rows } = await pool.query<ProductRow>(
    `INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [
      shop.id,
      data.name,
      data.description ?? null,
      data.price,
      data.stock,
      data.category ?? null,
      data.image ?? null,
      data.model3d ?? null,
    ],
  );
  return rows[0];
}

export async function assertProductOwnership(ownerId: number, productId: number): Promise<ProductRow> {
  const product = await getProductById(productId);
  if (!product) {
    throw new PermissionException('Produit introuvable.');
  }
  const shop = await getShopByOwnerId(ownerId);
  if (!shop || shop.id !== product.shop_id) {
    throw new PermissionException('Vous ne pouvez gérer que votre propre commerce.');
  }
  return product;
}

export async function updateProductForOwner(
  ownerId: number,
  productId: number,
  data: Partial<ProductInput>,
): Promise<ProductRow> {
  await assertProductOwnership(ownerId, productId);
  const { rows } = await pool.query<ProductRow>(
    `UPDATE products SET
       name = COALESCE($2, name),
       description = COALESCE($3, description),
       price = COALESCE($4, price),
       stock = COALESCE($5, stock),
       category = COALESCE($6, category),
       image = COALESCE($7, image),
       model_3d = COALESCE($8, model_3d)
     WHERE id = $1
     RETURNING *`,
    [
      productId,
      data.name ?? null,
      data.description ?? null,
      data.price ?? null,
      data.stock ?? null,
      data.category ?? null,
      data.image ?? null,
      data.model3d ?? null,
    ],
  );
  return rows[0];
}

export async function deleteProductById(id: number): Promise<void> {
  await pool.query('DELETE FROM products WHERE id = $1', [id]);
}
