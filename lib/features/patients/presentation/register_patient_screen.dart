import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/db/enums.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/l10n.dart';
import '../../visits/presentation/visit_providers.dart';
import '../domain/new_patient.dart';

/// Name, household head, location, phone and account status. Saves to the phone and returns.
class RegisterPatientScreen extends ConsumerStatefulWidget {
  const RegisterPatientScreen({super.key});

  @override
  ConsumerState<RegisterPatientScreen> createState() =>
      _RegisterPatientScreenState();
}

class _RegisterPatientScreenState extends ConsumerState<RegisterPatientScreen> {
  final _name = TextEditingController();
  final _head = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();
  AccountStatus _status = AccountStatus.active;
  bool _saving = false;

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _location.text.trim().isNotEmpty &&
      NewPatient.isValidPhone(_phone.text);

  @override
  void dispose() {
    _name.dispose();
    _head.dispose();
    _location.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    final saved = context.l10n.savedOnPhone;
    setState(() => _saving = true);
    try {
      await ref
          .read(patientRepositoryProvider)
          .register(
            NewPatient(
              fullName: _name.text,
              headName: _head.text,
              location: _location.text,
              phoneNumber: _phone.text,
              accountStatus: _status,
            ),
          );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      rethrow;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved)));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppHeader(
        title: l.registerNewPatient,
        status: ref.watch(syncStatusProvider),
        onBack: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.pagePadding),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l.fieldFullName),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Tokens.s16),
          TextField(
            controller: _head,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l.fieldHouseholdHead,
              helperText: l.fieldHouseholdHeadHint,
            ),
          ),
          const SizedBox(height: Tokens.s16),
          TextField(
            controller: _location,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l.fieldLocation),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Tokens.s16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l.fieldPhoneNumber,
              helperText: l.fieldPhoneNumberHint,
              errorText: NewPatient.isValidPhone(_phone.text)
                  ? null
                  : l.phoneNumberInvalid,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Tokens.s16),
          Text(l.fieldAccountStatus, style: Tokens.caption),
          const SizedBox(height: Tokens.s8),
          SegmentedButton<AccountStatus>(
            segments: [
              ButtonSegment(
                value: AccountStatus.active,
                label: Text(l.statusActive),
              ),
              ButtonSegment(
                value: AccountStatus.inactive,
                label: Text(l.statusInactive),
              ),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
          const SizedBox(height: Tokens.s24),
          PrimaryButton(
            label: l.savePatient,
            loading: _saving,
            onPressed: _valid ? _save : null,
          ),
        ],
      ),
    );
  }
}
