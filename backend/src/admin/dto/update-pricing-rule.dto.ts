import { Transform, Type } from 'class-transformer';
import { IsNumber, IsOptional, Matches, Min } from 'class-validator';

export class UpdatePricingRuleDto {
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  price_per_hour: number;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim().toUpperCase() : value))
  @Matches(/^[A-Z]{3}$/)
  currency?: string;
}
