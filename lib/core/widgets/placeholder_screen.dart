import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/l10n.dart';
import '../sync/sync_status.dart';
import 'app_header.dart';

/// Temporary screen body used until each feature is built.
class PlaceholderScreen extends ConsumerWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.message,
    this.onBack,
    this.action,
  });

  final String title;
  final String? message;
  final VoidCallback? onBack;
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppHeader(
        title: title,
        status: ref.watch(syncStatusProvider),
        onBack: onBack,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message ?? context.l10n.comingSoon,
                style: Tokens.caption,
                textAlign: TextAlign.center,
              ),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}
