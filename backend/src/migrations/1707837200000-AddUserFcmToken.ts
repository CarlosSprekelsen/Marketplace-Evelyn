import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddUserFcmToken1707837200000 implements MigrationInterface {
  name = 'AddUserFcmToken1707837200000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "users" ADD COLUMN "fcm_token" varchar`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "fcm_token"`);
  }
}
