import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddUserPasswordResetFields1707837400000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "users" ADD COLUMN "password_reset_token_hash" varchar`);
    await queryRunner.query(`ALTER TABLE "users" ADD COLUMN "password_reset_expires_at" timestamp`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "password_reset_expires_at"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "password_reset_token_hash"`);
  }
}
