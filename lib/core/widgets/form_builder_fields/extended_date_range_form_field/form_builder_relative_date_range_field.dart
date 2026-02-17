import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class FormBuilderRelativeDateRangePicker extends StatefulWidget {
  final String name;
  final RelativeDateRangeQuery initialValue;
  final void Function(RelativeDateRangeQuery? query)? onChanged;
  const FormBuilderRelativeDateRangePicker({
    super.key,
    required this.name,
    required this.initialValue,
    this.onChanged,
  });

  @override
  State<FormBuilderRelativeDateRangePicker> createState() =>
      _FormBuilderRelativeDateRangePickerState();
}

class _FormBuilderRelativeDateRangePickerState
    extends State<FormBuilderRelativeDateRangePicker> {
  late int _offset;
  late final TextEditingController _offsetTextEditingController;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialValue.offset;
    _offsetTextEditingController = TextEditingController(
      text: widget.initialValue.offset.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<RelativeDateRangeQuery>(
      name: widget.name,
      initialValue: widget.initialValue,
      onChanged: widget.onChanged?.call,
      builder: (field) => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.of(context)!.last),
              SizedBox(
                width: 80,
                child: TextFormField(
                  decoration: InputDecoration(labelText: S.of(context)!.amount),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  // validator: (value) { //TODO: Check if this is required
                  // do numeric validation
                  // },
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) {
                      setState(() {
                        _offset = parsed;
                      });
                      field.didChange((field.value)?.copyWith(offset: parsed));
                    }
                  },
                  controller: _offsetTextEditingController,
                ),
              ),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<DateRangeUnit?>(
                  initialValue: field.value?.unit,
                  items: DateRangeUnit.values
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(
                            _dateRangeUnitToLocalizedString(unit, _offset),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      field.didChange(field.value!.copyWith(unit: value)),
                  decoration: InputDecoration(
                    labelText: S.of(context)!.timeUnit,
                  ),
                ),
              ),
            ],
          ),
          // RelativeDateRangePickerHelper(
          //   field: field,
          //   onChanged: (value) {
          //     if (value is RelativeDateRangeQuery) {
          //       setState(() => _offset = value.offset);
          //       _offsetTextEditingController.text = _offset.toString();
          //     }
          //   },
          // ),
        ],
      ),
    );
  }

  String _dateRangeUnitToLocalizedString(DateRangeUnit unit, int? count) {
    switch (unit) {
      case DateRangeUnit.day:
        return S.of(context)!.days(count ?? 1);
      case DateRangeUnit.week:
        return S.of(context)!.weeks(count ?? 1);
      case DateRangeUnit.month:
        return S.of(context)!.months(count ?? 1);
      case DateRangeUnit.year:
        return S.of(context)!.years(count ?? 1);
    }
  }
}
