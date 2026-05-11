import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';

class BackupManagerScreen extends StatefulWidget {
  const BackupManagerScreen({super.key});

  @override
  State<BackupManagerScreen> createState() => _BackupManagerScreenState();
}

class _BackupManagerScreenState extends State<BackupManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FileSystemEntity> _backups = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final files = await BackupService.listBackups();
      setState(() => _backups = files);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _export(BackupType type, ExportFormat format) async {
    setState(() => _isLoading = true);
    try {
      final file = await BackupService.exportData(type: type, format: format);
      await _loadBackups(); // Refresh list to show new file

      if (mounted) {
        _showNotification(
          'Exportado: ${file.path.split('/').last}',
          action: SnackBarAction(
            label: 'COMPARTIR',
            textColor: Colors.white,
            onPressed: () => _shareFile(file),
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restore(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Restauración'),
        content: const Text(
            'ADVERTENCIA: Se reemplazarán todos los datos actuales con los del respaldo.\n\nSe creará un respaldo de seguridad automático antes de proceder.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('RESTAURAR')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await BackupService.restoreBackup(file);
      await _loadBackups();
      if (mounted) {
        _showNotification('Restauración completada exitosamente');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importExternal() async {
    setState(() => _isLoading = true);
    try {
      final success = await BackupService.restoreFromExternalFile();
      if (success) {
        await _loadBackups();
        if (mounted) {
          _showNotification('Restauración completada exitosamente');
        }
      } else {
        if (mounted) {
          _showError('No se seleccionó ningún archivo');
        }
      }
    } catch (e) {
      // Ignore normal cancel, catch specific formatting or other errors
      if (!e.toString().contains('User canceled')) {
        _showError(e.toString());
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(FileSystemEntity file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Respaldo'),
        content:
            Text('¿Estás seguro de eliminar ${file.path.split('/').last}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await BackupService.deleteBackup(file);
      _loadBackups();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _shareFile(FileSystemEntity file) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Respaldo generado'),
    );
  }

  // Helper for styled notifications
  void _showNotification(String message,
      {bool isError = false, SnackBarAction? action}) {
    if (!mounted) return;

    // Remove existing snackbars
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating, // Floating style
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3), // Quicker teardown
        dismissDirection: DismissDirection.horizontal, // Swipe to dismiss
        action: action ??
            (isError
                ? null
                : SnackBarAction(
                    label: 'OK', textColor: Colors.white, onPressed: () {})),
      ),
    );
  }

  void _showError(String message) {
    _showNotification(message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151924),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Gestión de Respaldos',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelColor: const Color(0xFFA0A8C1),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal, fontSize: 13),
                    tabs: [
                      Tab(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.restore,
                                  size: 20,
                                  color: _tabController.index == 0
                                      ? AppTheme.primary
                                      : const Color(0xFF6B7494)),
                              const SizedBox(width: 6),
                              const Text('Restaurar'),
                            ],
                          ),
                        ),
                      ),
                      Tab(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download,
                                  size: 20,
                                  color: _tabController.index == 1
                                      ? AppTheme.primary
                                      : const Color(0xFF6B7494)),
                              const SizedBox(width: 6),
                              const Text('Exportar'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRestoreTab(),
                _buildExportTab(),
              ],
            ),
    );
  }

  // TAB 1: RESTORE (JSON ONLY)
  Widget _buildRestoreTab() {
    // Filter only JSON for restore list
    final restoreFiles =
        _backups.where((f) => f.path.endsWith('.json')).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF4A90E2).withValues(alpha: 0.20),
                      width: 1.0),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF4A90E2), size: 18),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Aquí puedes gestionar los puntos de restauración del sistema. Los respaldos automáticos se guardan diariamente.',
                        style: TextStyle(
                            color: Color(0xFFA0A8C1),
                            fontSize: 13,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildSecondaryGlassButton(
                  onTap: _importExternal,
                  icon: Icons.upload_file,
                  label: 'Importar Archivo',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPrimaryGradientButton(
                  onTap: () => _export(BackupType.full, ExportFormat.json),
                  icon: Icons.save,
                  label: 'Nuevo Respaldo',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: restoreFiles.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: restoreFiles.length,
                  itemBuilder: (context, index) {
                    final file = restoreFiles[index];
                    final name = file.path.split('/').last;
                    final stat = file.statSync();
                    final date =
                        "${stat.modified.day}/${stat.modified.month} ${stat.modified.hour.toString().padLeft(2, '0')}:${stat.modified.minute.toString().padLeft(2, '0')}";

                    return _buildBackupCard(file, name, date);
                  },
                ),
        ),
      ],
    );
  }

  // TAB 2: EXPORT (EXCEL/CSV - GRANULAR)
  Widget _buildExportTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF51CF66).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF51CF66).withValues(alpha: 0.25)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.folder_open, color: Color(0xFF51CF66), size: 20),
                    SizedBox(width: 8),
                    Text('Almacenamiento Local',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF51CF66))),
                  ]),
                  SizedBox(height: 8),
                  Text(
                      'Los archivos exportados se guardan de forma segura en la aplicación. Puedes usar la opción Compartir para enviarlos a otros destinos.',
                      style: TextStyle(
                          color: Color(0xFFA0A8C1), fontSize: 13, height: 1.5))
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildExportCard(
          title: 'Inventario de Productos',
          subtitle: 'Lista completa de productos, stock y costos.',
          icon: Icons.inventory,
          moduleColor: const Color(0xFFFF6B9D),
          onExcel: () => _export(BackupType.products, ExportFormat.excel),
          onCsv: () => _export(BackupType.products, ExportFormat.csv),
        ),
        _buildExportCard(
          title: 'Clientes y Proveedores',
          subtitle: 'Datos de contacto de todas las partes.',
          icon: Icons.people,
          moduleColor: const Color(0xFF4ECDC4),
          onExcel: () => _export(BackupType.parties, ExportFormat.excel),
          onCsv: () => _export(BackupType.parties, ExportFormat.csv),
        ),
        _buildExportCard(
          title: 'Base de Datos Completa',
          subtitle: 'Todas las tablas y relaciones del sistema.',
          icon: Icons.dns,
          moduleColor: const Color(0xFF4A90E2),
          onExcel: () => _export(BackupType.full, ExportFormat.excel),
          onCsv: () => _export(BackupType.full, ExportFormat.csv),
        ),
        const SizedBox(height: 24),
        const Text('OPCIONES INDIVIDUALES',
            style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                letterSpacing: 1.2,
                color: Color(0xFF6B7494))),
        const SizedBox(height: 12),
        _buildExportCard(
            title: 'Solo Clientes',
            subtitle: '',
            icon: Icons.person,
            moduleColor: const Color(0xFF4ECDC4),
            onExcel: () => _export(BackupType.clients, ExportFormat.excel),
            onCsv: () => _export(BackupType.clients, ExportFormat.csv),
            compact: true),
        _buildExportCard(
            title: 'Solo Proveedores',
            subtitle: '',
            icon: Icons.local_shipping,
            moduleColor: const Color(0xFF4ECDC4),
            onExcel: () => _export(BackupType.suppliers, ExportFormat.excel),
            onCsv: () => _export(BackupType.suppliers, ExportFormat.csv),
            compact: true),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B)
                        .withValues(alpha: 0.06), // Very subtle
                    shape: BoxShape.circle,
                  ),
                ),
                Icon(Icons.history,
                    size: 96,
                    color: const Color(0xFFFF6B6B)
                        .withValues(alpha: 0.30)), // 30% icon
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Aún no hay respaldos',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Crea tu primer respaldo para proteger\nlos datos de tu negocio',
              style: TextStyle(
                  color: Color(0xFFA0A8C1), fontSize: 16, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            InkWell(
              onTap: () => _export(BackupType.full, ExportFormat.json),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF5757)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      '+ Crear Primer Respaldo',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryGlassButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.20), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: const Color(0xFFA0A8C1), size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryGradientButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF5757)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackupCard(FileSystemEntity file, String name, String date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08), width: 1.5),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Coral Border
                  Container(
                    width: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B6B),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          // Circular Icon
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFFF6B6B)
                                      .withValues(alpha: 0.25),
                                  width: 1),
                            ),
                            child: const Icon(Icons.history,
                                color: Color(0xFFFF6B6B), size: 20),
                          ),
                          const SizedBox(width: 14),
                          // Text Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 3),
                                FutureBuilder<String>(
                                  future: BackupService.getBackupSize(file),
                                  builder: (ctx, snap) => Text(
                                    '$date • ${snap.data ?? "..."}',
                                    style: const TextStyle(
                                        color: Color(0xFF6B7494),
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Specific ⋮ Menu
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => _buildBottomSheetMenu(file),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child:
                              Icon(Icons.more_vert, color: Color(0xFF6B7494)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetMenu(FileSystemEntity file) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B), // Match dark theme bottoms
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.restore, color: Colors.green),
            title:
                const Text('Restaurar', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _restore(file as File);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.blue),
            title:
                const Text('Compartir', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _shareFile(file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title:
                const Text('Eliminar', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _delete(file);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildExportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color moduleColor,
    required VoidCallback onExcel,
    required VoidCallback onCsv,
    bool compact = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08), width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: moduleColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: moduleColor.withValues(alpha: 0.25),
                                width: 1),
                          ),
                          child: Icon(icon, color: moduleColor, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16)),
                              if (subtitle.isNotEmpty)
                                Text(subtitle,
                                    style: const TextStyle(
                                        color: Color(0xFFA0A8C1),
                                        fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                        height: 1,
                        thickness: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (compact) const Spacer(),
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20),
                                width: 1.5),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onCsv,
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    Icon(Icons.description,
                                        color: Color(0xFFA0A8C1), size: 18),
                                    SizedBox(width: 6),
                                    Text('CSV',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF51CF66), Color(0xFF3DBD56)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF51CF66)
                                    .withValues(alpha: 0.30),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onExcel,
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    Icon(Icons.table_chart,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 6),
                                    Text('Excel',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: moduleColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
