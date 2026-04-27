import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import '../../services/pdf_generator_service.dart';
import '../../services/printer/thermal_printer_service.dart';
import 'package:printing/printing.dart';
import '../../models/transaction_model.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';

class PrintPreviewScreen extends StatefulWidget {
  final Transaction transaction;

  const PrintPreviewScreen({super.key, required this.transaction});

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  final Color primaryGreen = const Color(0xFF00BFA5); // Matching EPSON mock
  bool _isPrinting = false;

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

  void _printReceipt() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      final pdfBytes = await _generatePdfReceipt();
      final thermalService = ThermalPrinterService.instance;

      if (thermalService.isConnected) {
        // Print directly to connected bluetooth thermal printer
        final success = await thermalService.printPdf(pdfBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(success ? 'Impresión enviada correctamente' : 'Error al imprimir'),
            backgroundColor: success ? primaryGreen : Colors.red,
          ));
        }
      } else {
        // Fallback to Android System Print (AirPrint / System Spooler)
        await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdfBytes,
            name: 'Recibo_${widget.transaction.id}');
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _showPrinterPairingDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: Color(0xFF1E2333),
        title: Text('Buscando impresoras...', style: TextStyle(color: Colors.white)),
        content: SizedBox(height: 50, child: Center(child: CircularProgressIndicator())),
      )
    );

    final printers = await ThermalPrinterService.instance.scan();
    if (mounted) Navigator.pop(context); // Close loading dialog

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2333),
        title: const Text('Vincular Impresora Térmica', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (printers.isEmpty)
              const Text(
                'No se detectaron impresoras. Asegúrate de que estén encendidas, en modo de emparejamiento, y que Bluetooth esté activado.',
                style: TextStyle(color: Colors.white70),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: printers.length,
                  itemBuilder: (ctx, i) => ListTile(
                    title: Text(printers[i].name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text('MAC: ${printers[i].address}', style: const TextStyle(color: Colors.white54)),
                    trailing: const Icon(Icons.bluetooth_connected, color: Colors.white70),
                    onTap: () async {
                      Navigator.pop(ctx);
                      _connectToPrinter(printers[i].address);
                    },
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () async {
                await Permission.bluetooth.request();
                const intent = AndroidIntent(action: 'android.settings.BLUETOOTH_SETTINGS');
                await intent.launch();
              },
              icon: const Icon(Icons.settings_bluetooth, color: Color(0xFF00BFA5)),
              label: const Text('Abrir Ajustes de Bluetooth', style: TextStyle(color: Color(0xFF00BFA5))),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
        ],
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
                              color: Color(0xFFA0A8C1),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _showPrinterPairingDialog,
                  icon: const Icon(Icons.bluetooth_searching, color: Colors.white),
                  label: const Text('Vincular Impresora', style: TextStyle(color: Colors.white)),
                ),
                if (isConnected)
                  TextButton(
                    onPressed: () async {
                      await ThermalPrinterService.instance.disconnect();
                      setState(() {});
                    },
                    child: const Text('Desconectar', style: TextStyle(color: Colors.redAccent)),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketPreview() {
    final profile = context.read<SettingsProvider>().profile;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
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
        useActions: false, // Hides the built-in toolbar
        maxPageWidth: 400, // Keeps it narrow like a ticket
        initialPageFormat: PdfPageFormat.roll80, // 80mm format
        scrollViewDecoration: const BoxDecoration(color: Colors.white), // Match background
        pdfPreviewPageDecoration: const BoxDecoration(), // Remove default page styling
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151924),
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
                    const Color(0xFF151924).withValues(alpha: 0.0),
                    const Color(0xFF151924).withValues(alpha: 0.8),
                    const Color(0xFF151924),
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
