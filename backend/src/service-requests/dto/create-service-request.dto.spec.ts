import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { CreateServiceRequestDto } from './create-service-request.dto';

describe('CreateServiceRequestDto', () => {
  function createDto(overrides: Partial<Record<string, unknown>> = {}) {
    return plainToInstance(CreateServiceRequestDto, {
      district_id: '123e4567-e89b-12d3-a456-426614174000',
      address_detail: 'Calle 1 #23, Edificio Azul',
      hours_requested: 3,
      scheduled_at: '2026-03-01T10:00:00Z',
      ...overrides,
    });
  }

  it('should accept scheduled_at with :00 minutes', async () => {
    const dto = createDto({ scheduled_at: '2026-03-01T10:00:00Z' });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('should accept scheduled_at with :30 minutes', async () => {
    const dto = createDto({ scheduled_at: '2026-03-01T10:30:00Z' });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('should reject scheduled_at with :15 minutes', async () => {
    const dto = createDto({ scheduled_at: '2026-03-01T10:15:00Z' });
    const errors = await validate(dto);
    const slotError = errors.find((e) => e.property === 'scheduled_at');
    expect(slotError).toBeDefined();
  });

  it('should reject scheduled_at with :45 minutes', async () => {
    const dto = createDto({ scheduled_at: '2026-03-01T10:45:00Z' });
    const errors = await validate(dto);
    const slotError = errors.find((e) => e.property === 'scheduled_at');
    expect(slotError).toBeDefined();
  });

  it('should reject scheduled_at with arbitrary minutes', async () => {
    const dto = createDto({ scheduled_at: '2026-03-01T10:07:00Z' });
    const errors = await validate(dto);
    const slotError = errors.find((e) => e.property === 'scheduled_at');
    expect(slotError).toBeDefined();
  });
});
