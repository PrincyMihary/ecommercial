/**
 * Exceptions métier — transposition directe des 5 exceptions définies
 * dans lib/database/database_helper.dart et lib/services/auth_service.dart
 * (voir migration_plan.md §16).
 *
 * Les messages sont volontairement identiques à ceux déjà écrits côté
 * Flutter, pour que les futurs écrans continuent d'afficher le même
 * texte sans modification (voir ApiClient, §16).
 */

export class AuthException extends Error {
  readonly code = 'AUTH_ERROR';
  constructor(message: string) {
    super(message);
    this.name = 'AuthException';
  }
}

export class ShopException extends Error {
  readonly code = 'SHOP_ERROR';
  constructor(message: string) {
    super(message);
    this.name = 'ShopException';
  }
}

export class PermissionException extends Error {
  readonly code = 'PERMISSION_ERROR';
  constructor(message: string) {
    super(message);
    this.name = 'PermissionException';
  }
}

export class OrderException extends Error {
  readonly code = 'ORDER_ERROR';
  constructor(message: string) {
    super(message);
    this.name = 'OrderException';
  }
}

export class BlockingOrdersException extends Error {
  readonly code = 'BLOCKING_ORDERS';
  readonly orders: unknown[];
  constructor(message: string, orders: unknown[]) {
    super(message);
    this.name = 'BlockingOrdersException';
    this.orders = orders;
  }
}

export class NotFoundException extends Error {
  readonly code = 'NOT_FOUND';
  constructor(message: string) {
    super(message);
    this.name = 'NotFoundException';
  }
}

export class ValidationException extends Error {
  readonly code = 'VALIDATION_ERROR';
  constructor(message: string) {
    super(message);
    this.name = 'ValidationException';
  }
}

export class ImageStorageException extends Error {
  readonly code = 'IMAGE_STORAGE_ERROR';
  constructor(message: string) {
    super(message);
    this.name = 'ImageStorageException';
  }
}

export class Model3dStorageException extends Error {
  readonly code = 'MODEL_STORAGE_ERROR';
  constructor(message: string) {
    super(message);
    this.name = 'Model3dStorageException';
  }
}
