/**
 * Petit utilitaire pour exécuter un fichier .sql (schema.sql ou seed.sql)
 * contre la base PostgreSQL configurée dans .env, sans dépendance
 * supplémentaire (pas de CLI psql requis).
 *
 * Usage : node -r dotenv/config ./scripts/run-sql.js database/schema.sql
 */
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

async function main() {
  const file = process.argv[2];
  if (!file) {
    console.error('Usage: node run-sql.js <fichier.sql>');
    process.exit(1);
  }

  const sqlPath = path.resolve(process.cwd(), file);
  const sql = fs.readFileSync(sqlPath, 'utf8');

  const client = new Client({
    host: process.env.DATABASE_HOST || 'localhost',
    port: Number(process.env.DATABASE_PORT || 5432),
    database: process.env.DATABASE_NAME || 'ecommercial',
    user: process.env.DATABASE_USER || 'postgres',
    password: process.env.DATABASE_PASSWORD || '',
  });

  await client.connect();
  try {
    console.log(`Exécution de ${file}...`);
    await client.query(sql);
    console.log('OK.');
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
