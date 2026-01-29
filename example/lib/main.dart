import 'dart:io';
import 'package:dt_exchange_sdk/dt_banner_ad.dart';
import 'package:flutter/material.dart';
import 'package:dt_exchange_sdk/dt_exchange_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'Ready';
  bool _isInitialized = false;

  // Replace these IDs with your actual Digital Turbine Console IDs
  // iOS and Android require separate App IDs and Spot IDs

  final String _androidAppId = "YOUR_ANDROID_APP_ID";
  final String _androidRewardedSpotId = "YOUR_ANDROID_REWARDED_SPOT_ID";
  final String _androidInterstitialSpotId = "YOUR_ANDROID_INTERSTITIAL_SPOT_ID";
  final String _androidBannerSpotId = "YOUR_ANDROID_BANNER_SPOT_ID";

  final String _iosAppId = "YOUR_IOS_APP_ID";
  final String _iosRewardedSpotId = "YOUR_IOS_REWARDED_SPOT_ID";
  final String _iosInterstitialSpotId = "YOUR_IOS_INTERSTITIAL_SPOT_ID";
  final String _iosBannerSpotId = "YOUR_IOS_BANNER_SPOT_ID";

  String get _appId => Platform.isAndroid ? _androidAppId : _iosAppId;
  String get _rewardedSpotId =>
      Platform.isAndroid ? _androidRewardedSpotId : _iosRewardedSpotId;
  String get _interstitialSpotId =>
      Platform.isAndroid ? _androidInterstitialSpotId : _iosInterstitialSpotId;
  String get _bannerSpotId =>
      Platform.isAndroid ? _androidBannerSpotId : _iosBannerSpotId;

  @override
  void initState() {
    super.initState();
    _setupSdkListener();
  }

  void _setupSdkListener() {
    DtExchangeSdk.onEvent.listen((event) {
      print("[DT Event] ${event.type} / Data: ${event.data}");

      setState(() {
        switch (event.type) {
          case DtEventType.initialized:
            _isInitialized = true;
            _status = "SDK Initialized ✅";
            break;
          case DtEventType.adLoaded:
            final adType = event.data?['adType'] ?? 'Ad';
            _status = "$adType Loaded! 📥";
            break;
          case DtEventType.adLoadFailed:
            final error = event.data?['error'] ?? 'Unknown';
            _status = "Load Failed ❌ ($error)";
            break;
          case DtEventType.adRewarded:
            _status = "💰 REWARD GIVEN! 💰";
            break;
          case DtEventType.adDismissed:
            _status = "Ad Dismissed 👋";
            break;
          default:
            _status = "Event: ${event.type.name}";
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    print("_appId $_appId ");
    print("_rewardedSpotId $_rewardedSpotId ");
    print("_interstitialSpotId $_interstitialSpotId ");
    print("_bannerSpotId $_bannerSpotId ");

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('DT Exchange Test')),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[200],
                  child: Text(
                    "STATUS: $_status",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    DtExchangeSdk.initialize(appId: _appId);
                  },
                  child: const Text("1. Initialize SDK"),
                ),
                const Divider(height: 30),

                const Text(
                  "Reward Video",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => DtExchangeSdk.loadRewardedVideo(
                          spotId: _rewardedSpotId,
                        ),
                        child: const Text("Load Reward"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => DtExchangeSdk.showRewardedVideo(),
                        child: const Text("Show Reward"),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),

                const Text(
                  "Interstitial",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => DtExchangeSdk.loadInterstitial(
                          spotId: _interstitialSpotId,
                        ),
                        child: const Text("Load Interstitial"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => DtExchangeSdk.showInterstitial(),
                        child: const Text("Show Interstitial"),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),

                const Text(
                  "Banner Ad",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (_isInitialized)
                  Container(
                    alignment: Alignment.center,
                    color: Colors.black12,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: DtExchangeBanner(
                      spotId: _bannerSpotId,
                      width: 320,
                      height: 50,
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text("Please initialize SDK first."),
                  ),
                const SizedBox(height: 5),
                const Center(child: Text("Banner Area (320x50)")),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
