import 'dart:ui' as ui;
import 'package:flutter/material.dart';

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
      borderColor = const Color(0xFFFF6B6B);
      bgColor = Colors.white.withValues(alpha: 0.10);
    } else if (_isFocused) {
      borderColor = const Color(0xFF4ECDC4);
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
