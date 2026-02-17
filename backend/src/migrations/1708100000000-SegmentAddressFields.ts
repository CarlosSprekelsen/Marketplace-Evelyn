import { MigrationInterface, QueryRunner } from 'typeorm';

export class SegmentAddressFields1708100000000 implements MigrationInterface {
  name = 'SegmentAddressFields1708100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // --- service_requests ---
    await queryRunner.query(
      `ALTER TABLE "service_requests" ADD "address_street" varchar(200) NOT NULL DEFAULT ''`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_requests" ADD "address_number" varchar(50) NOT NULL DEFAULT ''`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_requests" ADD "address_floor_apt" varchar(100)`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_requests" ADD "address_reference" varchar(300)`,
    );
    // Migrate existing data: copy address_detail into address_street
    await queryRunner.query(
      `UPDATE "service_requests" SET "address_street" = "address_detail" WHERE "address_detail" IS NOT NULL`,
    );
    await queryRunner.query(`ALTER TABLE "service_requests" DROP COLUMN "address_detail"`);

    // --- recurring_requests ---
    await queryRunner.query(
      `ALTER TABLE "recurring_requests" ADD "address_street" varchar(200) NOT NULL DEFAULT ''`,
    );
    await queryRunner.query(
      `ALTER TABLE "recurring_requests" ADD "address_number" varchar(50) NOT NULL DEFAULT ''`,
    );
    await queryRunner.query(
      `ALTER TABLE "recurring_requests" ADD "address_floor_apt" varchar(100)`,
    );
    await queryRunner.query(
      `ALTER TABLE "recurring_requests" ADD "address_reference" varchar(300)`,
    );
    // Migrate existing data
    await queryRunner.query(
      `UPDATE "recurring_requests" SET "address_street" = "address_detail" WHERE "address_detail" IS NOT NULL`,
    );
    await queryRunner.query(`ALTER TABLE "recurring_requests" DROP COLUMN "address_detail"`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // --- recurring_requests ---
    await queryRunner.query(
      `ALTER TABLE "recurring_requests" ADD "address_detail" text NOT NULL DEFAULT ''`,
    );
    await queryRunner.query(
      `UPDATE "recurring_requests" SET "address_detail" = "address_street"`,
    );
    await queryRunner.query(`ALTER TABLE "recurring_requests" DROP COLUMN "address_reference"`);
    await queryRunner.query(`ALTER TABLE "recurring_requests" DROP COLUMN "address_floor_apt"`);
    await queryRunner.query(`ALTER TABLE "recurring_requests" DROP COLUMN "address_number"`);
    await queryRunner.query(`ALTER TABLE "recurring_requests" DROP COLUMN "address_street"`);

    // --- service_requests ---
    await queryRunner.query(
      `ALTER TABLE "service_requests" ADD "address_detail" text NOT NULL DEFAULT ''`,
    );
    await queryRunner.query(
      `UPDATE "service_requests" SET "address_detail" = "address_street"`,
    );
    await queryRunner.query(`ALTER TABLE "service_requests" DROP COLUMN "address_reference"`);
    await queryRunner.query(`ALTER TABLE "service_requests" DROP COLUMN "address_floor_apt"`);
    await queryRunner.query(`ALTER TABLE "service_requests" DROP COLUMN "address_number"`);
    await queryRunner.query(`ALTER TABLE "service_requests" DROP COLUMN "address_street"`);
  }
}
