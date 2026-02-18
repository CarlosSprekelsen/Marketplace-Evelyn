import * as bcrypt from 'bcrypt';
import { config } from 'dotenv';
import { AppDataSource } from '../data-source';
import { User, UserRole } from '../users/user.entity';

config();

const DEFAULT_ADMIN_EMAIL = 'admin@marketplace.local';
const DEFAULT_ADMIN_PASSWORD = 'change-me-in-production';

async function seedAdmin(): Promise<void> {
  const adminEmail = (process.env.ADMIN_EMAIL ?? DEFAULT_ADMIN_EMAIL).trim().toLowerCase();
  const adminPassword = (process.env.ADMIN_PASSWORD ?? DEFAULT_ADMIN_PASSWORD).trim();

  if (!adminEmail || !adminPassword) {
    throw new Error('ADMIN_EMAIL and ADMIN_PASSWORD must be set');
  }

  await AppDataSource.initialize();

  try {
    const usersRepository = AppDataSource.getRepository(User);

    const existingAdmin = await usersRepository.findOne({
      where: { email: adminEmail },
    });

    if (existingAdmin) {
      console.log('Admin user already exists');
      return;
    }

    const firstDistrict = await AppDataSource.query(
      'SELECT id FROM districts ORDER BY created_at ASC LIMIT 1',
    );

    if (!Array.isArray(firstDistrict) || firstDistrict.length === 0 || !firstDistrict[0]?.id) {
      throw new Error('Cannot create admin user: no districts found. Run base seed first.');
    }

    const passwordHash = await bcrypt.hash(adminPassword, 10);

    const adminUser = usersRepository.create({
      email: adminEmail,
      password_hash: passwordHash,
      role: UserRole.ADMIN,
      full_name: 'Platform Admin',
      phone: '+971500000000',
      district_id: firstDistrict[0].id as string,
      is_verified: true,
      is_blocked: false,
    });

    await usersRepository.save(adminUser);
    console.log('Admin user created');
  } finally {
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy();
    }
  }
}

seedAdmin().catch((error: unknown) => {
  console.error('Error running admin seed:', error);
  process.exit(1);
});
