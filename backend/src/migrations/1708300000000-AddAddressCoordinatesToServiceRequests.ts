import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddAddressCoordinatesToServiceRequests1708300000000
  implements MigrationInterface
{
  name = 'AddAddressCoordinatesToServiceRequests1708300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "service_requests" ADD "address_latitude" decimal(10,7)`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_requests" ADD "address_longitude" decimal(10,7)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "service_requests" DROP COLUMN "address_longitude"`);
    await queryRunner.query(`ALTER TABLE "service_requests" DROP COLUMN "address_latitude"`);
  }
}
