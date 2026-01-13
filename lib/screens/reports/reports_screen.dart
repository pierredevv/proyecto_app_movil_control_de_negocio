import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    // Load data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DashboardProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => await provider.loadDashboardData(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(context, provider),
                  const SizedBox(height: 16),
                  Text(
                    'Transacciones Recientes',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (provider.recentTransactions.isEmpty)
                    const Center(child: Text('No hay actividad reciente'))
                  else
                    ...provider.recentTransactions.map((t) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              t.type.name == 'sale'
                                  ? Icons.arrow_circle_up
                                  : Icons.arrow_circle_down,
                              color: t.type.name == 'sale'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text(t.type.name == 'sale'
                                ? 'Venta'
                                : t.type.name.toUpperCase()),
                            subtitle: Text(
                                DateFormat('dd/MM/yyyy HH:mm').format(t.date)),
                            trailing: Text(
                              '\$${t.totalAmount.toStringAsFixed(2)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, DashboardProvider provider) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Resumen de Hoy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(
                    context, 'Ventas', provider.totalSalesToday, Colors.green),
                _buildMetric(context, 'Compras', provider.totalPurchasesToday,
                    Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Balance: \$${provider.netBalance.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: provider.netBalance >= 0 ? Colors.green : Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(
      BuildContext context, String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
