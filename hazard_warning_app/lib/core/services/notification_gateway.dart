import 'package:hazard_warning_app/core/models/models.dart';

/// Demo stand-in for the Notification Gateway. Returns a deterministic
/// per-channel outcome so every run of the demo looks the same.
class NotificationGateway {
  const NotificationGateway();

  // Share of recipients with the app in the background (audible applies).
  static const _audibleShare = 0.42;
  static const _failureRate = {
    AlertChannel.push: 0.031,
    AlertChannel.sms: 0.012,
    AlertChannel.audible: 0.045,
  };

  List<ChannelDelivery> dispatch(int recipients) {
    return AlertChannel.values.map((channel) {
      final targeted = channel == AlertChannel.audible
          ? (recipients * _audibleShare).round()
          : recipients;
      final failed = (targeted * _failureRate[channel]!).round();
      return ChannelDelivery(
        channel: channel,
        targeted: targeted,
        delivered: targeted - failed,
        failed: failed,
      );
    }).toList();
  }

  /// Resends failed deliveries on each channel's fallback. A few remain
  /// unreachable (e.g. handsets switched off).
  List<ChannelDelivery> retryFailed(List<ChannelDelivery> deliveries) {
    return deliveries.map((d) {
      if (d.failed == 0) return d;
      final recovered = (d.failed * 0.92).round();
      return d.copyWith(
        failed: d.failed - recovered,
        recovered: d.recovered + recovered,
        fallback: d.channel.fallback,
      );
    }).toList();
  }
}
