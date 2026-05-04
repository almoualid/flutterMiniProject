import 'package:flutter/material.dart';

/// A full-width primary button that shows a spinner while [isLoading] is true.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isLoading
            ? const SizedBox(
                key: ValueKey('loader'),
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(key: ValueKey('label'), label),
      ),
    );
  }
}
