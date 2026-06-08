import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class GlassTextFieldGroup extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String placeholder;
  final String? errorText;
  final TextInputType? keyboardType;
  final Function(String)? onChanged;

  const GlassTextFieldGroup({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    required this.placeholder,
    this.errorText,
    this.keyboardType,
    this.onChanged,
  });

  @override
  State<GlassTextFieldGroup> createState() => _GlassTextFieldGroupState();
}

class _GlassTextFieldGroupState extends State<GlassTextFieldGroup> {
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
      borderColor = AppTheme.redAccent;
      bgColor = Colors.white.withValues(alpha: 0.10);
    } else if (_isFocused) {
      borderColor = AppTheme.greenIcon;
      bgColor = Colors.white.withValues(alpha: 0.15);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 56),
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
                        color: AppTheme.textSecondary, size: 24),
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
                            color: AppTheme.textTertiary, fontSize: 16),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
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
                  color: AppTheme.redAccent, size: 14),
              const SizedBox(width: 4),
              Text(
                widget.errorText!,
                style: const TextStyle(color: AppTheme.redAccent, fontSize: 12),
              ),
            ],
          ),
        ]
      ],
    );
  }
}
