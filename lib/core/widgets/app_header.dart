import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/l10n.dart';
import 'status_pill.dart';

/// Title + status pill on a white bar. Pass [onBack] for detail screens.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.title,
    required this.status,
    this.onBack,
  });

  final String title;
  final SyncStatusKind status;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Tokens.surface,
        border: Border(bottom: BorderSide(color: Tokens.divider)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.pagePadding),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    tooltip: context.l10n.back,
                    constraints: const BoxConstraints(
                      minWidth: Tokens.minTouch,
                      minHeight: Tokens.minTouch,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, color: Tokens.ink),
                  ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Tokens.heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                StatusPill(kind: status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
