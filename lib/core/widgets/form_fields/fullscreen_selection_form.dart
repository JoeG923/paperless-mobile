import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:paperless_mobile/core/extensions/flutter_extensions.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class FullscreenSelectionForm extends StatefulWidget {
  final FocusNode? focusNode;
  final TextEditingController? controller;

  final String hintText;
  final Widget leadingIcon;
  final bool autofocus;

  final VoidCallback? onTextFieldCleared;
  final List<Widget> trailingActions;
  final Widget Function(BuildContext context, int index) selectionBuilder;
  final int selectionCount;
  final void Function(String value)? onKeyboardSubmit;
  final Widget? floatingActionButton;

  const FullscreenSelectionForm({
    super.key,
    this.focusNode,
    this.controller,
    required this.hintText,
    required this.leadingIcon,
    this.autofocus = true,
    this.onTextFieldCleared,
    this.trailingActions = const [],
    required this.selectionBuilder,
    required this.selectionCount,
    this.onKeyboardSubmit,
    this.floatingActionButton,
  });

  @override
  State<FullscreenSelectionForm> createState() =>
      _FullscreenSelectionFormState();
}

class _FullscreenSelectionFormState extends State<FullscreenSelectionForm> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;

  bool _showClearIcon = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = (widget.controller ?? TextEditingController())
      ..addListener(() {
        setState(() {
          _showClearIcon = _controller.text.isNotEmpty;
        });
      });
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        //Delay keyboard popup to ensure open animation is finished before.
        Future.delayed(
          const Duration(milliseconds: 200),
          () => _focusNode.requestFocus(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: widget.floatingActionButton,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        toolbarHeight: 72,
        leading: BackButton(color: theme.colorScheme.onSurface),
        title: TextFormField(
          focusNode: _focusNode,
          controller: _controller,
          onFieldSubmitted: (value) {
            FocusScope.of(context).unfocus();
            widget.onKeyboardSubmit?.call(value);
          },
          autofocus: true,
          style: theme.textTheme.bodyLarge?.apply(
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.zero,
            hintStyle: theme.textTheme.bodyLarge?.apply(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            icon: widget.leadingIcon,
            hintText: widget.hintText,
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          if (_showClearIcon)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                widget.onTextFieldCleared?.call();
              },
            ),
          ...widget.trailingActions,
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: theme.colorScheme.outline),
        ),
      ),
      body: Builder(
        builder: (context) {
          if (widget.selectionCount == 0) {
            return Align(
              alignment: Alignment.topCenter,
              child: Text(S.of(context)!.noItemsFound).padded(16),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: widget.selectionCount,
                  itemBuilder: (BuildContext context, int index) {
                    final highlight =
                        AutocompleteHighlightedOption.of(context) == index;
                    if (highlight) {
                      SchedulerBinding.instance.addPostFrameCallback((
                        Duration timeStamp,
                      ) {
                        Scrollable.ensureVisible(context, alignment: 0);
                      });
                    }
                    return widget.selectionBuilder(context, index);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
