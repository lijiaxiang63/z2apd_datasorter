import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:z2apd_datasorter/main.dart';
import 'package:z2apd_datasorter/providers/rules_provider.dart';
import 'package:z2apd_datasorter/providers/conversion_provider.dart';
import 'package:z2apd_datasorter/providers/update_provider.dart';

void main() {
  testWidgets('App renders title', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => RulesProvider()),
          ChangeNotifierProvider(create: (_) => ConversionProvider()),
          ChangeNotifierProvider(create: (_) => UpdateProvider()),
        ],
        child: const Z2apdDatasorterApp(),
      ),
    );

    expect(find.text('z2apd_datasorter'), findsOneWidget);
    expect(find.text('Version v1.1.3+2'), findsOneWidget);
  });
}
