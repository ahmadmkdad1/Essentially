/**
 * Seeds realistic demo data (providers, services, customers, requests,
 * reviews and open reports) so every role has something to explore.
 *
 *   npm run seed            # adds demo data if it is not there yet
 *   npm run seed -- --fresh # wipes ALL data first (development only)
 */
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DataSource, DeepPartial } from 'typeorm';
import { AppModule } from '../app.module.js';
import { Category } from '../categories/category.entity.js';
import {
  PriceUnit,
  ReportReason,
  ReportTargetType,
  RequestStatus,
  Role,
} from '../common/enums.js';
import { Listing } from '../listings/listing.entity.js';
import { Report } from '../reports/report.entity.js';
import { ServiceRequest } from '../requests/service-request.entity.js';
import { Review } from '../reviews/review.entity.js';
import { User } from '../users/user.entity.js';
import { UsersService } from '../users/users.service.js';
import { AuditLog } from '../admin/audit-log.entity.js';

const DEMO_PASSWORD = 'Demo@1234';
const DAY = 24 * 60 * 60 * 1000;

const PLACES = {
  hamra: {
    latitude: 33.8966,
    longitude: 35.4823,
    address: 'Hamra Street, Beirut',
  },
  achrafieh: {
    latitude: 33.8886,
    longitude: 35.5198,
    address: 'Sassine Square, Achrafieh, Beirut',
  },
  verdun: {
    latitude: 33.8786,
    longitude: 35.4836,
    address: 'Verdun Street, Beirut',
  },
  baabda: {
    latitude: 33.8339,
    longitude: 35.5442,
    address: 'Main Road, Baabda',
  },
  dbayeh: {
    latitude: 33.9435,
    longitude: 35.59,
    address: 'Dbayeh Highway, Metn',
  },
  jounieh: {
    latitude: 33.9808,
    longitude: 35.6178,
    address: 'Kaslik, Jounieh',
  },
  tripoli: {
    latitude: 34.4367,
    longitude: 35.8497,
    address: 'Al Mina, Tripoli',
  },
  saida: {
    latitude: 33.5571,
    longitude: 35.3729,
    address: 'Riad El Solh Street, Saida',
  },
};

interface ProviderSeed {
  email: string;
  fullName: string;
  businessName: string;
  phone: string;
  bio: string;
  place: keyof typeof PLACES;
  listings: Array<{
    key: string;
    title: string;
    description: string;
    price: number;
    priceUnit?: PriceUnit;
    category: string;
    radius?: number;
  }>;
}

const PROVIDERS: ProviderSeed[] = [
  {
    email: 'provider@essentially.app',
    fullName: 'Karim Nassar',
    businessName: 'Cedar Gas Services',
    phone: '+961 70 111 222',
    bio: 'Licensed gas technicians serving Beirut since 2012. Same-day delivery, certified safety checks.',
    place: 'achrafieh',
    listings: [
      {
        key: 'gasRefill',
        title: 'Gas cylinder delivery (10 kg)',
        description:
          'Full 10 kg cylinder delivered to your door and safely connected. Empty cylinder exchange included.',
        price: 12,
        category: 'gas',
        radius: 12,
      },
      {
        key: 'gasLeak',
        title: 'Gas leak inspection',
        description:
          'Complete inspection of hoses, regulators and connections with an electronic leak detector.',
        price: 25,
        category: 'gas',
        radius: 15,
      },
      {
        key: 'gasLine',
        title: 'Kitchen gas line installation',
        description:
          'Copper gas line installation for kitchens, including valves, fittings and a pressure test.',
        price: 60,
        category: 'gas',
        radius: 20,
      },
    ],
  },
  {
    email: 'aquapure@essentially.app',
    fullName: 'Rana Khoury',
    businessName: 'AquaPure Lebanon',
    phone: '+961 71 333 444',
    bio: 'Clean drinking water delivery and professional tank sanitation across Greater Beirut.',
    place: 'hamra',
    listings: [
      {
        key: 'water5g',
        title: 'Drinking water gallon (5 gal)',
        description:
          'Purified, mineral-balanced drinking water in sealed 5-gallon bottles. Minimum order of 2.',
        price: 2.5,
        category: 'water',
        radius: 10,
      },
      {
        key: 'tankClean',
        title: 'Water tank cleaning & sanitation',
        description:
          'Drain, scrub and disinfect rooftop water tanks up to 2,000 L. Certificate provided.',
        price: 40,
        category: 'water',
        radius: 15,
      },
      {
        key: 'filter',
        title: 'Under-sink filtration system',
        description:
          '5-stage reverse osmosis system supplied and installed, with first filter change free.',
        price: 85,
        category: 'water',
        radius: 15,
      },
    ],
  },
  {
    email: 'volt@essentially.app',
    fullName: 'Hadi Haddad',
    businessName: 'Volt Power Generators',
    phone: '+961 76 555 666',
    bio: 'Neighbourhood generator subscriptions and 24/7 emergency electricians.',
    place: 'baabda',
    listings: [
      {
        key: 'gen5a',
        title: '5A generator subscription',
        description:
          'Reliable 5-amp generator subscription with automatic switch-over during power cuts.',
        price: 45,
        priceUnit: PriceUnit.MONTHLY,
        category: 'electricity',
        radius: 5,
      },
      {
        key: 'electrician',
        title: 'Emergency electrician visit',
        description:
          'Certified electrician for breakers, short circuits, sockets and wiring faults. Billed hourly.',
        price: 20,
        priceUnit: PriceUnit.HOURLY,
        category: 'electricity',
        radius: 15,
      },
    ],
  },
  {
    email: 'fibernet@essentially.app',
    fullName: 'Nour Saleh',
    businessName: 'FiberNet Home',
    phone: '+961 78 777 888',
    bio: 'Fast home internet with professional Wi-Fi coverage design.',
    place: 'verdun',
    listings: [
      {
        key: 'fiber',
        title: 'Home fiber internet — 100 Mbps',
        description:
          'Unlimited fiber internet, free router and installation within 48 hours.',
        price: 35,
        priceUnit: PriceUnit.MONTHLY,
        category: 'internet',
        radius: 20,
      },
      {
        key: 'mesh',
        title: 'Whole-home Wi-Fi mesh setup',
        description:
          'Survey, install and configure a 3-node mesh network to remove dead zones.',
        price: 50,
        category: 'internet',
        radius: 20,
      },
    ],
  },
  {
    email: 'skyview@essentially.app',
    fullName: 'Elie Mansour',
    businessName: 'SkyView Satellite',
    phone: '+961 70 999 000',
    bio: 'Satellite dish installation and receiver servicing for Keserwan and Metn.',
    place: 'jounieh',
    listings: [
      {
        key: 'dish',
        title: 'Satellite dish installation & alignment',
        description:
          'Mounting, cabling and precise alignment for Nilesat/Arabsat with signal report.',
        price: 40,
        category: 'satellite',
        radius: 25,
      },
      {
        key: 'receiver',
        title: 'Receiver repair & channel setup',
        description:
          'Diagnose and fix receivers, update firmware and re-scan all channels.',
        price: 15,
        category: 'satellite',
        radius: 25,
      },
    ],
  },
  {
    email: 'suncore@essentially.app',
    fullName: 'Maya Azar',
    businessName: 'SunCore Solar',
    phone: '+961 71 121 314',
    bio: 'Solar maintenance specialists keeping your panels and batteries at peak output.',
    place: 'dbayeh',
    listings: [
      {
        key: 'solarClean',
        title: 'Solar panel cleaning (up to 12 panels)',
        description:
          'Deionised water cleaning that can recover up to 25% lost efficiency.',
        price: 30,
        category: 'solar',
        radius: 30,
      },
      {
        key: 'inverter',
        title: 'Inverter & battery maintenance',
        description:
          'Full health check of inverter, charge controller and battery bank with report.',
        price: 45,
        category: 'solar',
        radius: 30,
      },
    ],
  },
  {
    email: 'fixit@essentially.app',
    fullName: 'Tony Rizk',
    businessName: 'FixIt Plumbing',
    phone: '+961 76 151 617',
    bio: 'Fast, tidy plumbing repairs. No call-out fee inside Beirut.',
    place: 'achrafieh',
    listings: [
      {
        key: 'leakFix',
        title: 'Leak & pipe repair',
        description:
          'Find and fix leaking pipes, taps and joints. Parts billed separately.',
        price: 18,
        priceUnit: PriceUnit.HOURLY,
        category: 'plumbing',
        radius: 12,
      },
      {
        key: 'heater',
        title: 'Water heater installation',
        description:
          'Install electric or solar-assisted water heaters up to 100 L, including safety valve.',
        price: 70,
        category: 'plumbing',
        radius: 15,
      },
    ],
  },
  {
    email: 'north@essentially.app',
    fullName: 'Bilal Omar',
    businessName: 'North Utilities',
    phone: '+961 70 181 920',
    bio: 'Gas and water services for Tripoli and the North.',
    place: 'tripoli',
    listings: [
      {
        key: 'northGas',
        title: 'Gas cylinder delivery — Tripoli',
        description:
          '10 kg gas cylinder delivery and connection across Tripoli and Al Mina.',
        price: 11,
        category: 'gas',
        radius: 15,
      },
      {
        key: 'northWater',
        title: 'Water tank refill (truck)',
        description:
          'Water truck delivery up to 5,000 L for buildings and homes.',
        price: 30,
        category: 'water',
        radius: 20,
      },
    ],
  },
  {
    email: 'quickcash@essentially.app',
    fullName: 'Sam Doe',
    businessName: 'QuickCash Repairs',
    phone: '+961 79 000 111',
    bio: 'Any repair, any time, cheapest prices guaranteed!!!',
    place: 'hamra',
    listings: [
      {
        key: 'shadyAc',
        title: 'AC repair — ANY problem only $5',
        description:
          'We fix any AC problem for just $5!!! Pay upfront by transfer to book a slot.',
        price: 5,
        category: 'maintenance',
        radius: 50,
      },
    ],
  },
];

const CUSTOMERS = [
  {
    email: 'user@essentially.app',
    fullName: 'Lina Haddad',
    phone: '+961 70 202 303',
    place: 'hamra' as const,
  },
  {
    email: 'omar@essentially.app',
    fullName: 'Omar Khalil',
    phone: '+961 71 404 505',
    place: 'achrafieh' as const,
  },
  {
    email: 'maya@essentially.app',
    fullName: 'Maya Saad',
    phone: '+961 76 606 707',
    place: 'jounieh' as const,
  },
];

async function seed() {
  const logger = new Logger('Seed');
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error', 'warn', 'log'],
  });
  const ds = app.get(DataSource);
  const usersService = app.get(UsersService);

  if (process.argv.includes('--fresh')) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('Refusing to wipe a production database');
    }
    logger.warn('Wiping existing data (--fresh)');
    for (const entity of [AuditLog, Report, Review, ServiceRequest, Listing]) {
      await ds.createQueryBuilder().delete().from(entity).execute();
    }
    await ds
      .createQueryBuilder()
      .delete()
      .from(User)
      .where('role != :role', { role: Role.ADMIN })
      .execute();
  }

  if (await ds.getRepository(User).existsBy({ email: PROVIDERS[0].email })) {
    logger.log(
      'Demo data already present — nothing to do (use --fresh to reset).',
    );
    await app.close();
    return;
  }

  const passwordHash = await usersService.hashPassword(DEMO_PASSWORD);
  const categories = new Map(
    (await ds.getRepository(Category).find()).map((c) => [c.slug, c]),
  );

  await ds.transaction(async (em) => {
    const listings = new Map<string, Listing>();
    const providers = new Map<string, User>();

    for (const p of PROVIDERS) {
      const place = PLACES[p.place];
      const provider = await em.save(
        em.create(User, {
          fullName: p.fullName,
          email: p.email,
          passwordHash,
          role: Role.PROVIDER,
          phone: p.phone,
          businessName: p.businessName,
          bio: p.bio,
          ...place,
        }),
      );
      providers.set(p.email, provider);

      for (const [i, l] of p.listings.entries()) {
        const category = categories.get(l.category);
        if (!category) throw new Error(`Unknown category ${l.category}`);
        // Spread listings slightly so they don't overlap on the map.
        const listing = await em.save(
          em.create(Listing, {
            title: l.title,
            description: l.description,
            price: l.price,
            priceUnit: l.priceUnit ?? PriceUnit.FIXED,
            currency: 'USD',
            categoryId: category.id,
            providerId: provider.id,
            latitude: place.latitude + (i - 1) * 0.0025,
            longitude: place.longitude + (i - 1) * 0.0025,
            address: place.address,
            serviceRadiusKm: l.radius ?? 15,
          } as DeepPartial<Listing>),
        );
        listings.set(l.key, listing);
      }
    }

    const customers = new Map<string, User>();
    for (const c of CUSTOMERS) {
      const customer = await em.save(
        em.create(User, {
          fullName: c.fullName,
          email: c.email,
          passwordHash,
          role: Role.USER,
          phone: c.phone,
          ...PLACES[c.place],
        }),
      );
      customers.set(c.email, customer);
    }

    const makeRequest = async (
      customerEmail: string,
      listingKey: string,
      status: RequestStatus,
      daysAgo: number,
      extra: Partial<ServiceRequest> = {},
    ) => {
      const customer = customers.get(customerEmail)!;
      const listing = listings.get(listingKey)!;
      const createdAt = new Date(Date.now() - daysAgo * DAY);
      return em.save(
        em.create(ServiceRequest, {
          listingId: listing.id,
          customerId: customer.id,
          providerId: listing.providerId,
          status,
          address: customer.address!,
          latitude: customer.latitude!,
          longitude: customer.longitude!,
          quotedPrice: listing.price,
          createdAt,
          respondedAt:
            status === RequestStatus.PENDING
              ? null
              : new Date(createdAt.getTime() + DAY / 4),
          completedAt:
            status === RequestStatus.COMPLETED
              ? new Date(createdAt.getTime() + DAY)
              : null,
          ...extra,
        } as DeepPartial<ServiceRequest>),
      );
    };

    const addReview = async (
      req: ServiceRequest,
      rating: number,
      comment: string,
    ) => {
      const review = await em.save(
        em.create(Review, {
          requestId: req.id,
          listingId: req.listingId,
          providerId: req.providerId,
          authorId: req.customerId,
          rating,
          comment,
        }),
      );
      const all = await em.find(Review, {
        where: { listingId: req.listingId, isHidden: false },
      });
      const avg = all.reduce((s, r) => s + r.rating, 0) / all.length;
      await em.update(
        Listing,
        { id: req.listingId },
        {
          ratingAverage: Math.round(avg * 100) / 100,
          ratingCount: all.length,
        },
      );
      return review;
    };

    const lina = 'user@essentially.app';
    const omar = 'omar@essentially.app';
    const maya = 'maya@essentially.app';

    const r1 = await makeRequest(
      lina,
      'gasRefill',
      RequestStatus.COMPLETED,
      12,
      {
        message: 'Second floor, please ring twice.',
        providerNote: 'Delivered and connected.',
      },
    );
    await addReview(
      r1,
      5,
      'Arrived within an hour and checked the regulator too. Highly recommended!',
    );

    const r2 = await makeRequest(omar, 'gasLine', RequestStatus.COMPLETED, 20);
    await addReview(
      r2,
      4,
      'Clean installation, slightly later than planned but great work.',
    );

    const r3 = await makeRequest(maya, 'dish', RequestStatus.COMPLETED, 8);
    await addReview(r3, 5, 'Perfect signal on every channel now.');

    await makeRequest(lina, 'tankClean', RequestStatus.ACCEPTED, 2, {
      message: 'Tank is on the roof, building has an elevator.',
      providerNote: 'Booked for Saturday 9am.',
      preferredDate: new Date(Date.now() + 2 * DAY),
    });
    await makeRequest(omar, 'gasLeak', RequestStatus.PENDING, 0.2, {
      message: 'Smell of gas near the oven since this morning.',
    });
    await makeRequest(maya, 'receiver', RequestStatus.PENDING, 0.5);
    await makeRequest(lina, 'fiber', RequestStatus.PENDING, 1, {
      message: 'Is installation possible this week?',
    });
    await makeRequest(omar, 'gen5a', RequestStatus.REJECTED, 5, {
      providerNote: 'Sorry, our Achrafieh line is at full capacity.',
    });
    await makeRequest(lina, 'heater', RequestStatus.CANCELLED, 9, {
      cancelledAt: new Date(Date.now() - 8 * DAY),
    });

    const shady = await makeRequest(
      lina,
      'shadyAc',
      RequestStatus.COMPLETED,
      6,
    );
    const badReview = await addReview(
      shady,
      1,
      'Charged me $60 instead of $5 and the AC still does not work. Total scam.',
    );

    const quickCash = providers.get('quickcash@essentially.app')!;
    const shadyListing = listings.get('shadyAc')!;
    await em.save([
      em.create(Report, {
        reporterId: customers.get(lina)!.id,
        targetType: ReportTargetType.LISTING,
        targetUserId: quickCash.id,
        targetListingId: shadyListing.id,
        reason: ReportReason.MISLEADING_PRICING,
        details:
          'Listed at $5 but I was charged $60 on site and asked to pay upfront by transfer.',
      }),
      em.create(Report, {
        reporterId: customers.get(omar)!.id,
        targetType: ReportTargetType.USER,
        targetUserId: quickCash.id,
        reason: ReportReason.FRAUD,
        details:
          'Asked me to wire a deposit before the visit and then stopped answering calls.',
      }),
      em.create(Report, {
        reporterId: quickCash.id,
        targetType: ReportTargetType.REVIEW,
        targetUserId: customers.get(lina)!.id,
        targetListingId: shadyListing.id,
        targetReviewId: badReview.id,
        reason: ReportReason.HARASSMENT,
        details:
          'This review is fake and damages my business. Please remove it.',
      }),
    ]);
  });

  logger.log(
    'Demo data created. Demo accounts (password: ' + DEMO_PASSWORD + '):',
  );
  logger.log('  customer : user@essentially.app');
  logger.log('  provider : provider@essentially.app');
  logger.log(
    '  admin    : ' +
      (process.env.ADMIN_EMAIL ?? 'admin@essentially.app') +
      ' (password from ADMIN_PASSWORD in .env)',
  );
  await app.close();
}

seed().catch((err) => {
  console.error(err);
  process.exit(1);
});
