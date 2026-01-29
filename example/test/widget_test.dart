import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dt_exchange_sdk_example/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('1. Initialize SDK'), findsOneWidget);
  });
}
