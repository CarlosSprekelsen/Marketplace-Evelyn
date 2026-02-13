import { MigrationInterface, QueryRunner } from 'typeorm';

export class InitialSchema1707837000000 implements MigrationInterface {
  name = 'InitialSchema1707837000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Enable UUID extension
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);

    // Create enum types
    await queryRunner.query(`
      CREATE TYPE "user_role_enum" AS ENUM ('CLIENT', 'PROVIDER', 'ADMIN')
    `);

    await queryRunner.query(`
      CREATE TYPE "service_request_status_enum" AS ENUM (
        'PENDING',
        'ACCEPTED',
        'IN_PROGRESS',
        'COMPLETED',
        'CANCELLED',
        'EXPIRED'
      )
    `);

    // Create districts table
    await queryRunner.query(`
      CREATE TABLE "districts" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "name" varchar NOT NULL,
        "is_active" boolean NOT NULL DEFAULT true,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_districts_name" UNIQUE ("name"),
        CONSTRAINT "PK_districts" PRIMARY KEY ("id")
      )
    `);

    // Create users table
    await queryRunner.query(`
      CREATE TABLE "users" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "email" varchar NOT NULL,
        "password_hash" varchar NOT NULL,
        "role" "user_role_enum" NOT NULL,
        "full_name" varchar NOT NULL,
        "phone" varchar NOT NULL,
        "district_id" uuid NOT NULL,
        "is_verified" boolean NOT NULL DEFAULT false,
        "is_blocked" boolean NOT NULL DEFAULT false,
        "refresh_token_hash" varchar,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_users_email" UNIQUE ("email"),
        CONSTRAINT "PK_users" PRIMARY KEY ("id")
      )
    `);

    // Create service_requests table
    await queryRunner.query(`
      CREATE TABLE "service_requests" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "client_id" uuid NOT NULL,
        "provider_id" uuid,
        "district_id" uuid NOT NULL,
        "address_detail" text NOT NULL,
        "hours_requested" integer NOT NULL,
        "price_total" decimal(10,2) NOT NULL,
        "scheduled_at" TIMESTAMP NOT NULL,
        "status" "service_request_status_enum" NOT NULL DEFAULT 'PENDING',
        "accepted_at" TIMESTAMP,
        "started_at" TIMESTAMP,
        "completed_at" TIMESTAMP,
        "cancelled_at" TIMESTAMP,
        "cancelled_by" uuid,
        "cancelled_by_role" varchar,
        "cancellation_reason" text,
        "expires_at" TIMESTAMP NOT NULL,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_service_requests" PRIMARY KEY ("id")
      )
    `);

    // Create index on (status, expires_at) for expiration cron job
    await queryRunner.query(`
      CREATE INDEX "IDX_service_requests_status_expires_at"
      ON "service_requests" ("status", "expires_at")
    `);

    // Create pricing_rules table
    await queryRunner.query(`
      CREATE TABLE "pricing_rules" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "district_id" uuid NOT NULL,
        "price_per_hour" decimal(10,2) NOT NULL,
        "min_hours" integer NOT NULL DEFAULT 1,
        "max_hours" integer NOT NULL DEFAULT 8,
        "is_active" boolean NOT NULL DEFAULT true,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_pricing_rules" PRIMARY KEY ("id")
      )
    `);

    // Create ratings table
    await queryRunner.query(`
      CREATE TABLE "ratings" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "service_request_id" uuid NOT NULL,
        "client_id" uuid NOT NULL,
        "provider_id" uuid NOT NULL,
        "stars" integer NOT NULL,
        "comment" text,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_ratings_service_request_id" UNIQUE ("service_request_id"),
        CONSTRAINT "PK_ratings" PRIMARY KEY ("id")
      )
    `);

    // Add foreign key constraints
    await queryRunner.query(`
      ALTER TABLE "users"
      ADD CONSTRAINT "FK_users_district_id"
      FOREIGN KEY ("district_id") REFERENCES "districts"("id")
      ON DELETE NO ACTION ON UPDATE NO ACTION
    `);

    await queryRunner.query(`
      ALTER TABLE "service_requests"
      ADD CONSTRAINT "FK_service_requests_client_id"
      FOREIGN KEY ("client_id") REFERENCES "users"("id")
      ON DELETE NO ACTION ON UPDATE NO ACTION
    `);

    await queryRunner.query(`
      ALTER TABLE "service_requests"
      ADD CONSTRAINT "FK_service_requests_provider_id"
      FOREIGN KEY ("provider_id") REFERENCES "users"("id")
      ON DELETE NO ACTION ON UPDATE NO ACTION
    `);

    await queryRunner.query(`
      ALTER TABLE "service_requests"
      ADD CONSTRAINT "FK_service_requests_district_id"
      FOREIGN KEY ("district_id") REFERENCES "districts"("id")
      ON DELETE NO ACTION ON UPDATE NO ACTION
    `);

    await queryRunner.query(`
      ALTER TABLE "service_requests"
      ADD CONSTRAINT "FK_service_requests_cancelled_by"
      FOREIGN KEY ("cancelled_by") REFERENCES "users"("id")
      ON DELETE NO ACTION ON UPDATE NO ACTION
    `);

    await queryRunner.query(`
      ALTER TABLE "pricing_rules"
      ADD CONSTRAINT "FK_pricing_rules_district_id"
      FOREIGN KEY ("district_id") REFERENCES "districts"("id")
      ON DELETE NO ACTION ON UPDATE NO ACTION
    `);

    // Partial unique index: one active pricing rule per district
    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_pricing_rules_district_active"
      ON "pricing_rules" ("district_id")
      WHERE "is_active" = true
    `);

    await queryRunner.query(`
      ALTER TABLE "ratings"
      ADD CONSTRAINT "FK_ratings_service_request_id"
      FOREIGN KEY ("service_request_id") REFERENCES "service_requests"("id")
      ON DELETE NO ACTION ON UPDATE NO ACTION
    `);

    await queryRunner.query(`
      ALTER TABLE "ratings"
      ADD CONSTRAINT "FK_ratings_client_id"
      FOREIGN KEY ("client_id") REFERENCES "users"("id")
      ON DELETE NO ACTION ON UPDATE NO ACTION
    `);

    await queryRunner.query(`
      ALTER TABLE "ratings"
      ADD CONSTRAINT "FK_ratings_provider_id"
      FOREIGN KEY ("provider_id") REFERENCES "users"("id")
      ON DELETE NO ACTION ON UPDATE NO ACTION
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Drop foreign key constraints
    await queryRunner.query(`ALTER TABLE "ratings" DROP CONSTRAINT "FK_ratings_provider_id"`);
    await queryRunner.query(`ALTER TABLE "ratings" DROP CONSTRAINT "FK_ratings_client_id"`);
    await queryRunner.query(
      `ALTER TABLE "ratings" DROP CONSTRAINT "FK_ratings_service_request_id"`,
    );
    await queryRunner.query(`DROP INDEX IF EXISTS "UQ_pricing_rules_district_active"`);
    await queryRunner.query(
      `ALTER TABLE "pricing_rules" DROP CONSTRAINT "FK_pricing_rules_district_id"`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_requests" DROP CONSTRAINT "FK_service_requests_cancelled_by"`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_requests" DROP CONSTRAINT "FK_service_requests_district_id"`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_requests" DROP CONSTRAINT "FK_service_requests_provider_id"`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_requests" DROP CONSTRAINT "FK_service_requests_client_id"`,
    );
    await queryRunner.query(`ALTER TABLE "users" DROP CONSTRAINT "FK_users_district_id"`);

    // Drop tables
    await queryRunner.query(`DROP TABLE "ratings"`);
    await queryRunner.query(`DROP TABLE "pricing_rules"`);
    await queryRunner.query(`DROP INDEX "IDX_service_requests_status_expires_at"`);
    await queryRunner.query(`DROP TABLE "service_requests"`);
    await queryRunner.query(`DROP TABLE "users"`);
    await queryRunner.query(`DROP TABLE "districts"`);

    // Drop enum types
    await queryRunner.query(`DROP TYPE "service_request_status_enum"`);
    await queryRunner.query(`DROP TYPE "user_role_enum"`);
  }
}
