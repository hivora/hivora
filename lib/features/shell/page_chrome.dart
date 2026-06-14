import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Chrome a sub-page hands the app shell to render in its top app bar: the
/// page's real (often dynamic) [title] and an optional [onBack] override for
/// back navigation that isn't a plain route pop — e.g. an in-page master→detail
/// step. When a page publishes nothing the shell falls back to a route-derived
/// title and a pop/parent-route back.
@immutable
class PageChromeData {
  const PageChromeData({this.location, this.title, this.onBack});

  /// The route this chrome belongs to. The shell only honours an override whose
  /// [location] matches the route currently on screen, so stale chrome from a
  /// page being torn down is ignored automatically (no dispose ordering race).
  final String? location;
  final String? title;
  final VoidCallback? onBack;
}

/// Carries the chrome published by the visible sub-page to the shell's top bar.
class PageChromeController extends ChangeNotifier {
  PageChromeData _data = const PageChromeData();

  String? titleFor(String location) =>
      _data.location == location ? _data.title : null;

  VoidCallback? onBackFor(String location) =>
      _data.location == location ? _data.onBack : null;

  void publish(PageChromeData data) {
    if (_data.location == data.location &&
        _data.title == data.title &&
        identical(_data.onBack, data.onBack)) {
      return;
    }
    _data = data;
    notifyListeners();
  }
}

/// Provides a [PageChromeController] to the shell's top bar (which listens) and
/// to descendant pages (which publish without subscribing).
class PageChromeScope extends InheritedNotifier<PageChromeController> {
  const PageChromeScope({
    super.key,
    required PageChromeController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Listening lookup — the caller rebuilds when the chrome changes.
  static PageChromeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PageChromeScope>();
    assert(scope != null, 'No PageChromeScope found in context');
    return scope!.notifier!;
  }

  /// Non-listening lookup — for pages that only publish.
  static PageChromeController? maybeRead(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PageChromeScope>()?.notifier;
}

/// Declarative helper a sub-page wraps around its body to publish [title] /
/// [onBack] to the shell's app bar. Re-publishes whenever those change and is a
/// silent no-op where no [PageChromeScope] is present (e.g. in unit tests).
class PageChrome extends StatefulWidget {
  const PageChrome({
    super.key,
    this.title,
    this.onBack,
    required this.child,
  });

  final String? title;
  final VoidCallback? onBack;
  final Widget child;

  @override
  State<PageChrome> createState() => _PageChromeState();
}

class _PageChromeState extends State<PageChrome> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePublish();
  }

  @override
  void didUpdateWidget(PageChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        !identical(oldWidget.onBack, widget.onBack)) {
      _schedulePublish();
    }
  }

  // Publishing after the frame keeps us clear of the build phase (the shell's
  // top bar listens to the same controller) and lets us read the active route.
  void _schedulePublish() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = PageChromeScope.maybeRead(context);
      if (controller == null) return;
      controller.publish(PageChromeData(
        location: GoRouterState.of(context).matchedLocation,
        title: widget.title,
        onBack: widget.onBack,
      ));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
