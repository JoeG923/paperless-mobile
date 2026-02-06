import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:paperless_mobile/core/service/file_service.dart';
import 'package:path/path.dart' as p;

part 'receive_share_state.dart';

class ConsumptionChangeNotifier extends ChangeNotifier {
  List<File> pendingFiles = [];

  final Completer _restored = Completer();

  Future<void> get isInitialized => _restored.future;

  Future<void> loadFromConsumptionDirectory({required String userId}) async {
    pendingFiles = await _getCurrentFiles(userId);
    if (!_restored.isCompleted) {
      _restored.complete();
    }
    notifyListeners();
  }

  /// Creates a local copy of all shared files and reloads all files
  /// from the user's consumption directory. Returns the newly added files copied to the consumption directory.
  Future<List<File>> addFiles({
    required List<File> files,
    required String userId,
  }) async {
    if (files.isEmpty) {
      return [];
    }
    final consumptionDirectory = await FileService.instance
        .getConsumptionDirectory(userId: userId);
    final List<File> localFiles = [];
    for (final file in files) {
      final isLocalFile = await _isWithinDirectory(
        file,
        directory: consumptionDirectory,
      );
      if (!isLocalFile) {
        final localDestination = await _allocateUniqueDestination(
          consumptionDirectory,
          p.basename(file.path),
        );
        final localFile = await file.copy(localDestination.path);
        localFiles.add(localFile);
      } else {
        localFiles.add(file);
      }
    }
    await loadFromConsumptionDirectory(userId: userId);
    return localFiles;
  }

  /// Marks a file as processed by removing it from the queue and deleting the local copy of the file.
  Future<void> discardFile(File file, {required String userId}) async {
    final consumptionDirectory = await FileService.instance
        .getConsumptionDirectory(userId: userId);
    final isLocalFile = await _isWithinDirectory(
      file,
      directory: consumptionDirectory,
    );
    if (isLocalFile) {
      await file.delete();
    }
    return loadFromConsumptionDirectory(userId: userId);
  }

  /// Returns the next file to process of null if no file exists.
  Future<File?> getNextFile({required String userId}) async {
    final files = await _getCurrentFiles(userId);
    if (files.isEmpty) {
      return null;
    }
    return files.first;
  }

  Future<List<File>> _getCurrentFiles(String userId) async {
    final directory = await FileService.instance.getConsumptionDirectory(
      userId: userId,
    );
    return await FileService.instance.getAllFiles(directory);
  }

  Future<File> _allocateUniqueDestination(
    Directory directory,
    String originalFilename,
  ) async {
    final baseName = p.basenameWithoutExtension(originalFilename);
    final extension = p.extension(originalFilename);

    var candidate = File(p.join(directory.path, '$baseName$extension'));
    var suffix = 1;
    while (await candidate.exists()) {
      candidate = File(p.join(directory.path, '${baseName}_$suffix$extension'));
      suffix++;
    }
    return candidate;
  }

  Future<bool> _isWithinDirectory(
    File file, {
    required Directory directory,
  }) async {
    try {
      final canonicalDirectory = p.normalize(
        await directory.resolveSymbolicLinks(),
      );
      final canonicalFile = p.normalize(await file.resolveSymbolicLinks());
      return p.isWithin(canonicalDirectory, canonicalFile) ||
          canonicalDirectory == canonicalFile;
    } on FileSystemException {
      return false;
    }
  }
}
