import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_cancel_button.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_confirm_button.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  /*static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }*/

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) {
    /// Converts an rgba value (0-1) into a 2-digit Hex code.
    String hexValue(double rgbaFloating) {
      final rgbaVal = (rgbaFloating * 255).round() & 0xFF;
      assert(rgbaVal == rgbaVal & 0xFF);
      return rgbaVal.toRadixString(16).padLeft(2, '0').toUpperCase();
    }

    return '${leadingHashSign ? '#' : ''}'
        '${hexValue(a)}${hexValue(r)}${hexValue(g)}${hexValue(b)}';
  }
}

enum ColorPickerType { colorPicker, materialPicker, blockPicker }

/// Creates a field for `Color` input selection
class FormBuilderColorPickerField extends FormBuilderField<Color> {
  //TODO: Add documentation
  final TextEditingController? controller;
  final ColorPickerType colorPickerType;
  final TextCapitalization textCapitalization;

  final TextAlign textAlign;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextDirection? textDirection;
  final bool autofocus;

  final bool obscureText;
  final bool autocorrect;
  final MaxLengthEnforcement? maxLengthEnforcement;

  final int maxLines;
  final bool expands;

  final bool showCursor;
  final int? minLines;
  final int? maxLength;
  final VoidCallback? onEditingComplete;
  final ValueChanged<Color>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final double cursorWidth;
  final Radius? cursorRadius;
  final Color? cursorColor;
  final Brightness? keyboardAppearance;
  final EdgeInsets scrollPadding;
  final bool enableInteractiveSelection;
  final InputCounterWidgetBuilder? buildCounter;

  final Widget Function(Color?)? colorPreviewBuilder;

  FormBuilderColorPickerField({
    super.key,
    //From Super
    required super.name,
    super.validator,
    super.initialValue,
    InputDecoration decoration = const InputDecoration(),
    super.onChanged,
    super.valueTransformer,
    super.enabled,
    super.onSaved,
    AutovalidateMode super.autovalidateMode = AutovalidateMode.disabled,
    super.onReset,
    super.focusNode,
    bool readOnly = false,
    this.colorPickerType = ColorPickerType.colorPicker,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.keyboardType,
    this.textInputAction,
    this.style,
    this.strutStyle,
    this.textDirection,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.maxLengthEnforcement,
    this.maxLines = 1,
    this.expands = false,
    this.showCursor = false,
    this.minLines,
    this.maxLength,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.cursorWidth = 2.0,
    this.cursorRadius,
    this.cursorColor,
    this.keyboardAppearance,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.enableInteractiveSelection = true,
    this.buildCounter,
    this.controller,
    this.colorPreviewBuilder,
  }) : super(
         builder: (FormFieldState<Color?> field) {
           final state = field as FormBuilderColorPickerFieldState;
           return TextField(
             style: style,
             decoration: decoration.copyWith(
               suffixIcon: colorPreviewBuilder != null
                   ? colorPreviewBuilder(field.value)
                   : LayoutBuilder(
                       key: ObjectKey(state.value),
                       builder: (context, constraints) {
                         return Padding(
                           padding: const EdgeInsets.all(8.0),
                           child: CircleAvatar(
                             key: ObjectKey(state.value),
                             backgroundColor: state.value,
                           ),
                         );
                       },
                     ),
             ),
             enabled: state.enabled,
             readOnly: readOnly,
             controller: state._effectiveController,
             focusNode: state.effectiveFocusNode,
             textAlign: textAlign,
             autofocus: autofocus,
             expands: expands,
             scrollPadding: scrollPadding,
             autocorrect: autocorrect,
             textCapitalization: textCapitalization,
             keyboardType: keyboardType,
             obscureText: obscureText,
             buildCounter: buildCounter,
             cursorColor: cursorColor,
             cursorRadius: cursorRadius,
             cursorWidth: cursorWidth,
             enableInteractiveSelection: enableInteractiveSelection,
             inputFormatters: inputFormatters,
             keyboardAppearance: keyboardAppearance,
             maxLength: maxLength,
             maxLengthEnforcement: maxLengthEnforcement,
             maxLines: maxLines,
             minLines: minLines,
             onEditingComplete: onEditingComplete,
             showCursor: showCursor,
             strutStyle: strutStyle,
             textDirection: textDirection,
             textInputAction: textInputAction,
           );
         },
       );

  @override
  FormBuilderColorPickerFieldState createState() =>
      FormBuilderColorPickerFieldState();
}

class FormBuilderColorPickerFieldState
    extends FormBuilderFieldState<FormBuilderColorPickerField, Color> {
  late TextEditingController _effectiveController;

  String? get valueString => value?.toHex();

  Color? _selectedColor;

  @override
  void initState() {
    super.initState();
    _effectiveController = widget.controller ?? TextEditingController();
    _effectiveController.text = valueString ?? '';
    effectiveFocusNode.addListener(_handleFocus);
  }

  @override
  void dispose() {
    effectiveFocusNode.removeListener(_handleFocus);
    // Dispose the _effectiveController when initState created it
    if (null == widget.controller) {
      _effectiveController.dispose();
    }
    super.dispose();
  }

  Future<void> _handleFocus() async {
    if (effectiveFocusNode.hasFocus && enabled) {
      effectiveFocusNode.unfocus();
      final selected = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            // title: null, //const Text('Pick a color!'),
            content: _buildColorPicker(),
            actions: <Widget>[
              const DialogCancelButton(),
              DialogConfirmButton(label: S.of(context)!.ok),
            ],
          );
        },
      );
      if (true == selected) {
        didChange(_selectedColor);
      }
    }
  }

  Widget _buildColorPicker() {
    switch (widget.colorPickerType) {
      case ColorPickerType.colorPicker:
        return ColorPicker(
          pickerColor: value ?? Colors.transparent,
          onColorChanged: _colorChanged,
          colorPickerWidth: 300,
          displayThumbColor: true,
          enableAlpha: true,
          paletteType: PaletteType.hsl,
          pickerAreaHeightPercent: 1.0,
        );
      case ColorPickerType.materialPicker:
        return MaterialPicker(
          pickerColor: value ?? Colors.transparent,
          onColorChanged: _colorChanged,
          enableLabel: true, // only on portrait mode
        );
      case ColorPickerType.blockPicker:
        return BlockPicker(
          pickerColor: value ?? Colors.transparent,
          onColorChanged: _colorChanged,
        );
    }
  }

  void _colorChanged(Color color) => _selectedColor = color;

  void _setTextFieldString() => _effectiveController.text = valueString ?? '';

  @override
  void didChange(Color? value) {
    super.didChange(value);
    _setTextFieldString();
  }

  @override
  void reset() {
    super.reset();
    _setTextFieldString();
  }
}
