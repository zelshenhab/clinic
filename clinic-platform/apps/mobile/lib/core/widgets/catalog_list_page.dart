import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../catalog/catalog_list_cubit.dart';
import '../catalog/catalog_query.dart';
import '../localization/app_localizations.dart';
import '../localization/failure_message.dart';
import 'app_components.dart';
import 'app_skeleton.dart';

class CatalogListPage<T, C extends CatalogListCubit<T>> extends StatefulWidget {
  const CatalogListPage({
    super.key,
    required this.clinicId,
    required this.title,
    required this.empty,
    required this.itemBuilder,
    this.searchLabel,
    this.initialQuery = const CatalogQuery(),
    this.filters,
    this.scaffold = true,
  });
  final String clinicId, title, empty;
  final String? searchLabel;
  final CatalogQuery initialQuery;
  final Widget Function(T) itemBuilder;
  final Widget Function(CatalogListState<T>)? filters;
  final bool scaffold;
  @override
  State<CatalogListPage<T, C>> createState() => _CatalogListPageState<T, C>();
}

class _CatalogListPageState<T, C extends CatalogListCubit<T>>
    extends State<CatalogListPage<T, C>> {
  final search = TextEditingController();
  String? locale;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = Localizations.localeOf(context).languageCode;
    if (current != locale) {
      locale = current;
      context.read<C>().load(
        widget.clinicId,
        query: widget.initialQuery.copy(locale: current, search: search.text),
        force: true,
      );
    }
  }

  @override
  void didUpdateWidget(covariant CatalogListPage<T, C> old) {
    super.didUpdateWidget(old);
    if (old.clinicId != widget.clinicId ||
        old.initialQuery.parameters.toString() !=
            widget.initialQuery.parameters.toString()) {
      search.clear();
      context.read<C>().load(
        widget.clinicId,
        query: widget.initialQuery.copy(locale: locale ?? 'ru'),
        force: true,
      );
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final content = BlocBuilder<C, CatalogListState<T>>(
      builder: (context, state) => RefreshIndicator(
        onRefresh: context.read<C>().refresh,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          itemCount: state.items.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 20),
                  if (widget.searchLabel != null) ...[
                    TextField(
                      controller: search,
                      maxLength: 100,
                      decoration: InputDecoration(
                        hintText: widget.searchLabel,
                        counterText: '',
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: context.read<C>().search,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (widget.filters != null) ...[
                    widget.filters!(state),
                    const SizedBox(height: 20),
                  ],
                  if (state.clinicId != widget.clinicId ||
                      state.status == CatalogStatus.initial ||
                      state.status == CatalogStatus.loading)
                    const AppSkeleton()
                  else if (state.status == CatalogStatus.error &&
                      state.items.isEmpty)
                    AppErrorView(
                      message: failureMessage(t, state.failure),
                      retry: context.read<C>().refresh,
                    )
                  else if (state.items.isEmpty)
                    AppEmptyState(
                      title: state.query.search.isNotEmpty
                          ? t.noSearchResults
                          : widget.empty,
                      body: state.query.search.isNotEmpty
                          ? t.searchEmptyBody
                          : null,
                    ),
                ],
              );
            }
            if (index <= state.items.length) {
              if (state.clinicId != widget.clinicId) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: widget.itemBuilder(state.items[index - 1]),
              );
            }
            return Column(
              children: [
                if (state.failure != null && state.items.isNotEmpty)
                  AppErrorView(
                    message: failureMessage(t, state.failure),
                    retry: context.read<C>().next,
                  ),
                if (state.hasMore) ...[
                  const SizedBox(height: 8),
                  AppButton(
                    label: t.loadMore,
                    busy: state.loadingMore,
                    onPressed: context.read<C>().next,
                  ),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
    return widget.scaffold
        ? AppScaffold(title: widget.title, child: content)
        : content;
  }
}
