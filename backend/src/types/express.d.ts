/**
 * Étend le type `Request` d'Express pour exposer l'utilisateur courant,
 * attaché par le middleware `authenticate` (src/middleware/auth.ts) une
 * fois le JWT vérifié.
 *
 * `user` ne contient que l'identifiant : les modules qui en ont besoin
 * rechargent l'utilisateur complet depuis PostgreSQL (repository), pour
 * ne jamais faire circuler de donnée potentiellement périmée depuis le
 * JWT lui-même.
 */
export interface AuthenticatedUser {
  id: number;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthenticatedUser;
    }
  }
}

export {};
