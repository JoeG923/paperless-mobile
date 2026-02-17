import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  group('CustomFieldModel', () {
    test('parses server snake_case payload and serializes back', () {
      final field = CustomFieldModel.fromJson({
        'id': 7,
        'name': 'Invoice Number',
        'data_type': 'string',
        'extra_data': {
          'select_options': [
            {'id': 'a', 'label': 'A'},
          ],
        },
        'document_count': 10,
      });

      expect(field.id, 7);
      expect(field.name, 'Invoice Number');
      expect(field.dataType, CustomFieldDataType.string);
      expect(field.documentCount, 10);
      expect(field.toJson()['data_type'], 'string');
      expect(field.toJson()['extra_data'], isA<Map<String, dynamic>>());
    });

    test('maps legacy dataType values for backwards compatibility', () {
      final textField = CustomFieldModel.fromJson({
        'id': 1,
        'name': 'Legacy Text',
        'dataType': 'text',
      });
      final numberField = CustomFieldModel.fromJson({
        'id': 2,
        'name': 'Legacy Number',
        'dataType': 'number',
      });

      expect(textField.dataType, CustomFieldDataType.string);
      expect(numberField.dataType, CustomFieldDataType.float);
    });
  });

  group('CustomFieldInstance', () {
    test('uses field key for server compatibility', () {
      const instance = CustomFieldInstance(id: 5, value: 'value');
      expect(instance.toJson(), {'field': 5, 'value': 'value'});
      expect(
        CustomFieldInstance.fromJson({'field': 5, 'value': true}).value,
        true,
      );
    });
  });
}
