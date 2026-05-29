import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/database_service.dart';
import '../../models/expense_category.dart';
import '../../widgets/common/glass_text_field_group.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  List<ExpenseCategory> _categories = [];
  int? _selectedCategoryId;
  bool _loadingCategories = true;

  String? _descError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await DatabaseService().getExpenseCategories();
      setState(() {
        _categories = cats;
        _loadingCategories = false;
      });
    } catch (e) {
      debugPrint('Error loading expense categories: $e');
      setState(() => _loadingCategories = false);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _descError = _descController.text.trim().isEmpty ? 'Requerido' : null;

      final v = double.tryParse(_amountController.text);
      if (_amountController.text.isEmpty) {
        _amountError = 'Requerido';
      } else if (v == null || v <= 0) {
        _amountError = 'Inválido';
      } else {
        _amountError = null;
      }
    });

    return _descError == null && _amountError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    if (!_formKey.currentState!.validate()) return;

    final desc = _descController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0;

    try {
      await context
          .read<DashboardProvider>()
          .addExpense(desc, amount, categoryId: _selectedCategoryId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gasto registrado exitosamente'),
            backgroundColor: Color(0xFF51CF66),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  bool _canSave() {
    return _descController.text.trim().isNotEmpty &&
        _amountController.text.isNotEmpty &&
        _descError == null &&
        _amountError == null;
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'bolt':
        return Icons.bolt;
      case 'people':
        return Icons.people;
      case 'build':
        return Icons.build;
      case 'receipt':
        return Icons.receipt;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'category':
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface, size: 24),
        title: Text(
          'Registrar Gasto',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassTextFieldGroup(
                label: 'Descripción del Gasto *',
                controller: _descController,
                icon: Icons.description_outlined,
                placeholder: 'Ej. Taxi, Almuerzo, Limpieza',
                errorText: _descError,
                onChanged: (_) {
                  setState(() {
                    _descError = _descController.text.trim().isEmpty
                        ? 'Requerido'
                        : null;
                  });
                },
              )
                  .animate()
                  .fade(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 0.ms),
              const SizedBox(height: 20),
              
              // ── Category Selector ──────────────────────────────────
              Text(
                'Categoría del Gasto',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ).animate().fade(duration: 300.ms, delay: 25.ms),
              const SizedBox(height: 8),
              _loadingCategories
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategoryId == cat.id;
                        final colorVal = int.tryParse(cat.color) ?? 0xFF6B7494;
                        final catColor = Color(colorVal);

                        return ChoiceChip(
                          avatar: Icon(
                            _getIconData(cat.icon),
                            size: 16,
                            color: isSelected ? Colors.white : catColor,
                          ),
                          label: Text(cat.name),
                          selected: isSelected,
                          selectedColor: catColor,
                          backgroundColor: theme.cardColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategoryId = selected ? cat.id : null;
                            });
                          },
                        );
                      }).toList(),
                    ).animate().fade(duration: 300.ms, delay: 25.ms),
              const SizedBox(height: 20),

              GlassTextFieldGroup(
                label: 'Monto (Bs.) *',
                controller: _amountController,
                icon: Icons.payments_outlined,
                placeholder: 'Ingresa el monto',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                errorText: _amountError,
                onChanged: (_) {
                  setState(() {
                    final v = double.tryParse(_amountController.text);
                    if (_amountController.text.isEmpty) {
                      _amountError = 'Requerido';
                    } else if (v == null || v <= 0) {
                      _amountError = 'Inválido';
                    } else {
                      _amountError = null;
                    }
                  });
                },
              )
                  .animate()
                  .fade(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 50.ms),
              const SizedBox(height: 32),
              _AnimatedSaveButton(
                onTap: _save,
                isEnabled: _canSave(),
              )
                  .animate()
                  .fade(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 100.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedSaveButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isEnabled;

  const _AnimatedSaveButton({required this.onTap, required this.isEnabled});

  @override
  State<_AnimatedSaveButton> createState() => _AnimatedSaveButtonState();
}

class _AnimatedSaveButtonState extends State<_AnimatedSaveButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Registrar Gasto',
          style: TextStyle(
              color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.diagonal3Values(
            _isPressed ? 0.97 : 1.0, _isPressed ? 0.97 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // Deep Intense Red Gradient tailored for Expenses
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4B4B), Color(0xFFFF3131)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: _isPressed
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFFFF4B4B).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ],
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.money_off, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Registrar Gasto',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
