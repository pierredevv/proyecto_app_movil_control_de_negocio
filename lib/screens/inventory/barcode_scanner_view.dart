import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({super.key});

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> {
  final MobileScannerController controller = MobileScannerController();
  bool _isScanned = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isScanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() {
          _isScanned = true;
        });
        Navigator.pop(context, barcode.rawValue);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Escanear Código',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Torch Button
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, state, child) {
              if (!state.isInitialized || !state.isRunning) {
                return const SizedBox();
              }
              switch (state.torchState) {
                case TorchState.off:
                  return IconButton(
                    icon: const Icon(Icons.flash_off, color: Colors.grey),
                    onPressed: () => controller.toggleTorch(),
                  );
                case TorchState.on:
                  return IconButton(
                    icon: const Icon(Icons.flash_on, color: Colors.yellow),
                    onPressed: () => controller.toggleTorch(),
                  );
                case TorchState.auto:
                case TorchState.unavailable:
                  return const SizedBox();
              }
            },
          ),
          // Camera Switch Button
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, state, child) {
              if (!state.isInitialized || !state.isRunning) {
                return const SizedBox();
              }
              switch (state.cameraDirection) {
                case CameraFacing.front:
                  return IconButton(
                    icon: const Icon(Icons.camera_front),
                    onPressed: () => controller.switchCamera(),
                  );
                case CameraFacing.back:
                  return IconButton(
                    icon: const Icon(Icons.camera_rear),
                    onPressed: () => controller.switchCamera(),
                  );
                default:
                  return const SizedBox();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _handleBarcode,
          ),
          CustomPaint(
            painter: ScannerOverlayPainter(
                borderColor: Theme.of(context).primaryColor),
            child: Container(),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Apunta al código de barras',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  ScannerOverlayPainter({
    required this.borderColor,
    this.borderRadius = 10,
    this.borderLength = 30,
    this.cutOutSize = 300,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scanWindowSize = cutOutSize;
    final double left = (size.width - scanWindowSize) / 2;
    final double top = (size.height - scanWindowSize) / 2;
    final Rect scanRect =
        Rect.fromLTWH(left, top, scanWindowSize, scanWindowSize);

    // Draw background with hole
    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
          RRect.fromRectAndRadius(scanRect, Radius.circular(borderRadius)))
      ..fillType = PathFillType.evenOdd;

    final Paint backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawPath(backgroundPath, backgroundPaint);

    // Draw corners
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final RRect borderRRect =
        RRect.fromRectAndRadius(scanRect, Radius.circular(borderRadius));

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(borderRRect.left, borderRRect.top + borderLength)
        ..lineTo(borderRRect.left, borderRRect.top)
        ..lineTo(borderRRect.left + borderLength, borderRRect.top),
      borderPaint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(borderRRect.right - borderLength, borderRRect.top)
        ..lineTo(borderRRect.right, borderRRect.top)
        ..lineTo(borderRRect.right, borderRRect.top + borderLength),
      borderPaint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(borderRRect.right, borderRRect.bottom - borderLength)
        ..lineTo(borderRRect.right, borderRRect.bottom)
        ..lineTo(borderRRect.right - borderLength, borderRRect.bottom),
      borderPaint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(borderRRect.left + borderLength, borderRRect.bottom)
        ..lineTo(borderRRect.left, borderRRect.bottom)
        ..lineTo(borderRRect.left, borderRRect.bottom - borderLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
