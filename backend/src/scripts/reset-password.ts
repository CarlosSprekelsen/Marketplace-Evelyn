/**
 * CLI script to reset a user's password directly in the database.
 * Run from VPS (SSH/VPN only, never exposed to the internet).
 *
 * Usage:
 *   npx ts-node -r tsconfig-paths/register src/scripts/reset-password.ts <email> <new_password>
 *
 * Inside Docker:
 *   docker-compose exec backend npx ts-node -r tsconfig-paths/register src/scripts/reset-password.ts <email> <new_password>
 */
import { AppDataSource } from '../data-source';
import { User } from '../users/user.entity';
import * as bcrypt from 'bcrypt';

async function main() {
  const [, , email, newPassword] = process.argv;

  if (!email || !newPassword) {
    console.error('Usage: reset-password.ts <email> <new_password>');
    process.exit(1);
  }

  if (newPassword.length < 6) {
    console.error('Password must be at least 6 characters');
    process.exit(1);
  }

  await AppDataSource.initialize();

  const userRepository = AppDataSource.getRepository(User);
  const user = await userRepository.findOne({ where: { email } });

  if (!user) {
    console.error(`User not found: ${email}`);
    await AppDataSource.destroy();
    process.exit(1);
  }

  const password_hash = await bcrypt.hash(newPassword, 10);
  await userRepository.update(user.id, {
    password_hash,
    refresh_token_hash: null,
    password_reset_token_hash: null,
    password_reset_expires_at: null,
  } as any);

  console.log(`Password reset successfully for: ${email} (role: ${user.role})`);
  await AppDataSource.destroy();
}

main().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
