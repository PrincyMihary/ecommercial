// Valeurs par défaut pour l'exécution des tests. Ce fichier est chargé
// par Jest (voir jest.config.js -> setupFiles) AVANT que app.ts / db/pool.ts
// ne soient importés, afin que `config/env.ts` lise ces variables plutôt
// que celles de `.env` (dotenv ne réécrit jamais une variable déjà
// définie dans process.env).
//
// DATABASE_* doit pointer vers une base PostgreSQL de test réelle,
// avec le schéma déjà appliqué (voir README.md, section Tests).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET ?? 'test-secret-do-not-use-in-prod';
process.env.JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN ?? '1h';
process.env.DATABASE_HOST = process.env.DATABASE_HOST ?? 'localhost';
process.env.DATABASE_PORT = process.env.DATABASE_PORT ?? '5433';
process.env.DATABASE_NAME = process.env.DATABASE_NAME ?? 'ecommercial_test';
process.env.DATABASE_USER = process.env.DATABASE_USER ?? 'postgres';
process.env.DATABASE_PASSWORD = process.env.DATABASE_PASSWORD ?? '2305';
