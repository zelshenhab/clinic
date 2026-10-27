import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/failure_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_components.dart';
import '../../domain/entities/family_member.dart';
import '../../domain/repositories/family_repository.dart';

String relationshipLabel(AppLocalizations t, FamilyRelationship value) =>
    switch (value) {
      FamilyRelationship.child => t.relationChild,
      FamilyRelationship.spouse => t.relationSpouse,
      FamilyRelationship.parent => t.relationParent,
      FamilyRelationship.sibling => t.relationSibling,
      FamilyRelationship.other => t.relationOther,
    };

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key, required this.family});
  final FamilyRepository family;
  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  List<FamilyMember> members = const [];
  FailureKind? failure;
  bool loading = true;
  RequestCancellation token = RequestCancellation();
  int request = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    token.cancel();
    token = RequestCancellation();
    final current = ++request;
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final data = await widget.family.list(token);
      if (mounted && current == request) setState(() => members = data);
    } on AppException catch (e) {
      if (mounted && current == request && e.kind != FailureKind.cancelled) {
        setState(() => failure = e.kind);
      }
    } finally {
      if (mounted && current == request) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    token.cancel();
    super.dispose();
  }

  Future<void> edit([FamilyMember? member]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FamilyMemberForm(family: widget.family, member: member),
    );
    if (saved == true && mounted) await load();
  }

  Future<void> remove(FamilyMember member) async {
    final t = AppLocalizations.of(context)!;
    if (!await confirmationDialog(
      context,
      title: t.removeFamilyMemberTitle,
      body: t.removeFamilyMemberBody,
      confirm: t.removeFamilyMember,
    )) {
      return;
    }
    try {
      await widget.family.remove(member.id);
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failureMessage(t, e.kind))));
      }
    }
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode;
    return AppScaffold(
      title: t.familyMembers,
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(t.familyMembersHelp),
            const SizedBox(height: 16),
            if (loading) const LinearProgressIndicator(),
            if (failure != null)
              AppErrorView(message: failureMessage(t, failure), retry: load),
            if (!loading && failure == null && members.isEmpty)
              AppEmptyState(
                title: t.noFamilyMembers,
                icon: Icons.family_restroom_outlined,
              ),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.lightBlue,
                      child: Icon(Icons.person_outline, color: AppColors.blue),
                    ),
                    title: Text(m.fullName),
                    subtitle: Text(
                      [
                        relationshipLabel(t, m.relationship),
                        if (m.dateOfBirth != null)
                          DateFormat('d MMMM y', locale).format(m.dateOfBirth!),
                      ].join(' · '),
                    ),
                    onTap: () => edit(m),
                    trailing: IconButton(
                      tooltip: t.removeFamilyMember,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => remove(m),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (!loading && failure == null)
              AppButton(
                label: t.addFamilyMember,
                icon: Icons.person_add_alt_outlined,
                onPressed: () => edit(),
              ),
          ],
        ),
      ),
    );
  }
}

class FamilyMemberForm extends StatefulWidget {
  const FamilyMemberForm({super.key, required this.family, this.member});
  final FamilyRepository family;
  final FamilyMember? member;
  @override
  State<FamilyMemberForm> createState() => _FamilyMemberFormState();
}

class _FamilyMemberFormState extends State<FamilyMemberForm> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.member?.fullName);
  late FamilyRelationship relationship =
      widget.member?.relationship ?? FamilyRelationship.child;
  late DateTime? birth = widget.member?.dateOfBirth;
  bool busy = false;
  FailureKind? failure;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final member = widget.member;
      if (member == null) {
        await widget.family.add(name.text, relationship, birth);
      } else {
        await widget.family.update(member.id, name.text, relationship, birth);
      }
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) setState(() => failure = e.kind);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.member == null ? t.addFamilyMember : t.editFamilyMember,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: name,
              label: t.fullName,
              maxLength: 120,
              autofillHints: const [AutofillHints.name],
              validator: (value) =>
                  (value ?? '').trim().length < 2 ? t.nameInvalid : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FamilyRelationship>(
              isExpanded: true,
              initialValue: relationship,
              decoration: InputDecoration(labelText: t.relationship),
              items: [
                for (final r in FamilyRelationship.values)
                  DropdownMenuItem(
                    value: r,
                    child: Text(relationshipLabel(t, r)),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (v) => setState(() => relationship = v ?? relationship),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.cake_outlined),
              label: Text(
                birth == null
                    ? t.dateOfBirthOptional
                    : DateFormat('d MMMM y', locale).format(birth!),
              ),
              onPressed: busy
                  ? null
                  : () async {
                      final now = DateTime.now(),
                          today = DateTime(now.year, now.month, now.day);
                      final chosen = await showDatePicker(
                        context: context,
                        initialDate: birth ?? today,
                        firstDate: DateTime(1900),
                        lastDate: today,
                      );
                      if (chosen != null && mounted) {
                        setState(() => birth = chosen);
                      }
                    },
            ),
            if (birth != null)
              TextButton(
                onPressed: busy ? null : () => setState(() => birth = null),
                child: Text(t.clearDate),
              ),
            if (failure != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  failureMessage(t, failure),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            AppButton(label: t.save, busy: busy, onPressed: save),
          ],
        ),
      ),
    );
  }
}
