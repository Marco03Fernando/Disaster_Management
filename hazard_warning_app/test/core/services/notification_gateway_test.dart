import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/services/notification_gateway.dart';

void main() {
  const gateway = NotificationGateway();

  ChannelDelivery forChannel(List<ChannelDelivery> all, AlertChannel c) =>
      all.firstWhere((d) => d.channel == c);

  group('dispatch', () {
    test('returns one result per channel, in channel order', () {
      final result = gateway.dispatch(1000);

      expect(result.map((d) => d.channel), AlertChannel.values);
    });

    test('push and SMS target every recipient; audible targets 42%', () {
      final result = gateway.dispatch(10000);

      expect(forChannel(result, AlertChannel.push).targeted, 10000);
      expect(forChannel(result, AlertChannel.sms).targeted, 10000);
      expect(forChannel(result, AlertChannel.audible).targeted, 4200);
    });

    test('applies the demo failure rates (3.1% push, 1.2% SMS, 4.5% audible)',
        () {
      final result = gateway.dispatch(10000);

      expect(forChannel(result, AlertChannel.push).failed, 310);
      expect(forChannel(result, AlertChannel.sms).failed, 120);
      expect(forChannel(result, AlertChannel.audible).failed, 189);
    });

    test('rounds fractional counts to whole citizens (Kelani basin, 12,480)',
        () {
      final result = gateway.dispatch(12480);

      expect(forChannel(result, AlertChannel.audible).targeted, 5242);
      expect(forChannel(result, AlertChannel.push).failed, 387);
      expect(forChannel(result, AlertChannel.sms).failed, 150);
      expect(forChannel(result, AlertChannel.audible).failed, 236);
    });

    test('no retry has happened yet: nothing recovered, no fallback recorded',
        () {
      for (final d in gateway.dispatch(5000)) {
        expect(d.recovered, 0);
        expect(d.fallback, isNull);
      }
    });

    test('zero recipients gives zero targeted, delivered and failed', () {
      for (final d in gateway.dispatch(0)) {
        expect(d.targeted, 0);
        expect(d.delivered, 0);
        expect(d.failed, 0);
        expect(d.successRatio, 1);
      }
    });

    test('a single recipient never produces a negative or fractional outcome',
        () {
      for (final d in gateway.dispatch(1)) {
        expect(d.failed, 0, reason: '${d.channel.name} rounds down to 0');
        expect(d.delivered, d.targeted);
      }
    });

    test('is deterministic: the same input always gives the same outcome', () {
      final a = gateway.dispatch(777);
      final b = gateway.dispatch(777);

      for (var i = 0; i < a.length; i++) {
        expect(a[i].targeted, b[i].targeted);
        expect(a[i].failed, b[i].failed);
      }
    });

    for (final n in [1, 2, 10, 99, 1000, 12480, 21300, 100000]) {
      test('invariant for $n recipients: delivered + failed = targeted', () {
        for (final d in gateway.dispatch(n)) {
          expect(d.delivered + d.failed, d.targeted, reason: d.channel.name);
          expect(d.failed, inInclusiveRange(0, d.targeted));
          expect(d.targeted, lessThanOrEqualTo(n));
        }
      });
    }

    test('audible never targets more recipients than push', () {
      final result = gateway.dispatch(50000);

      expect(forChannel(result, AlertChannel.audible).targeted,
          lessThan(forChannel(result, AlertChannel.push).targeted));
    });
  });

  group('retryFailed', () {
    test('recovers 92% of failures on each channel and records the fallback',
        () {
      final before = gateway.dispatch(10000);

      final after = gateway.retryFailed(before);

      final push = forChannel(after, AlertChannel.push);
      expect(push.recovered, 285); // round(310 * 0.92)
      expect(push.failed, 25);
      expect(push.fallback, AlertChannel.sms);

      final sms = forChannel(after, AlertChannel.sms);
      expect(sms.recovered, 110);
      expect(sms.failed, 10);
      expect(sms.fallback, AlertChannel.push);

      final audible = forChannel(after, AlertChannel.audible);
      expect(audible.recovered, 174);
      expect(audible.failed, 15);
      expect(audible.fallback, AlertChannel.sms);
    });

    test('keeps the original first-attempt delivery count', () {
      final before = gateway.dispatch(10000);

      final after = gateway.retryFailed(before);

      for (var i = 0; i < before.length; i++) {
        expect(after[i].delivered, before[i].delivered);
        expect(after[i].targeted, before[i].targeted);
      }
    });

    test('moves citizens from failed to recovered without losing anyone', () {
      final before = gateway.dispatch(10000);

      final after = gateway.retryFailed(before);

      for (var i = 0; i < before.length; i++) {
        expect(after[i].failed + after[i].recovered, before[i].failed);
        expect(after[i].totalDelivered, greaterThan(before[i].totalDelivered));
        expect(after[i].totalDelivered, lessThanOrEqualTo(after[i].targeted));
      }
    });

    test('leaves a channel with no failures unchanged', () {
      final clean = ChannelDelivery(
        channel: AlertChannel.push,
        targeted: 50,
        delivered: 50,
        failed: 0,
      );

      final after = gateway.retryFailed([clean]);

      expect(after.single.failed, 0);
      expect(after.single.recovered, 0);
      expect(after.single.fallback, isNull,
          reason: 'no fallback was used, so none is recorded');
    });

    test('small failure counts still leave unreachable citizens or recover all',
        () {
      final one = ChannelDelivery(
        channel: AlertChannel.sms,
        targeted: 10,
        delivered: 9,
        failed: 1,
      );

      final after = gateway.retryFailed([one]).single;

      expect(after.failed + after.recovered, 1);
      expect(after.fallback, AlertChannel.push);
    });

    test('an empty list gives an empty list', () {
      expect(gateway.retryFailed(const []), isEmpty);
    });

    test('retrying again keeps recovering but never exceeds the target', () {
      final once = gateway.retryFailed(gateway.dispatch(10000));

      final twice = gateway.retryFailed(once);

      for (var i = 0; i < once.length; i++) {
        expect(twice[i].recovered, greaterThanOrEqualTo(once[i].recovered));
        expect(twice[i].totalDelivered, lessThanOrEqualTo(twice[i].targeted));
      }
    });
  });
}
