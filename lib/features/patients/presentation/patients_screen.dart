import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/avatar_initial.dart';
import '../../../core/widgets/list_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/l10n.dart';
import '../../visits/presentation/visit_providers.dart';

/// Everyone registered on this phone, with a way to register someone new.
class PatientsScreen extends ConsumerWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final patients = ref.watch(patientsProvider).value ?? const <Patient>[];
    return Scaffold(
      appBar: AppHeader(
        title: l.navPatients,
        status: ref.watch(syncStatusProvider),
      ),
      body: Padding(
        padding: const EdgeInsets.all(Tokens.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryButton(
              label: l.registerPatient,
              onPressed: () => context.push('/patients/new'),
            ),
            const SizedBox(height: Tokens.s16),
            Expanded(
              child: patients.isEmpty
                  ? Center(
                      child: Text(
                        l.noPatientsYet,
                        style: Tokens.caption,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: patients.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Tokens.s8),
                      itemBuilder: (_, i) => ListCard(
                        title: patients[i].fullName,
                        leading: AvatarInitial(name: patients[i].fullName),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
