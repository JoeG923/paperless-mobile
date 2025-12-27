import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:paperless_mobile/main.dart' as app;

void main() {
  patrolTest('app launches', ($) async {
    app.main();
    await $.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
