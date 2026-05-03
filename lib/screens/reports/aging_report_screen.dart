import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../customers/customer_ledger_screen.dart';
import '../suppliers/supplier_ledger_screen.dart';

class AgingReportScreen extends StatefulWidget {
  const AgingReportScreen({super.key});

  @override
  State<AgingReportScreen> createState() => _AgingReportScreenState();
}

class _AgingReportScreenState extends State<AgingReportScreen> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _customerAgingReport = [];
  List<Map<String, dynamic>> _supplierAgingReport = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando reporte: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSummaryCard(List<Map<String, dynamic>> report, bool isCustomer) {
    if (report.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40.0),
        child: Center(
          child: Text(
            isCustomer ? 'No hay cuentas por cobrar pendientes.' : 'No hay cuentas por pagar pendientes.',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final totalPendiente = report.fold<double>(0, (sum, item) => sum + (item['total'] as num).toDouble());
    final totalVencido = report.fold<double>(0, (sum, item) => sum + (item['days_30_60'] as num).toDouble() + (item['days_60_plus'] as num).toDouble());
    final fmt = NumberFormat.currency(symbol: 'Bs. ', decimalDigits: 2, locale: 'es_BO');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: const Color(0xFF1E2432),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
              ]),
          child: Column(
            children: [
              Text(isCustomer ? 'Cartera Total por Cobrar' : 'Cartera Total por Pagar',
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
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
                   _buildSummaryItem('Al Día', totalPendiente - totalVencido, isCustomer ? AppTheme.greenAccent : AppTheme.primary, fmt),
                   _buildSummaryItem('Vencido (>30d)', totalVencido, isCustomer ? AppTheme.redAccent : const Color(0xFFF59F00), fmt),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(isCustomer ? 'Detalle por Cliente' : 'Detalle por Proveedor',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...report.map((entityData) {
          return Card(
            color: const Color(0xFF1E2432),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text((entityData['entity_name'] as String?) ?? 'Desconocido',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(NumberFormat.currency(symbol: 'Bs. ', decimalDigits: 2, locale: 'es_BO').format((entityData['total'] as num).toDouble()),
                            style: TextStyle(color: isCustomer ? AppTheme.redAccent : AppTheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        _buildAgeColumn('0-30 días', (entityData['current'] as num).toDouble(), Colors.white70),
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

  Widget _buildSummaryItem(String label, double amount, Color color, NumberFormat fmt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Text(fmt.format(amount),
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAgeColumn(String label, double amount, Color color) {
    final fmt = NumberFormat.currency(symbol: 'Bs. ', decimalDigits: 2, locale: 'es_BO');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(fmt.format(amount), style: TextStyle(color: color, fontSize: 14)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // N4 NOTE: This screen intentionally uses hardcoded dark theme colors
    // (0xFF151924 background, 0xFF1E2432 cards). If light theme support is
    // added in the future, migrate to Theme.of(context).scaffoldBackgroundColor
    // and colorScheme equivalents.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF151924),
        appBar: AppBar(
          title: const Text('Antigüedad de Deuda'),
          backgroundColor: const Color(0xFF1E2432),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadReport,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Por Cobrar', icon: Icon(Icons.download, size: 20)),
              Tab(text: 'Por Pagar', icon: Icon(Icons.upload, size: 20)),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: _loadReport,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSummaryCard(_customerAgingReport, true),
                      ],
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: _loadReport,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSummaryCard(_supplierAgingReport, false),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
