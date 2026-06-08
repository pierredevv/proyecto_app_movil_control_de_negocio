import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/database_service.dart';
import '../../services/report_export_service.dart';
import '../../services/snackbar_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_helper.dart';
import '../customers/customer_ledger_screen.dart';
import '../suppliers/supplier_ledger_screen.dart';

class AgingReportScreen extends StatefulWidget {
  const AgingReportScreen({super.key});

  @override
  State<AgingReportScreen> createState() => _AgingReportScreenState();
}

class _AgingReportScreenState extends State<AgingReportScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _customerAgingReport = [];
  List<Map<String, dynamic>> _supplierAgingReport = [];
  bool _isLoading = true;
  bool _isExporting = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final customers = await _db.getAgingReport(entityType: 'CUSTOMER');
      final suppliers = await _db.getAgingReport(entityType: 'SUPPLIER');
      setState(() {
        _customerAgingReport = customers;
        _supplierAgingReport = suppliers;
      });
    } catch (e) {
      if (mounted) {
        SnackbarService.showError('Error cargando reporte: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportReport(bool isPdf) async {
    setState(() => _isExporting = true);
    try {
      final isCustomerTab = _tabController.index == 0;
      final report = isCustomerTab ? _customerAgingReport : _supplierAgingReport;
      final entityType = isCustomerTab ? 'CUSTOMER' : 'SUPPLIER';
      final title = isCustomerTab ? 'Cuentas por Cobrar' : 'Cuentas por Pagar';

      final totalPending = report.fold<double>(0, (sum, item) => sum + (item['total'] as num).toDouble());

      final exportService = ReportExportService();
      final data = AgingReportData(
        businessName: title,
        entityType: entityType,
        report: report,
        totalPending: totalPending,
      );

      final bytes = isPdf
          ? await exportService.exportAgingReportPdf(data)
          : await exportService.exportAgingReportExcel(data);

      final dir = await getTemporaryDirectory();
      final ext = isPdf ? 'pdf' : 'xlsx';
      final file = File('${dir.path}/reporte_antiguedad_$entityType.$ext');
      await file.writeAsBytes(bytes);

      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Reporte de Antigüedad de Deuda ($title)',
            sharePositionOrigin: box != null
                ? box.localToGlobal(Offset.zero) & box.size
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarService.showError('Error al exportar: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Widget _buildSummaryCard(List<Map<String, dynamic>> report, bool isCustomer, ThemeData theme) {
    if (report.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                isCustomer ? 'No hay cuentas por cobrar pendientes.' : 'No hay cuentas por pagar pendientes.',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      );
    }

    final totalPendiente = report.fold<double>(0, (sum, item) => sum + (item['total'] as num).toDouble());
    final totalVencido = report.fold<double>(0, (sum, item) => sum + (item['days_30_60'] as num).toDouble() + (item['days_60_plus'] as num).toDouble());
    final fmt = CurrencyHelper.formatter;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
              ]),
          child: Column(
            children: [
              Text(isCustomer ? 'Cartera Total por Cobrar' : 'Cartera Total por Pagar',
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 16)),
              const SizedBox(height: 8),
              Text(fmt.format(totalPendiente),
                  style: TextStyle(
                      color: isCustomer ? AppTheme.primary : AppTheme.redAccent,
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                children: [
                   _buildSummaryItem('Al Día', totalPendiente - totalVencido, isCustomer ? AppTheme.greenAccent : AppTheme.primary, fmt, theme),
                   _buildSummaryItem('Vencido (>30d)', totalVencido, isCustomer ? AppTheme.redAccent : const Color(0xFFF59F00), fmt, theme),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(isCustomer ? 'Detalle por Cliente' : 'Detalle por Proveedor',
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...report.map((entityData) {
          return Card(
            color: theme.cardColor,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (isCustomer) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerLedgerScreen(
                        customerId: entityData['entity_id'],
                        customerName: entityData['entity_name'],
                      ),
                    ),
                  ).then((_) => _loadReport());
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupplierLedgerScreen(
                        supplierId: entityData['entity_id'],
                        supplierName: entityData['entity_name'],
                      ),
                    ),
                  ).then((_) => _loadReport());
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            (entityData['entity_name'] as String?) ?? 'Desconocido',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyHelper.formatter
                                .format(
                                    (entityData['total'] as num).toDouble()),
                            style: TextStyle(
                                color: isCustomer
                                    ? AppTheme.redAccent
                                    : AppTheme.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        _buildAgeColumn('0-30 días', (entityData['current'] as num).toDouble(), theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                        _buildAgeColumn('31-60 días', (entityData['days_30_60'] as num).toDouble(), Colors.orangeAccent),
                        _buildAgeColumn('+60 días', (entityData['days_60_plus'] as num).toDouble(), isCustomer ? AppTheme.redAccent : const Color(0xFFF59F00)),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color, NumberFormat fmt, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14)),
        Text(fmt.format(amount),
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAgeColumn(String label, double amount, Color color) {
    final fmt = CurrencyHelper.formatter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12)),
        const SizedBox(height: 4),
        Text(fmt.format(amount), style: TextStyle(color: color, fontSize: 14)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Antigüedad de Deuda'),
        backgroundColor: theme.cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar PDF',
            onPressed: _isLoading || _isExporting ? null : () => _exportReport(true),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Exportar Excel',
            onPressed: _isLoading || _isExporting ? null : () => _exportReport(false),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.54),
          tabs: const [
            Tab(text: 'Por Cobrar', icon: Icon(Icons.download, size: 20)),
            Tab(text: 'Por Pagar', icon: Icon(Icons.upload, size: 20)),
          ],
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    RefreshIndicator(
                      onRefresh: _loadReport,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildSummaryCard(_customerAgingReport, true, theme),
                        ],
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: _loadReport,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildSummaryCard(_supplierAgingReport, false, theme),
                        ],
                      ),
                    ),
                  ],
                ),
          if (_isExporting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Generando reporte...'),
                      ],
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
