import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  String? _descError;
  String? _amountError;

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
      await context.read<DashboardProvider>().addExpense(desc, amount);
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
              backgroundColor: const Color(0xFFFF6B6B)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151924),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151924),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white, size: 24),
        title: const Text(
          'Registrar Gasto',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
              _GlassTextFieldGroup(
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
              const SizedBox(height: 16),
              _GlassTextFieldGroup(
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

class _GlassTextFieldGroup extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String placeholder;
  final String? errorText;
  final TextInputType? keyboardType;
  final Function(String)? onChanged;

  const _GlassTextFieldGroup({
    required this.label,
    required this.controller,
    required this.icon,
    required this.placeholder,
    this.errorText,
    this.keyboardType,
    this.onChanged,
  });

  @override
  State<_GlassTextFieldGroup> createState() => _GlassTextFieldGroupState();
}

class _GlassTextFieldGroupState extends State<_GlassTextFieldGroup> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;

    Color borderColor = Colors.white.withValues(alpha: 0.08);
    Color bgColor = Colors.white.withValues(alpha: 0.10);

    if (hasError) {
      borderColor = const Color(0xFFFF6B6B); // Red border on error
      bgColor = Colors.white.withValues(alpha: 0.10);
    } else if (_isFocused) {
      borderColor = const Color(0xFF4ECDC4); // Turquoise border on focus
      bgColor = Colors.white.withValues(alpha: 0.15);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: Color(0xFFA0A8C1),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: _isFocused || hasError ? 1.5 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(widget.icon,
                        color: const Color(0xFFA0A8C1), size: 24),
                  ),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      keyboardType: widget.keyboardType,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      onChanged: widget.onChanged,
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        hintStyle: const TextStyle(
                            color: Color(0xFF6B7494), fontSize: 16),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFFF6B6B), size: 14),
              const SizedBox(width: 4),
              Text(
                widget.errorText!,
                style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
              ),
            ],
          ),
        ]
      ],
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
