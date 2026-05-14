// ignore_for_file: camel_case_types

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:paperless_document_scanner/types/edge_detection_result.dart';

final DynamicLibrary _nativeInteropLib = Platform.isAndroid
    ? DynamicLibrary.open("libnative_edge_detection.so")
    : DynamicLibrary.process();

class EdgeDetection {
  static Future<EdgeDetectionResult> detectEdgesFromFile(String path) async {
    final detectEdges = _nativeInteropLib
        .lookup<NativeFunction<_c_detect_edges_from_file>>(
            "detect_edges_from_file")
        .asFunction<_dart_detect_edges_from_file>();

    NativeEdgeDetectionResult detectionResult =
        detectEdges(path.toNativeUtf8()).ref;

    return EdgeDetectionResult(
        topLeft: Offset(
            detectionResult.topLeft.ref.x, detectionResult.topLeft.ref.y),
        topRight: Offset(
            detectionResult.topRight.ref.x, detectionResult.topRight.ref.y),
        bottomLeft: Offset(
            detectionResult.bottomLeft.ref.x, detectionResult.bottomLeft.ref.y),
        bottomRight: Offset(detectionResult.bottomRight.ref.x,
            detectionResult.bottomRight.ref.y));
  }

  static Future<EdgeDetectionResult> detectEdges(Uint8List bytes) async {
    final detectEdges = _nativeInteropLib
        .lookup<NativeFunction<_c_detect_edges>>("detect_edges")
        .asFunction<_dart_detect_edges>();

    Pointer<Uint8> imgBuffer = malloc.allocate<Uint8>(bytes.lengthInBytes);
    Uint8List buffer = imgBuffer.asTypedList(bytes.lengthInBytes);
    buffer.setAll(0, bytes);

    NativeEdgeDetectionResult detectionResult = detectEdges(
      imgBuffer,
      buffer.lengthInBytes,
    ).ref;

    final result = EdgeDetectionResult(
      topLeft: Offset(
        detectionResult.topLeft.ref.x,
        detectionResult.topLeft.ref.y,
      ),
      topRight: Offset(
        detectionResult.topRight.ref.x,
        detectionResult.topRight.ref.y,
      ),
      bottomLeft: Offset(
        detectionResult.bottomLeft.ref.x,
        detectionResult.bottomLeft.ref.y,
      ),
      bottomRight: Offset(
        detectionResult.bottomRight.ref.x,
        detectionResult.bottomRight.ref.y,
      ),
    );
    return result;
  }
}

typedef _c_detect_edges_from_file = Pointer<NativeEdgeDetectionResult> Function(
  Pointer<Utf8> imagePath,
);

typedef _c_detect_edges = Pointer<NativeEdgeDetectionResult> Function(
  Pointer<Uint8> bytes,
  Int32 byteSize,
);

typedef _dart_detect_edges_from_file = Pointer<NativeEdgeDetectionResult>
    Function(
  Pointer<Utf8> imagePath,
);

typedef _dart_detect_edges = Pointer<NativeEdgeDetectionResult> Function(
  Pointer<Uint8> bytes,
  int byteSize,
);
