import { pool } from '../../db/pool';

/**
 * Ligne brute de la table `users` (schema.sql d'Agent 1). Contient
 * `password_hash` : ne JAMAIS renvoyer ce type directement dans une
 * réponse HTTP — voir `toPublicUser` dans auth.service.ts.
 */
export interface UserRow {
  id: number;
  full_name: string;
  email: string;
  phone: string | null;
  password_hash: string;
  created_at: Date;
}

export interface CreateUserInput {
  fullName: string;
  email: string;
  phone: string | null;
  passwordHash: string;
}

/**
 * Recherche un utilisateur par email (déjà normalisé en minuscules par
 * l'appelant — la colonne `email` du schema.sql d'Agent 1 est un TEXT
 * UNIQUE classique, pas CITEXT, donc la normalisation applicative est
 * nécessaire ici pour un matching insensible à la casse cohérent avec
 * `auth_service.dart` actuel).
 */
export async function findUserByEmail(email: string): Promise<UserRow | null> {
  const result = await pool.query<UserRow>(
    'SELECT id, full_name, email, phone, password_hash, created_at FROM users WHERE email = $1',
    [email],
  );
  return result.rows[0] ?? null;
}

export async function findUserById(id: number): Promise<UserRow | null> {
  const result = await pool.query<UserRow>(
    'SELECT id, full_name, email, phone, password_hash, created_at FROM users WHERE id = $1',
    [id],
  );
  return result.rows[0] ?? null;
}

/**
 * Insère un nouvel utilisateur. SQL paramétré uniquement (règle de
 * sécurité). La contrainte UNIQUE sur `email` reste la garantie
 * ultime d'unicité (protection contre une course entre la vérification
 * applicative et l'insertion) ; l'appelant (auth.service.ts) doit
 * catcher le code d'erreur PostgreSQL `23505` en secours.
 */
export async function insertUser(input: CreateUserInput): Promise<UserRow> {
  const result = await pool.query<UserRow>(
    `INSERT INTO users (full_name, email, phone, password_hash)
     VALUES ($1, $2, $3, $4)
     RETURNING id, full_name, email, phone, password_hash, created_at`,
    [input.fullName, input.email, input.phone, input.passwordHash],
  );
  return result.rows[0];
}
