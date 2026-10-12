import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

class CatalogFilters extends StatelessWidget {
  const CatalogFilters({
    super.key,
    required this.sort,
    required this.onSort,
    this.specialty,
    this.specialties = const {},
    this.onSpecialty,
    this.category,
    this.categories = const {},
    this.onCategory,
    this.doctors = false,
  });
  final String sort;
  final String? specialty, category;
  final Map<String, String> specialties, categories;
  final ValueChanged<String> onSort;
  final ValueChanged<String?>? onSpecialty, onCategory;
  final bool doctors;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final sorts = {
      'featured': t.sortFeatured,
      'name': t.sortName,
      'price_asc': t.sortPriceAsc,
      'price_desc': t.sortPriceDesc,
      if (doctors) 'experience_desc': t.sortExperience,
    };
    return Column(
      children: [
        if (onSpecialty != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              key: ValueKey('specialty:${specialties.keys.join()}:$specialty'),
              initialValue: specialties.containsKey(specialty) ? specialty : '',
              isExpanded: true,
              decoration: InputDecoration(labelText: t.filterSpecialty),
              items: [
                DropdownMenuItem(value: '', child: Text(t.allSpecialties)),
                ...specialties.entries.map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => onSpecialty!(value == '' ? null : value),
            ),
          ),
        if (onCategory != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              key: ValueKey('category:${categories.keys.join()}:$category'),
              initialValue: categories.containsKey(category) ? category : '',
              isExpanded: true,
              decoration: InputDecoration(labelText: t.category),
              items: [
                DropdownMenuItem(value: '', child: Text(t.allCategories)),
                ...categories.entries.map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => onCategory!(value == '' ? null : value),
            ),
          ),
        DropdownButtonFormField<String>(
          key: ValueKey('sort:$sort'),
          initialValue: sort,
          isExpanded: true,
          decoration: InputDecoration(labelText: t.sortLabel),
          items: sorts.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (value) {
            if (value != null) onSort(value);
          },
        ),
      ],
    );
  }
}
