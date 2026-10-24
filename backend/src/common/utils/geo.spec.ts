import { boundingBox, haversineKm } from './geo.js';

describe('geo utils', () => {
  const beirut = { latitude: 33.8938, longitude: 35.5018 };
  const byblos = { latitude: 34.1211, longitude: 35.6481 };

  it('computes zero distance for the same point', () => {
    expect(haversineKm(beirut, beirut)).toBe(0);
  });

  it('computes a known distance (Beirut -> Byblos ~ 28.5 km)', () => {
    const d = haversineKm(beirut, byblos);
    expect(d).toBeGreaterThan(27);
    expect(d).toBeLessThan(30);
  });

  it('is symmetric', () => {
    expect(haversineKm(beirut, byblos)).toBeCloseTo(
      haversineKm(byblos, beirut),
      10,
    );
  });

  it('builds a bounding box that contains points inside the radius', () => {
    const box = boundingBox(beirut, 30);
    expect(byblos.latitude).toBeGreaterThan(box.minLat);
    expect(byblos.latitude).toBeLessThan(box.maxLat);
    expect(byblos.longitude).toBeGreaterThan(box.minLng);
    expect(byblos.longitude).toBeLessThan(box.maxLng);
  });

  it('excludes points far outside the radius', () => {
    const box = boundingBox(beirut, 10);
    expect(byblos.latitude).toBeGreaterThan(box.maxLat);
  });
});
