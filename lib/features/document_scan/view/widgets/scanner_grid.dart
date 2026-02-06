import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:paperless_mobile/features/document_scan/view/widgets/scanned_image_item.dart';

class ScannerGrid extends StatelessWidget {
  static const double _maxTileExtent = 160.0;

  final List<File> scans;
  final SliverOverlapAbsorberHandle searchBarHandle;
  final SliverOverlapAbsorberHandle actionsHandle;
  final Future<void> Function(File file) onDelete;

  const ScannerGrid({
    super.key,
    required this.scans,
    required this.searchBarHandle,
    required this.actionsHandle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: CustomScrollView(
        slivers: [
          SliverOverlapInjector(handle: searchBarHandle),
          SliverOverlapInjector(handle: actionsHandle),
          SliverGrid.builder(
            itemCount: scans.length,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: _maxTileExtent,
              childAspectRatio: 1 / sqrt(2),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              return ScannedImageItem(
                file: scans[index],
                onDelete: () {
                  onDelete(scans[index]);
                },
                index: index,
                totalNumberOfFiles: scans.length,
              );
            },
          ),
        ],
      ),
    );
  }
}
