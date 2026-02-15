import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddUserAvailability1707837100000 implements MigrationInterface {
  name = 'AddUserAvailability1707837100000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN "is_available" boolean NOT NULL DEFAULT true`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "is_available"`);
  }
}
