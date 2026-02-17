import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:paperless_mobile/core/database/hive/hive_extensions.dart';

class HintStateBuilder extends StatelessWidget {
  final String? listenKey;
  final Widget Function(BuildContext context, Box<bool> box) builder;
  const HintStateBuilder({super.key, required this.builder, this.listenKey});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<bool>>(
      valueListenable: Hive.hintStateBox.listenable(
        keys: listenKey != null ? [listenKey] : null,
      ),
      builder: (context, box, child) {
        return builder(context, box);
      },
    );
  }
}
