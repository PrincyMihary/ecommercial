import { serializeApiResponse } from '../src/api/serialization';

describe('API BIGINT/BIGSERIAL serialization', () => {
  it('converts only explicitly selected ID paths to numbers', () => {
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

  it('does not lose precision for an unsafe BIGINT ID', () => {
    expect(() =>
      serializeApiResponse(
        { user: { id: '9007199254740992' } },
        ['user.id'],
      ),
    ).toThrow(/safe integer range/);
  });

  it('accepts safe BIGINT values returned as strings', () => {
    const result = serializeApiResponse(
      { user: { id: '9007199254740991' } },
      ['user.id'],
    );

    expect(result.user.id).toBe(Number.MAX_SAFE_INTEGER);
    expect(typeof result.user.id).toBe('number');
  });
});
