import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateUserAddresses1708200000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE "address_label_enum" AS ENUM ('CASA', 'OFICINA', 'OTRO')
    `);

    await queryRunner.query(`
      CREATE TABLE "user_addresses" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "label" "address_label_enum" NOT NULL,
        "label_custom" varchar(50),
        "district_id" uuid NOT NULL,
        "address_street" varchar(200) NOT NULL,
        "address_number" varchar(50) NOT NULL,
        "address_floor_apt" varchar(100),
        "address_reference" varchar(300),
        "latitude" decimal(10,7),
        "longitude" decimal(10,7),
        "is_default" boolean NOT NULL DEFAULT false,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_user_addresses" PRIMARY KEY ("id"),
        CONSTRAINT "FK_user_addresses_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_user_addresses_district" FOREIGN KEY ("district_id") REFERENCES "districts"("id")
      )
    `);

    await queryRunner.query(`
      CREATE INDEX "IDX_user_addresses_user_default" ON "user_addresses" ("user_id", "is_default")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "user_addresses"`);
    await queryRunner.query(`DROP TYPE "address_label_enum"`);
  }
}
