import { serializeApiResponse, toSafeApiId } from '../src/api/serialization';

describe('toSafeApiId', () => {
  it('converts a simple BIGINT-as-string id to a number', () => {
    const result = toSafeApiId('1');
    expect(result).toBe(1);
    expect(typeof result).toBe('number');
  });

  it('converts a nested id the same way (module callers pass the nested value directly)', () => {
    const payload = { shop: { id: '1' } };
    const converted = { shop: { id: toSafeApiId(payload.shop.id, 'shop.id') } };
    expect(converted).toEqual({ shop: { id: 1 } });
    expect(typeof converted.shop.id).toBe('number');
  });

  it('converts every id in an array of rows', () => {
    const rows = [{ id: '1' }, { id: '2' }];
    const converted = rows.map((row) => ({ id: toSafeApiId(row.id) }));
    expect(converted).toEqual([{ id: 1 }, { id: 2 }]);
  });

  it('leaves null and undefined untouched (nullable FK columns)', () => {
    expect(toSafeApiId(null)).toBeNull();
    expect(toSafeApiId(undefined)).toBeUndefined();
  });

  it('does not touch numeric strings that are not declared as ids', () => {
    const raw = { id: '1', phone: '123456', reference: '00123', postalCode: '501' };
    const dto = {
      id: toSafeApiId(raw.id, 'id'),
      phone: raw.phone,
      reference: raw.reference,
      postalCode: raw.postalCode,
    };

    expect(typeof dto.id).toBe('number');
    expect(dto.id).toBe(1);
    expect(typeof dto.phone).toBe('string');
    expect(dto.phone).toBe('123456');
    expect(typeof dto.reference).toBe('string');
    expect(dto.reference).toBe('00123');
    expect(typeof dto.postalCode).toBe('string');
    expect(dto.postalCode).toBe('501');
  });

  it('accepts a value already at Number.MAX_SAFE_INTEGER', () => {
    const value = String(Number.MAX_SAFE_INTEGER);
    const result = toSafeApiId(value);
    expect(result).toBe(Number.MAX_SAFE_INTEGER);
    expect(typeof result).toBe('number');
  });

  it('accepts a safe value just below Number.MAX_SAFE_INTEGER', () => {
    const value = String(Number.MAX_SAFE_INTEGER - 1);
    expect(toSafeApiId(value)).toBe(Number.MAX_SAFE_INTEGER - 1);
  });

  it('throws instead of silently truncating a value above Number.MAX_SAFE_INTEGER', () => {
    const unsafe = String(BigInt(Number.MAX_SAFE_INTEGER) + 1n);
    expect(() => toSafeApiId(unsafe)).toThrow(/safe integer range/);
  });

  it('throws on a non-integer value rather than guessing', () => {
    expect(() => toSafeApiId('not-an-id')).toThrow(/not a valid integer/);
  });
});

describe('serializeApiResponse (path-based variant)', () => {
  it('converts only the explicitly declared id paths, including nested and array paths', () => {
    const payload = {
      user: { id: '1', phone: '123456' },
      metadata: { count: '2' },
      items: [{ id: '3', quantity: '4' }],
    };

    const result = serializeApiResponse(payload, ['user.id', 'items[].id']);

    expect(result).toEqual({
      user: { id: 1, phone: '123456' },
      metadata: { count: '2' },
      items: [{ id: 3, quantity: '4' }],
    });
    expect(typeof result.user.id).toBe('number');
    expect(typeof result.user.phone).toBe('string');
    expect(typeof result.metadata.count).toBe('string');
    expect(typeof result.items[0].id).toBe('number');
  });

  it('does not mutate the original object (defensive clone)', () => {
    const payload = { id: '1' };
    const result = serializeApiResponse(payload, ['id']);
    expect(payload.id).toBe('1');
    expect(result.id).toBe(1);
  });

  it('propagates the safe-integer-range error for a declared path', () => {
    expect(() =>
      serializeApiResponse({ user: { id: '9007199254740992' } }, ['user.id']),
    ).toThrow(/safe integer range/);
  });
});
