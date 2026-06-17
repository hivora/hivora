import 'dart:ui';

import '../models/work_models.dart';
import 'app_colors.dart';
import 'hue_colors.dart';

/// Resolves per-project label / workflow-state hues for the surfaces that
/// render chips and state badges (issues, board, sprint, search). Built from
/// one or many projects (a board can span several); falls back to the global
/// palette when a name has no configured hue, so nothing ever renders blank.
class ProjectPalette {
  ProjectPalette._(this._stateHues, this._labelHues);

  final Map<String, int> _stateHues;
  final Map<String, int> _labelHues;

  static final ProjectPalette empty = ProjectPalette._(const {}, const {});

  factory ProjectPalette.fromProject(Project? project) {
    if (project == null) return empty;
    return ProjectPalette.fromProjects([project]);
  }

  factory ProjectPalette.fromProjects(Iterable<Project> projects) {
    final states = <String, int>{};
    final labels = <String, int>{};
    for (final p in projects) {
      for (final s in p.workflowStates) {
        states.putIfAbsent(s.name, () => s.hue);
      }
      for (final l in p.labels) {
        labels.putIfAbsent(l.name, () => l.hue);
      }
    }
    return ProjectPalette._(states, labels);
  }

  /// Configured hue for a label name, or null when unknown.
  int? labelHue(String name) => _labelHues[name];

  /// State badge color: the project's configured hue, else the global palette.
  Color stateColor(String state) {
    final hue = _stateHues[state];
    return hue != null ? hueColor(hue) : AppColors.stateColor(state);
  }
}
