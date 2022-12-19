import 'dart:typed_data';

import 'package:camera/camera.dart';
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:qr_code_dart_scan/src/util/extensions.dart';
import 'package:zxing_lib/zxing.dart';

///
/// Created by
///
/// ─▄▀─▄▀
/// ──▀──▀
/// █▀▀▀▀▀█▄
/// █░░░░░█─█
/// ▀▄▄▄▄▄▀▀
///
/// Rafaelbarbosatec
/// on 28/06/22
class DecodeImageEvent {
  final bool invert;
  final Uint8List image;
  final List<BarcodeFormat> formats;

  DecodeImageEvent({
    required this.image,
    this.invert = false,
    this.formats = const [],
  });

  DecodeImageEvent.fromMap(Map map)
      : invert = map['invert'] as bool,
        image = map['image'] as Uint8List,
        formats = map['formats']
            .map<BarcodeFormat>((f) => BarcodeFormat.values[f])
            .toList();

  Map toMap() {
    return {
      'invert': invert,
      'image': image,
      'formats': formats.map((e) => e.index).toList(),
    };
  }

  DecodeImageEvent copyWith({
    bool? invert,
    Uint8List? image,
    List<BarcodeFormat>? formats,
  }) {
    return DecodeImageEvent(
      invert: invert ?? this.invert,
      image: image ?? this.image,
      formats: formats ?? this.formats,
    );
  }
}

class DecodeCameraImageEvent {
  final bool invert;
  final CameraImage cameraImage;
  final List<BarcodeFormat> formats;

  DecodeCameraImageEvent({
    required this.cameraImage,
    this.invert = false,
    this.formats = const [],
  });

  DecodeCameraImageEvent.fromMap(Map map)
      : invert = map['invert'] as bool,
        cameraImage = _fromPlateformData(map),
        formats = map['formats']
            .map<BarcodeFormat>((f) => BarcodeFormat.values[f])
            .toList();

  static CameraImage _fromPlateformData(Map<dynamic, dynamic> map) {
    return CameraImage.fromPlatformInterface(
      CameraImageData(
        format: CameraImageFormat(
          map['image']['format']['group'],
          raw: map['image']['format']['raw'],
        ),
        height: map['image']['height'],
        width: map['image']['width'],
        planes: (map['image']?['planes'] as List? ?? []).map((e) {
          return CameraImagePlane(
            bytes: e['bytes'],
            bytesPerRow: e['bytesPerRow'],
            bytesPerPixel: e['bytesPerPixel'],
            height: e['height'],
            width: e['width'],
          );
        }).toList(),
      ),
    );
  }

  Map toMap() {
    return {
      'invert': invert,
      'image': cameraImage.toPlatformData(),
      'formats': formats.map((e) => e.index).toList(),
    };
  }

  DecodeCameraImageEvent copyWith({
    bool? invert,
    CameraImage? cameraImage,
    List<BarcodeFormat>? formats,
  }) {
    return DecodeCameraImageEvent(
      invert: invert ?? this.invert,
      cameraImage: cameraImage ?? this.cameraImage,
      formats: formats ?? this.formats,
    );
  }
}
