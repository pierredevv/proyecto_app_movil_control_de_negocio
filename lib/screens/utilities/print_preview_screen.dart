import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/transaction_model.dart';
import '../../utils/number_to_words.dart';

class PrintPreviewScreen extends StatefulWidget {
  final Transaction transaction;

  const PrintPreviewScreen({super.key, required this.transaction});

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  final Color primaryGreen = const Color(0xFF00BFA5); // Matching EPSON mock

  Printer? _selectedPrinter;
  List<Printer> _printers = [];
  int _copies = 1;
  bool _isLoadingPrinters = true;

  // Advanced Printer Settings
  String _printMedia = 'Papel normal';
  final List<String> _mediaOptions = [
    'Papel normal',
    'Papel fino',
    'Papel grueso',
    'Sobres',
    'Etiquetas'
  ];

  String _colorMode = 'Automático';
  final List<String> _colorOptions = ['Automático', 'Color', 'Monocromo'];

  String _printQuality = 'Normal (600 x 600 dpi)';
  final List<String> _qualityOptions = [
    'Normal (600 x 600 dpi)',
    'Fina (2400 dpi)'
  ];

  bool _duplexPrinting = false;
  bool _tonerSaverMode = false;

  // Image Settings (Dummy State)
  double _brightness = 0.5;
  double _contrast = 0.5;
  double _saturation = 0.5;
  double _colorTone = 0.5;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      setState(() {
        _printers = printers.where((p) => p.isAvailable).toList();
        if (_printers.isNotEmpty) {
          _selectedPrinter = _printers.first;
        }
      });
    } catch (e) {
      debugPrint('Error loading printers: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPrinters = false);
    }
  }

  Future<Uint8List> _generatePdfReceipt() async {
    final pdf = pw.Document(
        title: 'Factura ${widget.transaction.id}',
        author: 'MI NEGOCIO S.A.',
        compress: false);

    // Dynamic Options Mapping
    final isColor = _colorMode == 'Color' || _colorMode == 'Automático';
    final textColor = isColor ? PdfColors.black : PdfColors.grey900;

    // Choose format
    PdfPageFormat ticketFormat = PdfPageFormat.roll80;
    if (_printMedia == 'Papel normal' || _printMedia == 'Papel Grueso') {
      ticketFormat = PdfPageFormat.roll80;
    } else if (_printMedia == 'Papel fino') {
      ticketFormat = PdfPageFormat.roll57;
    }

    // Multiply operations just loop generating identical pages based on Copies.
    // However, directPrintPdf supports a copies parameter as JobSettings if supported by the OS natively,
    // but generating copies in the document ensures it works everywhere.
    for (int i = 0; i < _copies; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: ticketFormat,
          margin: const pw.EdgeInsets.all(10),
          build: (pw.Context context) {
            String entityName = 'Consumidor Final';
            if (widget.transaction is Sale &&
                (widget.transaction as Sale).customerName != null &&
                (widget.transaction as Sale).customerName!.isNotEmpty) {
              entityName = (widget.transaction as Sale).customerName!;
            } else if (widget.transaction is Purchase &&
                (widget.transaction as Purchase).supplierName != null &&
                (widget.transaction as Purchase).supplierName!.isNotEmpty) {
              entityName = (widget.transaction as Purchase).supplierName!;
            }

            return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text('FACTURA',
                      style: pw.TextStyle(
                          color: textColor,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14)),
                  pw.Text('CON DERECHO A CRÉDITO FISCAL',
                      style: pw.TextStyle(
                          color: textColor,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10)),
                  pw.Text('MI NEGOCIO S.A.',
                      style: pw.TextStyle(
                          color: textColor,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12)),
                  pw.Text('SUCURSAL NO. 1',
                      style: pw.TextStyle(color: textColor, fontSize: 8)),
                  pw.Text('Punto de Venta No. 1',
                      style: pw.TextStyle(color: textColor, fontSize: 8)),
                  pw.Text('ZONA: Centro, CALLE: Bolivar #123',
                      style: pw.TextStyle(color: textColor, fontSize: 8)),
                  pw.Text('Teléfono: 70010203',
                      style: pw.TextStyle(color: textColor, fontSize: 8)),
                  pw.Text('SANTA CRUZ',
                      style: pw.TextStyle(color: textColor, fontSize: 8)),
                  pw.Text('NIT: 1020304050',
                      style: pw.TextStyle(
                          color: textColor,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8)),
                  pw.Text('NRO. FACTURA: \${widget.transaction.id ?? 0}',
                      style: pw.TextStyle(
                          color: textColor,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8)),
                  pw.Text('CÓD. AUTORIZACIÓN: F09A8B7C6D5E',
                      style: pw.TextStyle(color: textColor, fontSize: 8)),
                  pw.SizedBox(height: 8),
                  pw.Divider(
                      borderStyle: pw.BorderStyle.dashed,
                      thickness: 0.5,
                      color: isColor ? PdfColors.grey : PdfColors.black),
                  pw.SizedBox(height: 8),
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('SEÑOR(RES): $entityName',
                        style: pw.TextStyle(
                            color: textColor,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('NIT/CI: 12345678',
                        style: pw.TextStyle(
                            color: textColor,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                        'FECHA DE EMISIÓN: ${DateFormat('dd/MM/yyyy h:mm a').format(widget.transaction.date)}',
                        style: pw.TextStyle(
                            color: textColor,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(
                      borderStyle: pw.BorderStyle.dashed,
                      thickness: 0.5,
                      color: isColor ? PdfColors.grey : PdfColors.black),
                  pw.SizedBox(height: 8),
                  pw.Row(children: [
                    pw.Expanded(
                        flex: 1,
                        child: pw.Text('CANTIDAD',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                                color: textColor,
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(
                        flex: 3,
                        child: pw.Text('DESCRIPCIÓN',
                            style: pw.TextStyle(
                                color: textColor,
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text('PRECIO',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                                color: textColor,
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(
                        flex: 1,
                        child: pw.Text('DCTO',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                                color: textColor,
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text('TOTAL',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                color: textColor,
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold))),
                  ]),
                  pw.SizedBox(height: 4),
                  ...widget.transaction.items.map((item) {
                    return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Row(children: [
                          pw.Expanded(
                              flex: 1,
                              child: pw.Text(
                                  '${item.quantity.toStringAsFixed(2)} CAJ',
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(
                                      color: textColor, fontSize: 7))),
                          pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                  '1000\${item.productId} - \${item.productName}', // Mock Code
                                  style: pw.TextStyle(
                                      color: textColor, fontSize: 7),
                                  maxLines: 2)),
                          pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                  (item.subtotal / item.quantity)
                                      .toStringAsFixed(2),
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(
                                      color: textColor, fontSize: 7))),
                          pw.Expanded(
                              flex: 1,
                              child: pw.Text('0.00',
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(
                                      color: textColor, fontSize: 7))),
                          pw.Expanded(
                              flex: 2,
                              child: pw.Text(item.subtotal.toStringAsFixed(2),
                                  textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(
                                      color: textColor, fontSize: 7))),
                        ]));
                  }),
                  pw.SizedBox(height: 8),
                  pw.Divider(
                      borderStyle: pw.BorderStyle.dashed,
                      thickness: 0.5,
                      color: isColor ? PdfColors.grey : PdfColors.black),
                  pw.SizedBox(height: 8),
                  _buildPdfTotalRow(
                      'SUBTOTAL', widget.transaction.totalAmount, textColor),
                  _buildPdfTotalRow('DESCUENTO', 0.00, textColor),
                  _buildPdfTotalRow('TOTAL A PAGAR',
                      widget.transaction.totalAmount, textColor),
                  _buildPdfTotalRow('EFECTIVO',
                      widget.transaction.totalAmount + 10.0, textColor,
                      isBold: false),
                  _buildPdfTotalRow('CAMBIO', 10.00, textColor, isBold: false),
                  _buildPdfTotalRow('IMPORTE BASE CRÉDITO FISCAL',
                      widget.transaction.totalAmount, textColor),
                  pw.SizedBox(height: 12),
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                        NumberToWords.toLiteral(widget.transaction.totalAmount),
                        style: pw.TextStyle(
                            color: textColor,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(
                      borderStyle: pw.BorderStyle.dashed,
                      thickness: 0.5,
                      color: isColor ? PdfColors.grey : PdfColors.black),
                  pw.SizedBox(height: 8),
                  pw.Text(
                      '"ESTA FACTURA CONTRIBUYE AL\nDESARROLLO DEL PAÍS. EL USO ILÍCITO\nSERÁ SANCIONADO PENALMENTE DE ACUERDO A LEY"',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          color: textColor,
                          fontSize: 7,
                          fontStyle: pw.FontStyle.italic,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      'Ley N° 453: El proveedor deberá suministrar el servicio sin discriminación, con respeto, calidez y trato cortés a los usuarios y consumidores.',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(color: textColor, fontSize: 6)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      'Este documento es la representación gráfica de un documento fiscal emitido en una modalidad de facturación en línea.',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(color: textColor, fontSize: 6)),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    width: 60,
                    height: 60,
                    child: pw.BarcodeWidget(
                      color: textColor,
                      barcode: pw.Barcode.qrCode(),
                      data:
                          'https://siat.impuestos.gob.bo/consulta/QR?nit=1020304050&cuf=F09A',
                      drawText: false,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Doc: FFA/000-000\${widget.transaction.id}',
                      style: pw.TextStyle(color: textColor, fontSize: 6)),
                  pw.Text('SalesSystem - v1.0',
                      style: pw.TextStyle(color: textColor, fontSize: 6)),
                ]);
          },
        ),
      );
    }
    return pdf.save();
  }

  pw.Widget _buildPdfTotalRow(String label, double amount, PdfColor textColor,
      {bool isBold = true}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  color: textColor,
                  fontSize: 8,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('Bs. ${amount.toStringAsFixed(2)}',
              style: pw.TextStyle(
                  color: textColor,
                  fontSize: 8,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  void _printReceipt() async {
    final pdfBytes = await _generatePdfReceipt();

    if (_selectedPrinter != null) {
      await Printing.directPrintPdf(
          printer: _selectedPrinter!,
          onLayout: (PdfPageFormat format) => pdfBytes);
    } else {
      // Fallback to system dialog if no printer natively found
      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) => pdfBytes,
          name: 'Recibo_\${widget.transaction.id}');
    }
  }

  void _incrementCopies() => setState(() => _copies++);
  void _decrementCopies() {
    if (_copies > 1) setState(() => _copies--);
  }

  Widget _buildDropdownRow(String label, String currentValue,
      List<String> options, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: currentValue,
                  dropdownColor: const Color(0xFF1E2333),
                  isDense: true,
                  isExpanded: true,
                  icon:
                      const Icon(Icons.arrow_drop_down, color: Colors.white54),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.normal),
                  items: options.map((opt) {
                    return DropdownMenuItem(
                        value: opt,
                        child: Text(opt, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSwitchRow(
      String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 14)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: primaryGreen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      dense: true,
    );
  }

  void _showAdvancedSettingsDialog() {
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF151924),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return StatefulBuilder(builder: (context, setModalState) {
            Widget buildSlider(
                String title, double value, ValueChanged<double> onChanged) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                      Text('${(value * 100).toInt()}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                  Slider(
                    value: value,
                    activeColor: primaryGreen,
                    inactiveColor: Colors.white24,
                    onChanged: (val) {
                      setModalState(() => onChanged(val));
                      setState(() => onChanged(val)); // Sync main state
                    },
                  )
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20,
                  right: 20,
                  top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ajustes Avanzados',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  buildSlider(
                      'Brillo', _brightness, (val) => _brightness = val),
                  const SizedBox(height: 12),
                  buildSlider('Contraste', _contrast, (val) => _contrast = val),
                  const SizedBox(height: 12),
                  buildSlider(
                      'Saturación', _saturation, (val) => _saturation = val),
                  const SizedBox(height: 12),
                  buildSlider(
                      'Tono de Color', _colorTone, (val) => _colorTone = val),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('APLICAR',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          });
        });
  }

  Widget _buildTopPrinterConfigurator() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
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
                    color: primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.print, color: primaryGreen),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('IMPRESORA',
                          style: TextStyle(
                              color: Color(0xFFA0A8C1),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                      if (_isLoadingPrinters)
                        const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                      else if (_printers.isEmpty)
                        const Text('Ninguna detectada',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold))
                      else
                        DropdownButtonHideUnderline(
                          child: DropdownButton<Printer>(
                            value: _selectedPrinter,
                            dropdownColor: const Color(0xFF1E2333),
                            isDense: true,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down,
                                color: Colors.white70),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            items: _printers.map((p) {
                              return DropdownMenuItem<Printer>(
                                value: p,
                                child: Text(p.name,
                                    overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedPrinter = val);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Número de copias',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                Row(
                  children: [
                    InkWell(
                      onTap: _decrementCopies,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: primaryGreen.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.remove,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    Container(
                      width: 40,
                      alignment: Alignment.center,
                      child: Text('$_copies',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                    InkWell(
                      onTap: _incrementCopies,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: primaryGreen.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.add, color: primaryGreen, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Advanced Setup specific to traditional Printers
          _buildDropdownRow('Soporte de imp.', _printMedia, _mediaOptions,
              (val) => setState(() => _printMedia = val!)),
          _buildDropdownRow('Color', _colorMode, _colorOptions,
              (val) => setState(() => _colorMode = val!)),
          _buildDropdownRow('Calidad', _printQuality, _qualityOptions,
              (val) => setState(() => _printQuality = val!)),
          const Divider(color: Colors.white12, height: 1),
          _buildSwitchRow('Impresión a doble cara', _duplexPrinting,
              (val) => setState(() => _duplexPrinting = val)),
          _buildSwitchRow('Ahorro de tóner', _tonerSaverMode,
              (val) => setState(() => _tonerSaverMode = val)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTicketPreview() {
    String entityName = 'Consumidor Final';
    if (widget.transaction is Sale &&
        (widget.transaction as Sale).customerName != null &&
        (widget.transaction as Sale).customerName!.isNotEmpty) {
      entityName = (widget.transaction as Sale).customerName!;
    } else if (widget.transaction is Purchase &&
        (widget.transaction as Purchase).supplierName != null &&
        (widget.transaction as Purchase).supplierName!.isNotEmpty) {
      entityName = (widget.transaction as Purchase).supplierName!;
    }

    // Dynamic Options Mapping for Preview
    final isColor = _colorMode == 'Color' || _colorMode == 'Automático';
    final textColor = isColor ? Colors.black : Colors.black87;
    final dividerColor = isColor ? Colors.black38 : Colors.black;

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
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('FACTURA',
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'monospace')),
          Text('CON DERECHO A CRÉDITO FISCAL',
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  fontFamily: 'monospace')),
          Text('MI NEGOCIO S.A.',
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'monospace')),
          Text('SUCURSAL NO. 1',
              style: TextStyle(
                  color: textColor, fontSize: 10, fontFamily: 'monospace')),
          Text('Punto de Venta No. 1',
              style: TextStyle(
                  color: textColor, fontSize: 10, fontFamily: 'monospace')),
          Text('ZONA: Centro, CALLE: Bolivar #123',
              style: TextStyle(
                  color: textColor, fontSize: 10, fontFamily: 'monospace')),
          Text('Teléfono: 70010203',
              style: TextStyle(
                  color: textColor, fontSize: 10, fontFamily: 'monospace')),
          Text('SANTA CRUZ',
              style: TextStyle(
                  color: textColor, fontSize: 10, fontFamily: 'monospace')),
          Text('NIT: 1020304050',
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  fontFamily: 'monospace')),
          Text('NRO. FACTURA: \${widget.transaction.id ?? 0}',
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  fontFamily: 'monospace')),
          Text('CÓD. AUTORIZACIÓN: F09A8B7C6D5E',
              style: TextStyle(
                  color: textColor, fontSize: 10, fontFamily: 'monospace')),

          const SizedBox(height: 8),
          Text('- - - - - - - - - - - - - - - - - - - - - - ',
              maxLines: 1,
              style: TextStyle(color: dividerColor, fontFamily: 'monospace')),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SEÑOR(RES): $entityName',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
                Text('NIT/CI: 12345678',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
                Text(
                    'FECHA DE EMISIÓN: ${DateFormat('dd/MM/yyyy h:mm a').format(widget.transaction.date)}',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Text('- - - - - - - - - - - - - - - - - - - - - - ',
              maxLines: 1,
              style: TextStyle(color: dividerColor, fontFamily: 'monospace')),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                  flex: 1,
                  child: Text('CANTIDAD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace'))),
              Expanded(
                  flex: 3,
                  child: Text('DESCRIPCIÓN',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace'))),
              Expanded(
                  flex: 2,
                  child: Text('PRECIO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace'))),
              Expanded(
                  flex: 1,
                  child: Text('DCTO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace'))),
              Expanded(
                  flex: 2,
                  child: Text('TOTAL',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace'))),
            ],
          ),
          const SizedBox(height: 8),

          Column(
            children: widget.transaction.items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                        flex: 1,
                        child: Text('${item.quantity.toStringAsFixed(2)} CAJ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: textColor,
                                fontSize: 10,
                                fontFamily: 'monospace'))),
                    Expanded(
                        flex: 3,
                        child: Text(
                            '1000\${item.productId} - \${item.productName}',
                            style: TextStyle(
                                color: textColor,
                                fontSize: 10,
                                fontFamily: 'monospace'),
                            maxLines: 2)),
                    Expanded(
                        flex: 2,
                        child: Text(
                            (item.subtotal / item.quantity).toStringAsFixed(2),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: textColor,
                                fontSize: 10,
                                fontFamily: 'monospace'))),
                    Expanded(
                        flex: 1,
                        child: Text('0.00',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: textColor,
                                fontSize: 10,
                                fontFamily: 'monospace'))),
                    Expanded(
                        flex: 2,
                        child: Text(item.subtotal.toStringAsFixed(2),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: textColor,
                                fontSize: 10,
                                fontFamily: 'monospace'))),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),
          Text('- - - - - - - - - - - - - - - - - - - - - - ',
              maxLines: 1,
              style: TextStyle(color: dividerColor, fontFamily: 'monospace')),
          const SizedBox(height: 8),

          _buildTicketTotalRow(
              'SUBTOTAL', widget.transaction.totalAmount, textColor),
          _buildTicketTotalRow('DESCUENTO', 0.00, textColor),
          _buildTicketTotalRow(
              'TOTAL A PAGAR', widget.transaction.totalAmount, textColor),
          _buildTicketTotalRow(
              'EFECTIVO', widget.transaction.totalAmount + 10.0, textColor,
              isBold: false),
          _buildTicketTotalRow('CAMBIO', 10.00, textColor, isBold: false),
          _buildTicketTotalRow('IMPORTE BASE CRÉDITO FISCAL',
              widget.transaction.totalAmount, textColor),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Text(NumberToWords.toLiteral(widget.transaction.totalAmount),
                style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace')),
          ),

          const SizedBox(height: 8),
          Text('- - - - - - - - - - - - - - - - - - - - - - ',
              maxLines: 1,
              style: TextStyle(color: dividerColor, fontFamily: 'monospace')),
          const SizedBox(height: 8),

          Text(
              '"ESTA FACTURA CONTRIBUYE AL\nDESARROLLO DEL PAÍS. EL USO ILÍCITO\nSERÁ SANCIONADO PENALMENTE DE ACUERDO A LEY"',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: textColor,
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),

          const SizedBox(height: 8),
          Text(
              'Ley N° 453: El proveedor deberá suministrar el servicio sin discriminación, con respeto, calidez y trato cortés a los usuarios y consumidores.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: textColor, fontSize: 8, fontFamily: 'monospace')),

          const SizedBox(height: 8),
          Text(
              'Este documento es la representación gráfica de un documento fiscal emitido en una modalidad de facturación en línea.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: textColor, fontSize: 8, fontFamily: 'monospace')),

          const SizedBox(height: 16),
          Icon(Icons.qr_code_2,
              size: 80, color: textColor), // Placeholder QR equivalent

          const SizedBox(height: 8),
          Text('Doc: FFA/000-000\${widget.transaction.id}',
              style: TextStyle(
                  color: textColor, fontSize: 8, fontFamily: 'monospace')),
          Text('SalesSystem - v1.0',
              style: TextStyle(
                  color: textColor, fontSize: 8, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildTicketTotalRow(String label, double amount, Color textColor,
      {bool isBold = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'monospace')),
          Text('Bs. ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'monospace')),
        ],
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
        actions: [
          IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: _showAdvancedSettingsDialog),
        ],
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
                  SliverToBoxAdapter(
                    child: _buildTicketPreview(),
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
                onPressed: _printReceipt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 8,
                  shadowColor: primaryGreen.withValues(alpha: 0.5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.print, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'IMPRIMIR AHORA',
                      style: TextStyle(
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
