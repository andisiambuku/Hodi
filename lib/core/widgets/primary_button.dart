import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

enum PrimaryButtonStyle { filled, outlinedDanger, filledDanger }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = PrimaryButtonStyle.filled,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final PrimaryButtonStyle style;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Tokens.radiusButton),
    );
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(label);
    final enabled = onPressed != null && !loading;

    return switch (style) {
      PrimaryButtonStyle.filled => FilledButton(
        onPressed: enabled ? onPressed : null,
        child: child,
      ),
      PrimaryButtonStyle.filledDanger => FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Tokens.danger),
        onPressed: enabled ? onPressed : null,
        child: child,
      ),
      PrimaryButtonStyle.outlinedDanger => OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(Tokens.minTouch),
          foregroundColor: Tokens.danger,
          side: const BorderSide(color: Tokens.danger),
          shape: shape,
          textStyle: Tokens.bodyStrong,
        ),
        onPressed: enabled ? onPressed : null,
        child: Text(label),
      ),
    };
  }
}
