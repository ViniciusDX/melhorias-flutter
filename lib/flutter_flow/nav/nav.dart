import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mitsubishi/car/cars_widget.dart';
import 'package:mitsubishi/car_request/car_request_widget.dart';
import 'package:provider/provider.dart';

import '/auth/custom_auth/auth_util.dart' show authManager;
import '/auth/custom_auth/custom_auth_user_provider.dart' show MitsubishiAuthUser;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/widgets/notifications/app_notifications.dart';

export 'package:go_router/go_router.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

String homeRouteForMember(String? member) {
  switch ((member ?? '').toUpperCase()) {
    case 'ADMIN':
      return CarRequestWidget.routeName;
    case 'DRIVER':
      return DriverRequestsWidget.routeName;
    case 'RENTAL':
      return RegisterCarRequestWidget.routeName;
    default:
      return MyRequestsWidget.routeName;
  }
}

String homePathForMember(String? member) {
  switch ((member ?? '').toUpperCase()) {
    case 'ADMIN':
      return CarRequestWidget.routePath;
    case 'DRIVER':
      return DriverRequestsWidget.routePath;
    case 'RENTAL':
      return RegisterCarRequestWidget.routePath;
    default:
      return MyRequestsWidget.routePath;
  }
}

Widget _homePageForMember(String? member) {
  final route = homeRouteForMember(member);
  if (route == CarRequestWidget.routeName) return CarRequestWidget();
  if (route == DriverRequestsWidget.routeName) return const DriverRequestsWidget();
  if (route == RegisterCarRequestWidget.routeName) {
    return const RegisterCarRequestWidget();
  }
  return const MyRequestsWidget();
}

DateTime? _jwtExpFromToken(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = utf8.decode(base64Url.decode(base64.normalize(parts[1])));
    final map = jsonDecode(payload);
    final exp = (map is Map) ? map['exp'] : null;
    if (exp is int) return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    if (exp is String) {
      final v = int.tryParse(exp);
      if (v != null) return DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    return null;
  } catch (_) {
    return null;
  }
}

bool _isTokenValid() {
  final t = authManager.authenticationToken;
  if (t == null || t.trim().isEmpty) return false;

  final exp = authManager.tokenExpiration ?? _jwtExpFromToken(t);
  if (exp == null) return false;

  final nowSkew = DateTime.now().add(const Duration(seconds: 5));
  return exp.isAfter(nowSkew);
}

Future<void> _kickToLogin(BuildContext? ctx) async {
  try { await authManager.signOut(); } catch (_) {}
  final context = ctx ?? appNavigatorKey.currentContext;
  if (context == null) return;

  GoRouter.of(context).goNamed(LoginWidget.routeName);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final c = appNavigatorKey.currentContext ?? context;
    if (c.mounted) {
      AppNotifications.error(c, 'Session expired. Please sign in again.');
    }
  });
}

void navigateToHomeFor(BuildContext context, String? member) {
  context.goNamedAuth(homeRouteForMember(member), context.mounted);
}

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._() {
    _lastTokenValid = _isTokenValid();
    _tokenWatcher = Timer.periodic(const Duration(seconds: 5), (_) {
      final nowValid = _isTokenValid();
      if (nowValid != _lastTokenValid) {
        _lastTokenValid = nowValid;
        notifyListeners();
        if (!nowValid) _kickToLogin(null);
      }
    });
  }

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  MitsubishiAuthUser? initialUser;
  MitsubishiAuthUser? user;
  bool showSplashImage = true;
  String? _redirectLocation;

  bool notifyOnAuthChange = true;

  bool get loading => user == null || showSplashImage;
  bool get loggedIn => user?.loggedIn ?? false;
  bool get initiallyLoggedIn => initialUser?.loggedIn ?? false;
  bool get shouldRedirect => loggedIn && _redirectLocation != null;

  String getRedirectLocation() => _redirectLocation!;
  bool hasRedirect() => _redirectLocation != null;
  void setRedirectLocationIfUnset(String loc) => _redirectLocation ??= loc;
  void clearRedirectLocation() => _redirectLocation = null;

  void updateNotifyOnAuthChange(bool notify) => notifyOnAuthChange = notify;

  void update(MitsubishiAuthUser newUser) {
    final shouldUpdate =
        user?.uid == null || newUser.uid == null || user?.uid != newUser.uid;
    initialUser ??= newUser;
    user = newUser;
    if (notifyOnAuthChange && shouldUpdate) {
      notifyListeners();
    }
    updateNotifyOnAuthChange(true);
  }

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }

  Timer? _tokenWatcher;
  bool _lastTokenValid = true;

  @override
  void dispose() {
    _tokenWatcher?.cancel();
    super.dispose();
  }
}

GoRouter createRouter(AppStateNotifier appStateNotifier) => GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  refreshListenable: appStateNotifier,
  navigatorKey: appNavigatorKey,

  redirect: (context, state) {
    final current = state.uri.toString();
    final onLogin = current == LoginWidget.routePath;
    final onForgot = current == ForgotPasswordOrFirstAccessWidget.routePath;
    final tokenValid = _isTokenValid();

    if (!tokenValid && !(onLogin || onForgot)) {
      appStateNotifier.setRedirectLocationIfUnset(state.uri.toString());
      return LoginWidget.routePath;
    }

    if (tokenValid && current == '/') {
      final targetPath = homePathForMember(authManager.member);
      if (targetPath != current) {
        return targetPath;
      }
    }

    if (tokenValid && (onLogin || onForgot) && appStateNotifier.hasRedirect()) {
      final loc = appStateNotifier.getRedirectLocation();
      appStateNotifier.clearRedirectLocation();
      return loc;
    }

    return null;
  },

  errorBuilder: (context, state) =>
  (_isTokenValid()) ? _homePageForMember(authManager.member) : const LoginWidget(),

  routes: [
    FFRoute(
      name: '_initialize',
      path: '/',
      builder: (context, _) =>
      (_isTokenValid()) ? _homePageForMember(authManager.member) : const LoginWidget(),
      requireAuth: false,
    ),
    FFRoute(
      name: LoginWidget.routeName,
      path: LoginWidget.routePath,
      builder: (context, params) => const LoginWidget(),
      requireAuth: false,
    ),
    FFRoute(
      name: ForgotPasswordOrFirstAccessWidget.routeName,
      path: ForgotPasswordOrFirstAccessWidget.routePath,
      builder: (context, params) => const ForgotPasswordOrFirstAccessWidget(),
      requireAuth: false,
    ),
    FFRoute(
      name: CarsWidget.routeName,
      path: CarsWidget.routePath,
      builder: (context, params) => CarsWidget(),
      requireAuth: true,
    ),
    FFRoute(
      name: CarRequestWidget.routeName,
      path: CarRequestWidget.routePath,
      builder: (context, params) => CarRequestWidget(),
      requireAuth: true,
    ),
    FFRoute(
      name: DriversWidget.routeName,
      path: DriversWidget.routePath,
      builder: (context, params) => DriversWidget(),
      requireAuth: true,
    ),
    FFRoute(
      name: RequestedCarWidget.routeName,
      path: RequestedCarWidget.routePath,
      builder: (context, params) => RequestedCarWidget(),
      requireAuth: true,
    ),
    FFRoute(
      name: DriverRequestsWidget.routeName,
      path: DriverRequestsWidget.routePath,
      builder: (context, params) => const DriverRequestsWidget(),
      requireAuth: true,
    ),
    FFRoute(
      name: RegisterCarRequestWidget.routeName,
      path: RegisterCarRequestWidget.routePath,
      builder: (context, params) => const RegisterCarRequestWidget(),
      requireAuth: true,
    ),
    FFRoute(
      name: RentalRescheduleRequestsWidget.routeName,
      path: RentalRescheduleRequestsWidget.routePath,
      builder: (context, params) => const RentalRescheduleRequestsWidget(),
      requireAuth: true,
    ),
    FFRoute(
      name: MyRequestsWidget.routeName,
      path: MyRequestsWidget.routePath,
      builder: (context, params) => const MyRequestsWidget(),
      requireAuth: true,
    ),

    FFRoute(
      name: RegisterPreferencesNav.routeName,
      path: RegisterPreferencesNav.routePath,
      builder: (context, params) {
        final u = authManager.userData;
        final userId =
            int.tryParse(authManager.uid ?? '') ??
                (u?['id'] is num ? (u?['id'] as num).toInt() : 0);
        final userEmail = u?['email']?.toString();
        final userPhone = u?['phoneNumber']?.toString();

        return RegisterPreferencesNav(
          userId: userId,
          userEmail: userEmail,
          userPhone: userPhone,
        );
      },
      requireAuth: true,
    ),
  ].map((r) => r.toRoute(appStateNotifier)).toList(),
);

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls =>
      Map.fromEntries(entries.where((e) => e.value != null).map((e) => MapEntry(e.key, e.value!)));
}

extension NavigationExtensions on BuildContext {
  bool _needsLogin() {
    final invalid = !_isTokenValid();
    if (invalid) _kickToLogin(this);
    return invalid;
  }

  void goNamedAuth(
      String name,
      bool mounted, {
        Map<String, String> pathParameters = const <String, String>{},
        Map<String, String> queryParameters = const <String, String>{},
        Object? extra,
        bool ignoreRedirect = false,
      }) {
    if (!mounted) return;
    if (GoRouter.of(this).shouldRedirect(ignoreRedirect)) return;
    if (_needsLogin()) return;
    goNamed(name, pathParameters: pathParameters, queryParameters: queryParameters, extra: extra);
  }

  void pushNamedAuth(
      String name,
      bool mounted, {
        Map<String, String> pathParameters = const <String, String>{},
        Map<String, String> queryParameters = const <String, String>{},
        Object? extra,
        bool ignoreRedirect = false,
      }) {
    if (!mounted) return;
    if (GoRouter.of(this).shouldRedirect(ignoreRedirect)) return;
    if (_needsLogin()) return;
    pushNamed(name, pathParameters: pathParameters, queryParameters: queryParameters, extra: extra);
  }

  void safePop() {
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension GoRouterExtensions on GoRouter {
  AppStateNotifier get appState => AppStateNotifier.instance;
  void prepareAuthEvent([bool ignoreRedirect = false]) =>
      appState.hasRedirect() && !ignoreRedirect ? null : appState.updateNotifyOnAuthChange(false);
  bool shouldRedirect(bool ignoreRedirect) => !ignoreRedirect && appState.hasRedirect();
  void clearRedirectLocation() => appState.clearRedirectLocation();
  void setRedirectLocationIfUnset(String location) => appState.updateNotifyOnAuthChange(false);
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap => extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo =>
      extraMap.containsKey(kTransitionInfoKey) ? extraMap[kTransitionInfoKey] as TransitionInfo : TransitionInfo.appDefault();
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  bool get isEmpty =>
      state.allParams.isEmpty || (state.allParams.length == 1 && state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
    state.allParams.entries.where(isAsyncParam).map(
          (param) async {
        final doc = await asyncParams[param.key]!(param.value).onError((_, __) => null);
        if (doc != null) {
          futureParamValues[param.key] = doc;
          return true;
        }
        return false;
      },
    ),
  ).onError((_, __) => [false]).then((v) => v.every((e) => e));
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
    name: name,
    path: path,
    redirect: (context, state) {
      if (appStateNotifier.shouldRedirect) {
        final redirectLocation = appStateNotifier.getRedirectLocation();
        appStateNotifier.clearRedirectLocation();
        return redirectLocation;
      }

      if (requireAuth && !_isTokenValid()) {
        appStateNotifier.setRedirectLocationIfUnset(state.uri.toString());
        return LoginWidget.routePath;
      }
      return null;
    },
    pageBuilder: (context, state) {
      fixStatusBarOniOS16AndBelow(context);
      final ffParams = FFParameters(state, asyncParams);
      final page = ffParams.hasFutures
          ? FutureBuilder(
        future: ffParams.completeFutures(),
        builder: (context, _) => builder(context, ffParams),
      )
          : builder(context, ffParams);

      final child = appStateNotifier.loading
          ? Center(
        child: SizedBox(
          width: 50.0,
          height: 50.0,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              FlutterFlowTheme.of(context).primary,
            ),
          ),
        ),
      )
          : page;

      final transitionInfo = state.transitionInfo;
      return transitionInfo.hasTransition
          ? CustomTransitionPage(
        key: state.pageKey,
        child: child,
        transitionDuration: transitionInfo.duration,
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) =>
            PageTransition(
              type: transitionInfo.transitionType,
              duration: transitionInfo.duration,
              reverseDuration: transitionInfo.duration,
              alignment: transitionInfo.alignment,
              child: child,
            ).buildTransitions(context, animation, secondaryAnimation, child),
      )
          : MaterialPage(key: state.pageKey, child: child);
    },
    routes: routes,
  );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() => TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage && location != '/' && location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) =>
      Provider.value(value: RootPageContext(true, errorRoute), child: child);
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList =
    lastMatch is ImperativeRouteMatch ? lastMatch.matches : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
