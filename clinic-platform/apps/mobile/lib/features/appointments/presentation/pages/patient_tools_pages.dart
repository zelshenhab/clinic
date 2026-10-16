import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../../../core/localization/failure_message.dart';
import '../../../../core/widgets/app_components.dart';
import '../../domain/repositories/patient_tools_repository.dart';

class NearestPage extends StatefulWidget {
  const NearestPage({
    super.key,
    required this.clinicId,
    required this.timezone,
    required this.tools,
  });
  final String clinicId, timezone;
  final PatientToolsRepository tools;
  @override
  State<NearestPage> createState() => _NearestPageState();
}

class _NearestPageState extends State<NearestPage> {
  String? specialty;
  NearestResults? result;
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
      final data = await widget.tools.nearest(
        widget.clinicId,
        specialty,
        token,
      );
      if (mounted && current == request) setState(() => result = data);
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode,
        zone = tz.getLocation(widget.timezone);
    return AppScaffold(
      title: t.nearestAvailable,
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(t.nearestHelp),
            Text('${t.clinicTimezone}: ${widget.timezone}'),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: specialty,
              decoration: InputDecoration(labelText: t.specialties),
              items: [
                DropdownMenuItem(value: null, child: Text(t.allSpecialties)),
                ...?(result?.specialties.entries.map(
                  (s) => DropdownMenuItem(
                    value: s.key,
                    child: Text(localized(s.value, locale)),
                  ),
                )),
              ],
              onChanged: loading
                  ? null
                  : (v) {
                      setState(() => specialty = v);
                      load();
                    },
            ),
            if (loading) const LinearProgressIndicator(),
            if (failure != null)
              AppErrorView(message: failureMessage(t, failure), retry: load),
            if (!loading && failure == null && result?.items.isEmpty == true)
              Text(t.noAvailableTimes),
            if (!loading && failure == null)
              ...?result?.items.map(
                (a) => AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localized(a.doctorName, locale),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(localized(a.serviceName, locale)),
                      Text(
                        DateFormat(
                          'd MMMM y · HH:mm',
                          locale,
                        ).format(tz.TZDateTime.from(a.startsAt, zone)),
                      ),
                      Text(rub(a.price, locale)),
                      TextButton(
                        onPressed: () => context.push(
                          Uri(
                            path: '/booking',
                            queryParameters: {
                              'doctorId': a.doctorId,
                              'serviceId': a.serviceId,
                              'date': DateFormat(
                                'yyyy-MM-dd',
                              ).format(tz.TZDateTime.from(a.startsAt, zone)),
                            },
                          ).toString(),
                        ),
                        child: Text(t.confirmBooking),
                      ),
                    ],
                  ),
                ),
              ),
            if (result != null)
              Text('${t.searchedUntil}: ${result!.searchedUntil}'),
            if (result?.limited == true) Text(t.searchLimited),
          ],
        ),
      ),
    );
  }
}

class WaitlistPage extends StatefulWidget {
  const WaitlistPage({super.key, required this.clinicId, required this.tools});
  final String clinicId;
  final PatientToolsRepository tools;
  @override
  State<WaitlistPage> createState() => _WaitlistPageState();
}

class _WaitlistPageState extends State<WaitlistPage> {
  final token = RequestCancellation();
  List<WaitlistEntry> entries = [];
  bool loading = true;
  String? busy;
  FailureKind? failure;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final rows = await widget.tools.waitlist(widget.clinicId, token);
      if (mounted) setState(() => entries = rows);
    } on AppException catch (e) {
      if (mounted && e.kind != FailureKind.cancelled) {
        setState(() => failure = e.kind);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    token.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AppScaffold(
      title: t.waitlist,
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(t.waitlistHelp),
            if (loading) const LinearProgressIndicator(),
            if (failure != null)
              AppErrorView(message: failureMessage(t, failure), retry: load),
            if (!loading && entries.isEmpty) Text(t.waitlistEmpty),
            ...entries.map(
              (w) => AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.day),
                    Text(
                      localized(
                        w.doctorName,
                        Localizations.localeOf(context).languageCode,
                      ),
                    ),
                    Text(
                      localized(
                        w.serviceName,
                        Localizations.localeOf(context).languageCode,
                      ),
                    ),
                    Text(switch (w.state) {
                      'waiting' => t.waitlistWaiting,
                      'notified' => t.waitlistNotified,
                      _ => t.cancelled,
                    }),
                    TextButton(
                      onPressed: () => context.push(
                        Uri(
                          path: '/booking',
                          queryParameters: {
                            'doctorId': w.doctorId,
                            'serviceId': w.serviceId,
                            'date': w.day,
                          },
                        ).toString(),
                      ),
                      child: Text(t.availableTimes),
                    ),
                    if (w.state == 'waiting')
                      TextButton(
                        onPressed: busy != null
                            ? null
                            : () async {
                                setState(() => busy = w.id);
                                try {
                                  await widget.tools.leaveWaitlist(
                                    widget.clinicId,
                                    w.id,
                                  );
                                  if (mounted) await load();
                                } on AppException catch (e) {
                                  if (mounted) setState(() => failure = e.kind);
                                } finally {
                                  if (mounted) setState(() => busy = null);
                                }
                              },
                        child: Text(t.leaveWaitlist),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
