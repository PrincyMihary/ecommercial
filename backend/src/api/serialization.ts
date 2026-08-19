import { Response } from 'express';

export type ApiIdPath = string;

const MAX_SAFE_BIGINT = BigInt(Number.MAX_SAFE_INTEGER);
const MIN_SAFE_BIGINT = BigInt(Number.MIN_SAFE_INTEGER);

/**
 * Converts only explicitly declared PostgreSQL BIGINT/BIGSERIAL ID fields
 * to JSON-safe JavaScript numbers.
 *
 * Path syntax:
 *   - `user.id` targets a nested property.
 *   - `items[].id` targets `id` on every element of an array.
 *
 * Numeric strings elsewhere in the response are never touched.
 * A BIGINT outside JavaScript's safe integer range causes an error instead
 * of being rounded and silently corrupting an identifier.
 */
export function serializeApiResponse<T>(
  body: T,
  idPaths: readonly ApiIdPath[],
): T {
  const root = cloneForSerialization(body);
  for (const path of idPaths) {
    convertAtPath(root, parsePath(path), path);
  }
  return root;
}

/**
 * Central HTTP helper used by controllers. Future modules should use this
 * helper rather than calling `Number(row.id)` in repositories/services.
 */
export function sendApiJson<T>(
  res: Response,
  statusCode: number,
  body: T,
  idPaths: readonly ApiIdPath[],
): void {
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

type PathSegment =
  | { kind: 'property'; name: string }
  | { kind: 'arrayProperty'; name: string };

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

function convertAtPath(
  root: any,
  segments: PathSegment[],
  originalPath: string,
): void {
  visit(root, 0, originalPath, segments);
}

function visit(
  current: any,
  index: number,
  originalPath: string,
  segments: PathSegment[],
): void {
  if (current === null || current === undefined) return;

  const segment = segments[index];
  if (!segment) return;

  if (segment.kind === 'property') {
    if (index === segments.length - 1) {
      if (Object.prototype.hasOwnProperty.call(current, segment.name)) {
        current[segment.name] = toSafeJsonInteger(
          current[segment.name],
          originalPath,
        );
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
      collection[i] = toSafeJsonInteger(collection[i], `${originalPath}[${i}]`);
    }
    return;
  }

  for (const item of collection) {
    visit(item, index + 1, originalPath, segments);
  }
}

function toSafeJsonInteger(value: unknown, path: string): number | null | undefined {
  if (value === null || value === undefined) return value as null | undefined;

  if (typeof value === 'number') {
    if (!Number.isSafeInteger(value)) {
      throw new Error(
        `API ID "${path}" is outside JavaScript's safe integer range.`,
      );
    }
    return value;
  }

  let bigintValue: bigint;
  if (typeof value === 'bigint') {
    bigintValue = value;
  } else if (typeof value === 'string' && /^-?\d+$/.test(value)) {
    bigintValue = BigInt(value);
  } else {
    throw new Error(`API ID "${path}" is not a valid integer value.`);
  }

  if (bigintValue > MAX_SAFE_BIGINT || bigintValue < MIN_SAFE_BIGINT) {
    throw new Error(
      `API ID "${path}" is outside JavaScript's safe integer range.`,
    );
  }

  return Number(bigintValue);
}
