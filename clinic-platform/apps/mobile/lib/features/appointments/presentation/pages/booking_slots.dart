import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/failure_message.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../authentication/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/booking_context.dart';
import '../bloc/booking_flow_cubit.dart';

class BookingSlots extends StatefulWidget {
  const BookingSlots({super.key, required this.data, required this.query});
  final BookingContext data;
  final CatalogQuery query;
  @override
  State<BookingSlots> createState() => _BookingSlotsState();
}

class _BookingSlotsState extends State<BookingSlots>
    with WidgetsBindingObserver {
  late DateTime day;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = tz.TZDateTime.now(tz.getLocation(widget.data.clinic.timezone));
    day = DateTime(now.year, now.month, now.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configure();
  }

  @override
  void didUpdateWidget(covariant BookingSlots old) {
    super.didUpdateWidget(old);
    if (old.data.doctor?.id != widget.data.doctor?.id ||
        old.data.service?.id != widget.data.service?.id ||
        old.data.clinic.id != widget.data.clinic.id) {
      _configure();
    }
  }

  void _configure() {
    final d = widget.data;
    if (d.doctor != null && d.service != null) {
      context.read<BookingFlowCubit>().configure(
        d.clinic.id,
        d.doctor!.id,
        d.service!.id,
        DateFormat('yyyy-MM-dd').format(day),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<BookingFlowCubit>().refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode,
        zone = tz.getLocation(widget.data.clinic.timezone);
    return BlocBuilder<BookingFlowCubit, BookingFlowState>(
      builder: (context, state) {
        final flow = context.read<BookingFlowCubit>(),
            signedIn =
                context.watch<AuthCubit>().state.status ==
                AuthStatus.authenticated;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.availableTimes,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('${t.clinicTimezone}: ${widget.data.clinic.timezone}'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(DateFormat('d MMMM y', locale).format(day)),
              onPressed: state.busy
                  ? null
                  : () async {
                      final now = tz.TZDateTime.now(zone),
                          today = DateTime(now.year, now.month, now.day);
                      final chosen = await showDatePicker(
                        context: context,
                        initialDate: day.isBefore(today) ? today : day,
                        firstDate: today,
                        lastDate: today.add(const Duration(days: 180)),
                      );
                      if (chosen != null && mounted) {
                        setState(() => day = chosen);
                        _configure();
                      }
                    },
            ),
            if (state.loading) const LinearProgressIndicator(),
            if (state.failure != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  failureMessage(t, state.failure),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (!state.loading && state.slots.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(t.noAvailableTimes),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.slots
                  .map(
                    (slot) => ChoiceChip(
                      label: Text(
                        DateFormat(
                          'HH:mm',
                        ).format(tz.TZDateTime.from(slot.startsAt, zone)),
                      ),
                      selected: slot.startsAt == state.selected,
                      onSelected: state.busy || state.loading
                          ? null
                          : (_) => flow.select(slot.startsAt),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            if (state.receipt != null)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green),
                    Text(t.bookingSuccess),
                    Text('${t.bookingReference}: ${state.receipt!.id}'),
                    Text(
                      DateFormat('d MMMM y · HH:mm', locale).format(
                        tz.TZDateTime.from(state.receipt!.startsAt, zone),
                      ),
                    ),
                    Text(
                      state.receipt!.status == 'pending'
                          ? t.pending
                          : t.confirmed,
                    ),
                    Text(
                      NumberFormat.currency(
                        locale: locale,
                        symbol: '₽',
                      ).format(state.receipt!.price),
                    ),
                    TextButton(
                      onPressed: () => context.go('/appointments'),
                      child: Text(t.appointments),
                    ),
                  ],
                ),
              ),
            AppButton(
              label: signedIn ? t.confirmBooking : t.signInToBook,
              busy: state.busy,
              onPressed:
                  state.loading ||
                      state.selected == null ||
                      state.receipt != null
                  ? null
                  : () async {
                      if (!signedIn) {
                        context.go(
                          Uri(
                            path: '/login',
                            queryParameters: {
                              ...widget.query.parameters,
                              'from': 'booking',
                            },
                          ).toString(),
                        );
                        return;
                      }
                      final approved = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(t.confirmBooking),
                          content: Text(
                            DateFormat(
                              'd MMMM y · HH:mm',
                              locale,
                            ).format(tz.TZDateTime.from(state.selected!, zone)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(t.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(t.confirmBooking),
                            ),
                          ],
                        ),
                      );
                      if (approved == true && mounted) await flow.book();
                    },
            ),
            TextButton(
              onPressed: state.busy ? null : () => flow.refresh(),
              child: Text(t.refreshAvailability),
            ),
          ],
        );
      },
    );
  }
}
