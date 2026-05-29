import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../services/database_service.dart';
import '../../services/report_export_service.dart';
import '../../services/snackbar_service.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_theme.dart';
import '../sales/sale_detail_screen.dart';

class SalesPeriodReportScreen extends StatefulWidget {
  const SalesPeriodReportScreen({super.key});

  @override
  State<SalesPeriodReportScreen> createState() =>
      _SalesPeriodReportScreenState();
}

class _SalesPeriodReportScreenState extends State<SalesPeriodReportScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = true;
  bool _isExporting = false;
  List<Transaction> _sales = [];
  Map<String, dynamic> _metrics = {};
  String _selectedPeriod = 'Hoy';

  // Custom date range
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  DateTime get _startDate {
    final now = DateTime.now();
    if (_selectedPeriod == 'Hoy') {
      return DateTime(now.year, now.month, now.day);
    } else if (_selectedPeriod == 'Semana') {
      final start = now.subtract(Duration(days: now.weekday - 1));
      return DateTime(start.year, start.month, start.day);
    } else if (_selectedPeriod == 'Mes') {
      return DateTime(now.year, now.month, 1);
    } else if (_selectedPeriod == 'Personalizado' && _customRange != null) {
      return _customRange!.start;
    }
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _endDate {
    if (_selectedPeriod == 'Personalizado' && _customRange != null) {
      return DateTime(_customRange!.end.year, _customRange!.end.month,
          _customRange!.end.day, 23, 59, 59);
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    try {
      final start = _startDate;
      final end = _endDate;

      // Fetch transactions list + aggregated metrics concurrently
      final results = await Future.wait([
        _db.getTransactionsByDateRange(start, end,
            type: TransactionType.sale),
        _db.getSalesReportByDateRange(start, end),
      ]);

      setState(() {
        _sales = results[0] as List<Transaction>;
        _metrics = results[1] as Map<String, dynamic>;
      });
    } catch (e) {
      if (mounted) {
        SnackbarService.showError('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectCustomDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      locale: const Locale('es', 'BO'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      setState(() {
        _customRange = range;
        _selectedPeriod = 'Personalizado';
      });
      _loadSales();
    }
  }

  Future<void> _exportReport(bool isPdf) async {
    setState(() => _isExporting = true);
    try {
      final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
      final data = SalesReportData(
        startDate: _startDate,
        endDate: _endDate,
        businessName: 'Reporte de Ventas',
        metrics: _metrics,
        transactions: _sales
            .whereType<Sale>()
            .map((sale) {
              return {
                'id': sale.id,
                'date': dateFmt.format(sale.date),
                'customer': sale.customerName ?? 'Ocasional',
                'total': sale.totalAmount,
                'status': sale.status,
              };
            })
            .toList(),
      );

      final exportService = ReportExportService();
      final bytes = isPdf
          ? await exportService.exportSalesReportPdf(data)
          : await exportService.exportSalesReportExcel(data);

      final dir = await getTemporaryDirectory();
      final ext = isPdf ? 'pdf' : 'xlsx';
      final file = File('${dir.path}/reporte_ventas.$ext');
      await file.writeAsBytes(bytes);

      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Reporte de Ventas',
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
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String get _periodLabel {
    if (_selectedPeriod == 'Personalizado' && _customRange != null) {
      final fmt = DateFormat('dd MMM', 'es_BO');
      return '${fmt.format(_customRange!.start)} — ${fmt.format(_customRange!.end)}';
    }
    return _selectedPeriod;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Reporte de Ventas'),
        backgroundColor: theme.cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar PDF',
            onPressed:
                _isLoading || _isExporting ? null : () => _exportReport(true),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Exportar Excel',
            onPressed:
                _isLoading || _isExporting ? null : () => _exportReport(false),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Period Selector ──────────────────────────────────────────
          Container(
            color: theme.cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    ['Hoy', 'Semana', 'Mes', 'Personalizado'].map((period) {
                  final isSelected = _selectedPeriod == period;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        period == 'Personalizado' && isSelected
                            ? _periodLabel
                            : period,
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.primary,
                      backgroundColor: theme.scaffoldBackgroundColor,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : theme.colorScheme.onSurface.withValues(alpha: 0.54),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      onSelected: (selected) {
                        if (!selected) return;
                        if (period == 'Personalizado') {
                          _selectCustomDateRange();
                        } else {
                          setState(() => _selectedPeriod = period);
                          _loadSales();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.greenIcon))
                : RefreshIndicator(
                    color: AppTheme.greenIcon,
                    backgroundColor: theme.cardColor,
                    onRefresh: _loadSales,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ── Metrics Cards ──────────────────────────────
                        _buildMetricsSection(theme)
                            .animate()
                            .fade(duration: 300.ms)
                            .slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 16),

                        // ── Top Products ───────────────────────────────
                        if ((_metrics['top_products'] as List?)?.isNotEmpty ==
                            true) ...[
                          _buildTopProducts(theme)
                              .animate()
                              .fade(duration: 300.ms, delay: 50.ms)
                              .slideY(begin: 0.1, end: 0, delay: 50.ms),
                          const SizedBox(height: 16),
                        ],

                        // ── Unit Breakdown ─────────────────────────────
                        if ((_metrics['unit_breakdown'] as List?)?.isNotEmpty ==
                            true) ...[
                          _buildUnitBreakdown(theme)
                              .animate()
                              .fade(duration: 300.ms, delay: 75.ms)
                              .slideY(begin: 0.1, end: 0, delay: 75.ms),
                          const SizedBox(height: 16),
                        ],

                        // ── Transaction List ───────────────────────────
                        Text(
                          'Transacciones (${_sales.length})',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ).animate().fade(duration: 300.ms, delay: 100.ms),
                        const SizedBox(height: 12),

                        if (_sales.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long,
                                      size: 64,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.2)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No hay ventas en este período.',
                                    style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.54)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._sales.asMap().entries.map((entry) {
                            final index = entry.key;
                            final sale = entry.value as Sale;
                            Widget tile = _buildSaleTile(sale, theme);
                            if (index < 10) {
                              return tile.animate().fade(
                                  duration: 250.ms,
                                  delay: (125 + index * 30).ms);
                            }
                            return tile;
                          }),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),

          // ── Export Overlay ───────────────────────────────────────────
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

  // ── METRICS SECTION ─────────────────────────────────────────────────────

  Widget _buildMetricsSection(ThemeData theme) {
    final totalSales = (_metrics['total_sales'] as num?)?.toDouble() ?? 0;
    final txCount = (_metrics['transaction_count'] as int?) ?? 0;
    final avgTicket = (_metrics['avg_ticket'] as num?)?.toDouble() ?? 0;
    final grossProfit = (_metrics['gross_profit'] as num?)?.toDouble() ?? 0;
    final marginPct =
        (_metrics['gross_margin_pct'] as num?)?.toDouble() ?? 0;
    final totalUnits =
        (_metrics['total_sale_units_sold'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text('Total Ventas',
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 16)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Bs. ${totalSales.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: AppTheme.greenAccent,
                  fontSize: 32,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _metricChip(
                  Icons.receipt_long, '$txCount ventas', theme),
              _metricChip(Icons.shopping_bag,
                  '${totalUnits.toStringAsFixed(0)} productos', theme),
              _metricChip(Icons.confirmation_number,
                  'Ticket: Bs. ${avgTicket.toStringAsFixed(2)}', theme),
              _metricChip(
                  Icons.trending_up,
                  'Margen: ${marginPct.toStringAsFixed(1)}%',
                  theme,
                  color: grossProfit >= 0
                      ? AppTheme.greenAccent
                      : AppTheme.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String text, ThemeData theme,
      {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.blueIcon).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppTheme.blueIcon),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: color ?? AppTheme.blueIcon,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── TOP PRODUCTS ────────────────────────────────────────────────────────

  Widget _buildTopProducts(ThemeData theme) {
    final topProducts = _metrics['top_products'] as List? ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text('Top Productos',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...topProducts.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final revenue =
                (p['total_revenue'] as num?)?.toDouble() ?? 0;
            final qty = (p['total_qty'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['product_name']?.toString() ?? '',
                            style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text(
                            '${qty.toStringAsFixed(1)} ${p['sale_unit'] ?? 'UNI'}',
                            style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.54),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Text('Bs. ${revenue.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: AppTheme.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── UNIT BREAKDOWN ──────────────────────────────────────────────────────

  Widget _buildUnitBreakdown(ThemeData theme) {
    final breakdown = _metrics['unit_breakdown'] as List? ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ventas por Tipo de Unidad',
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: breakdown.map((u) {
              final unit = u['sale_unit']?.toString() ?? 'UNI';
              final qty = (u['quantity'] as num?)?.toDouble() ?? 0;
              return Chip(
                avatar: Icon(
                  unit == 'CAJ' ? Icons.inventory_2 : Icons.scale,
                  size: 16,
                  color: AppTheme.blueIcon,
                ),
                label: Text(
                    '$unit: ${qty.toStringAsFixed(1)}',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface, fontSize: 13)),
                backgroundColor:
                    AppTheme.blueIcon.withValues(alpha: 0.1),
                side: BorderSide.none,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── SALE TILE ───────────────────────────────────────────────────────────

  Widget _buildSaleTile(Sale sale, ThemeData theme) {
    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              theme.colorScheme.surfaceContainerHighest,
          child:
              const Icon(Icons.shopping_bag, color: AppTheme.primary, size: 20),
        ),
        title: Text(sale.customerName ?? 'Cliente Ocasional',
            style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold)),
        subtitle: Text(
            DateFormat('dd/MM/yyyy HH:mm').format(sale.date),
            style: TextStyle(
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.54),
                fontSize: 12)),
        trailing: Text('Bs. ${sale.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
                color: AppTheme.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        onTap: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale)));
        },
      ),
    );
  }
}
