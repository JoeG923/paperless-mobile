import 'package:flutter/material.dart';

class ObscuredInputTextFormField extends StatefulWidget {
  final String? initialValue;
  final String label;
  final String? hintText;
  final void Function(String?) onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final FocusNode? focusNode;

  final ValueChanged<String?>? onFieldSubmitted;

  const ObscuredInputTextFormField({
    super.key,
    required this.onChanged,
    required this.label,
    this.hintText,
    this.validator,
    this.initialValue,
    this.enabled = true,
    this.focusNode,
    this.onFieldSubmitted,
  });

  @override
  State<ObscuredInputTextFormField> createState() =>
      _ObscuredInputTextFormFieldState();
}

class _ObscuredInputTextFormFieldState
    extends State<ObscuredInputTextFormField> {
  bool _showPassword = false;
  late final FocusNode _passwordFocusNode;
  late final bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _passwordFocusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (_ownsFocusNode) {
      _passwordFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: widget.enabled,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      initialValue: widget.initialValue,
      focusNode: _passwordFocusNode,
      obscureText: !_showPassword,
      autocorrect: false,
      onChanged: widget.onChanged,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        label: Text(widget.label),
        hintText: widget.hintText,
        suffixIcon: IconButton(
          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() {
            _showPassword = !_showPassword;
          }),
        ),
      ),
    );
  }
}
