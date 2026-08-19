import { pool } from '../../db/pool';
import { AuthException } from '../../errors';
import { toSafeApiId } from '../../api/serialization';

export interface UserRow {
  id: number;
  full_name: string;
  email: string;
  phone: string | null;
  password_hash: string;
  created_at: string;
}

export async function findUserByEmail(email: string): Promise<UserRow | null> {
  const { rows } = await pool.query<UserRow>('SELECT * FROM users WHERE email = $1 LIMIT 1', [email]);
  return rows[0] ?? null;
}

export async function findUserById(id: number): Promise<UserRow | null> {
  const { rows } = await pool.query<UserRow>('SELECT * FROM users WHERE id = $1 LIMIT 1', [id]);
  return rows[0] ?? null;
}

export async function insertUser(data: {
  fullName: string;
  email: string;
  phone: string | null;
  passwordHash: string;
}): Promise<UserRow> {
  try {
    const { rows } = await pool.query<UserRow>(
      `INSERT INTO users (full_name, email, phone, password_hash)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [data.fullName, data.email, data.phone, data.passwordHash],
    );
    return rows[0];
  } catch (err) {
    const pgErr = err as { code?: string };
    if (pgErr.code === '23505') {
      // Reproduit exactement le message de DatabaseHelper.createUser
      // (contrainte UNIQUE sur email, cf. migration_plan.md §10).
      throw new AuthException('Cet email est déjà utilisé.');
    }
    throw err;
  }
}

/** Représentation publique d'un utilisateur : jamais password_hash. */
export function toPublicUser(row: UserRow) {
  return {
    id: toSafeApiId(row.id, 'user.id'),
    fullName: row.full_name,
    email: row.email,
    phone: row.phone,
    createdAt: row.created_at,
  };
}
