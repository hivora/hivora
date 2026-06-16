import 'package:flutter/foundation.dart';

import '../../core/models/work_models.dart';

/// Multi-criteria board filter. Empty sets mean "no restriction" for that
/// facet. State / type / priority are stored as UPPER-CASE backend codes;
/// [assignees] holds user ids. The same instance backs both the people strip
/// (which toggles [assignees]) and the glass filter popup, so selection stays
/// in lockstep across the board.
@immutable
class BoardFilter {
  const BoardFilter({
    this.states = const {},
    this.types = const {},
    this.priorities = const {},
    this.assignees = const {},
  });

  final Set<String> states;
  final Set<String> types;
  final Set<String> priorities;
  final Set<String> assignees;

  bool get isEmpty =>
      states.isEmpty &&
      types.isEmpty &&
      priorities.isEmpty &&
      assignees.isEmpty;

  int get activeCount =>
      states.length + types.length + priorities.length + assignees.length;

  /// Whether [issue] passes every active facet (AND across facets, OR within).
  bool matches(Issue issue) {
    if (states.isNotEmpty && !states.contains(issue.state.toUpperCase())) {
      return false;
    }
    if (types.isNotEmpty && !types.contains(issue.type.toUpperCase())) {
      return false;
    }
    if (priorities.isNotEmpty &&
        !priorities.contains(issue.priority.toUpperCase())) {
      return false;
    }
    if (assignees.isNotEmpty &&
        (issue.assigneeId == null || !assignees.contains(issue.assigneeId))) {
      return false;
    }
    return true;
  }

  BoardFilter copyWith({
    Set<String>? states,
    Set<String>? types,
    Set<String>? priorities,
    Set<String>? assignees,
  }) => BoardFilter(
    states: states ?? this.states,
    types: types ?? this.types,
    priorities: priorities ?? this.priorities,
    assignees: assignees ?? this.assignees,
  );

  /// Returns a copy with [value] toggled in the facet named [facet].
  BoardFilter toggle(BoardFilterFacet facet, String value) {
    Set<String> next(Set<String> current) {
      final updated = {...current};
      if (!updated.remove(value)) updated.add(value);
      return updated;
    }

    return switch (facet) {
      BoardFilterFacet.state => copyWith(states: next(states)),
      BoardFilterFacet.type => copyWith(types: next(types)),
      BoardFilterFacet.priority => copyWith(priorities: next(priorities)),
      BoardFilterFacet.assignee => copyWith(assignees: next(assignees)),
    };
  }

  static const empty = BoardFilter();
}

enum BoardFilterFacet { state, type, priority, assignee }

/// The distinct facet values available to filter on, derived from the issues
/// currently loaded for a board so custom workflow states resolve without
/// hardcoding. Preserves first-seen order.
class BoardFilterOptions {
  BoardFilterOptions({
    required this.states,
    required this.types,
    required this.priorities,
    required this.assignees,
  });

  /// UPPER-CASE workflow-state codes.
  final List<String> states;

  /// UPPER-CASE issue-type codes.
  final List<String> types;

  /// UPPER-CASE priority codes.
  final List<String> priorities;

  /// Assignee user ids.
  final List<String> assignees;

  bool get isEmpty =>
      states.isEmpty &&
      types.isEmpty &&
      priorities.isEmpty &&
      assignees.isEmpty;

  factory BoardFilterOptions.fromIssues(Iterable<Issue> issues) {
    final states = <String>{};
    final types = <String>{};
    final priorities = <String>{};
    final assignees = <String>{};
    for (final issue in issues) {
      if (issue.state.isNotEmpty) states.add(issue.state.toUpperCase());
      if (issue.type.isNotEmpty) types.add(issue.type.toUpperCase());
      if (issue.priority.isNotEmpty) {
        priorities.add(issue.priority.toUpperCase());
      }
      final a = issue.assigneeId;
      if (a != null && a.isNotEmpty) assignees.add(a);
    }
    return BoardFilterOptions(
      states: states.toList(),
      types: types.toList(),
      priorities: priorities.toList(),
      assignees: assignees.toList(),
    );
  }
}
