import 'dotenv/config';

function required(name: string, fallback?: string): string {
  const value = process.env[name] ?? fallback;
  if (value === undefined) {
    throw new Error(`Variable d'environnement manquante : ${name}`);
  }
  return value;
}

export const env = {
  port: Number(process.env.PORT ?? 3000),

  db: {
    host: required('DATABASE_HOST', 'localhost'),
    port: Number(process.env.DATABASE_PORT ?? 5432),
    database: required('DATABASE_NAME', 'ecommercial'),
    user: required('DATABASE_USER', 'postgres'),
    password: process.env.DATABASE_PASSWORD ?? '',
  },

  jwt: {
    secret: required('JWT_SECRET', 'change-me-in-each-local-env'),
    expiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
  },

  uploads: {
    maxImageBytes: Number(process.env.UPLOAD_MAX_IMAGE_MB ?? 8) * 1024 * 1024,
    maxModelBytes: Number(process.env.UPLOAD_MAX_MODEL_MB ?? 50) * 1024 * 1024,
  },
};
