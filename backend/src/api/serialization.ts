/**
 * Convention de sérialisation des identifiants PostgreSQL BIGINT/BIGSERIAL.
 *
 * `pg` renvoie les colonnes BIGINT/BIGSERIAL (OID 20) sous forme de
 * `string` en JavaScript, pour ne jamais perdre de précision au-delà de
 * `Number.MAX_SAFE_INTEGER`. Les modèles Flutter attendent cependant un
 * `number` JSON (`map['id'] as int`) : voir migration_plan.md §6-7.
 *
 * Ce module fournit LA conversion explicite, centralisée et testée à
 * utiliser pour les identifiants exposés par l'API :
 *
 *   - `toSafeApiId(value)`       : convertit UNE valeur (utilisé dans les
 *     DTO/mapper de chaque module — auth, shops, products, orders...).
 *   - `serializeApiResponse` /
 *     `sendApiJson`               : variante « chemins déclarés », utile
 *     pour convertir plusieurs champs (y compris imbriqués/tableaux) sur
 *     un corps de réponse déjà construit, sans toucher aux DTO existants.
 *
 * Dans les deux cas :
 *   - seuls les champs explicitement désignés comme des identifiants
 *     sont convertis (jamais de conversion globale de toutes les
 *     chaînes numériques, ni de tous les BIGINT PostgreSQL) ;
 *   - une valeur hors de la plage entière sûre de JavaScript
 *     (`Number.MAX_SAFE_INTEGER` / `MIN_SAFE_INTEGER`) déclenche une
 *     erreur explicite plutôt qu'une conversion silencieuse avec perte
 *     de précision.
 */

import { Response } from 'express';

export type ApiIdPath = string;

const MAX_SAFE_BIGINT = BigInt(Number.MAX_SAFE_INTEGER);
const MIN_SAFE_BIGINT = BigInt(Number.MIN_SAFE_INTEGER);

/**
 * Convertit une valeur unique représentant un identifiant PostgreSQL
 * BIGINT/BIGSERIAL (typiquement `string` telle que renvoyée par `pg`,
 * parfois déjà `number` ou `bigint`) en `number` JSON-safe.
 *
 * `null`/`undefined` sont renvoyés tels quels (colonnes FK nullable,
 * ex. `shops.owner_id`, `order_items.product_id`).
 *
 * Lève une erreur si la valeur n'est pas un entier valide, ou si elle
 * dépasse la plage entière sûre de JavaScript — jamais de troncature
 * silencieuse.
 */
export function toSafeApiId(value: unknown, fieldName = 'id'): number | null | undefined {
  if (value === null || value === undefined) return value as null | undefined;

  if (typeof value === 'number') {
    if (!Number.isSafeInteger(value)) {
      throw new Error(`API ID "${fieldName}" is outside JavaScript's safe integer range.`);
    }
    return value;
  }

  let bigintValue: bigint;
  if (typeof value === 'bigint') {
    bigintValue = value;
  } else if (typeof value === 'string' && /^-?\d+$/.test(value)) {
    bigintValue = BigInt(value);
  } else {
    throw new Error(`API ID "${fieldName}" is not a valid integer value.`);
  }

  if (bigintValue > MAX_SAFE_BIGINT || bigintValue < MIN_SAFE_BIGINT) {
    throw new Error(`API ID "${fieldName}" is outside JavaScript's safe integer range.`);
  }

  return Number(bigintValue);
}

/**
 * Variante "chemins déclarés" : convertit uniquement les champs
 * explicitement listés dans `idPaths` sur une copie de `body`.
 *
 * Syntaxe des chemins :
 *   - `user.id`      cible une propriété imbriquée ;
 *   - `items[].id`    cible `id` sur chaque élément d'un tableau.
 *
 * Les autres chaînes numériques du corps de réponse (téléphone,
 * référence, code postal...) ne sont jamais touchées.
 */
export function serializeApiResponse<T>(body: T, idPaths: readonly ApiIdPath[]): T {
  const root = cloneForSerialization(body);
  for (const path of idPaths) {
    convertAtPath(root, parsePath(path), path);
  }
  return root;
}

/**
 * Helper HTTP central. À utiliser dans les futurs modules à la place de
 * `Number(row.id)` dispersés dans les contrôleurs/services.
 */
export function sendApiJson<T>(res: Response, statusCode: number, body: T, idPaths: readonly ApiIdPath[]): void {
  res.status(statusCode).json(serializeApiResponse(body, idPaths));
}

function cloneForSerialization(value: unknown): any {
  if (value === null || value === undefined) return value;
  if (value instanceof Date) return value;
  if (Array.isArray(value)) return value.map(cloneForSerialization);
  if (typeof value === 'object') {
    const output: Record<string, unknown> = {};
    for (const [key, child] of Object.entries(value)) {
      output[key] = cloneForSerialization(child);
    }
    return output;
  }
  return value;
}

type PathSegment = { kind: 'property'; name: string } | { kind: 'arrayProperty'; name: string };

function parsePath(path: string): PathSegment[] {
  if (!path.trim()) {
    throw new Error('API ID serialization path must not be empty.');
  }

  return path.split('.').map((segment) => {
    if (segment.endsWith('[]')) {
      const name = segment.slice(0, -2);
      if (!name) throw new Error(`Invalid API ID serialization path: ${path}`);
      return { kind: 'arrayProperty', name };
    }

    if (!segment) throw new Error(`Invalid API ID serialization path: ${path}`);
    return { kind: 'property', name: segment };
  });
}

function convertAtPath(root: any, segments: PathSegment[], originalPath: string): void {
  visit(root, 0, originalPath, segments);
}

function visit(current: any, index: number, originalPath: string, segments: PathSegment[]): void {
  if (current === null || current === undefined) return;

  const segment = segments[index];
  if (!segment) return;

  if (segment.kind === 'property') {
    if (index === segments.length - 1) {
      if (Object.prototype.hasOwnProperty.call(current, segment.name)) {
        current[segment.name] = toSafeApiId(current[segment.name], originalPath);
      }
      return;
    }

    if (Object.prototype.hasOwnProperty.call(current, segment.name)) {
      visit(current[segment.name], index + 1, originalPath, segments);
    }
    return;
  }

  const collection = current[segment.name];
  if (!Array.isArray(collection)) return;

  if (index === segments.length - 1) {
    for (let i = 0; i < collection.length; i += 1) {
      collection[i] = toSafeApiId(collection[i], `${originalPath}[${i}]`);
    }
    return;
  }

  for (const item of collection) {
    visit(item, index + 1, originalPath, segments);
  }
}
