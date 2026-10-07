import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/network/fake_api_client.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/locale_provider.dart';
import '../../home/presentation/home_providers.dart';
import 'debug_remote_edits.dart';

/// Nurse details, the device name other devices see, and debug tools.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final _name = TextEditingController(text: ref.read(deviceNameProvider));

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final api = ref.watch(apiClientProvider);
    final nurse = ref.watch(nurseProfileProvider);
    final language = ref.watch(localeProvider)?.languageCode;
    return Scaffold(
      appBar: AppHeader(
        title: l.profileTitle,
        status: ref.watch(syncStatusProvider),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.pagePadding),
        children: [
          Text(l.profileNurse(nurse.firstName), style: Tokens.heading),
          Text(l.profileSubCounty(nurse.subCounty), style: Tokens.caption),
          const SizedBox(height: Tokens.s24),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l.deviceName,
              helperText: l.deviceNameHelp,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => ref.read(deviceNameProvider.notifier).rename(v),
            onTapOutside: (_) =>
                ref.read(deviceNameProvider.notifier).rename(_name.text),
          ),
          const SizedBox(height: Tokens.s24),
          DropdownButtonFormField<String?>(
            initialValue: language,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.languageTitle),
            items: [
              DropdownMenuItem(value: null, child: Text(l.langSystem)),
              // Each language is named in itself, so it can always be found.
              DropdownMenuItem(value: 'en', child: Text(l.langEnglish)),
              DropdownMenuItem(value: 'sw', child: Text(l.langSwahili)),
            ],
            onChanged: (v) => ref.read(localeProvider.notifier).choose(v),
          ),
          if (!kReleaseMode) ...[
            const SizedBox(height: Tokens.s32),
            const Text('Debug', style: Tokens.heading),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Simulate offline'),
              subtitle: const Text(
                'Acts as if the network is gone. Not in release builds.',
              ),
              value: ref.watch(simulateOfflineProvider),
              onChanged: ref.read(simulateOfflineProvider.notifier).set,
            ),
            if (api is FakeApiClient) ...[
              const SizedBox(height: Tokens.s8),
              PrimaryButton(
                label: 'Simulate temperature edit from Clinic Tablet 2',
                onPressed: () =>
                    _inject(context, () => injectRemoteTemperature(ref, api)),
              ),
              const SizedBox(height: Tokens.s8),
              PrimaryButton(
                label: 'Simulate visit type edit from Clinic Tablet 2',
                onPressed: () =>
                    _inject(context, () => injectRemoteVisitType(ref, api)),
              ),
              const SizedBox(height: Tokens.s8),
              PrimaryButton(
                label: 'Simulate delete of a visit from Clinic Tablet 2',
                onPressed: () =>
                    _inject(context, () => injectRemoteDelete(ref, api)),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _inject(
    BuildContext context,
    Future<String> Function() action,
  ) async {
    final msg = await action();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}
