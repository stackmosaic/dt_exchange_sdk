import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Enum defining all possible events coming from the Native SDK
enum DtEventType {
  initialized,
  adLoaded,
  adLoadFailed,
  adImpression,
  adClicked,
  adShowFailed,
  adDismissed,
  adRewarded,
  unknown,
}

/// A wrapper class to hold event type and extra data (like error messages)
class DtEvent {
  final DtEventType type;
  final Map<dynamic, dynamic>? data;

  DtEvent(this.type, this.data);
}

class DtExchangeSdk {
  static const MethodChannel _channel = MethodChannel('dt_exchange_sdk');
  static const EventChannel _eventChannel = EventChannel(
    'dt_exchange_sdk_events',
  );

  /// Initialize the SDK.
  static Future<void> initialize({required String appId}) async {
    await _channel.invokeMethod('initialize', {'appId': appId});
  }

  // -----------------------------------------------------------------------
  // Rewarded Video
  // -----------------------------------------------------------------------

  static Future<void> loadRewardedVideo({required String spotId}) async {
    await _channel.invokeMethod('loadRewardedVideo', {'spotId': spotId});
  }

  static Future<void> showRewardedVideo() async {
    await _channel.invokeMethod('showRewardedVideo');
  }

  // -----------------------------------------------------------------------
  // Interstitial Ad (New)
  // -----------------------------------------------------------------------

  /// Request to load an Interstitial Ad (Video or Static).
  static Future<void> loadInterstitial({required String spotId}) async {
    await _channel.invokeMethod('loadInterstitial', {'spotId': spotId});
  }

  /// Show the loaded Interstitial Ad.
  static Future<void> showInterstitial() async {
    await _channel.invokeMethod('showInterstitial');
  }

  // -----------------------------------------------------------------------
  // Event Stream
  // -----------------------------------------------------------------------

  static Stream<DtEvent> get onEvent {
    return _eventChannel.receiveBroadcastStream().map((dynamic event) {
      final Map<dynamic, dynamic> map = event;
      final String typeStr = map['type'];

      DtEventType type;
      switch (typeStr) {
        case 'onInitialized':
          type = DtEventType.initialized;
          break;
        case 'onAdLoaded':
          type = DtEventType.adLoaded;
          break;
        case 'onAdLoadFailed':
          type = DtEventType.adLoadFailed;
          break;
        case 'onAdImpression':
          type = DtEventType.adImpression;
          break;
        case 'onAdClicked':
          type = DtEventType.adClicked;
          break;
        case 'onAdShowFailed':
          type = DtEventType.adShowFailed;
          break;
        case 'onAdDismissed':
          type = DtEventType.adDismissed;
          break;
        case 'onAdRewarded':
          type = DtEventType.adRewarded;
          break;
        default:
          type = DtEventType.unknown;
      }
      return DtEvent(type, map);
    });
  }
}
