import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:go_router/go_router.dart';

import '/backend/api_requests/api_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

import '/auth/custom_auth/auth_util.dart';
import 'package:mitsubishi/widgets/notifications/app_notifications.dart';

bool _isAdmin(String? member) => (member ?? '').toUpperCase() == 'ADMIN';
bool _isDriver(String? member) => (member ?? '').toUpperCase() == 'DRIVER';
bool _isRental(String? member) => (member ?? '').toUpperCase() == 'RENTAL';

class AppDrawer extends StatelessWidget {
  // >>> CONSTRUTOR SEM const <<<
  const AppDrawer({
    super.key,
    // ADMIN
    required this.onGoDrivers,
    required this.onGoCarRequest,
    required this.onGoCars,
    // USER
    this.onGoMyRequests,
    this.onGoRegisterPreferences,
    // RENTAL
    this.onGoRegisterCarRequest,
    this.onGoRequestForRescheduling,
    // header
    this.userEmail,
    this.member,
  });

  final VoidCallback onGoDrivers;
  final VoidCallback onGoCarRequest;
  final VoidCallback onGoCars;

  final VoidCallback? onGoMyRequests;
  final VoidCallback? onGoRegisterPreferences;
  final VoidCallback? onGoRegisterCarRequest;
  final VoidCallback? onGoRequestForRescheduling;

  final String? userEmail;
  final String? member;

  @override
  Widget build(BuildContext context) {
    final effectiveEmail =
    (userEmail?.isNotEmpty ?? false) ? userEmail! : (authManager.email ?? '—');
    final effectiveMember =
    (member?.isNotEmpty ?? false) ? member! : authManager.member;
    final isAdmin = _isAdmin(effectiveMember);
    final isDriver = _isDriver(effectiveMember);
    final isRental = _isRental(effectiveMember);

    return Drawer(
      elevation: 16,
      child: SafeArea(
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.9,
          child: Container(
            decoration: const BoxDecoration(color: Color(0xFF4F4F4F)),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 0, 0),
                  child: Text(
                    'Car Control System',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight:
                        FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: const Color(0xFFCBCBCB),
                      fontSize: 25,
                    ),
                  ),
                ),
                Divider(thickness: 2, color: FlutterFlowTheme.of(context).alternate),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 0, 0),
                  child: Text(
                    effectiveEmail,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight:
                        FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).alternate,
                    ),
                  ),
                ),
                Divider(thickness: 1, color: FlutterFlowTheme.of(context).alternate),

                // ====== MENU CONDITION ======
                if (isAdmin)
                  const Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(22, 5, 10, 12),
                    child: _AdminMenuItems(),
                  )
                else if (isDriver)
                  const Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(22, 5, 10, 12),
                    child: _DriverMenuItems(),
                  )
                else if (isRental)
                    const Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(22, 5, 10, 12),
                      child: _RentalMenuItems(),
                    )
                  else
                    const Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(22, 5, 10, 12),
                      child: _UserMenuItems(),
                    ),

                const SizedBox(height: 8),
                Divider(thickness: 1, color: FlutterFlowTheme.of(context).alternate),

                const Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(22, 8, 10, 20),
                  child: _LogoutItem(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================= ADMIN MENU =======================
class _AdminMenuItems extends StatelessWidget {
  const _AdminMenuItems();

  TextStyle _itemTextStyle(BuildContext context) =>
      FlutterFlowTheme.of(context).bodyMedium.override(
        font: GoogleFonts.inter(fontWeight: FontWeight.w600),
        color: FlutterFlowTheme.of(context).alternate,
        fontSize: 18,
      );

  BoxDecoration _itemDecoration(BuildContext context) => BoxDecoration(
    color: FlutterFlowTheme.of(context).secondaryText,
    borderRadius: BorderRadius.circular(10),
  );

  void _safeNavigate(BuildContext context, VoidCallback go) {
    final scaffold = Scaffold.maybeOf(context);
    scaffold?.closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) => go());
  }

  @override
  Widget build(BuildContext context) {
    final appDrawer = context.findAncestorWidgetOfExactType<AppDrawer>()!;
    final textStyle = _itemTextStyle(context);
    final deco = _itemDecoration(context);

    Widget buildItem({
      required Widget leading,
      required String label,
      VoidCallback? onTap,
    }) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 47,
            decoration: deco,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 0, 0),
                  child: leading,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AutoSizeText(
                    label,
                    maxLines: 1,
                    minFontSize: 12,
                    stepGranularity: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildItem(
          leading: Icon(Icons.directions_car,
              color: FlutterFlowTheme.of(context).alternate, size: 24),
          label: 'Register Cars',
          onTap: () => _safeNavigate(context, appDrawer.onGoCars),
        ),
        buildItem(
          leading: FaIcon(FontAwesomeIcons.userSecret,
              color: FlutterFlowTheme.of(context).alternate, size: 24),
          label: 'Register Drivers',
          onTap: () => _safeNavigate(context, appDrawer.onGoDrivers),
        ),
        buildItem(
          leading: Icon(Icons.local_taxi,
              color: FlutterFlowTheme.of(context).alternate, size: 24),
          label: 'Car Request',
          onTap: () => _safeNavigate(context, appDrawer.onGoCarRequest),
        ),
        buildItem(
          leading: Icon(
            Icons.directions_car_filled,
            color: FlutterFlowTheme.of(context).alternate,
            size: 24,
          ),
          label: 'My Requests',
          onTap: () => _safeNavigate(
            context,
            appDrawer.onGoMyRequests ??
                    () => context.goNamed(MyRequestsWidget.routeName),
          ),
        ),
        buildItem(
          leading: Icon(
            Icons.schedule_send,
            color: FlutterFlowTheme.of(context).alternate,
            size: 24,
          ),
          label: 'Request for Rescheduling',
          onTap: () => _safeNavigate(
            context,
            appDrawer.onGoRequestForRescheduling ??
                    () => context.goNamed(RentalRescheduleRequestsWidget.routeName),
          ),
        ),
        buildItem(
          leading: Icon(
            Icons.person_outline,
            color: FlutterFlowTheme.of(context).alternate,
            size: 24,
          ),
          label: 'Register and Preferences',
          onTap: () => _safeNavigate(
            context,
            appDrawer.onGoRegisterPreferences ??
                    () => context.goNamed(RegisterPreferencesNav.routeName),
          ),
        ),
      ],
    );
  }
}

// ======================= RENTAL MENU =======================
class _RentalMenuItems extends StatelessWidget {
  const _RentalMenuItems();

  TextStyle _itemTextStyle(BuildContext context) =>
      FlutterFlowTheme.of(context).bodyMedium.override(
        font: GoogleFonts.inter(fontWeight: FontWeight.w700),
        color: FlutterFlowTheme.of(context).alternate,
        fontSize: 18,
      );

  BoxDecoration _itemDecoration(BuildContext context) => BoxDecoration(
    color: FlutterFlowTheme.of(context).secondaryText,
    borderRadius: BorderRadius.circular(10),
  );

  void _go(BuildContext context, VoidCallback nav) {
    Scaffold.maybeOf(context)?.closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) => nav());
  }

  @override
  Widget build(BuildContext context) {
    final appDrawer = context.findAncestorWidgetOfExactType<AppDrawer>()!;
    final textStyle = _itemTextStyle(context);
    final deco = _itemDecoration(context);

    Widget buildItem({
      required Widget leading,
      required String label,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 47,
            decoration: deco,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 0, 0),
                  child: leading,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AutoSizeText(
                    label,
                    maxLines: 1,
                    minFontSize: 12,
                    stepGranularity: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildItem(
          leading: Icon(
            Icons.local_taxi,
            size: 24,
            color: FlutterFlowTheme.of(context).alternate,
          ),
          label: 'Car Request',
          onTap: () => _go(
            context,
            appDrawer.onGoRegisterCarRequest ??
                    () => context.goNamed(RegisterCarRequestWidget.routeName),
          ),
        ),
        buildItem(
          leading: Icon(
            Icons.schedule_send,
            size: 24,
            color: FlutterFlowTheme.of(context).alternate,
          ),
          label: 'Request for Rescheduling',
          onTap: () => _go(
            context,
            appDrawer.onGoRequestForRescheduling ??
                    () => context.goNamed(RentalRescheduleRequestsWidget.routeName),
          ),
        ),
      ],
    );
  }
}

// ======================= DRIVER MENU =======================
class _DriverMenuItems extends StatelessWidget {
  const _DriverMenuItems();

  TextStyle _itemTextStyle(BuildContext context) =>
      FlutterFlowTheme.of(context).bodyMedium.override(
        font: GoogleFonts.inter(fontWeight: FontWeight.w700),
        color: FlutterFlowTheme.of(context).alternate,
        fontSize: 18,
      );

  BoxDecoration _itemDecoration(BuildContext context) => BoxDecoration(
    color: FlutterFlowTheme.of(context).secondaryText,
    borderRadius: BorderRadius.circular(10),
  );

  void _go(BuildContext context, VoidCallback nav) {
    Scaffold.maybeOf(context)?.closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) => nav());
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = _itemTextStyle(context);
    final deco = _itemDecoration(context);

    Widget buildItem({
      required Widget leading,
      required String label,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 47,
            decoration: deco,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 0, 0),
                  child: leading,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AutoSizeText(
                    label,
                    maxLines: 1,
                    minFontSize: 12,
                    stepGranularity: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildItem(
          leading: Icon(
            Icons.local_taxi,
            size: 24,
            color: FlutterFlowTheme.of(context).alternate,
          ),
          label: 'Driver Requests',
          onTap: () => _go(context, () => context.goNamed(DriverRequestsWidget.routeName)),
        ),
      ],
    );
  }
}

// ======================= USER MENU =======================
class _UserMenuItems extends StatelessWidget {
  const _UserMenuItems();

  TextStyle _itemTextStyle(BuildContext context) =>
      FlutterFlowTheme.of(context).bodyMedium.override(
        font: GoogleFonts.inter(fontWeight: FontWeight.w700),
        color: FlutterFlowTheme.of(context).alternate,
        fontSize: 18,
      );

  BoxDecoration _itemDecoration(BuildContext context) => BoxDecoration(
    color: FlutterFlowTheme.of(context).secondaryText,
    borderRadius: BorderRadius.circular(10),
  );

  void _go(BuildContext context, VoidCallback nav) {
    Scaffold.maybeOf(context)?.closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) => nav());
  }

  @override
  Widget build(BuildContext context) {
    final appDrawer = context.findAncestorWidgetOfExactType<AppDrawer>()!;
    final textStyle = _itemTextStyle(context);
    final deco = _itemDecoration(context);

    Widget buildItem({
      required Widget leading,
      required String label,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 47,
            decoration: deco,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 0, 0),
                  child: leading,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AutoSizeText(
                    label,
                    maxLines: 1,
                    minFontSize: 12,
                    stepGranularity: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildItem(
          leading: Icon(
            Icons.directions_car_filled,
            size: 24,
            color: FlutterFlowTheme.of(context).alternate,
          ),
          label: 'My Requests',
          onTap: () => _go(
            context,
            appDrawer.onGoMyRequests ??
                    () => context.goNamed(MyRequestsWidget.routeName),
          ),
        ),
        buildItem(
          leading: Icon(
            Icons.person_outline,
            size: 24,
            color: FlutterFlowTheme.of(context).alternate,
          ),
          label: 'Register and Preferences',
          onTap: () => _go(
            context,
            appDrawer.onGoRegisterPreferences ??
                    () => context.goNamed(RegisterPreferencesNav.routeName),
          ),
        ),
      ],
    );
  }
}

// ======================= LOGOUT =======================
class _LogoutItem extends StatelessWidget {
  const _LogoutItem();

  void _logout(BuildContext context) {
    Scaffold.maybeOf(context)?.closeDrawer();
    ApiManager.setAccessToken(null);
    context.goNamed(LoginWidget.routeName);
    AppNotifications.success(context, 'You have logged out.');
  }

  @override
  Widget build(BuildContext context) {
    final deco = BoxDecoration(
      color: FlutterFlowTheme.of(context).secondaryText,
      borderRadius: BorderRadius.circular(10),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _logout(context),
      child: Container(
        height: 47,
        decoration: deco,
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsetsDirectional.fromSTEB(10, 0, 0, 0),
              child: Icon(Icons.logout_rounded, color: Color(0xFFE34A48), size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AutoSizeText(
                'Exit',
                maxLines: 1,
                minFontSize: 12,
                stepGranularity: 1,
                overflow: TextOverflow.ellipsis,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  color: const Color(0xFFE34A48),
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
