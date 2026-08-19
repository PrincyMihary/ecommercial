import { pool } from '../../db/pool';
import { PermissionException, ShopException } from '../../errors';

export interface ShopRow {
  id: number;
  owner_id: number | null;
  name: string;
  description: string | null;
  address: string | null;
  latitude: number | null;
  longitude: number | null;
  google_place_id: string | null;
  category: string;
  image: string | null;
  created_at: string;
  updated_at: string;
}

export interface ShopInput {
  name: string;
  description?: string | null;
  address?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  googlePlaceId?: string | null;
  category: string;
  image?: string | null;
}

export async function getAllShops(): Promise<ShopRow[]> {
  const { rows } = await pool.query<ShopRow>('SELECT * FROM shops ORDER BY name ASC');
  return rows;
}

export async function getShopById(id: number): Promise<ShopRow | null> {
  const { rows } = await pool.query<ShopRow>('SELECT * FROM shops WHERE id = $1 LIMIT 1', [id]);
  return rows[0] ?? null;
}

export async function getShopByOwnerId(ownerId: number): Promise<ShopRow | null> {
  const { rows } = await pool.query<ShopRow>('SELECT * FROM shops WHERE owner_id = $1 LIMIT 1', [ownerId]);
  return rows[0] ?? null;
}

export async function createShopForOwner(ownerId: number, data: ShopInput): Promise<ShopRow> {
  try {
    const { rows } = await pool.query<ShopRow>(
      `INSERT INTO shops (owner_id, name, description, address, latitude, longitude, google_place_id, category, image)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [
        ownerId,
        data.name,
        data.description ?? null,
        data.address ?? null,
        data.latitude ?? null,
        data.longitude ?? null,
        data.googlePlaceId ?? null,
        data.category,
        data.image ?? null,
      ],
    );
    return rows[0];
  } catch (err) {
    const pgErr = err as { code?: string };
    if (pgErr.code === '23505') {
      // Reproduit ShopException('Vous possédez déjà un commerce.'),
      // levée côté SQLite sur DatabaseException.isUniqueConstraintError()
      // (contrainte UNIQUE sur owner_id) — voir migration_plan.md §10.
      throw new ShopException('Vous possédez déjà un commerce.');
    }
    throw err;
  }
}

export async function assertShopOwnership(ownerId: number, shopId: number): Promise<ShopRow> {
  const shop = await getShopById(shopId);
  if (!shop || shop.owner_id == null || shop.owner_id !== ownerId) {
    throw new PermissionException('Vous ne pouvez gérer que votre propre commerce.');
  }
  return shop;
}

export async function updateShop(id: number, data: Partial<ShopInput>): Promise<ShopRow> {
  const { rows } = await pool.query<ShopRow>(
    `UPDATE shops SET
       name = COALESCE($2, name),
       description = COALESCE($3, description),
       address = COALESCE($4, address),
       latitude = COALESCE($5, latitude),
       longitude = COALESCE($6, longitude),
       google_place_id = COALESCE($7, google_place_id),
       category = COALESCE($8, category),
       image = COALESCE($9, image)
     WHERE id = $1
     RETURNING *`,
    [
      id,
      data.name ?? null,
      data.description ?? null,
      data.address ?? null,
      data.latitude ?? null,
      data.longitude ?? null,
      data.googlePlaceId ?? null,
      data.category ?? null,
      data.image ?? null,
    ],
  );
  return rows[0];
}

export async function deleteShopById(id: number): Promise<void> {
  await pool.query('DELETE FROM products WHERE shop_id = $1', [id]);
  await pool.query('DELETE FROM shops WHERE id = $1', [id]);
}
