import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddUserTermsAcceptedAt1707837300000 implements MigrationInterface {
  name = 'AddUserTermsAcceptedAt1707837300000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "users" ADD COLUMN "terms_accepted_at" timestamp`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "terms_accepted_at"`);
  }
}
