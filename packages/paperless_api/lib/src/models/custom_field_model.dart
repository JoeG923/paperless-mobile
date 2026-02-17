import 'package:equatable/equatable.dart';
import 'package:paperless_api/src/models/custom_field_data_type.dart';

class CustomFieldModel with EquatableMixin {
  final int? id;
  final String? name;
  final CustomFieldDataType dataType;
  final Map<String, dynamic>? extraData;
  final int? documentCount;

  CustomFieldModel({
    this.id,
    required this.name,
    required this.dataType,
    this.extraData,
    this.documentCount,
  });

  @override
  List<Object?> get props => [id, name, dataType, extraData, documentCount];

  factory CustomFieldModel.fromJson(Map<String, dynamic> json) {
    return CustomFieldModel(
      id: _tryInt(json['id']),
      name: json['name'] as String?,
      dataType: CustomFieldDataType.fromWireValue(
        (json['data_type'] ?? json['dataType'] ?? 'string').toString(),
      ),
      extraData: (json['extra_data'] as Map?)?.cast<String, dynamic>(),
      documentCount: _tryInt(json['document_count']),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      if (id != null) 'id': id,
      'name': name,
      'data_type': dataType.wireValue,
    };
    if (extraData != null) {
      json['extra_data'] = extraData;
    }
    if (documentCount != null) {
      json['document_count'] = documentCount;
    }
    return json;
  }
}

/// An instance of the [CustomFieldModel].
class CustomFieldInstance {
  final int? id;
  final Object? value;

  const CustomFieldInstance({this.id, this.value});

  factory CustomFieldInstance.fromJson(Map<String, dynamic> json) {
    return CustomFieldInstance(
      id: _tryInt(json['field'] ?? json['id']),
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {if (id != null) 'field': id, 'value': value};
  }
}

int? _tryInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}
