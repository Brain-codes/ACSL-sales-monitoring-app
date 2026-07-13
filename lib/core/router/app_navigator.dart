import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Context-free navigation entry points for non-widget code (services,
/// controllers) during the GetX -> go_router transition.
///
/// [rootNavigatorKey] is the router's navigator key (wired in app_router.dart),
/// so `rootNavigatorKey.currentContext` is a valid routing context.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// First bottom-nav destination after sign-in. Roles share one shell; the
/// drawer self-filters by permission.
const String homePath = '/dashboard';
const String loginRoutePath = '/login';

void goLogin() => rootNavigatorKey.currentContext?.go(loginRoutePath);

void goHome() => rootNavigatorKey.currentContext?.go(homePath);
