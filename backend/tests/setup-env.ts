// Valeurs par défaut pour l'exécution des tests. DATABASE_URL doit
// pointer vers une base PostgreSQL de test réelle (non fournie par cet
// environnement) — voir README.md, section Tests.
process.env.JWT_SECRET = process.env.JWT_SECRET ?? 'test-secret-do-not-use-in-prod';
process.env.JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN ?? '1h';
process.env.DATABASE_URL =
  process.env.DATABASE_URL ?? 'postgres://postgres:2305@localhost:5433/ecommercial_test';
process.env.NODE_ENV = 'test';
