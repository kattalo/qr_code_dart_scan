import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_dart_scan/src/qr_code_dart_scan_controller.dart';
import 'package:qr_code_dart_scan/src/util/extensions.dart';
import 'package:qr_code_dart_scan/src/util/qr_code_dart_scan_resolution_preset.dart';
import 'package:zxing_lib/zxing.dart';

import 'decoder/qr_code_dart_scan_decoder.dart';

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
/// on 12/08/21

enum TypeCamera { back, front }

enum TypeScan { live, takePicture }

typedef TakePictureButtonBuilder = Widget Function(
  BuildContext context,
  QRCodeDartScanController controller,
  bool loading,
);

class QRCodeDartScanView extends StatefulWidget {
  final TypeCamera typeCamera;
  final TypeScan typeScan;
  final ValueChanged<Result>? onCapture;
  final bool scanInvertedQRCode;

  /// Use to limit a specific format
  /// If null use all accepted formats
  final List<BarcodeFormat> formats;
  final QRCodeDartScanController? controller;
  final QRCodeDartScanResolutionPreset resolutionPreset;
  final Widget? child;
  final double? widthPreview;
  final double? heightPreview;
  final TakePictureButtonBuilder? takePictureButtonBuilder;
  const QRCodeDartScanView({
    Key? key,
    this.typeCamera = TypeCamera.back,
    this.typeScan = TypeScan.live,
    this.onCapture,
    this.scanInvertedQRCode = false,
    this.resolutionPreset = QRCodeDartScanResolutionPreset.medium,
    this.controller,
    this.formats = QRCodeDartScanDecoder.acceptedFormats,
    this.child,
    this.takePictureButtonBuilder,
    this.widthPreview = double.maxFinite,
    this.heightPreview = double.maxFinite,
  }) : super(key: key);

  @override
  QRCodeDartScanViewState createState() => QRCodeDartScanViewState();
}

class QRCodeDartScanViewState extends State<QRCodeDartScanView>
    with WidgetsBindingObserver
    implements DartScanInterface {
  CameraController? controller;
  late QRCodeDartScanController qrCodeDartScanController;
  late QRCodeDartScanDecoder dartScanDecoder;
  bool initialized = false;
  bool processingImg = false;
  String? _lastText;
  Timer? _webImageStreamTimer;

  @override
  TypeScan typeScan = TypeScan.live;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!(controller?.value.isInitialized == true)) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      postFrame(() {
        setState(() {
          initialized = false;
          controller?.dispose();
        });
      });
    } else if (state == AppLifecycleState.resumed) {
      _initController();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    typeScan = widget.typeScan;
    dartScanDecoder = QRCodeDartScanDecoder(formats: widget.formats);
    _initController();
  }

  @override
  void dispose() {
    _webImageStreamTimer?.cancel();

    WidgetsBinding.instance.removeObserver(this);
    qrCodeDartScanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: initialized ? _getCameraWidget(context) : widget.child,
    );
  }

  void _initController() async {
    final camera = await _getCamera();
    controller = CameraController(
      camera,
      widget.resolutionPreset.toResolutionPreset(),
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    qrCodeDartScanController = widget.controller ?? QRCodeDartScanController();
    await controller!.initialize();
    qrCodeDartScanController.configure(controller!, this);
    if (typeScan == TypeScan.live) {
      _startImageStream();
    }
    postFrame(() {
      setState(() {
        initialized = true;
      });
    });
  }

  void _startImageStream() {
    if (kIsWeb) {
      // Web does not support image stream (tested with camera-0.10.5+9)
      // A workaround is to take a picture every 500 ms :)
      if (_webImageStreamTimer != null) {
        _webImageStreamTimer!.cancel();
      }

      _webImageStreamTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) {
          if (!qrCodeDartScanController.scanEnabled) return;

          takePictureAndDecode();
        },
      );
    } else {
      controller?.startImageStream(_imageStream);
    }
  }

  Future<void> _stopImageStream() async {
    if (kIsWeb) {
      // Web uses a timer instead of image stream
      _webImageStreamTimer?.cancel();
    } else {
      await controller?.stopImageStream();
    }
  }

  void _imageStream(CameraImage image) async {
    if (!qrCodeDartScanController.scanEnabled) return;
    if (processingImg) return;
    processingImg = true;
    _processImage(image);
  }

  void _processImage(CameraImage image) async {
    final decoded = await dartScanDecoder.decodeCameraImage(
      image,
      scanInverted: widget.scanInvertedQRCode,
    );

    if (decoded != null && mounted) {
      if (_lastText != decoded.text) {
        _lastText = decoded.text;
        widget.onCapture?.call(decoded);
      }
    }

    processingImg = false;
  }

  @override
  Future<void> takePictureAndDecode() async {
    if (processingImg) return;
    setState(() {
      processingImg = true;
    });
    final xFile = await controller?.takePicture();

    if (xFile != null) {
      final decoded = await dartScanDecoder.decodeFile(
        xFile,
        scanInverted: widget.scanInvertedQRCode,
      );

      if (decoded != null && mounted) {
        widget.onCapture?.call(decoded);
      }
    }

    setState(() {
      processingImg = false;
    });
  }

  Widget _buildButton() {
    return widget.takePictureButtonBuilder?.call(
          context,
          qrCodeDartScanController,
          processingImg,
        ) ??
        _ButtonTakePicture(
          onTakePicture: takePictureAndDecode,
          isLoading: processingImg,
        );
  }

  @override
  Future<void> changeTypeScan(TypeScan type) async {
    if (typeScan == type) {
      return;
    }
    if (typeScan == TypeScan.takePicture) {
      _startImageStream();
    } else {
      await _stopImageStream();
      processingImg = false;
    }
    setState(() {
      typeScan = type;
    });
  }

  Widget _getCameraWidget(BuildContext context) {
    if (controller == null) {
      if (kDebugMode) print('_getCameraWidget() controller is null');
      return const SizedBox.shrink();
    }
    if (!controller!.value.isInitialized) {
      if (kDebugMode) print('_getCameraWidget() camera not initialized');
      return const SizedBox.shrink();
    }
    if (controller!.value.previewSize == null) {
      if (kDebugMode) print('_getCameraWidget() preview size not set');
      return const SizedBox.shrink();
    }
    var camera = controller!.value;

    var sizePreview = camera.previewSize;

    print('SIZE // camera.previewSize = ${camera.previewSize}');

    if (widget.widthPreview != null) {
      sizePreview =
          Size(widget.widthPreview!, widget.widthPreview! / camera.aspectRatio);
    } else if (widget.heightPreview != null) {
      sizePreview = Size(
          widget.heightPreview! * camera.aspectRatio, widget.heightPreview!);
    }

    print('SIZE // sizePreview = $sizePreview');

    var scale = sizePreview!.width / camera.previewSize!.width;

    print('SIZE // scale = $scale');

    return SizedBox(
      width: sizePreview.width,
      height: sizePreview.height,
      child: Stack(
        children: [
          Transform.scale(
            scale: scale,
            child: Center(
              child: CameraPreview(
                controller!,
              ),
            ),
          ),
          if (typeScan == TypeScan.takePicture) _buildButton(),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }

  Future<CameraDescription> _getCamera() async {
    final CameraLensDirection lensDirection;
    switch (widget.typeCamera) {
      case TypeCamera.back:
        lensDirection = CameraLensDirection.back;
        break;
      case TypeCamera.front:
        lensDirection = CameraLensDirection.front;
        break;
    }

    final cameras = await availableCameras();
    return cameras.firstWhere(
      (camera) => camera.lensDirection == lensDirection,
      orElse: () => cameras.first,
    );
  }
}

class _ButtonTakePicture extends StatelessWidget {
  static const buttonContainerHeight = 150.0;
  static const buttonSize = 80.0;
  static const progressSize = 40.0;
  final VoidCallback onTakePicture;
  final bool isLoading;
  const _ButtonTakePicture({
    Key? key,
    required this.onTakePicture,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: buttonContainerHeight,
        color: Colors.black,
        child: Center(
          child: InkWell(
            onTap: onTakePicture,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: isLoading
                    ? const Center(
                        child: SizedBox(
                          width: progressSize,
                          height: progressSize,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
