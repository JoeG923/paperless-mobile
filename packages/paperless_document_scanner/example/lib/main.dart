import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as imglib;
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:path_provider/path_provider.dart';

late final List<CameraDescription> cameras;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const EdgeDetectionApp());
}

class EdgeDetectionApp extends StatefulWidget {
  const EdgeDetectionApp({super.key});

  @override
  State<EdgeDetectionApp> createState() => _EdgeDetectionAppState();
}

class _EdgeDetectionAppState extends State<EdgeDetectionApp> {
  @override
  void initState() {
    super.initState();
  }

  Uint8List concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  Image convertYUV420toImageColor(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    debugPrint("uvRowStride: $uvRowStride");
    debugPrint("uvPixelStride: $uvPixelStride");

    // imgLib -> Image package from https://pub.dartlang.org/packages/image
    var img = imglib.Image(
      width: width,
      height: height,
    ); // Create Image buffer

    // Fill image buffer with plane[0] from YUV420_888
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex =
            uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];
        // Calculate pixel color
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        // color: 0x FF  FF  FF  FF
        //           A   B   G   R
        img.data?.setPixelRgb(x, y, r, g, b);
      }
    }

    imglib.PngEncoder pngEncoder = imglib.PngEncoder(level: 0);
    final png = pngEncoder.encode(img);
    return Image.memory(png);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        body: CameraAwesomeBuilder.awesome(
          saveConfig: SaveConfig.photo(
            pathBuilder: (sensors) async => SingleCaptureRequest(
                "${(await getApplicationDocumentsDirectory()).path}/test.jpg",
                sensors
                        .where((element) =>
                            element.position == SensorPosition.front)
                        .firstOrNull ??
                    sensors.first),
          ),
          onImageForAnalysis: (image) async {},
          imageAnalysisConfig: AnalysisConfig(
            // Android specific options
            androidOptions: const AndroidAnalysisOptions.yuv420(
              // Target width (CameraX will chose the closest resolution to this width)
              width: 250,
            ),
            // Wether to start automatically the analysis (true by default)
            autoStart: true,
            // Max frames per second, null for no limit (default)
          ),
        ),
      ),
    );
  }
}
