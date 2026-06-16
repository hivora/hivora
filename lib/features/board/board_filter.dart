import 'package:flutter/foundation.dart';

import '../../core/models/work_models.dart';

/// Multi-criteria board filter. Empty sets mean "no restriction" for that
/// facet. State / type / priority are stored as UPPER-CASE backend codes;
/// [assignees]/[authors] hold user ids, [sprints] hold sprint ids (or
/// [noSprint] for "Kein Sprint"), [labels] hold tag names. The same instance
/// backs both the people strip (which toggles [assignees]) and the glass filter
/// popup, so selection stays in lockstep across the board.
@immutable
class BoardFilter {
  const BoardFilter({
    this.states = const {},
    this.types = const {},
    this.priorities = const {},
    this.assignees = const {},
    this.sprints = const {},
    this.authors = const {},
    this.labels = const {},
  });

  final Set<String> states;
  final Set<String> types;
  final Set<String> priorities;
  final Set<String> assignees;
  final Set<String> sprints;
  final Set<String> authors;
  final Set<String> labels;

  /// Sentinel value used in [sprints] to match issues with no sprint.
  static const noSprint = '__none__';

  bool get isEmpty =>
      states.isEmpty &&
      types.isEmpty &&
      priorities.isEmpty &&
      assignees.isEmpty &&
      sprints.isEmpty &&
      authors.isEmpty &&
      labels.isEmpty;

  int get activeCount =>
      states.length +
      types.length +
      priorities.length +
      assignees.length +
      sprints.length +
      authors.length +
      labels.length;

  Set<String> facet(BoardFilterFacet f) => switch (f) {
    BoardFilterFacet.state => states,
    BoardFilterFacet.type => types,
    BoardFilterFacet.priority => priorities,
    BoardFilterFacet.assignee => assignees,
    BoardFilterFacet.sprint => sprints,
    BoardFilterFacet.author => authors,
    BoardFilterFacet.label => labels,
  };

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
    if (sprints.isNotEmpty) {
      final inSprint =
          issue.sprintId != null && sprints.contains(issue.sprintId);
      final inNone = issue.sprintId == null && sprints.contains(noSprint);
      if (!inSprint && !inNone) return false;
    }
    if (authors.isNotEmpty &&
        (issue.reporterId == null || !authors.contains(issue.reporterId))) {
      return false;
    }
    if (labels.isNotEmpty && !issue.tags.any(labels.contains)) {
      return false;
    }
    return true;
  }

  BoardFilter copyWith({
    Set<String>? states,
    Set<String>? types,
    Set<String>? priorities,
    Set<String>? assignees,
    Set<String>? sprints,
    Set<String>? authors,
    Set<String>? labels,
  }) => BoardFilter(
    states: states ?? this.states,
    types: types ?? this.types,
    priorities: priorities ?? this.priorities,
    assignees: assignees ?? this.assignees,
    sprints: sprints ?? this.sprints,
    authors: authors ?? this.authors,
    labels: labels ?? this.labels,
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
      BoardFilterFacet.sprint => copyWith(sprints: next(sprints)),
      BoardFilterFacet.author => copyWith(authors: next(authors)),
      BoardFilterFacet.label => copyWith(labels: next(labels)),
    };
  }

  static const empty = BoardFilter();
}

enum BoardFilterFacet { state, type, priority, assignee, sprint, author, label }

/// The distinct facet values available to filter on, derived from the issues
/// currently loaded for a board (plus the board's sprints and project labels)
/// so custom workflow states / labels resolve without hardcoding. Preserves
/// first-seen order.
class BoardFilterOptions {
  BoardFilterOptions({
    required this.states,
    required this.types,
    required this.priorities,
    required this.assignees,
    required this.authors,
    required this.sprints,
    required this.labels,
  });

  /// UPPER-CASE workflow-state codes.
  final List<String> states;

  /// UPPER-CASE issue-type codes.
  final List<String> types;

  /// UPPER-CASE priority codes.
  final List<String> priorities;

  /// Assignee user ids.
  final List<String> assignees;

  /// Reporter (author) user ids.
  final List<String> authors;

  /// Sprint ids in board order (the "Kein Sprint" sentinel is added by the UI).
  final List<String> sprints;

  /// Label / tag names.
  final List<String> labels;

  bool get isEmpty =>
      states.isEmpty &&
      types.isEmpty &&
      priorities.isEmpty &&
      assignees.isEmpty &&
      authors.isEmpty &&
      sprints.isEmpty &&
      labels.isEmpty;

  factory BoardFilterOptions.from({
    required Iterable<Issue> issues,
    required List<Sprint> boardSprints,
    required Iterable<String> projectLabels,
  }) {
    final states = <String>{};
    final types = <String>{};
    final priorities = <String>{};
    final assignees = <String>{};
    final authors = <String>{};
    final labels = <String>{};
    for (final issue in issues) {
      if (issue.state.isNotEmpty) states.add(issue.state.toUpperCase());
      if (issue.type.isNotEmpty) types.add(issue.type.toUpperCase());
      if (issue.priority.isNotEmpty) {
        priorities.add(issue.priority.toUpperCase());
      }
      final a = issue.assigneeId;
      if (a != null && a.isNotEmpty) assignees.add(a);
      final r = issue.reporterId;
      if (r != null && r.isNotEmpty) authors.add(r);
      for (final t in issue.tags) {
        if (t.isNotEmpty) labels.add(t);
      }
    }
    labels.addAll(projectLabels.where((l) => l.isNotEmpty));
    return BoardFilterOptions(
      states: states.toList(),
      types: types.toList(),
      priorities: priorities.toList(),
      assignees: assignees.toList(),
      authors: authors.toList(),
      sprints: [for (final s in boardSprints) s.id],
      labels: labels.toList(),
    );
  }
}
