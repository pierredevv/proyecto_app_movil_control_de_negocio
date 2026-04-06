import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../sales/sale_detail_screen.dart';

class SalesPeriodReportScreen extends StatefulWidget {
  const SalesPeriodReportScreen({super.key});

  @override
  State<SalesPeriodReportScreen> createState() => _SalesPeriodReportScreenState();
}

class _SalesPeriodReportScreenState extends State<SalesPeriodReportScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = true;
  List<Transaction> _sales = [];
  String _selectedPeriod = 'Hoy';

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    try {
      DateTime start;
      DateTime end = DateTime.now();

      if (_selectedPeriod == 'Hoy') {
        start = DateTime(end.year, end.month, end.day);
      } else if (_selectedPeriod == 'Semana') {
        start = end.subtract(Duration(days: end.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
      } else { // 'Mes'
        start = DateTime(end.year, end.month, 1);
      }

      final transactions = await _db.getTransactionsByDateRange(
        start, 
        end, 
        type: TransactionType.sale
      );
      
      setState(() {
        _sales = transactions;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalSales => _sales.fold(0.0, (sum, item) => sum + item.totalAmount);
  int get _totalTransactions => _sales.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151924),
      appBar: AppBar(
        title: const Text('Reporte de Ventas'),
        backgroundColor: const Color(0xFF1E2432),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: const Color(0xFF1E2432),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['Hoy', 'Semana', 'Mes'].map((period) {
                final isSelected = _selectedPeriod == period;
                return ChoiceChip(
                  label: Text(period),
                  selected: isSelected,
                  selectedColor: AppTheme.primary,
                  backgroundColor: const Color(0xFF151924),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedPeriod = period);
                      _loadSales();
                    }
                  },
                );
              }).toList(),
            ),
          ),

          // Summary Card
          Padding(
             padding: const EdgeInsets.all(16.0),
             child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2432),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    const Text('Total Ventas', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Bs. ${_totalSales.toStringAsFixed(2)}', 
                        style: const TextStyle(color: AppTheme.primary, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text('$_totalTransactions Transacciones', style: const TextStyle(color: Colors.white54)),
                  ],
                ),
             ),
          ),

          // List
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _sales.isEmpty
                  ? const Center(child: Text('No hay ventas en este periodo.', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _sales.length,
                      itemBuilder: (context, index) {
                        final sale = _sales[index] as Sale;
                        return Card(
                          color: const Color(0xFF1E2432),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const CircleAvatar(
                               backgroundColor: Color(0xFF2E364A),
                               child: Icon(Icons.shopping_bag, color: AppTheme.primary, size: 20),
                            ),
                            title: Text(sale.customerName ?? 'Cliente Ocasional', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(sale.date), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            trailing: Text('Bs. ${sale.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                            onTap: () {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale)));
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
