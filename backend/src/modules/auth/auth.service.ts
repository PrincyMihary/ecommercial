import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env';
import { AppError } from '../../errors/AppError';
import {
  findUserByEmail,
  findUserById,
  insertUser,
  UserRow,
} from './auth.repository';

// Cost factor bcrypt "raisonnable" comme demandé par le document maître
// (recommandation 10-12). 12 offre une marge de sécurité correcte sans
// pénaliser excessivement la latence de login sur une exécution locale.
const BCRYPT_COST_FACTOR = 12;

// Reprend exactement le comportement actuel (_minPasswordLength dans
// auth_service.dart) pour préserver l'UX existante.
const MIN_PASSWORD_LENGTH = 6;

const EMAIL_ALREADY_USED_MESSAGE = 'Email déjà utilisé.';
const INVALID_CREDENTIALS_MESSAGE = 'Email ou mot de passe incorrect.';

/** Forme publique d'un utilisateur : jamais de password_hash. */
export interface PublicUser {
  id: number;
  full_name: string;
  email: string;
  phone: string | null;
  created_at: string;
}

export interface RegisterInput {
  fullName: string;
  email: string;
  phone?: string | null;
  password: string;
}

export interface LoginInput {
  email: string;
  password: string;
}

export interface AuthResult {
  user: PublicUser;
  token: string;
}

/**
 * Convertit une ligne SQL en objet public. Les clés sont volontairement
 * en snake_case pour rester directement compatibles avec
 * `User.fromMap` côté Flutter (qui lit `full_name` / `created_at`), afin
 * qu'aucune modification du modèle Dart ne soit nécessaire lors de la
 * future bascule HTTP (voir plan de migration §21).
 */
function toPublicUser(row: UserRow): PublicUser {
  return {
    id: row.id,
    full_name: row.full_name,
    email: row.email,
    phone: row.phone,
    created_at:
      row.created_at instanceof Date
        ? row.created_at.toISOString()
        : String(row.created_at),
  };
}

// Validation volontairement simple (même esprit que
// `_looksLikeEmail` dans auth_service.dart) : présence d'un '@' et d'un
// '.' après, sans regex exhaustive RFC 5322.
function looksLikeEmail(value: string): boolean {
  const at = value.indexOf('@');
  if (at <= 0) return false;
  const dot = value.indexOf('.', at);
  return dot > at + 1 && dot < value.length - 1;
}

function signToken(userId: number): string {
  return jwt.sign({ sub: userId }, env.jwtSecret, {
    expiresIn: env.jwtExpiresIn,
  } as jwt.SignOptions);
}

export async function register(input: RegisterInput): Promise<AuthResult> {
  const trimmedName = input.fullName.trim();
  const normalizedEmail = input.email.trim().toLowerCase();
  const trimmedPhone = input.phone?.trim();
  const password = input.password;

  if (trimmedName.length === 0) {
    throw new AppError(400, 'AUTH_NAME_REQUIRED', 'Le nom est obligatoire.');
  }
  if (!looksLikeEmail(normalizedEmail)) {
    throw new AppError(400, 'AUTH_INVALID_EMAIL', 'Adresse email invalide.');
  }
  if (password.length < MIN_PASSWORD_LENGTH) {
    throw new AppError(
      400,
      'AUTH_PASSWORD_TOO_SHORT',
      `Le mot de passe doit contenir au moins ${MIN_PASSWORD_LENGTH} caractères.`,
    );
  }

  const existing = await findUserByEmail(normalizedEmail);
  if (existing) {
    throw new AppError(409, 'AUTH_EMAIL_ALREADY_USED', EMAIL_ALREADY_USED_MESSAGE);
  }

  const passwordHash = await bcrypt.hash(password, BCRYPT_COST_FACTOR);

  let created: UserRow;
  try {
    created = await insertUser({
      fullName: trimmedName,
      email: normalizedEmail,
      phone: trimmedPhone && trimmedPhone.length > 0 ? trimmedPhone : null,
      passwordHash,
    });
  } catch (err: unknown) {
    // Filet de sécurité contre une course entre la vérification ci-dessus
    // et l'insertion : la contrainte UNIQUE PostgreSQL (code 23505) est
    // l'arbitre final de l'unicité de l'email.
    if (isUniqueViolation(err)) {
      throw new AppError(409, 'AUTH_EMAIL_ALREADY_USED', EMAIL_ALREADY_USED_MESSAGE);
    }
    throw err;
  }

  const token = signToken(created.id);
  return { user: toPublicUser(created), token };
}

export async function login(input: LoginInput): Promise<AuthResult> {
  const normalizedEmail = input.email.trim().toLowerCase();
  const password = input.password;

  const row = await findUserByEmail(normalizedEmail);
  if (!row) {
    // Ne jamais révéler si c'est l'email ou le mot de passe qui est en
    // cause (règle explicite, déjà respectée par le comportement actuel).
    throw new AppError(401, 'AUTH_INVALID_CREDENTIALS', INVALID_CREDENTIALS_MESSAGE);
  }

  const passwordMatches = await bcrypt.compare(password, row.password_hash);
  if (!passwordMatches) {
    throw new AppError(401, 'AUTH_INVALID_CREDENTIALS', INVALID_CREDENTIALS_MESSAGE);
  }

  const token = signToken(row.id);
  return { user: toPublicUser(row), token };
}

export async function getCurrentUser(userId: number): Promise<PublicUser> {
  const row = await findUserById(userId);
  if (!row) {
    // Le token est valide mais l'utilisateur n'existe plus (compte
    // supprimé entre l'émission du JWT et cette requête).
    throw new AppError(401, 'AUTH_USER_NOT_FOUND', 'Utilisateur introuvable.');
  }
  return toPublicUser(row);
}

function isUniqueViolation(err: unknown): boolean {
  return (
    typeof err === 'object' &&
    err !== null &&
    'code' in err &&
    (err as { code?: unknown }).code === '23505'
  );
}
