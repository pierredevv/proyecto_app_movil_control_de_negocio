import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/cash_register_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/report_export_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/database_service.dart'; // Added DatabaseService import
import '../../theme/app_theme.dart';
import '../../utils/currency_helper.dart';
import 'cash_register_movements_screen.dart';

class CashRegisterScreen extends StatefulWidget {
  const CashRegisterScreen({super.key});

  @override
  State<CashRegisterScreen> createState() => _CashRegisterScreenState();
}

class _CashRegisterScreenState extends State<CashRegisterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _openBalanceController = TextEditingController();
  final TextEditingController _closeCountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CashRegisterProvider>().checkActiveSession();
      context.read<CashRegisterProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _openBalanceController.dispose();
    _closeCountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _showOpenDialog() async {
    _openBalanceController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text(
            'Abrir Caja Registradora',
            style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingresa el monto inicial en efectivo (fondo de caja/cambio).',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _openBalanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Fondo Inicial (${CurrencyHelper.symbol})',
                  labelStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  prefixIcon: const Icon(Icons.payments, color: AppTheme.primary),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppTheme.primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final balance = double.tryParse(_openBalanceController.text);
                if (balance == null || balance < 0) {
                  SnackbarService.showError('Monto de apertura inválido');
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await context.read<CashRegisterProvider>().openSession(balance);
                  SnackbarService.showSuccess('Caja abierta exitosamente');
                } catch (e) {
                  SnackbarService.showError('Error al abrir caja: $e');
                }
              },
              child: const Text('Abrir Caja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCloseDialog() async {
    _closeCountController.clear();
    _notesController.clear();
    final provider = context.read<CashRegisterProvider>();
    await provider.loadSessionSummary();

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final summary = provider.currentSessionSummary;
          final opening = provider.activeRegister?.openingBalance ?? 0.0;
          final expected = opening + (summary['net_cash'] as double? ?? 0.0);
          final fmt = CurrencyHelper.formatter;

          return AlertDialog(
            backgroundColor: theme.cardColor,
            title: Text(
              'Cerrar Caja Registradora',
              style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Realiza el arqueo contando el efectivo físicamente en caja.',
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  _dialogSummaryRow('Fondo Inicial:', fmt.format(opening), theme),
                  _dialogSummaryRow('Ingresos (+):', fmt.format(summary['total_cash_in'] ?? 0.0), AppTheme.greenAccent),
                  _dialogSummaryRow('Egresos (-):', fmt.format(summary['total_cash_out'] ?? 0.0), AppTheme.redAccent),
                  const Divider(),
                  _dialogSummaryRow('Efectivo Esperado:', fmt.format(expected), theme, bold: true),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _closeCountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Efectivo Real Contado (${CurrencyHelper.symbol})',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                      prefixIcon: const Icon(Icons.calculate, color: AppTheme.blueIcon),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppTheme.blueIcon),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notas / Observaciones',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                      prefixIcon: const Icon(Icons.note_alt, color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancelar', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final counted = double.tryParse(_closeCountController.text);
                  if (counted == null || counted < 0) {
                    SnackbarService.showError('Monto de arqueo inválido');
                    return;
                  }
                  final notes = _notesController.text.trim();
                  
                  // Export PDF Arqueo receipt before closing
                  final active = provider.activeRegister!;
                  final settings = context.read<SettingsProvider>();
                  final bizName = settings.businessName.isNotEmpty ? settings.businessName : 'Mi Negocio';
                  
                  final summaryData = CashRegisterCloseData(
                    businessName: bizName,
                    openDate: active.openDate,
                    closeDate: DateTime.now(),
                    openingBalance: active.openingBalance,
                    closingBalance: counted,
                    expectedBalance: expected,
                    difference: counted - expected,
                    cashSummary: summary,
                    notes: notes.isNotEmpty ? notes : null,
                  );

                  Navigator.pop(ctx);
                  try {
                    // Close DB session
                    await provider.closeSession(counted, notes);
                    SnackbarService.showSuccess('Caja cerrada y arqueada con éxito');
                    
                    // Share/Print Arqueo PDF
                    _shareArqueoPdf(summaryData);
                  } catch (e) {
                    SnackbarService.showError('Error al cerrar caja: $e');
                  }
                },
                child: const Text('Cerrar Caja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _shareArqueoPdf(CashRegisterCloseData data) async {
    try {
      final exportService = ReportExportService();
      final bytes = await exportService.exportCashRegisterClosePdf(data);
      
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/arqueo_caja_${data.openDate.millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);

      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Arqueo de Caja - ${context.read<SettingsProvider>().businessName.isNotEmpty ? context.read<SettingsProvider>().businessName : "Mi Negocio"}',
            sharePositionOrigin: box != null
                ? box.localToGlobal(Offset.zero) & box.size
                : null,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sharing arqueo PDF: $e');
    }
  }

  Widget _dialogSummaryRow(String label, String value, dynamic colorOrTheme, {bool bold = false}) {
    Color color;
    if (colorOrTheme is Color) {
      color = colorOrTheme;
    } else {
      color = (colorOrTheme as ThemeData).colorScheme.onSurface;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 14, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<CashRegisterProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Caja Registradora'),
        backgroundColor: theme.cardColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.54),
          tabs: const [
            Tab(text: 'Sesión Activa', icon: Icon(Icons.point_of_sale, size: 20)),
            Tab(text: 'Historial', icon: Icon(Icons.history, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Sesión Activa
          _buildActiveSessionTab(provider, theme),
          // TAB 2: Historial
          _buildHistoryTab(provider, theme),
        ],
      ),
    );
  }

  Widget _buildActiveSessionTab(CashRegisterProvider provider, ThemeData theme) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!provider.hasActiveRegister) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.no_accounts, size: 80, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              Text(
                'Caja Cerrada',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Abre un turno / sesión de caja antes de registrar ventas o egresos en efectivo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _showOpenDialog,
                icon: const Icon(Icons.lock_open, color: Colors.white),
                label: const Text('Abrir Turno', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ).animate().scale(delay: 100.ms, duration: 200.ms),
            ],
          ),
        ),
      );
    }

    final active = provider.activeRegister!;
    final summary = provider.currentSessionSummary;
    final opening = active.openingBalance;
    final cashIn = (summary['total_cash_in'] as num?)?.toDouble() ?? 0.0;
    final cashOut = (summary['total_cash_out'] as num?)?.toDouble() ?? 0.0;
    final netCash = (summary['net_cash'] as num?)?.toDouble() ?? 0.0;
    final expected = opening + netCash;

    final fmt = CurrencyHelper.formatter;
    final timeFmt = DateFormat('dd MMM yyyy, HH:mm', CurrencyHelper.locale);

    return RefreshIndicator(
      onRefresh: () async {
        await provider.loadSessionSummary();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active session summary header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          CircleAvatar(backgroundColor: Colors.green, radius: 4),
                          SizedBox(width: 6),
                          Text('TURNO ABIERTO', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Text(
                      'Turno #${active.id}',
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Apertura: ${timeFmt.format(active.openDate)}',
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13),
                ),
                const Divider(height: 24),
                
                Text('Efectivo Esperado en Caja', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    fmt.format(expected),
                    style: const TextStyle(color: AppTheme.blueIcon, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ).animate().fade().slideY(begin: 0.05, end: 0),

          const SizedBox(height: 16),

          // Detail cards grid
          Row(
            children: [
              Expanded(
                child: _buildCashFlowCard(
                  'Fondo Inicial',
                  fmt.format(opening),
                  Icons.lock_open,
                  Colors.grey,
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCashFlowCard(
                  'Movimiento Neto',
                  (netCash >= 0 ? '+' : '') + fmt.format(netCash),
                  netCash >= 0 ? Icons.trending_up : Icons.trending_down,
                  netCash >= 0 ? AppTheme.greenAccent : AppTheme.redAccent,
                  theme,
                ),
              ),
            ],
          ).animate().fade(delay: 50.ms).slideY(begin: 0.05, end: 0, delay: 50.ms),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildCashFlowCard(
                  'Ingresos Turno',
                  fmt.format(cashIn),
                  Icons.arrow_downward,
                  AppTheme.greenAccent,
                  theme,
                  subText: 'Ventas cash + Cobros',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCashFlowCard(
                  'Egresos Turno',
                  fmt.format(cashOut),
                  Icons.arrow_upward,
                  AppTheme.redAccent,
                  theme,
                  subText: 'Gastos + Pagos prov.',
                ),
              ),
            ],
          ).animate().fade(delay: 100.ms).slideY(begin: 0.05, end: 0, delay: 100.ms),

          const SizedBox(height: 24),

          // Action button to Close Session
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            onPressed: _showCloseDialog,
            icon: const Icon(Icons.lock, color: Colors.white),
            label: const Text('Hacer Arqueo y Cerrar Caja', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ).animate().fade(delay: 150.ms).slideY(begin: 0.05, end: 0, delay: 150.ms),
        ],
      ),
    );
  }

  Widget _buildCashFlowCard(String title, String value, IconData icon, Color accentColor, ThemeData theme, {String? subText}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (subText != null) ...[
            const SizedBox(height: 4),
            Text(
              subText,
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.35), fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildHistoryTab(CashRegisterProvider provider, ThemeData theme) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final history = provider.history;
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'No hay cierres previos registrados',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54)),
            ),
          ],
        ),
      );
    }

    final fmt = CurrencyHelper.formatter;
    final timeFmt = DateFormat('dd MMM yyyy, HH:mm', CurrencyHelper.locale);

    return RefreshIndicator(
      onRefresh: () async {
        await provider.loadHistory();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final register = history[index];
          final isClosed = register.status == 'CLOSED';
          final diff = register.difference ?? 0.0;
          
          return Card(
            color: theme.cardColor,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: Icon(
                isClosed ? Icons.lock : Icons.lock_open,
                color: isClosed ? Colors.grey : Colors.green,
              ),
              title: Text(
                isClosed
                    ? 'Turno #${register.id} — Cerrado'
                    : 'Turno #${register.id} — Abierto',
                style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Apertura: ${timeFmt.format(register.openDate)}',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12),
              ),
              childrenPadding: const EdgeInsets.all(16),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHistoryRow('Fondo de Apertura:', fmt.format(register.openingBalance), theme),
                if (isClosed) ...[
                  _buildHistoryRow('Fecha de Cierre:', timeFmt.format(register.closeDate!), theme),
                  _buildHistoryRow('Monto Esperado:', fmt.format(register.expectedBalance!), theme),
                  _buildHistoryRow('Monto Contado:', fmt.format(register.closingBalance!), theme),
                  _buildHistoryRow(
                    diff >= 0 ? 'Sobrante:' : 'Faltante:',
                    fmt.format(diff.abs()),
                    diff >= 0 ? AppTheme.greenAccent : AppTheme.redAccent,
                    bold: true,
                  ),
                ],
                if (register.notes != null && register.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Observaciones:',
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    register.notes!,
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.8), fontSize: 12),
                  ),
                ],
                if (isClosed) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final settings = context.read<SettingsProvider>();
                      final bizName = settings.businessName.isNotEmpty ? settings.businessName : 'Mi Negocio';

                      // Fetch the cash summary for that closed period
                      final db = DatabaseService();
                      final cashSummary = await db.getCashSummaryByDateRange(
                        register.openDate.millisecondsSinceEpoch,
                        register.closeDate!.millisecondsSinceEpoch,
                      );

                      final summaryData = CashRegisterCloseData(
                        businessName: bizName,
                        openDate: register.openDate,
                        closeDate: register.closeDate!,
                        openingBalance: register.openingBalance,
                        closingBalance: register.closingBalance!,
                        expectedBalance: register.expectedBalance!,
                        difference: diff,
                        cashSummary: cashSummary,
                        notes: register.notes,
                      );

                      _shareArqueoPdf(summaryData);
                    },
                    icon: const Icon(Icons.share, color: AppTheme.primary),
                    label: const Text('Exportar / Imprimir Recibo de Arqueo', style: TextStyle(color: AppTheme.primary)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.blueIcon),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CashRegisterMovementsScreen(
                            openDate: register.openDate,
                            closeDate: register.closeDate!,
                            registerId: register.id!,
                            openingBalance: register.openingBalance,
                            expectedBalance: register.expectedBalance!,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_long, color: AppTheme.blueIcon),
                    label: const Text('Ver Movimientos del Turno', style: TextStyle(color: AppTheme.blueIcon)),
                  ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryRow(String label, String value, dynamic colorOrTheme, {bool bold = false}) {
    Color color;
    if (colorOrTheme is Color) {
      color = colorOrTheme;
    } else {
      color = (colorOrTheme as ThemeData).colorScheme.onSurface;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
