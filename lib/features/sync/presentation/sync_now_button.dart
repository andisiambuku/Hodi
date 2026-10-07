import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/l10n.dart';

/// "Sync now" with its caption: disabled offline (with an explanation),
/// disabled with progress while a sync is running.
class SyncNowButton extends ConsumerWidget {
  const SyncNowButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final online = ref.watch(isOnlineProvider);
    final syncing = ref.watch(syncProgressProvider);
    return Column(
      children: [
        PrimaryButton(
          label: l.syncNow,
          loading: syncing != null,
          onPressed: online
              ? () => ref
                    .read(syncEngineProvider)
                    .run(trigger: SyncTrigger.manual)
              : null,
        ),
        if (syncing != null) ...[
          const SizedBox(height: Tokens.s8),
          Text(
            l.syncSending(syncing.done, syncing.total),
            style: Tokens.caption,
            textAlign: TextAlign.center,
          ),
        ] else if (!online) ...[
          const SizedBox(height: Tokens.s8),
          Text(
            l.syncAutoCaption,
            style: Tokens.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
