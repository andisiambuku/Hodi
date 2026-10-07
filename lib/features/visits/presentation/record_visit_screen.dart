import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/l10n.dart';
import '../domain/new_visit.dart';
import 'visit_providers.dart';

/// Stub form: patient, visit type, time. Saves to the phone and returns.
class RecordVisitScreen extends ConsumerStatefulWidget {
  const RecordVisitScreen({super.key});

  @override
  ConsumerState<RecordVisitScreen> createState() => _RecordVisitScreenState();
}

class _RecordVisitScreenState extends ConsumerState<RecordVisitScreen> {
  Patient? _patient;
  String? _type;
  TimeOfDay _time = TimeOfDay.now();
  bool _saving = false;

  bool get _valid => _patient != null && _type != null;

  Future<void> _save() async {
    if (!_valid || _saving) return;
    final saved = context.l10n.savedOnPhone;
    setState(() => _saving = true);
    final now = DateTime.now();
    await ref
        .read(visitRepositoryProvider)
        .recordVisit(
          NewVisit(
            patientId: _patient!.id,
            patientName: _patient!.fullName,
            visitType: _type!,
            scheduledAt: DateTime(
              now.year,
              now.month,
              now.day,
              _time.hour,
              _time.minute,
            ),
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved)));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final patients = ref.watch(patientsProvider).value ?? const <Patient>[];
    return Scaffold(
      appBar: AppHeader(
        title: l.recordNewVisit,
        status: ref.watch(syncStatusProvider),
        onBack: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.pagePadding),
        children: [
          DropdownButtonFormField<Patient>(
            initialValue: _patient,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.fieldPatient),
            items: [
              for (final p in patients)
                DropdownMenuItem(value: p, child: Text(p.fullName)),
            ],
            onChanged: (p) => setState(() => _patient = p),
          ),
          const SizedBox(height: Tokens.s16),
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.fieldVisitTypeInput),
            // The stored value is the canonical English type; only the label
            // is translated.
            items: [
              for (final t in visitTypes)
                DropdownMenuItem(
                  value: t,
                  child: Text(localizedVisitType(l, t)),
                ),
            ],
            onChanged: (t) => setState(() => _type = t),
          ),
          const SizedBox(height: Tokens.s16),
          ListTile(
            minTileHeight: Tokens.minTouch,
            contentPadding: EdgeInsets.zero,
            title: Text(l.fieldTime, style: Tokens.caption),
            subtitle: Text(_time.format(context), style: Tokens.bodyStrong),
            trailing: const Icon(Icons.schedule),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (picked != null) setState(() => _time = picked);
            },
          ),
          const SizedBox(height: Tokens.s24),
          PrimaryButton(
            label: l.saveVisit,
            loading: _saving,
            onPressed: _valid ? _save : null,
          ),
        ],
      ),
    );
  }
}
