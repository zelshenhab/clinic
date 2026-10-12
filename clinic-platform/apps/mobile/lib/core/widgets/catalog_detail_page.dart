import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../catalog/scoped_resource_cubit.dart';
import '../catalog/catalog_list_cubit.dart';
import '../localization/app_localizations.dart';
import '../localization/failure_message.dart';
import 'app_components.dart';
import 'app_skeleton.dart';

class CatalogDetailPage<T, C extends ScopedResourceCubit<T>>
    extends StatefulWidget {
  const CatalogDetailPage({
    super.key,
    required this.clinicId,
    required this.title,
    required this.load,
    required this.content,
  });
  final String clinicId, title;
  final Future<void> Function(C cubit, String locale) load;
  final Widget Function(T data) content;
  @override
  State<CatalogDetailPage<T, C>> createState() =>
      _CatalogDetailPageState<T, C>();
}

class _CatalogDetailPageState<T, C extends ScopedResourceCubit<T>>
    extends State<CatalogDetailPage<T, C>> {
  String? locale;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = Localizations.localeOf(context).languageCode;
    if (locale != current) {
      locale = current;
      widget.load(context.read<C>(), current);
    }
  }

  @override
  void didUpdateWidget(covariant CatalogDetailPage<T, C> old) {
    super.didUpdateWidget(old);
    if (old.clinicId != widget.clinicId) {
      widget.load(context.read<C>(), locale ?? 'ru');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AppScaffold(
      title: widget.title,
      child: BlocBuilder<C, ResourceState<T>>(
        builder: (context, state) => RefreshIndicator(
          onRefresh: () => widget.load(context.read<C>(), locale ?? 'ru'),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              if (state.clinicId != widget.clinicId ||
                  state.status == CatalogStatus.initial ||
                  state.status == CatalogStatus.loading)
                const AppSkeleton()
              else if (state.status == CatalogStatus.error)
                AppErrorView(
                  message: failureMessage(t, state.failure),
                  retry: () => widget.load(context.read<C>(), locale ?? 'ru'),
                )
              else if (state.data != null)
                widget.content(state.data as T),
            ],
          ),
        ),
      ),
    );
  }
}
