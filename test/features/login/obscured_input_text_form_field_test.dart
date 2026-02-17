import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/features/login/view/widgets/form_fields/obscured_input_text_form_field.dart';

void main() {
  testWidgets('does not dispose externally provided focus node', (
    tester,
  ) async {
    final externalFocusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObscuredInputTextFormField(
            focusNode: externalFocusNode,
            label: 'Secret',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    externalFocusNode.dispose();
  });
}
