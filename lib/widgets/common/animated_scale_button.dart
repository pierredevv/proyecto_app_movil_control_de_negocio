import 'package:flutter/material.dart';
import '../../utils/haptic_feedback_helper.dart';

enum ButtonState { idle, loading, success }

class AnimatedScaleButton extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onPressed;
  final ButtonState state;
  final Duration animationDuration;
  final Color? successColor;

  const AnimatedScaleButton({
    super.key,
    required this.child,
    this.onPressed,
    this.state = ButtonState.idle,
    this.animationDuration = const Duration(milliseconds: 100),
    this.successColor,
  });

  @override
  State<AnimatedScaleButton> createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<AnimatedScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      lowerBound: 0.0,
      upperBound: 0.03, // Scales down to 0.97
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.state != ButtonState.idle || widget.onPressed == null) return;
    HapticFeedbackHelper.lightImpact();
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.state != ButtonState.idle || widget.onPressed == null) return;
    _controller.reverse();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    if (widget.state != ButtonState.idle) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // Handling button content based on state
    Widget content = widget.child;

    if (widget.state == ButtonState.loading) {
      content = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    } else if (widget.state == ButtonState.success) {
      content = Icon(
        Icons.check,
        color: widget.successColor ?? Colors.white,
        size: 24,
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: content,
            ),
          );
        },
      ),
    );
  }
}
