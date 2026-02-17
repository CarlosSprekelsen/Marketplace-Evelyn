import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateRecurringRequests1708000000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "recurring_requests" (
        "id" uuid DEFAULT uuid_generate_v4() NOT NULL,
        "client_id" uuid NOT NULL,
        "district_id" uuid NOT NULL,
        "address_detail" text NOT NULL,
        "hours_requested" integer NOT NULL,
        "day_of_week" integer NOT NULL,
        "time_of_day" varchar(5) NOT NULL,
        "is_active" boolean NOT NULL DEFAULT true,
        "next_scheduled_at" timestamp NOT NULL,
        "created_at" timestamp NOT NULL DEFAULT now(),
        "updated_at" timestamp NOT NULL DEFAULT now(),
        CONSTRAINT "PK_recurring_requests" PRIMARY KEY ("id"),
        CONSTRAINT "FK_recurring_requests_client" FOREIGN KEY ("client_id") REFERENCES "users"("id"),
        CONSTRAINT "FK_recurring_requests_district" FOREIGN KEY ("district_id") REFERENCES "districts"("id")
      )
    `);

    await queryRunner.query(
      `ALTER TABLE "service_requests" ADD COLUMN "recurring_request_id" uuid`,
    );
    await queryRunner.query(`
      ALTER TABLE "service_requests"
        ADD CONSTRAINT "FK_service_requests_recurring"
        FOREIGN KEY ("recurring_request_id") REFERENCES "recurring_requests"("id")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "service_requests" DROP CONSTRAINT "FK_service_requests_recurring"`,
    );
    await queryRunner.query(`ALTER TABLE "service_requests" DROP COLUMN "recurring_request_id"`);
    await queryRunner.query(`DROP TABLE "recurring_requests"`);
  }
}
