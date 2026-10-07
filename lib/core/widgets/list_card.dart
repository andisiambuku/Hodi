import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// White rounded card row: leading, title/subtitle, trailing.
class ListCard extends StatelessWidget {
  const ListCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.semanticLabel,
    this.borderColor,
    this.background = Tokens.surface,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// One spoken phrase for the whole row, instead of its pieces read apart.
  final String? semanticLabel;
  final Color? borderColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Tokens.radiusCard),
      side: BorderSide(color: borderColor ?? Tokens.divider),
    );
    final card = Material(
      color: background,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Tokens.minTouch),
          child: Padding(
            padding: const EdgeInsets.all(Tokens.s16),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: Tokens.s12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Tokens.bodyStrong),
                      if (subtitle != null)
                        Text(subtitle!, style: Tokens.caption),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: Tokens.s12),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
    final label = semanticLabel;
    if (label == null) return card;
    return Semantics(
      container: true,
      label: label,
      button: onTap != null,
      excludeSemantics: true,
      child: card,
    );
  }
}
