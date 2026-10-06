import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_provider.dart';

/// Bridges the old `setNavIndex(n)` vocabulary every sidebar/nav-card call
/// site already used to real navigation, via [AppProvider.routePaths] — the
/// same map the route table in `router.dart` is built from.
extension AppNavigation on BuildContext {
  void goSection(int navIndex) {
    final path = AppProvider.routePaths[navIndex];
    if (path != null) go(path);
  }
}
