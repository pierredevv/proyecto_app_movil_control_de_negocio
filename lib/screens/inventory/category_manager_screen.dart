import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/category.dart';
import '../../widgets/common/glass_dialog.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_layout.dart';

class CategoryManagerScreen extends StatefulWidget {
  const CategoryManagerScreen({super.key});

  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen> {
  final DatabaseService _db = DatabaseService();
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _db.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading categories: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCategoryDialog({Category? category}) async {
    final controller = TextEditingController(text: category?.name ?? '');
    final isEditing = category != null;

    final shouldSave = await showGlassDialog<bool>(
      context: context,
      title: isEditing ? 'Editar Categoría' : 'Nueva Categoría',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Nombre de la Categoría',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppTheme.blueIcon, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [AppTheme.blueIcon, Color(0xFF50A7EA)],
            ),
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );

    if (shouldSave == true && controller.text.trim().isNotEmpty && mounted) {
      try {
        if (isEditing) {
          await _db.updateCategory(Category(id: category.id, name: controller.text.trim()));
        } else {
          await _db.insertCategory(Category(name: controller.text.trim()));
        }
        if (!mounted) return;
        _loadCategories();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.redAccent),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(int id) async {
    final confirmed = await showGlassDialog<bool>(
      context: context,
      title: 'Eliminar Categoría',
      content: const Text(
        '¿Estás seguro? Los productos en esta categoría perderán su asignación.',
        style: TextStyle(color: Colors.white70, fontSize: 16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.redAccent.withValues(alpha: 0.2),
            border: Border.all(color: AppTheme.redAccent.withValues(alpha: 0.5)),
          ),
          child: TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Eliminar', style: TextStyle(color: AppTheme.redAccent, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );

    if (confirmed == true) {
      await _db.deleteCategory(id);
      if (!mounted) return;
      _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Gestión de Categorías', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: BoundedDesktopWrapper(child: Stack(
        children: [
          // Background Gradient & Blobs
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.surfaceDeep, AppTheme.surfaceSlate, AppTheme.surfaceDeep],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppTheme.blueIcon.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppTheme.blueIcon.withValues(alpha: 0.2), blurRadius: 100, spreadRadius: 20),
                ],
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _categories.isEmpty
                    ? Center(
                        child: Text(
                          'No hay categorías registradas.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 100),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.blueIcon.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.category_outlined, color: AppTheme.blueIcon),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          category.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary),
                                            onPressed: () => _showCategoryDialog(category: category),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: AppTheme.redAccent),
                                            onPressed: () => _deleteCategory(category.id!),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          
          // Fixed Floating Action Button (Glass styled)
          Positioned(
            bottom: 24,
            right: 24,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [AppTheme.blueIcon, Color(0xFF50A7EA)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.blueIcon.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: () => _showCategoryDialog(),
                backgroundColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          )
        ],
      ),),
    );
  }
}
