// ignore_for_file: camel_case_types

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:paperless_document_scanner/types/edge_detection_result.dart';

final DynamicLibrary _nativeInteropLib = Platform.isAndroid
    ? DynamicLibrary.open("libnative_edge_detection.so")
    : DynamicLibrary.process();

class ImageProcessing {
  static Future<bool> processImageFromFile(
    String path,
    EdgeDetectionResult result,
  ) async {
    final processImage = _nativeInteropLib
        .lookup<NativeFunction<_c_process_image_from_file>>(
            "process_image_from_file")
        .asFunction<_dart_process_image_from_file>();

    return processImage(
          path.toNativeUtf8(),
          result.topLeft.dx,
          result.topLeft.dy,
          result.topRight.dx,
          result.topRight.dy,
          result.bottomLeft.dx,
          result.bottomLeft.dy,
          result.bottomRight.dx,
          result.bottomRight.dy,
        ) ==
        1;
  }

  static Future<bool> processImage(
    Uint8List bytes,
    EdgeDetectionResult result,
  ) async {
    final processImage = _nativeInteropLib
        .lookup<NativeFunction<_c_process_image>>("process_image")
        .asFunction<_dart_process_image>();

    final imgBuffer = malloc.allocate<Uint8>(bytes.lengthInBytes);
    Uint8List buffer = imgBuffer.asTypedList(bytes.lengthInBytes);
    buffer.setAll(0, bytes);

    return processImage(
          imgBuffer,
          bytes.lengthInBytes,
          result.topLeft.dx,
          result.topLeft.dy,
          result.topRight.dx,
          result.topRight.dy,
          result.bottomLeft.dx,
          result.bottomLeft.dy,
          result.bottomRight.dx,
          result.bottomRight.dy,
        ) ==
        1;
  }
}

typedef _c_process_image_from_file = Int8 Function(
  Pointer<Utf8> imagePath,
  Double topLeftX,
  Double topLeftY,
  Double topRightX,
  Double topRightY,
  Double bottomLeftX,
  Double bottomLeftY,
  Double bottomRightX,
  Double bottomRightY,
);

typedef _c_process_image = Int8 Function(
  Pointer<Uint8> imagePath,
  Int32 byteSize,
  Double topLeftX,
  Double topLeftY,
  Double topRightX,
  Double topRightY,
  Double bottomLeftX,
  Double bottomLeftY,
  Double bottomRightX,
  Double bottomRightY,
);

typedef _dart_process_image_from_file = int Function(
  Pointer<Utf8> imagePath,
  double topLeftX,
  double topLeftY,
  double topRightX,
  double topRightY,
  double bottomLeftX,
  double bottomLeftY,
  double bottomRightX,
  double bottomRightY,
);

typedef _dart_process_image = int Function(
  Pointer<Uint8> imagePath,
  int byteSize,
  double topLeftX,
  double topLeftY,
  double topRightX,
  double topRightY,
  double bottomLeftX,
  double bottomLeftY,
  double bottomRightX,
  double bottomRightY,
);
