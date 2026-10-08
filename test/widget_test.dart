import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sogo_customer/main.dart';

void main() {
  testWidgets('SOGO app boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const SogoCustomerApp());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
