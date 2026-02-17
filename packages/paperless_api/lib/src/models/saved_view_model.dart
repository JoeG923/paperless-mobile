import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:paperless_api/src/models/document_filter.dart';
import 'package:paperless_api/src/models/filter_rule_model.dart';
import 'package:paperless_api/src/models/query_parameters/sort_field.dart';
import 'package:paperless_api/src/models/query_parameters/sort_order.dart';

part 'saved_view_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class SavedView with EquatableMixin {
  final int? id;
  final String name;

  final bool showOnDashboard;
  final bool showInSidebar;

  final SortField? sortField;
  final bool sortReverse;
  final List<FilterRule> filterRules;

  SavedView({
    this.id,
    required this.name,
    required this.showOnDashboard,
    required this.showInSidebar,
    this.sortField,
    required this.sortReverse,
    required this.filterRules,
  }) {
    filterRules.sort(
      (a, b) => (a.ruleType.compareTo(b.ruleType) != 0
          ? a.ruleType.compareTo(b.ruleType)
          : a.value?.compareTo(b.value ?? "") ?? -1),
    );
  }

  @override
  List<Object?> get props => [
    name,
    showOnDashboard,
    showInSidebar,
    sortField,
    sortReverse,
    filterRules,
  ];

  factory SavedView.fromJson(Map<String, dynamic> json) =>
      _$SavedViewFromJson(json);

  Map<String, dynamic> toJson() => _$SavedViewToJson(this);

  SavedView copyWith({
    int? id,
    String? name,
    bool? showOnDashboard,
    bool? showInSidebar,
    SortField? sortField,
    bool? sortReverse,
    List<FilterRule>? filterRules,
  }) {
    return SavedView(
      id: id ?? this.id,
      name: name ?? this.name,
      showOnDashboard: showOnDashboard ?? this.showOnDashboard,
      showInSidebar: showInSidebar ?? this.showInSidebar,
      sortField: sortField ?? this.sortField,
      sortReverse: sortReverse ?? this.sortReverse,
      filterRules: filterRules ?? this.filterRules,
    );
  }

  DocumentFilter toDocumentFilter() {
    return filterRules.fold(
      DocumentFilter(
        sortOrder: sortReverse ? SortOrder.descending : SortOrder.ascending,
        sortField: sortField,
        selectedView: id,
      ),
      (filter, filterRule) => filterRule.applyToFilter(filter),
    );
  }

  SavedView.fromDocumentFilter(
    DocumentFilter filter, {
    required String name,
    required bool showInSidebar,
    required bool showOnDashboard,
  }) : this(
         id: null,
         name: name,
         filterRules: FilterRule.fromFilter(filter),
         sortField: filter.sortField,
         showInSidebar: showInSidebar,
         showOnDashboard: showOnDashboard,
         sortReverse: filter.sortOrder == SortOrder.descending,
       );
}
