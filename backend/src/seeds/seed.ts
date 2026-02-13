import { AppDataSource } from '../data-source';
import { District } from '../districts/district.entity';
import { PricingRule } from '../pricing/pricing-rule.entity';

async function seed() {
  try {
    // Initialize data source
    await AppDataSource.initialize();
    console.log('Data Source has been initialized!');

    const districtRepository = AppDataSource.getRepository(District);
    const pricingRuleRepository = AppDataSource.getRepository(PricingRule);

    // Seed districts
    const districtsData = [
      { name: 'Dubai Marina' },
      { name: 'JBR (Jumeirah Beach Residence)' },
      { name: 'Downtown Dubai' },
      { name: 'Business Bay' },
      { name: 'Dubai Hills' },
    ];

    const districts: District[] = [];
    for (const districtData of districtsData) {
      const existingDistrict = await districtRepository.findOne({
        where: { name: districtData.name },
      });

      if (!existingDistrict) {
        const district = districtRepository.create(districtData);
        const savedDistrict = await districtRepository.save(district);
        districts.push(savedDistrict);
        console.log(`Created district: ${districtData.name}`);
      } else {
        districts.push(existingDistrict);
        console.log(`District already exists: ${districtData.name}`);
      }
    }

    // Seed pricing rules (3 examples for first 3 districts)
    const pricingRulesData = [
      {
        district_id: districts[0].id,
        price_per_hour: 20.0,
        min_hours: 1,
        max_hours: 8,
      }, // Dubai Marina
      {
        district_id: districts[1].id,
        price_per_hour: 22.0,
        min_hours: 1,
        max_hours: 8,
      }, // JBR
      {
        district_id: districts[2].id,
        price_per_hour: 25.0,
        min_hours: 1,
        max_hours: 8,
      }, // Downtown
    ];

    for (const pricingData of pricingRulesData) {
      const existingRule = await pricingRuleRepository.findOne({
        where: { district_id: pricingData.district_id, is_active: true },
      });

      if (!existingRule) {
        const pricingRule = pricingRuleRepository.create(pricingData);
        await pricingRuleRepository.save(pricingRule);
        const district = districts.find((d) => d.id === pricingData.district_id);
        console.log(
          `Created pricing rule for ${district?.name}: $${pricingData.price_per_hour}/hour`,
        );
      } else {
        const district = districts.find((d) => d.id === pricingData.district_id);
        console.log(`Pricing rule already exists for ${district?.name}`);
      }
    }

    console.log('\nSeeding completed successfully!');
    await AppDataSource.destroy();
  } catch (error) {
    console.error('Error during seeding:', error);
    process.exit(1);
  }
}

seed().catch((error) => {
  console.error('Unhandled error during seeding:', error);
  process.exit(1);
});
