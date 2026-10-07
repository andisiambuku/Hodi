import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/avatar_initial.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/sync_badge.dart';
import '../../../l10n/l10n.dart';
import 'visit_providers.dart';
import 'visits_screen.dart' show badgeFor;

/// A visit and its vitals. Vitals entry is a stub form; it exists so the
/// clinical-data conflict flows have something real to act on.
class VisitDetailScreen extends ConsumerWidget {
  const VisitDetailScreen({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final visit = ref.watch(visitProvider(visitId)).value;
    final vitals = ref.watch(vitalsForVisitProvider(visitId)).value;

    return Scaffold(
      appBar: AppHeader(
        title: l.visitTitle,
        status: ref.watch(syncStatusProvider),
        onBack: () => context.pop(),
      ),
      body: visit == null
          ? Padding(
              padding: const EdgeInsets.all(Tokens.pagePadding),
              child: Text(l.visitGone, style: Tokens.caption),
            )
          : ListView(
              padding: const EdgeInsets.all(Tokens.pagePadding),
              children: [
                Row(
                  children: [
                    AvatarInitial(name: visit.patientName, size: 56),
                    const SizedBox(width: Tokens.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(visit.patientName, style: Tokens.heading),
                          Text(
                            '${localizedVisitType(l, visit.visitType)} · ${DateFormat.Hm(locale).format(visit.scheduledAt)}',
                            style: Tokens.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Tokens.s8),
                SyncBadge(kind: badgeFor(visit.syncState)),
                const SizedBox(height: Tokens.s24),
                Text(l.vitalsTitle, style: Tokens.heading),
                const SizedBox(height: Tokens.s12),
                _VitalsCard(vitals: vitals, syncState: vitals?.syncState),
                const SizedBox(height: Tokens.s16),
                PrimaryButton(
                  label: vitals == null ? l.recordVitals : l.editVitals,
                  onPressed: () => _edit(context, ref, vitals),
                ),
              ],
            ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Vital? current,
  ) async {
    final result = await showModalBottomSheet<_VitalsInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VitalsSheet(current: current),
    );
    if (result == null) return;
    await ref
        .read(vitalsRepositoryProvider)
        .save(
          visitId,
          temperatureC: result.temperatureC,
          systolic: result.systolic,
          diastolic: result.diastolic,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.savedOnPhone)));
    }
  }
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({required this.vitals, required this.syncState});

  final Vital? vitals;
  final Object? syncState;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = vitals;
    String show(Object? x, String unit) => x == null ? '—' : '$x $unit';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Tokens.s16),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        border: Border.all(color: Tokens.divider),
      ),
      child: v == null
          ? Text(l.noVitals, style: Tokens.caption)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.vitalsTemperature(show(v.temperatureC, '°C')),
                  style: Tokens.body,
                ),
                const SizedBox(height: Tokens.s4),
                Text(
                  l.vitalsBloodPressure(
                    '${v.systolic ?? '—'}',
                    '${v.diastolic ?? '—'}',
                  ),
                  style: Tokens.body,
                ),
              ],
            ),
    );
  }
}

class _VitalsInput {
  const _VitalsInput({this.temperatureC, this.systolic, this.diastolic});

  final double? temperatureC;
  final int? systolic;
  final int? diastolic;
}

class _VitalsSheet extends StatefulWidget {
  const _VitalsSheet({this.current});

  final Vital? current;

  @override
  State<_VitalsSheet> createState() => _VitalsSheetState();
}

class _VitalsSheetState extends State<_VitalsSheet> {
  late final _temp = TextEditingController(
    text: widget.current?.temperatureC?.toString() ?? '',
  );
  late final _sys = TextEditingController(
    text: widget.current?.systolic?.toString() ?? '',
  );
  late final _dia = TextEditingController(
    text: widget.current?.diastolic?.toString() ?? '',
  );

  @override
  void dispose() {
    _temp.dispose();
    _sys.dispose();
    _dia.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Tokens.pagePadding,
        Tokens.s24,
        Tokens.pagePadding,
        MediaQuery.viewInsetsOf(context).bottom + Tokens.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _temp,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.l10n.inputTemperature,
            ),
          ),
          const SizedBox(height: Tokens.s12),
          TextField(
            controller: _sys,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.l10n.inputSystolic),
          ),
          const SizedBox(height: Tokens.s12),
          TextField(
            controller: _dia,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.l10n.inputDiastolic),
          ),
          const SizedBox(height: Tokens.s24),
          PrimaryButton(
            label: context.l10n.saveVitals,
            onPressed: () => Navigator.pop(
              context,
              _VitalsInput(
                temperatureC: double.tryParse(_temp.text),
                systolic: int.tryParse(_sys.text),
                diastolic: int.tryParse(_dia.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
