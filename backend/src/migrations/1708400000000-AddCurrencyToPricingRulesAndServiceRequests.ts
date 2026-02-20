import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddCurrencyToPricingRulesAndServiceRequests1708400000000
  implements MigrationInterface
{
  name = 'AddCurrencyToPricingRulesAndServiceRequests1708400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "pricing_rules" ADD "currency" character varying(3) NOT NULL DEFAULT 'AED'`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_requests" ADD "currency" character varying(3) NOT NULL DEFAULT 'AED'`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "service_requests" DROP COLUMN "currency"`);
    await queryRunner.query(`ALTER TABLE "pricing_rules" DROP COLUMN "currency"`);
  }
}
