import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/enums.dart';
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
                        subtitle: patients[i].phoneNumber ?? l.noPhoneNumber,
                        leading: AvatarInitial(name: patients[i].fullName),
                        trailing: _StatusChip(
                          status: patients[i].accountStatus,
                        ),
                        onTap: () => _confirmToggle(context, ref, patients[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmToggle(
  BuildContext context,
  WidgetRef ref,
  Patient patient,
) async {
  final l = context.l10n;
  final next = patient.accountStatus == AccountStatus.active
      ? AccountStatus.inactive
      : AccountStatus.active;
  final toInactive = next == AccountStatus.inactive;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        toInactive
            ? l.markInactiveTitle(patient.fullName)
            : l.markActiveTitle(patient.fullName),
      ),
      content: Text(l.markStatusBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(toInactive ? l.markInactiveAction : l.markActiveAction),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await ref.read(patientRepositoryProvider).setAccountStatus(patient.id, next);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        l.patientStatusChanged(
          patient.fullName,
          toInactive ? l.statusInactive : l.statusActive,
        ),
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AccountStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final active = status == AccountStatus.active;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.s12,
        vertical: Tokens.s4,
      ),
      decoration: BoxDecoration(
        color: active ? Tokens.primarySoft : Tokens.warningSoft,
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
      ),
      child: Text(
        active ? l.statusActive : l.statusInactive,
        style: Tokens.caption.copyWith(
          color: active ? Tokens.primary : Tokens.warningText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
