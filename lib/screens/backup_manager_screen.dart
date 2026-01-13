import 'dart:io';
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
        // Remove existing snackbars
        ScaffoldMessenger.of(context).clearSnackBars();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Exportado: ${file.path.split('/').last}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'COMPARTIR',
              textColor: Colors.white,
              onPressed: () => _shareFile(file),
            ),
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
      await BackupService.restoreFromExternalFile();
      await _loadBackups();
      if (mounted) {
        _showNotification('Restauración completada exitosamente');
      }
    } catch (e) {
      // Ignore cancel
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
  void _showNotification(String message, {bool isError = false}) {
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
        duration: const Duration(seconds: 4), // Fixed short duration
        action: isError
            ? null
            : SnackBarAction(
                label: 'OK', textColor: Colors.white, onPressed: () {}),
      ),
    );
  }

  void _showError(String message) {
    _showNotification(message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Respaldos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Restaurar', icon: Icon(Icons.restore)),
            Tab(text: 'Exportar', icon: Icon(Icons.download)),
          ],
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
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Aquí puedes gestionar los puntos de restauración del sistema. Los respaldos automáticos se guardan diariamente.',
                  style: TextStyle(color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _importExternal,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar Archivo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _export(BackupType.full, ExportFormat.json),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white),
                  icon: const Icon(Icons.save),
                  label: const Text('Nuevo Respaldo'),
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: restoreFiles.isEmpty
              ? const Center(child: Text('No hay respaldos locales'))
              : ListView.builder(
                  itemCount: restoreFiles.length,
                  itemBuilder: (context, index) {
                    final file = restoreFiles[index];
                    final name = file.path.split('/').last;
                    final stat = file.statSync();
                    final date =
                        "${stat.modified.day}/${stat.modified.month} ${stat.modified.hour}:${stat.modified.minute}";

                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.history),
                      ),
                      title: Text(name),
                      subtitle: FutureBuilder<String>(
                        future: BackupService.getBackupSize(file),
                        builder: (ctx, snap) =>
                            Text('$date • ${snap.data ?? "..."}'),
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'restore',
                            child: Row(
                              children: [
                                Icon(Icons.restore, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Restaurar')
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Compartir')
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Eliminar')
                              ],
                            ),
                          ),
                        ],
                        onSelected: (val) {
                          if (val == 'restore') _restore(file as File);
                          if (val == 'share') _shareFile(file);
                          if (val == 'delete') _delete(file);
                        },
                      ),
                    );
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
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.folder_open, color: Colors.green.shade800),
                  const SizedBox(width: 8),
                  Text('Almacenamiento Público',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900)),
                ]),
                const SizedBox(height: 8),
                Text(
                    'Los archivos exportados se guardan en la carpeta "Documents/Backups" de tu dispositivo para fácil acceso.',
                    style: TextStyle(color: Colors.green.shade900))
              ],
            )),
        const SizedBox(height: 20),
        _buildExportCard(
          title: 'Inventario de Productos',
          subtitle: 'Lista completa de productos, stock y costos.',
          icon: Icons.inventory,
          onExcel: () => _export(BackupType.products, ExportFormat.excel),
          onCsv: () => _export(BackupType.products, ExportFormat.csv),
        ),
        _buildExportCard(
          title: 'Clientes y Proveedores',
          subtitle: 'Datos de contacto de todas las partes.',
          icon: Icons.people,
          onExcel: () => _export(BackupType.parties, ExportFormat.excel),
          onCsv: () => _export(BackupType.parties, ExportFormat.csv),
        ),
        _buildExportCard(
          title: 'Base de Datos Completa',
          subtitle: 'Todas las tablas y relaciones del sistema.',
          icon: Icons.dns,
          onExcel: () => _export(BackupType.full, ExportFormat.excel),
          onCsv: () => _export(BackupType.full, ExportFormat.csv),
        ),
        const Divider(),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Opciones Individuales',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey))),
        _buildExportCard(
            title: 'Solo Clientes',
            subtitle: '',
            icon: Icons.person,
            onExcel: () => _export(BackupType.clients, ExportFormat.excel),
            onCsv: () => _export(BackupType.clients, ExportFormat.csv),
            compact: true),
        _buildExportCard(
            title: 'Solo Proveedores',
            subtitle: '',
            icon: Icons.local_shipping,
            onExcel: () => _export(BackupType.suppliers, ExportFormat.excel),
            onCsv: () => _export(BackupType.suppliers, ExportFormat.csv),
            compact: true),
      ],
    );
  }

  Widget _buildExportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onExcel,
    required VoidCallback onCsv,
    bool compact = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                    backgroundColor: Colors.grey.shade100,
                    child: Icon(icon, color: AppTheme.primary)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            if (!compact) const SizedBox(height: 16),
            if (!compact) const Divider(),
            if (!compact) const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (compact) const Spacer(),
                OutlinedButton.icon(
                  onPressed: onCsv,
                  icon: const Icon(Icons.description, size: 18),
                  label: const Text('CSV'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700]),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onExcel,
                  icon: const Icon(Icons.table_chart, size: 18),
                  label: const Text('Excel'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
