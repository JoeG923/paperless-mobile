import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:paperless_document_scanner/paperless_document_scanner.dart';
import 'package:paperless_document_scanner/types/edge_detection_result.dart';

class EdgeDetector {
  static Future<void> startEdgeDetectionFromFileIsolate(
    EdgeDetectionFromFileInput edgeDetectionInput,
  ) async {
    EdgeDetectionResult result =
        await EdgeDetection.detectEdgesFromFile(edgeDetectionInput.inputPath);
    edgeDetectionInput.sendPort.send(result);
  }

  static Future<void> startEdgeDetectionIsolate(
    EdgeDetectionInput edgeDetectionInput,
  ) async {
    EdgeDetectionResult result =
        await EdgeDetection.detectEdges(edgeDetectionInput.bytes);
    edgeDetectionInput.sendPort.send(result);
  }

  static Future<void> processImageIsolate(
      ProcessImageInput processImageInput) async {
    ImageProcessing.processImage(
      processImageInput.bytes,
      processImageInput.edgeDetectionResult,
    );
    processImageInput.sendPort.send(true);
  }

  Future<EdgeDetectionResult> detectEdgesFromFile(String filePath) async {
    final port = ReceivePort();

    _spawnIsolate<EdgeDetectionInput>(
      startEdgeDetectionIsolate,
      EdgeDetectionFromFileInput(
        inputPath: filePath,
        sendPort: port.sendPort,
      ),
      port,
    );

    return await _subscribeToPort<EdgeDetectionResult>(port);
  }

  Future<bool> processImageFromFile(
      String filePath, EdgeDetectionResult edgeDetectionResult) async {
    final port = ReceivePort();

    _spawnIsolate<ProcessImageInput>(
        processImageIsolate,
        ProcessImageFromFileInput(
            inputPath: filePath,
            edgeDetectionResult: edgeDetectionResult,
            sendPort: port.sendPort),
        port);

    return await _subscribeToPort<bool>(port);
  }

  void _spawnIsolate<T>(
    void Function(T) function,
    dynamic input,
    ReceivePort port,
  ) {
    Isolate.spawn<T>(function, input,
        onError: port.sendPort, onExit: port.sendPort);
  }

  Future<T> _subscribeToPort<T>(ReceivePort port) async {
    late StreamSubscription sub;

    var completer = Completer<T>();

    sub = port.listen((result) async {
      log(result.toString());
      await sub.cancel();
      completer.complete(await result);
    });

    return completer.future;
  }
}

class EdgeDetectionFromFileInput {
  EdgeDetectionFromFileInput({
    required this.inputPath,
    required this.sendPort,
  });

  final String inputPath;
  final SendPort sendPort;
}

class EdgeDetectionInput {
  EdgeDetectionInput({
    required this.bytes,
    required this.sendPort,
  });

  final Uint8List bytes;
  final SendPort sendPort;
}

class ProcessImageInput {
  ProcessImageInput({
    required this.bytes,
    required this.edgeDetectionResult,
    required this.sendPort,
  });

  final Uint8List bytes;
  final EdgeDetectionResult edgeDetectionResult;
  final SendPort sendPort;
}

class ProcessImageFromFileInput {
  ProcessImageFromFileInput({
    required this.inputPath,
    required this.edgeDetectionResult,
    required this.sendPort,
  });

  final String inputPath;
  final EdgeDetectionResult edgeDetectionResult;
  final SendPort sendPort;
}
