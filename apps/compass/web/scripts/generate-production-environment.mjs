import { writeFileSync } from 'node:fs';

const requiredEnvironmentVariables = ['SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY'];
const missingEnvironmentVariables = requiredEnvironmentVariables.filter((name) => !process.env[name]);

if (missingEnvironmentVariables.length > 0) {
  console.error(
    `Missing required environment variable${missingEnvironmentVariables.length === 1 ? '' : 's'}: ${missingEnvironmentVariables.join(', ')}`
  );
  process.exit(1);
}

const environmentFile = `export const environment = {
  production: true,
  supabaseUrl: ${JSON.stringify(process.env.SUPABASE_URL)},
  supabasePublishableKey: ${JSON.stringify(process.env.SUPABASE_PUBLISHABLE_KEY)}
};
`;

writeFileSync('src/environments/environment.prod.ts', environmentFile);