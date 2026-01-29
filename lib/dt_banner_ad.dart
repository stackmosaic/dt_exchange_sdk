import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DtExchangeBanner extends StatelessWidget {
  final String spotId;
  final double width;
  final double height;

  const DtExchangeBanner({
    super.key,
    required this.spotId,
    this.width = 320,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    const String viewType = 'dt_exchange_banner_view';
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'spotId': spotId,
    };

    final platform = Theme.of(context).platform;

    if (platform == TargetPlatform.android) {
      return SizedBox(
        width: width,
        height: height,
        child: AndroidView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        ),
      );
    } else if (platform == TargetPlatform.iOS) {
      return SizedBox(
        width: width,
        height: height,
        child: UiKitView(
          viewType: viewType,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: const Center(child: Text('Unsupported Platform')),
    );
  }
}
