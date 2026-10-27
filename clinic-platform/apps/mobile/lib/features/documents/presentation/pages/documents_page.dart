import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../../../core/localization/failure_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/document_opener.dart';
import '../../../../core/widgets/app_components.dart';
import '../../domain/entities/medical_document.dart';
import '../../domain/repositories/documents_repository.dart';

String documentKindLabel(AppLocalizations t, DocumentKind kind) =>
    switch (kind) {
      DocumentKind.report => t.docReport,
      DocumentKind.labResult => t.docLabResult,
      DocumentKind.imaging => t.docImaging,
      DocumentKind.prescription => t.docPrescription,
      DocumentKind.other => t.docOther,
    };

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({
    super.key,
    required this.clinicId,
    required this.timezone,
    required this.documents,
    this.opener = const DocumentOpener(),
  });
  final String clinicId, timezone;
  final DocumentsRepository documents;
  final DocumentOpener opener;
  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

// Person filter: null shows everyone, '' the account holder, otherwise a family member id.
class _DocumentsPageState extends State<DocumentsPage> {
  List<MedicalDocument> items = const [];
  FailureKind? failure;
  bool loading = true;
  String? person;
  String? opening;
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
      final data = await widget.documents.list(widget.clinicId, token);
      if (mounted && current == request) setState(() => items = data);
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

  Future<void> open(MedicalDocument document) async {
    final t = AppLocalizations.of(context)!;
    setState(() => opening = document.id);
    try {
      await widget.opener.open(
        await widget.documents.link(widget.clinicId, document.id),
      );
    } on AppException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.documentUnavailable)));
      }
    } finally {
      if (mounted) setState(() => opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode,
        zone = tz.getLocation(widget.timezone);
    final people = <String, String>{
      for (final d in items)
        if (d.familyMemberId != null)
          d.familyMemberId!: d.familyMemberName ?? '',
    };
    final visible = items
        .where((d) => person == null || (d.familyMemberId ?? '') == person)
        .toList();
    return AppScaffold(
      title: t.medicalDocuments,
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (people.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(t.allDocuments),
                    selected: person == null,
                    onSelected: (_) => setState(() => person = null),
                  ),
                  ChoiceChip(
                    label: Text(t.myself),
                    selected: person == '',
                    onSelected: (_) => setState(() => person = ''),
                  ),
                  for (final p in people.entries)
                    ChoiceChip(
                      label: Text(p.value),
                      selected: person == p.key,
                      onSelected: (_) => setState(() => person = p.key),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            if (loading) const LinearProgressIndicator(),
            if (failure != null)
              AppErrorView(message: failureMessage(t, failure), retry: load),
            if (!loading && failure == null && visible.isEmpty)
              AppEmptyState(
                title: t.noDocuments,
                icon: Icons.description_outlined,
              ),
            for (final d in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.lightBlue,
                      child: Icon(
                        d.mimeType == 'application/pdf'
                            ? Icons.picture_as_pdf_outlined
                            : Icons.image_outlined,
                        color: AppColors.blue,
                      ),
                    ),
                    title: Text(d.title),
                    subtitle: Text(
                      [
                        documentKindLabel(t, d.kind),
                        DateFormat(
                          'd MMMM y',
                          locale,
                        ).format(tz.TZDateTime.from(d.createdAt, zone)),
                        if (d.doctorName.isNotEmpty)
                          localized(d.doctorName, locale),
                        if (d.familyMemberName != null)
                          t.appointmentFor(d.familyMemberName!),
                      ].join('\n'),
                    ),
                    isThreeLine: true,
                    trailing: opening == d.id
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            tooltip: t.openDocument,
                            icon: const Icon(Icons.download_outlined),
                            onPressed: opening == null ? () => open(d) : null,
                          ),
                    onTap: opening == null ? () => open(d) : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
