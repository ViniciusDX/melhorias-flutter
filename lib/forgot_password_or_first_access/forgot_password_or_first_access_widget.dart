import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';

import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'forgot_password_or_first_access_model.dart';
export 'forgot_password_or_first_access_model.dart';

import '/backend/api_requests/api_calls.dart' as API;
import '/widgets/notifications/app_notifications.dart';

class ForgotPasswordOrFirstAccessWidget extends StatefulWidget {
  const ForgotPasswordOrFirstAccessWidget({super.key});

  static String routeName = 'ForgotPasswordOrFirstAccess';
  static String routePath = '/forgotPasswordOrFirstAccess';

  @override
  State<ForgotPasswordOrFirstAccessWidget> createState() =>
      _ForgotPasswordOrFirstAccessWidgetState();
}

class _ForgotPasswordOrFirstAccessWidgetState
    extends State<ForgotPasswordOrFirstAccessWidget> {
  late ForgotPasswordOrFirstAccessModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _submitting = false;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ForgotPasswordOrFirstAccessModel());
    _model.emailAddressTextController ??= TextEditingController();
    _model.emailAddressFocusNode ??= FocusNode();
    _model.emailAddressTextController!.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _model.emailAddressTextController?.removeListener(_onEmailChanged);
    _model.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    final email = _model.emailAddressTextController?.text.trim() ?? '';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (ok != _canSubmit) setState(() => _canSubmit = ok);
  }

  String _msgFromBody(dynamic body) {
    final dynamic root =
    (body is API.ApiCallResponse) ? body.jsonBody : body;

    if (root == null) return '';

    if (root is String) {
      return root.trim();
    }

    if (root is Map) {
      for (final k in const [
        'message',
        'Message',
        'detail',
        'Detail',
        'title',
        'error',
        'error_description',
        'reason',
        'description',
      ]) {
        final v = root[k];
        if (v != null) {
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }

      final errors = root['errors'] ?? root['Errors'];
      if (errors is Map) {
        final parts = <String>[];
        errors.forEach((_, v) {
          if (v is List) {
            parts.addAll(v.map((e) => e.toString()));
          } else if (v != null) {
            parts.add(v.toString());
          }
        });
        final flat = parts.where((e) => e.trim().isNotEmpty).join('\n').trim();
        if (flat.isNotEmpty) return flat;
      }
      return '';
    }

    if (root is List) {
      final joined = root.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).join('\n');
      return joined;
    }

    return root.toString();
  }

  Future<void> _submit() async {
    final email = _model.emailAddressTextController?.text.trim() ?? '';
    if (email.isEmpty || !_canSubmit || _submitting) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      final resp = await API.ForgotPasswordCall.call(email: email);
      if (!mounted) return;

      final code = resp.statusCode ?? 0;
      final isSuccess = code >= 200 && code < 300;
      final msg = (() {
        final m = _msgFromBody(resp);
        if (m.isNotEmpty) return m;
        return isSuccess
            ? 'Password reset e-mail sent.'
            : 'Request failed (HTTP $code).';
      })();

      if (isSuccess) {
        AppNotifications.success(context, msg);
      } else {
        AppNotifications.error(context, msg);
      }
    } catch (_) {
      if (!mounted) return;
      AppNotifications.error(context, 'Unexpected error. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFF1F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F4F8),
        automaticallyImplyLeading: false,
        leading: FlutterFlowIconButton(
          borderColor: Colors.transparent,
          borderRadius: 30.0,
          borderWidth: 1.0,
          buttonSize: 60.0,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF15161E),
            size: 30.0,
          ),
          onPressed: () async {
            context.pushNamed(
              LoginWidget.routeName,
              extra: <String, dynamic>{
                kTransitionInfoKey: const TransitionInfo(
                  hasTransition: true,
                  transitionType: PageTransitionType.leftToRight,
                ),
              },
            );
          },
        ),
        title: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4.0, 0.0, 0.0, 0.0),
          child: Text(
            'Back',
            style: FlutterFlowTheme.of(context).displaySmall.override(
              font: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontStyle:
                FlutterFlowTheme.of(context).displaySmall.fontStyle,
              ),
              color: const Color(0xFF15161E),
              fontSize: 16.0,
              letterSpacing: 0.0,
              fontWeight: FontWeight.w600,
              fontStyle:
              FlutterFlowTheme.of(context).displaySmall.fontStyle,
            ),
          ),
        ),
        actions: const [],
        centerTitle: false,
        elevation: 0.0,
      ),
      body: Align(
        alignment: const AlignmentDirectional(0.0, -1.0),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 570.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (responsiveVisibility(context: context, phone: false, tablet: false))
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                  child: InkWell(
                    onTap: () => context.safePop(),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 12),
                          child: Icon(Icons.arrow_back_rounded, color: Color(0xFF15161E), size: 24),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 0, 0),
                          child: Text(
                            'Back',
                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w500,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              color: const Color(0xFF15161E),
                              fontSize: 14,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w500,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 0, 15),
                child: Text(
                  'Forgot Password / First Access',
                  style: FlutterFlowTheme.of(context).headlineMedium.override(
                    font: GoogleFonts.outfit(
                      fontWeight: FontWeight.w500,
                      fontStyle: FlutterFlowTheme.of(context)
                          .headlineMedium
                          .fontStyle,
                    ),
                    color: const Color(0xFF15161E),
                    fontSize: 24,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w500,
                    fontStyle: FlutterFlowTheme.of(context)
                        .headlineMedium
                        .fontStyle,
                  ),
                ),
              ),
              SizedBox(
                width: 411,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
                  child: Text(
                    'You forgot your password or is it your first access? Here you can easily request a password.',
                    style: FlutterFlowTheme.of(context).labelMedium.override(
                      font: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w500,
                        fontStyle: FlutterFlowTheme.of(context)
                            .labelMedium
                            .fontStyle,
                      ),
                      color: const Color(0xFF606A85),
                      fontSize: 14,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w500,
                      fontStyle: FlutterFlowTheme.of(context)
                          .labelMedium
                          .fontStyle,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
                child: TextFormField(
                  controller: _model.emailAddressTextController,
                  focusNode: _model.emailAddressFocusNode,
                  autofillHints: const [AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Enter your email...',
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF6F61EF), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsetsDirectional.fromSTEB(24, 24, 20, 24),
                  ),
                ),
              ),
              Align(
                alignment: const AlignmentDirectional(0, 0),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0, 24, 0, 0),
                  child: FFButtonWidget(
                    onPressed: (_submitting || !_canSubmit) ? null : _submit,
                    text: _submitting ? 'Sending...' : 'Request new password',
                    options: FFButtonOptions(
                      width: 270,
                      height: 50,
                      color: FlutterFlowTheme.of(context).primary,
                      textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w500,
                          fontStyle: FlutterFlowTheme.of(context)
                              .titleSmall
                              .fontStyle,
                        ),
                        color: Colors.white,
                        fontSize: 16,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w500,
                        fontStyle: FlutterFlowTheme.of(context)
                            .titleSmall
                            .fontStyle,
                      ),
                      elevation: 3,
                      borderSide: const BorderSide(color: Colors.transparent, width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
