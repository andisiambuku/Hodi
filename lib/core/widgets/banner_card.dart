import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/l10n.dart';

enum BannerVariant { info, success, warning, error, dark }

/// Full-width banner. `success` is the mint "Loaded from this phone" style.
class BannerCard extends StatelessWidget {
  const BannerCard({
    super.key,
    required this.variant,
    required this.title,
    this.message,
    this.onDismiss,
    this.actions = const [],
  });

  final BannerVariant variant;
  final String title;
  final String? message;
  final VoidCallback? onDismiss;
  final List<Widget> actions;

  Color get _bg => switch (variant) {
    BannerVariant.info => Tokens.infoSoft,
    BannerVariant.success => Tokens.primarySoft,
    BannerVariant.warning => Tokens.warningSoft,
    BannerVariant.error => Tokens.dangerSoft,
    BannerVariant.dark => Tokens.ink,
  };

  Color get _titleColor => switch (variant) {
    BannerVariant.info => Tokens.infoText,
    BannerVariant.success => Tokens.primary,
    BannerVariant.warning => Tokens.warningText,
    BannerVariant.error => Tokens.dangerText,
    BannerVariant.dark => Colors.white,
  };

  Color get _bodyColor => switch (variant) {
    BannerVariant.dark => Colors.white70,
    _ => _titleColor,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Tokens.s16),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        border: variant == BannerVariant.error
            ? Border.all(color: Tokens.danger)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Tokens.bodyStrong.copyWith(color: _titleColor),
                ),
                if (message != null) ...[
                  const SizedBox(height: Tokens.s4),
                  Text(
                    message!,
                    style: Tokens.body.copyWith(color: _bodyColor),
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: Tokens.s12),
                  Wrap(
                    spacing: Tokens.s8,
                    runSpacing: Tokens.s8,
                    children: actions,
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              tooltip: context.l10n.dismiss,
              constraints: const BoxConstraints(
                minWidth: Tokens.minTouch,
                minHeight: Tokens.minTouch,
              ),
              padding: EdgeInsets.zero,
              onPressed: onDismiss,
              icon: Icon(Icons.close, color: _titleColor, size: 20),
            ),
        ],
      ),
    );
  }
}
