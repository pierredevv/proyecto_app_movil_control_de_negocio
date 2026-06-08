import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class PinPad extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final int maxLength;
  final int filledLength;
  final String? errorText;

  const PinPad({
    super.key,
    required this.onChanged,
    this.maxLength = 6,
    this.filledLength = 0,
    this.errorText,
  });

  void _onKey(String key) {
    HapticFeedback.lightImpact();
    onChanged(key);
  }

  void _onDelete() {
    HapticFeedback.lightImpact();
    onChanged('DEL');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (errorText != null) ...[
          Text(
            errorText!,
            style: const TextStyle(
              color: AppTheme.error,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildDots(),
        const SizedBox(height: 24),
        _buildKeypad(),
      ],
    );
  }

  Widget _buildDots() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(maxLength, (i) {
          final filled = i < filledLength;
          return Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled
                  ? AppTheme.primary
                  : Colors.transparent,
              border: Border.all(
                color: filled ? AppTheme.primary : AppTheme.textTertiary,
                width: 2,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildKeypad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['OK', '0', 'DEL'],
    ];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: keys.map((row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              return _KeypadButton(
                label: key,
                onTap: () {
                  if (key.isEmpty) return;
                  if (key == 'DEL') {
                    _onDelete();
                  } else if (key == 'OK') {
                    HapticFeedback.lightImpact();
                    onChanged('OK');
                  } else {
                    _onKey(key);
                  }
                },
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeypadButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return const SizedBox(width: 80, height: 80);
    }
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(40),
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: onTap,
          child: SizedBox(
            width: 80,
            height: 80,
            child: Center(
              child: label == 'DEL'
                  ? const Icon(
                      Icons.backspace_outlined,
                      color: AppTheme.textPrimary,
                      size: 24,
                    )
                  : label == 'OK'
                      ? const Icon(
                          Icons.check,
                          color: AppTheme.primary,
                          size: 32,
                        )
                      : Text(
                          label,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
            ),
          ),
        ),
      ),
    );
  }
}
