import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:apd_dcm2niix/main.dart';
import 'package:apd_dcm2niix/providers/rules_provider.dart';
import 'package:apd_dcm2niix/providers/conversion_provider.dart';

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
        ],
        child: const ApdDcm2niixApp(),
      ),
    );

    expect(find.text('APD DICOM -> NIfTI Converter'), findsOneWidget);
    expect(find.text('Version v1.1.0+1'), findsOneWidget);
  });
}
