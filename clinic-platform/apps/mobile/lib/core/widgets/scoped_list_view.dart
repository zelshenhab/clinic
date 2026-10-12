import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../network/scoped_list_cubit.dart';
import '../widgets/app_components.dart';
import '../widgets/app_skeleton.dart';
import '../localization/app_localizations.dart';
import '../localization/failure_message.dart';

class ScopedListView<T, C extends ScopedListCubit<T>> extends StatefulWidget {
  const ScopedListView({
    super.key,
    required this.clinicId,
    required this.title,
    required this.empty,
    required this.itemBuilder,
    this.footer,
  });
  final String clinicId, title, empty;
  final Widget Function(T item) itemBuilder;
  final Widget? footer;
  @override
  State<ScopedListView<T, C>> createState() => _ScopedListViewState<T, C>();
}

class _ScopedListViewState<T, C extends ScopedListCubit<T>>
    extends State<ScopedListView<T, C>> {
  @override
  void initState() {
    super.initState();
    context.read<C>().load(widget.clinicId);
  }

  @override
  void didUpdateWidget(covariant ScopedListView<T, C> old) {
    super.didUpdateWidget(old);
    if (old.clinicId != widget.clinicId) {
      context.read<C>().load(widget.clinicId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return BlocBuilder<C, ListState<T>>(
      builder: (context, state) => RefreshIndicator(
        onRefresh: () => context.read<C>().load(widget.clinicId),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 24),
            if (state.clinicId != widget.clinicId ||
                state.status == ListStatus.initial ||
                state.status == ListStatus.loading)
              const AppSkeleton()
            else if (state.status == ListStatus.error)
              AppErrorView(
                message: failureMessage(t, state.failure),
                retry: () => context.read<C>().load(widget.clinicId),
              )
            else if (state.items.isEmpty)
              AppEmptyState(title: widget.empty)
            else
              ...state.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: widget.itemBuilder(item),
                ),
              ),
            if (widget.footer != null) ...[
              const SizedBox(height: 20),
              widget.footer!,
            ],
          ],
        ),
      ),
    );
  }
}
