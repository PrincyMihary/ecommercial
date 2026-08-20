import bcrypt from 'bcryptjs';
import { Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env';
import { AuthException } from '../../errors';
import { findUserByEmail, findUserById, insertUser, toPublicUser } from './auth.repository';

const MIN_PASSWORD_LENGTH = 6;
const BCRYPT_COST = 11;

/**
 * Validation "email de forme plausible", reprise à l'identique de
 * AuthService._looksLikeEmail (Dart) : présence d'un '@' suivi d'un
 * '.' plus loin, sans regex RFC 5322 exhaustive.
 */
function looksLikeEmail(value: string): boolean {
  const at = value.indexOf('@');
  if (at <= 0) return false;
  const dot = value.indexOf('.', at);
  return dot > at + 1 && dot < value.length - 1;
}

function issueToken(userId: number, email: string): string {
  return jwt.sign({ sub: userId, email }, env.jwt.secret, {
    expiresIn: env.jwt.expiresIn,
  } as jwt.SignOptions);
}

export async function register(req: Request, res: Response) {
  const body = req.body ?? {};
  const fullName = String(body.fullName ?? body.fullname ??  body.full_name ?? '').trim();
  const normalizedEmail = String(body.email ?? '').trim().toLowerCase();
  const rawPhone = body.phone === undefined || body.phone === null ? '' : String(body.phone).trim();
  const password = String(body.password ?? '');

  if (fullName.length === 0) {
    throw new AuthException('Le nom est obligatoire.');
  }
  if (!looksLikeEmail(normalizedEmail)) {
    throw new AuthException('Adresse email invalide.');
  }
  if (password.length < MIN_PASSWORD_LENGTH) {
    throw new AuthException(`Le mot de passe doit contenir au moins ${MIN_PASSWORD_LENGTH} caractères.`);
  }

  const passwordHash = await bcrypt.hash(password, BCRYPT_COST);

  const user = await insertUser({
    fullName,
    email: normalizedEmail,
    phone: rawPhone.length === 0 ? null : rawPhone,
    passwordHash,
  });

  const token = issueToken(user.id, user.email);
  res.status(201).json({ token, user: toPublicUser(user) });
}

export async function login(req: Request, res: Response) {
  const body = req.body ?? {};
  const normalizedEmail = String(body.email ?? '').trim().toLowerCase();
  const password = String(body.password ?? '');

  const user = await findUserByEmail(normalizedEmail);
  if (!user) {
    // Message volontairement générique (ne révèle pas si c'est l'email
    // ou le mot de passe qui est en cause), voir auth_service.dart.
    throw new AuthException('Email ou mot de passe incorrect.');
  }

  const matches = await bcrypt.compare(password, user.password_hash);
  if (!matches) {
    throw new AuthException('Email ou mot de passe incorrect.');
  }

  const token = issueToken(user.id, user.email);
  res.json({ token, user: toPublicUser(user) });
}

export async function me(req: Request, res: Response) {
  const userId = req.user!.id;
  const user = await findUserById(userId);
  if (!user) {
    throw new AuthException('Utilisateur introuvable.');
  }
  res.json(toPublicUser(user));
}
