/**
 * Erreur métier générique, portée par un code HTTP et un code d'erreur
 * stable destiné au client (Flutter `ApiClient`).
 *
 * Format de réponse choisi (voir contradiction signalée entre le document
 * de mission et le plan de migration §16) : JSON PLAT au niveau racine,
 * conforme au plan de migration :
 *
 *   { "code": "AUTH_INVALID_CREDENTIALS", "message": "...", ...extra }
 *
 * `extra` permet d'ajouter des champs additionnels (ex. `orders` pour
 * `BlockingOrdersException`, non utilisé par ce module mais prévu pour
 * rester réutilisable par les modules futurs).
 */
export class AppError extends Error {
  readonly statusCode: number;
  readonly code: string;
  readonly extra?: Record<string, unknown>;

  constructor(
    statusCode: number,
    code: string,
    message: string,
    extra?: Record<string, unknown>,
  ) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
    this.extra = extra;
  }
}
