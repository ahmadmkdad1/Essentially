import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';

// Must be set before the AppModule (and its ConfigModule) is evaluated.
process.env.NODE_ENV = 'test';
process.env.DB_TYPE = 'sqlite';
process.env.DB_SQLITE_PATH = ':memory:';
process.env.DB_SYNCHRONIZE = 'true';
process.env.JWT_SECRET = 'e2e-test-secret-that-is-long-enough';
process.env.ADMIN_EMAIL = 'admin@test.app';
process.env.ADMIN_PASSWORD = 'Admin@12345';

const BEIRUT = { lat: 33.8938, lng: 35.5018 };
const TRIPOLI = { lat: 34.4367, lng: 35.8497 };

describe('Essentially marketplace (e2e)', () => {
  let app: INestApplication;
  let http: ReturnType<typeof request>;

  let userToken: string;
  let providerToken: string;
  let adminToken: string;
  let providerId: string;
  let categoryId: string;
  let listingId: string;
  let requestId: string;

  const auth = (token: string) => ({ Authorization: `Bearer ${token}` });

  beforeAll(async () => {
    const { AppModule } = await import('../src/app.module.js');
    const { setupApp } = await import('../src/setup-app.js');
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = setupApp(moduleRef.createNestApplication());
    await app.init();
    http = request(app.getHttpServer());
  });

  afterAll(async () => {
    await app?.close();
  });

  it('reports healthy', async () => {
    const res = await http.get('/api/health').expect(200);
    expect(res.body).toMatchObject({ status: 'ok', database: 'up' });
  });

  describe('auth', () => {
    it('registers a customer with a location', async () => {
      const res = await http
        .post('/api/auth/register')
        .send({
          fullName: 'Lina Customer',
          email: 'Lina@Example.com',
          password: 'Secret123',
          role: 'USER',
          latitude: BEIRUT.lat,
          longitude: BEIRUT.lng,
          address: 'Hamra, Beirut',
        })
        .expect(201);
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.user).toMatchObject({
        email: 'lina@example.com',
        role: 'USER',
      });
      expect(res.body.user.passwordHash).toBeUndefined();
      userToken = res.body.accessToken;
    });

    it('requires a business name for providers', async () => {
      await http
        .post('/api/auth/register')
        .send({
          fullName: 'No Biz',
          email: 'nobiz@example.com',
          password: 'Secret123',
          role: 'PROVIDER',
        })
        .expect(400);
    });

    it('registers a provider', async () => {
      const res = await http
        .post('/api/auth/register')
        .send({
          fullName: 'Karim Provider',
          email: 'karim@example.com',
          password: 'Secret123',
          role: 'PROVIDER',
          businessName: 'Karim Gas Co.',
          phone: '+961 70 000 000',
        })
        .expect(201);
      providerToken = res.body.accessToken;
      providerId = res.body.user.id;
    });

    it('never lets anyone self-register as admin', async () => {
      await http
        .post('/api/auth/register')
        .send({
          fullName: 'Evil',
          email: 'evil@example.com',
          password: 'Secret123',
          role: 'ADMIN',
        })
        .expect(400);
    });

    it('rejects duplicate emails', async () => {
      await http
        .post('/api/auth/register')
        .send({
          fullName: 'Dup',
          email: 'lina@example.com',
          password: 'Secret123',
          role: 'USER',
        })
        .expect(409);
    });

    it('rejects wrong credentials and logs in the bootstrapped admin', async () => {
      await http
        .post('/api/auth/login')
        .send({ email: 'admin@test.app', password: 'wrong-pass' })
        .expect(401);
      const res = await http
        .post('/api/auth/login')
        .send({ email: 'admin@test.app', password: 'Admin@12345' })
        .expect(200);
      expect(res.body.user.role).toBe('ADMIN');
      adminToken = res.body.accessToken;
    });

    it('protects private routes', async () => {
      await http.get('/api/users/me').expect(401);
      await http.get('/api/users/me').set(auth(userToken)).expect(200);
    });
  });

  describe('services', () => {
    it('lists the default categories', async () => {
      const res = await http.get('/api/categories').expect(200);
      expect(res.body.length).toBeGreaterThanOrEqual(5);
      categoryId = res.body.find((c: { slug: string }) => c.slug === 'gas').id;
    });

    it('only lets providers publish services', async () => {
      const body = {
        title: 'Gas cylinder refill',
        description:
          'Same-day delivery and safe installation of 10kg cylinders.',
        price: 12.5,
        categoryId: '',
        latitude: BEIRUT.lat + 0.01,
        longitude: BEIRUT.lng + 0.01,
        address: 'Verdun, Beirut',
        serviceRadiusKm: 20,
      };
      body.categoryId = categoryId;
      await http
        .post('/api/services')
        .set(auth(userToken))
        .send(body)
        .expect(403);
      const res = await http
        .post('/api/services')
        .set(auth(providerToken))
        .send(body)
        .expect(201);
      expect(res.body).toMatchObject({
        title: 'Gas cylinder refill',
        price: 12.5,
        status: 'ACTIVE',
      });
      listingId = res.body.id;
    });

    it('finds the service near the customer with its distance', async () => {
      const res = await http
        .get('/api/services')
        .query({ lat: BEIRUT.lat, lng: BEIRUT.lng, radiusKm: 10 })
        .expect(200);
      expect(res.body.total).toBe(1);
      const [item] = res.body.items;
      expect(item.id).toBe(listingId);
      expect(item.distanceKm).toBeGreaterThan(0);
      expect(item.distanceKm).toBeLessThan(3);
      expect(item.withinServiceArea).toBe(true);
      expect(item.provider.businessName).toBe('Karim Gas Co.');
      expect(item.provider.email).toBeUndefined();
    });

    it('does not show the service to customers far away', async () => {
      const res = await http
        .get('/api/services')
        .query({ lat: TRIPOLI.lat, lng: TRIPOLI.lng, radiusKm: 10 })
        .expect(200);
      expect(res.body.total).toBe(0);
    });

    it('validates search parameters', async () => {
      await http.get('/api/services').query({ lat: 200, lng: 0 }).expect(400);
    });
  });

  describe('request lifecycle', () => {
    it('lets a customer request a service using their saved location', async () => {
      const res = await http
        .post('/api/requests')
        .set(auth(userToken))
        .send({ listingId, message: 'Please call before arriving.' })
        .expect(201);
      expect(res.body).toMatchObject({
        status: 'PENDING',
        quotedPrice: 12.5,
        address: 'Hamra, Beirut',
      });
      requestId = res.body.id;
    });

    it('prevents duplicate open requests', async () => {
      await http
        .post('/api/requests')
        .set(auth(userToken))
        .send({ listingId })
        .expect(409);
    });

    it('shows the request to the provider with customer contact details', async () => {
      const res = await http
        .get('/api/requests')
        .set(auth(providerToken))
        .expect(200);
      expect(res.body.total).toBe(1);
      expect(res.body.items[0].customer.fullName).toBe('Lina Customer');
    });

    it('does not let the customer accept their own request', async () => {
      await http
        .patch(`/api/requests/${requestId}/accept`)
        .set(auth(userToken))
        .send({})
        .expect(403);
    });

    it('cannot complete before accepting', async () => {
      await http
        .patch(`/api/requests/${requestId}/complete`)
        .set(auth(providerToken))
        .send({})
        .expect(400);
    });

    it('accepts and completes the request', async () => {
      await http
        .patch(`/api/requests/${requestId}/accept`)
        .set(auth(providerToken))
        .send({ note: 'On my way at 10am' })
        .expect(200)
        .expect((res) => expect(res.body.status).toBe('ACCEPTED'));
      await http
        .patch(`/api/requests/${requestId}/complete`)
        .set(auth(providerToken))
        .send({})
        .expect(200)
        .expect((res) => expect(res.body.status).toBe('COMPLETED'));
    });

    it('lets the customer review a completed request once', async () => {
      await http
        .post('/api/reviews')
        .set(auth(userToken))
        .send({ requestId, rating: 5, comment: 'Fast and professional.' })
        .expect(201);
      await http
        .post('/api/reviews')
        .set(auth(userToken))
        .send({ requestId, rating: 4 })
        .expect(409);

      const listing = await http.get(`/api/services/${listingId}`).expect(200);
      expect(listing.body).toMatchObject({ ratingAverage: 5, ratingCount: 1 });
    });

    it('computes provider dashboard stats', async () => {
      const res = await http
        .get('/api/requests/stats')
        .set(auth(providerToken))
        .expect(200);
      expect(res.body).toMatchObject({
        totalRequests: 1,
        completedRevenue: 12.5,
        acceptanceRate: 1,
        ratingAverage: 5,
      });
    });

    it('exposes a public provider profile', async () => {
      const res = await http.get(`/api/providers/${providerId}`).expect(200);
      expect(res.body.stats.completedJobs).toBe(1);
      expect(res.body.listings).toHaveLength(1);
      expect(res.body.reviews).toHaveLength(1);
    });
  });

  describe('moderation', () => {
    let reportId: string;

    it('lets a customer report a service', async () => {
      const res = await http
        .post('/api/reports')
        .set(auth(userToken))
        .send({
          targetType: 'LISTING',
          targetId: listingId,
          reason: 'MISLEADING_PRICING',
          details: 'The final price was double the listed one.',
        })
        .expect(201);
      reportId = res.body.id;
      expect(res.body.targetUserId).toBe(providerId);
    });

    it('keeps the admin area admin-only', async () => {
      await http.get('/api/admin/stats').set(auth(userToken)).expect(403);
      await http.get('/api/admin/stats').set(auth(providerToken)).expect(403);
    });

    it('shows the open report in the admin queue', async () => {
      const res = await http
        .get('/api/admin/reports')
        .query({ status: 'OPEN' })
        .set(auth(adminToken))
        .expect(200);
      expect(res.body.total).toBe(1);
      expect(res.body.items[0].targetUser.openReports).toBe(1);
    });

    it('removes the listing when resolving the report', async () => {
      const res = await http
        .post(`/api/admin/reports/${reportId}/resolve`)
        .set(auth(adminToken))
        .send({
          action: 'REMOVE_LISTING',
          note: 'Confirmed misleading pricing.',
        })
        .expect(201);
      expect(res.body).toMatchObject({
        status: 'RESOLVED',
        actionTaken: 'REMOVE_LISTING',
      });

      const search = await http
        .get('/api/services')
        .query({ lat: BEIRUT.lat, lng: BEIRUT.lng })
        .expect(200);
      expect(search.body.total).toBe(0);
      await http.get(`/api/services/${listingId}`).expect(404);
      // The owner can still see why it was removed.
      const own = await http
        .get(`/api/services/${listingId}`)
        .set(auth(providerToken))
        .expect(200);
      expect(own.body).toMatchObject({
        status: 'REMOVED',
        removalReason: 'Confirmed misleading pricing.',
      });
      // ...but cannot bring it back.
      await http
        .patch(`/api/services/${listingId}/status`)
        .set(auth(providerToken))
        .send({ status: 'ACTIVE' })
        .expect(403);
    });

    it('cannot resolve the same report twice', async () => {
      await http
        .post(`/api/admin/reports/${reportId}/resolve`)
        .set(auth(adminToken))
        .send({ action: 'NONE', note: 'again' })
        .expect(400);
    });

    it('suspends a provider and blocks their access immediately', async () => {
      await http
        .patch(`/api/admin/users/${providerId}/status`)
        .set(auth(adminToken))
        .send({
          status: 'SUSPENDED',
          reason: 'Repeated misleading pricing',
          suspendDays: 3,
        })
        .expect(200);

      const existingSession = await http
        .get('/api/users/me')
        .set(auth(providerToken))
        .expect(403);
      expect(existingSession.body.code).toBe('ACCOUNT_SUSPENDED');

      const login = await http
        .post('/api/auth/login')
        .send({ email: 'karim@example.com', password: 'Secret123' })
        .expect(403);
      expect(login.body.message).toContain('suspended');
    });

    it('protects admin accounts from moderation', async () => {
      const me = await http
        .get('/api/users/me')
        .set(auth(adminToken))
        .expect(200);
      await http
        .patch(`/api/admin/users/${me.body.id}/status`)
        .set(auth(adminToken))
        .send({ status: 'BANNED', reason: 'test' })
        .expect(403);
    });

    it('records every action in the audit log', async () => {
      const res = await http
        .get('/api/admin/audit-log')
        .set(auth(adminToken))
        .expect(200);
      const actions = res.body.items.map((e: { action: string }) => e.action);
      expect(actions).toEqual(
        expect.arrayContaining(['REMOVE_LISTING', 'SUSPEND_USER']),
      );
    });

    it('summarises platform health for the dashboard', async () => {
      const res = await http
        .get('/api/admin/stats')
        .set(auth(adminToken))
        .expect(200);
      expect(res.body.users.byRole).toMatchObject({
        USER: 1,
        PROVIDER: 1,
        ADMIN: 1,
      });
      expect(res.body.users.byStatus.SUSPENDED).toBe(1);
      expect(res.body.listings.byStatus.REMOVED).toBe(1);
      expect(res.body.reports.byStatus.RESOLVED).toBe(1);
    });
  });
});
