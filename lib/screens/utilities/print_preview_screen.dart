import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import '../../services/pdf_generator_service.dart';
import '../../services/printer/thermal_printer_service.dart';
import '../../services/printer/thermal_printer_connection.dart';
import 'package:printing/printing.dart';
import '../../models/transaction_model.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../../theme/app_theme.dart';

class PrintPreviewScreen extends StatefulWidget {
  final Transaction transaction;

  const PrintPreviewScreen({super.key, required this.transaction});

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  final Color primaryGreen = const Color(0xFF00BFA5);
  bool _isPrinting = false;

  /// Width selected by the user for the connected thermal printer.
  /// Most portable Bluetooth printers are 58 mm; 80 mm is common for desktop
  /// thermal printers. Defaulting to 58 mm avoids buffer overflows on mobile.
  double _selectedWidthMm = 58.0;

  @override
  void initState() {
    super.initState();
    // Rebuild when connection status might have changed after coming back from settings
  }

  Future<Uint8List> _generatePdfReceipt() async {
    final profile = context.read<SettingsProvider>().profile;
    return await PdfGeneratorService().generateInvoice(
      widget.transaction,
      profile,
    );
  }

  Future<void> _printTestPage() async {
    final success = await ThermalPrinterService.instance
        .printTestPage(widthMm: _selectedWidthMm);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Prueba enviada — revisa la impresora'
            : 'Error al enviar la prueba de impresión'),
        backgroundColor: success ? primaryGreen : Colors.red,
      ));
    }
  }

  void _printReceipt() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      final thermalService = ThermalPrinterService.instance;

      if (thermalService.isConnected) {
        // Native ESC/POS path — no PDF, no rasterization, ~5 KB RAM.
        final profile = context.read<SettingsProvider>().profile;
        final success = await thermalService.printReceipt(
          widget.transaction,
          profile,
          widthMm: _selectedWidthMm,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              success ? 'Impresión enviada correctamente' : 'Error al imprimir',
            ),
            backgroundColor: success ? primaryGreen : Colors.red,
          ));
        }
      } else {
        // Fallback: Android system print spooler / AirPrint.
        // PDF is only generated here, where it is actually needed.
        final pdfBytes = await _generatePdfReceipt();
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: 'Recibo_${widget.transaction.id}',
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _showPrinterPairingDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => _PrinterScanDialog(
        primaryGreen: primaryGreen,
        onDeviceSelected: (address) {
          Navigator.pop(ctx);
          _connectToPrinter(address);
        },
      ),
    );
  }



  Future<void> _connectToPrinter(String address) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: Color(0xFF1E2333),
        title: Text('Conectando...', style: TextStyle(color: Colors.white)),
        content: SizedBox(height: 50, child: Center(child: CircularProgressIndicator())),
      )
    );

    final success = await ThermalPrinterService.instance.connect(address);
    if (mounted) Navigator.pop(context); // close connecting dialog

    if (mounted) {
      setState(() {}); // refresh UI connection status
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Impresora conectada' : 'No se pudo conectar. Verifica que esté encendida.'),
        backgroundColor: success ? primaryGreen : Colors.red,
      ));
    }
  }

  Widget _buildTopPrinterConfigurator() {
    final isConnected = ThermalPrinterService.instance.isConnected;
    final address = ThermalPrinterService.instance.connectedAddress;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isConnected ? primaryGreen : Colors.orange).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isConnected ? Icons.print : Icons.print_disabled, 
                    color: isConnected ? primaryGreen : Colors.orange
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('IMPRESORA TÉRMICA BLUETOOTH',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                      if (isConnected)
                        Text('Conectada ($address)',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold))
                      else
                        const Text('Ninguna conectada',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.bold))
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Paper-size selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ANCHO DE PAPEL',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<double>(
                  segments: const [
                    ButtonSegment(
                      value: 58.0,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('58 mm'),
                      ),
                      icon: Icon(Icons.phone_android, size: 16),
                    ),
                    ButtonSegment(
                      value: 80.0,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('80 mm'),
                      ),
                      icon: Icon(Icons.desktop_windows, size: 16),
                    ),
                  ],
                  selected: {_selectedWidthMm},
                  onSelectionChanged: (Set<double> selection) {
                    setState(() => _selectedWidthMm = selection.first);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                      (states) => states.contains(WidgetState.selected)
                          ? primaryGreen.withValues(alpha: 0.25)
                          : Colors.transparent,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                      (states) => states.contains(WidgetState.selected)
                          ? primaryGreen
                          : Colors.white70,
                    ),
                    side: WidgetStateProperty.all(
                      BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _showPrinterPairingDialog,
                  icon: const Icon(Icons.bluetooth_searching, color: Colors.white),
                  label: const Text('Vincular Impresora',
                      style: TextStyle(color: Colors.white)),
                ),
                if (isConnected)
                  TextButton(
                    onPressed: () async {
                      await ThermalPrinterService.instance.disconnect();
                      setState(() {});
                    },
                    child: const Text('Desconectar',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
          ),
          // Test-print row — only shown when a printer is connected.
          // Sends plain ESC/POS text with NO image rasterization, allowing
          // you to validate BT connection, paper width, and ESC/POS encoding
          // without wasting a full roll.
          if (isConnected) ...
          [
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _printTestPage,
                  icon: Icon(Icons.receipt_long,
                      color: primaryGreen, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Imprimir página de prueba (sin imagen)',
                      style: TextStyle(color: primaryGreen),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTicketPreview() {
    final profile = context.read<SettingsProvider>().profile;
    // Resolve the correct PDF roll format from the user's selection.
    // NOTE: PdfPageFormat.roll58 does not exist in pdf ^3.11.3 — only roll80
    // is a named constant. The 58 mm roll is constructed manually.
    final pageFormat = _selectedWidthMm == 58.0
        ? const PdfPageFormat(58.0 * PdfPageFormat.mm, double.infinity)
        : PdfPageFormat.roll80;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // key forces PdfPreview to rebuild when the format changes.
      key: ValueKey(_selectedWidthMm),
      child: PdfPreview(
        build: (format) => PdfGeneratorService().generateInvoice(
          widget.transaction,
          profile,
        ),
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        useActions: false,
        maxPageWidth: _selectedWidthMm == 58.0 ? 320 : 420,
        initialPageFormat: pageFormat,
        scrollViewDecoration: const BoxDecoration(color: Colors.white),
        pdfPreviewPageDecoration: const BoxDecoration(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Previsualización',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Matrix overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: CustomPaint(painter: GridPainter()),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      child: _buildTopPrinterConfigurator(),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 120),
                      child: _buildTicketPreview(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom IMPRIMIR AHORA button fixed at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.backgroundBlack.withValues(alpha: 0.0),
                    AppTheme.backgroundBlack.withValues(alpha: 0.8),
                    AppTheme.backgroundBlack,
                  ],
                ),
              ),
              child: ElevatedButton(
                onPressed: _isPrinting ? null : _printReceipt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 8,
                  shadowColor: primaryGreen.withValues(alpha: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isPrinting)
                      const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    else
                      const Icon(Icons.print, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      _isPrinting ? 'IMPRIMIENDO...' : 'IMPRIMIR AHORA',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Self-contained Bluetooth printer scanner dialog
// ---------------------------------------------------------------------------
// Uses a StatefulWidget so it can:
//   • auto-scan on first build (initState)
//   • update its own list without rebuilding the parent screen
//   • support pull-to-refresh (RefreshIndicator) to re-scan
//
// Uses a plain Dialog — NOT AlertDialog — because AlertDialog wraps its content
// in IntrinsicWidth, which asks ListView for intrinsic dimensions it cannot
// provide, causing "RenderShrinkWrappingViewport does not support returning
// intrinsic dimensions" and a cascading render crash.
class _PrinterScanDialog extends StatefulWidget {
  final Color primaryGreen;
  final void Function(String address) onDeviceSelected;

  const _PrinterScanDialog({
    required this.primaryGreen,
    required this.onDeviceSelected,
  });

  @override
  State<_PrinterScanDialog> createState() => _PrinterScanDialogState();
}

class _PrinterScanDialogState extends State<_PrinterScanDialog> {
  List<PrinterDevice> _printers = [];
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _isScanning = true);
    final found = await ThermalPrinterService.instance.scan();
    if (mounted) {
      setState(() {
        _printers = found;
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 42 % of screen height — adapts to every screen size and orientation.
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.42;

    return Dialog(
      backgroundColor: const Color(0xFF1E2333),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.bluetooth_searching,
                    color: widget.primaryGreen, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Vincular Impresora Térmica',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Desliza la lista hacia abajo para actualizar',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 12),

            // ── Device list ─────────────────────────────────────────────
            // ConstrainedBox gives the inner ListView a bounded height so
            // it can measure and scroll correctly inside a Column.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxListHeight,
                minHeight: 56,
              ),
              child: _isScanning
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _scan,
                      color: widget.primaryGreen,
                      backgroundColor: const Color(0xFF1E2333),
                      child: _printers.isEmpty
                          ? ListView(
                              // Needs AlwaysScrollableScrollPhysics so
                              // RefreshIndicator activates on an empty list.
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Text(
                                    'No se detectaron impresoras.\nAsegúrate de que estén encendidas y en modo de emparejamiento.\n\nDesliza hacia abajo para volver a buscar.',
                                    style: TextStyle(
                                        color: Colors.white60, height: 1.5),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const ClampingScrollPhysics(),
                              itemCount: _printers.length,
                              separatorBuilder: (_, __) => const Divider(
                                  color: Colors.white10, height: 1),
                              itemBuilder: (_, i) {
                                final device = _printers[i];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: widget.primaryGreen
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.print,
                                        color: widget.primaryGreen, size: 20),
                                  ),
                                  title: Text(
                                    device.name.isNotEmpty
                                        ? device.name
                                        : 'Dispositivo desconocido',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    device.address,
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 11),
                                  ),
                                  trailing: Icon(Icons.arrow_forward_ios,
                                      color: widget.primaryGreen, size: 14),
                                  onTap: () =>
                                      widget.onDeviceSelected(device.address),
                                );
                              },
                            ),
                    ),
            ),

            const Divider(color: Colors.white12, height: 24),

            // ── Footer actions ───────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      await Permission.bluetooth.request();
                      const intent = AndroidIntent(
                          action: 'android.settings.BLUETOOTH_SETTINGS');
                      await intent.launch();
                    },
                    icon: Icon(Icons.settings_bluetooth,
                        color: widget.primaryGreen, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Ajustes BT',
                          style: TextStyle(color: widget.primaryGreen)),
                    ),
                  ),
                ),
                // Manual re-scan button
                IconButton(
                  tooltip: 'Volver a buscar',
                  onPressed: _isScanning ? null : _scan,
                  icon: _isScanning
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: widget.primaryGreen))
                      : Icon(Icons.refresh, color: widget.primaryGreen),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar',
                      style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 20) {
      for (double j = 0; j < size.height; j += 20) {
        canvas.drawCircle(Offset(i, j), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
