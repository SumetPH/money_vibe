import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:money_vibe/services/exchange_rate_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExchangeRateService.clearCache();
  });

  tearDown(() {
    ExchangeRateService.clearCache();
  });

  test('returns 1.0 when base and quote are identical', () async {
    const service = ExchangeRateService();
    final rate = await service.fetchRate(base: 'USD', quote: 'USD');
    expect(rate, 1.0);
  });

  test(
    'rounds rates to 4 decimal places matching database numeric(15, 4)',
    () async {
      expect(ExchangeRateService.roundRate(33.964642), 33.9646);
      expect(ExchangeRateService.roundRate(33.96468), 33.9647);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': 'success',
            'base_code': 'USD',
            'rates': {'THB': 33.964642},
          }),
          200,
        );
      });

      final service = ExchangeRateService(client: mockClient);
      final rate = await service.fetchRate(base: 'USD', quote: 'THB');
      expect(rate, 33.9646);
    },
  );

  test(
    'rounds rates to 4 decimal places matching database numeric(15, 4)',
    () async {
      expect(ExchangeRateService.roundRate(33.964642), 33.9646);
      expect(ExchangeRateService.roundRate(33.96468), 33.9647);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': 'success',
            'base_code': 'USD',
            'rates': {'THB': 33.964642},
          }),
          200,
        );
      });

      final service = ExchangeRateService(client: mockClient);
      final rate = await service.fetchRate(base: 'USD', quote: 'THB');
      expect(rate, 33.9646);
    },
  );

  test(
    'fetches successfully from primary API (open.er-api.com) and caches it',
    () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (request.url.host == 'open.er-api.com') {
          return http.Response(
            jsonEncode({
              'result': 'success',
              'base_code': 'USD',
              'rates': {'THB': 34.50, 'EUR': 0.92},
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ExchangeRateService(client: mockClient);

      // Call 1: fetches from network
      final rate1 = await service.fetchRate(base: 'USD', quote: 'THB');
      expect(rate1, 34.50);
      expect(callCount, 1);

      // Call 2: should hit in-memory cache without calling network
      final rate2 = await service.fetchRate(base: 'USD', quote: 'THB');
      expect(rate2, 34.50);
      expect(callCount, 1);

      // Call 3: another quote in the same cached base should also hit cache
      final rate3 = await service.fetchRate(base: 'USD', quote: 'EUR');
      expect(rate3, 0.92);
      expect(callCount, 1);
    },
  );

  test('falls back to Frankfurter when primary API fails', () async {
    var primaryCalled = false;
    var fallbackCalled = false;

    final mockClient = MockClient((request) async {
      if (request.url.host == 'open.er-api.com') {
        primaryCalled = true;
        return http.Response('Service Unavailable', 503);
      }
      if (request.url.host == 'api.frankfurter.dev') {
        fallbackCalled = true;
        return http.Response(
          jsonEncode({
            'amount': 1.0,
            'base': 'USD',
            'date': '2026-11-19',
            'rates': {'THB': 34.25},
          }),
          200,
        );
      }
      return http.Response('Not Found', 404);
    });

    final service = ExchangeRateService(client: mockClient);
    final rate = await service.fetchRate(base: 'USD', quote: 'THB');

    expect(primaryCalled, isTrue);
    expect(fallbackCalled, isTrue);
    expect(rate, 34.25);
  });

  test('falls back to stale cache when both APIs fail', () async {
    final successClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'result': 'success',
          'base_code': 'USD',
          'rates': {'THB': 33.80},
        }),
        200,
      );
    });

    final initialService = ExchangeRateService(client: successClient);
    await initialService.fetchRate(base: 'USD', quote: 'THB');

    // Now simulate both APIs failing
    final failureClient = MockClient((request) async {
      return http.Response('Server Error', 500);
    });

    final failingService = ExchangeRateService(client: failureClient);
    // Force refresh will bypass fresh cache check, but since network fails, it falls back to stale cache
    final rate = await failingService.fetchRate(
      base: 'USD',
      quote: 'THB',
      forceRefresh: true,
    );
    expect(rate, 33.80);
  });

  test('throws exception when both APIs fail and no cache exists', () async {
    final failureClient = MockClient((request) async {
      return http.Response('Server Error', 500);
    });

    final service = ExchangeRateService(client: failureClient);
    expect(() => service.fetchRate(base: 'USD', quote: 'THB'), throwsException);
  });
}
