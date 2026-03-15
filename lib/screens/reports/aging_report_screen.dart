import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../customers/customer_ledger_screen.dart';

class AgingReportScreen extends StatefulWidget {
  const AgingReportScreen({super.key});

  @override
  State<AgingReportScreen> createState() => _AgingReportScreenState();
}

class _AgingReportScreenState extends State<AgingReportScreen> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _agingReport = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final report = await _db.getAgingReport();
      setState(() {
        _agingReport = report;
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

  Widget _buildSummaryCard() {
    final totalPendiente = _agingReport.fold<double>(
        0, (sum, item) => sum + (item['total'] as double));
    final totalVencido = _agingReport.fold<double>(
        0,
        (sum, item) =>
            sum +
            (item['days_30_60'] as double) +
            (item['days_60_plus'] as double));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFF1E2432),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]),
      child: Column(
        children: [
          const Text('Cartera Total por Cobrar',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Bs. ${totalPendiente.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Al Día', totalPendiente - totalVencido,
                  AppTheme.greenAccent),
              _buildSummaryItem(
                  'Vencido (>30d)', totalVencido, AppTheme.redAccent),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Text('Bs. ${amount.toStringAsFixed(2)}',
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _agingReport.isEmpty
              ? const Center(
                  child: Text('No hay cuentas por cobrar pendientes.',
                      style: TextStyle(color: Colors.white70)))
              : RefreshIndicator(
                  onRefresh: _loadReport,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 24),
                      const Text('Detalle por Cliente',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ..._agingReport.map((clientData) {
                        return Card(
                          color: const Color(0xFF1E2432),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerLedgerScreen(
                                    customerId: clientData['customer_id'],
                                    customerName: clientData['customer_name'],
                                  ),
                                ),
                              ).then((_) =>
                                  _loadReport()); // Refresh after returning
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(clientData['customer_name'],
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                          'Bs. ${(clientData['total'] as double).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              color: AppTheme.redAccent,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildAgeColumn(
                                          '0-30 días',
                                          clientData['current'],
                                          Colors.white70),
                                      _buildAgeColumn(
                                          '31-60 días',
                                          clientData['days_30_60'],
                                          Colors.orangeAccent),
                                      _buildAgeColumn(
                                          '+60 días',
                                          clientData['days_60_plus'],
                                          AppTheme.redAccent),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAgeColumn(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text('Bs. ${amount.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontSize: 14)),
      ],
    );
  }
}
