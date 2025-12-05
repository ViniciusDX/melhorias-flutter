import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/api_requests/api_calls.dart';
import '/backend/api_requests/api_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'login_model.dart';

import '/auth/custom_auth/auth_util.dart';
import '/widgets/notifications/app_notifications.dart';

export 'login_model.dart';

class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  static String routeName = 'Login';
  static String routePath = '/login';

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  late LoginModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginModel());

    _model.emailTextController ??= TextEditingController();
    _model.emailFocusNode ??= FocusNode();

    _model.passwordTextController ??= TextEditingController();
    _model.passwordFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  DateTime? _expFromJwt(String token) {
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

  String? _extractErrorMessage(dynamic body) {
    try {
      if (body == null) return null;

      if (body is Map) {
        if (body['errors'] is Map) {
          final errs = body['errors'] as Map;
          final msgs = <String>[];
          errs.forEach((_, v) {
            if (v is List && v.isNotEmpty) {
              msgs.add(v.first.toString());
            } else if (v is String && v.isNotEmpty) {
              msgs.add(v);
            }
          });
          if (msgs.isNotEmpty) return msgs.join('\n');
        }

        final m = body['message'] ??
            body['detail'] ??
            body['error_description'] ??
            body['error'] ??
            body['title'];
        if (m != null && m.toString().trim().isNotEmpty) {
          return m.toString().trim();
        }
      }

      if (body is String) {
        final s = body.trim();
        if (s.isEmpty) return null;
        try {
          final asJson = jsonDecode(s);
          final extracted = _extractErrorMessage(asJson);
          if (extracted != null && extracted.isNotEmpty) return extracted;
        } catch (_) {
          return s.length > 280 ? '${s.substring(0, 280)}…' : s;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _doLogin() async {
    final email = _model.emailTextController?.text.trim() ?? '';
    final password = _model.passwordTextController?.text ?? '';

    if (email.isEmpty || password.isEmpty) {
      AppNotifications.error(context, 'Please enter email and password.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final res = await UsersLoginCall.call(email: email, password: password);
      if (!mounted) return;

      if (res.succeeded) {
        final token = UsersLoginCall.token(res);
        if (token == null || token.isEmpty) {
          AppNotifications.error(context, 'Server response without token.');
          return;
        }

        ApiManager.setAccessToken(token);

        final userDyn = UsersLoginCall.user(res);
        Map<String, dynamic>? userJson;
        if (userDyn is Map) {
          userJson = userDyn.cast<String, dynamic>();
        }
        final uid = userJson?['id']?.toString();

        final tokenExp = _expFromJwt(token);

        await authManager.signIn(
          authenticationToken: token,
          tokenExpiration: tokenExp,
          authUid: uid,
        );
        if (userJson != null) {
          authManager.setUserData(userJson);
        }

        navigateToHomeFor(context, authManager.member);
      } else {
        String? msg = _extractErrorMessage(res.jsonBody) ?? _extractErrorMessage(res.bodyText);

        if (msg == null || msg.isEmpty) {
          if (res.statusCode == 401) {
            msg = 'Invalid email or password.';
          } else if (res.statusCode == 403) {
            msg = 'You do not have permission to sign in.';
          } else if (res.statusCode == 0) {
            msg = 'Network error. Please check your connection.';
          } else {
            msg = 'Login failed (${res.statusCode}).';
          }
        }

        AppNotifications.error(context, msg);
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifications.error(context, 'Error while authenticating: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: SafeArea(
          top: true,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                flex: 8,
                child: Padding(
                  padding:
                  const EdgeInsetsDirectional.fromSTEB(0.0, 50.0, 0.0, 0.0),
                  child: Container(
                    width: 100.0,
                    height: double.infinity,
                    decoration: const BoxDecoration(color: Colors.white),
                    alignment: const AlignmentDirectional(0.0, -1.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 140.0,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(16.0),
                                bottomRight: Radius.circular(16.0),
                              ),
                            ),
                            alignment:
                            const AlignmentDirectional(-1.0, 0.0),
                            child: Padding(
                              padding:
                              const EdgeInsetsDirectional.fromSTEB(
                                  30.0, 0.0, 30.0, 0.0),
                              child: Text(
                                'Mitsubishi Car Control System',
                                textAlign: TextAlign.center,
                                style: FlutterFlowTheme.of(context)
                                    .displaySmall
                                    .override(
                                  font: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w600,
                                    fontStyle:
                                    FlutterFlowTheme.of(context)
                                        .displaySmall
                                        .fontStyle,
                                  ),
                                  color: const Color(0xFF101213),
                                  fontSize: 36.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle:
                                  FlutterFlowTheme.of(context)
                                      .displaySmall
                                      .fontStyle,
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment:
                            const AlignmentDirectional(0.0, 0.0),
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Align(
                                    alignment:
                                    const AlignmentDirectional(
                                        0.0, 0.0),
                                    child: Container(
                                      width: 341.1,
                                      height: 46.49,
                                      decoration: BoxDecoration(
                                        color:
                                        FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                      ),
                                      child: Align(
                                        alignment:
                                        const AlignmentDirectional(
                                            0.0, 0.0),
                                        child: Text(
                                          'Sign in to start your session',
                                          textAlign: TextAlign.center,
                                          style: FlutterFlowTheme.of(
                                              context)
                                              .labelMedium
                                              .override(
                                            font: GoogleFonts
                                                .plusJakartaSans(
                                              fontWeight:
                                              FontWeight.w500,
                                              fontStyle:
                                              FlutterFlowTheme.of(
                                                  context)
                                                  .labelMedium
                                                  .fontStyle,
                                            ),
                                            color: const Color(
                                                0xFF57636C),
                                            fontSize: 14.0,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                            FontWeight.w500,
                                            fontStyle:
                                            FlutterFlowTheme.of(
                                                context)
                                                .labelMedium
                                                .fontStyle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                    const EdgeInsetsDirectional
                                        .fromSTEB(0.0, 0.0, 0.0, 16.0),
                                    child: SizedBox(
                                      width: 370.0,
                                      child: TextFormField(
                                        controller: _model
                                            .emailTextController,
                                        focusNode:
                                        _model.emailFocusNode,
                                        autofocus: true,
                                        autofillHints: const [
                                          AutofillHints.email
                                        ],
                                        obscureText: false,
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          labelStyle: FlutterFlowTheme
                                              .of(context)
                                              .labelMedium
                                              .override(
                                            font: GoogleFonts
                                                .plusJakartaSans(
                                              fontWeight:
                                              FontWeight.w500,
                                              fontStyle:
                                              FlutterFlowTheme.of(
                                                  context)
                                                  .labelMedium
                                                  .fontStyle,
                                            ),
                                            color: const Color(
                                                0xFF57636C),
                                            fontSize: 14.0,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                            FontWeight.w500,
                                            fontStyle:
                                            FlutterFlowTheme.of(
                                                context)
                                                .labelMedium
                                                .fontStyle,
                                          ),
                                          enabledBorder:
                                          OutlineInputBorder(
                                            borderSide: const BorderSide(
                                                color:
                                                Color(0xFFF1F4F8),
                                                width: 2.0),
                                            borderRadius:
                                            BorderRadius.circular(
                                                12.0),
                                          ),
                                          focusedBorder:
                                          OutlineInputBorder(
                                            borderSide: const BorderSide(
                                                color:
                                                Color(0xFF4B39EF),
                                                width: 2.0),
                                            borderRadius:
                                            BorderRadius.circular(
                                                12.0),
                                          ),
                                          errorBorder:
                                          OutlineInputBorder(
                                            borderSide: const BorderSide(
                                                color:
                                                Color(0xFFFF5963),
                                                width: 2.0),
                                            borderRadius:
                                            BorderRadius.circular(
                                                12.0),
                                          ),
                                          focusedErrorBorder:
                                          OutlineInputBorder(
                                            borderSide: const BorderSide(
                                                color:
                                                Color(0xFFFF5963),
                                                width: 2.0),
                                            borderRadius:
                                            BorderRadius.circular(
                                                12.0),
                                          ),
                                          filled: true,
                                          fillColor:
                                          const Color(0xFFF1F4F8),
                                        ),
                                        style: FlutterFlowTheme.of(
                                            context)
                                            .bodyMedium
                                            .override(
                                          font: GoogleFonts
                                              .plusJakartaSans(
                                            fontWeight:
                                            FontWeight.w500,
                                            fontStyle:
                                            FlutterFlowTheme.of(
                                                context)
                                                .bodyMedium
                                                .fontStyle,
                                          ),
                                          color: const Color(
                                              0xFF101213),
                                          fontSize: 14.0,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                          FontWeight.w500,
                                          fontStyle:
                                          FlutterFlowTheme.of(
                                              context)
                                              .bodyMedium
                                              .fontStyle,
                                        ),
                                        keyboardType:
                                        TextInputType.emailAddress,
                                        validator: _model
                                            .emailTextControllerValidator
                                            .asValidator(context),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                    const EdgeInsetsDirectional
                                        .fromSTEB(0.0, 0.0, 0.0, 16.0),
                                    child: SizedBox(
                                      width: 370.0,
                                      child: TextFormField(
                                        controller: _model
                                            .passwordTextController,
                                        focusNode:
                                        _model.passwordFocusNode,
                                        autofocus: true,
                                        autofillHints: const [
                                          AutofillHints.password
                                        ],
                                        obscureText: !_model
                                            .passwordVisibility,
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          labelStyle: FlutterFlowTheme
                                              .of(context)
                                              .labelMedium
                                              .override(
                                            font: GoogleFonts
                                                .plusJakartaSans(
                                              fontWeight:
                                              FontWeight.w500,
                                              fontStyle:
                                              FlutterFlowTheme.of(
                                                  context)
                                                  .labelMedium
                                                  .fontStyle,
                                            ),
                                            color: const Color(
                                                0xFF57636C),
                                            fontSize: 14.0,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                            FontWeight.w500,
                                            fontStyle:
                                            FlutterFlowTheme.of(
                                                context)
                                                .labelMedium
                                                .fontStyle,
                                          ),
                                          enabledBorder:
                                          OutlineInputBorder(
                                            borderSide: const BorderSide(
                                                color:
                                                Color(0xFFF1F4F8),
                                                width: 2.0),
                                            borderRadius:
                                            BorderRadius.circular(
                                                12.0),
                                          ),
                                          focusedBorder:
                                          OutlineInputBorder(
                                            borderSide: const BorderSide(
                                                color:
                                                Color(0xFF4B39EF),
                                                width: 2.0),
                                            borderRadius:
                                            BorderRadius.circular(
                                                12.0),
                                          ),
                                          errorBorder:
                                          OutlineInputBorder(
                                            borderSide: const BorderSide(
                                                color:
                                                Color(0xFFFF5963),
                                                width: 2.0),
                                            borderRadius:
                                            BorderRadius.circular(
                                                12.0),
                                          ),
                                          focusedErrorBorder:
                                          OutlineInputBorder(
                                            borderSide: const BorderSide(
                                                color:
                                                Color(0xFFFF5963),
                                                width: 2.0),
                                            borderRadius:
                                            BorderRadius.circular(
                                                12.0),
                                          ),
                                          filled: true,
                                          fillColor:
                                          const Color(0xFFF1F4F8),
                                          suffixIcon: InkWell(
                                            onTap: () => safeSetState(
                                                  () => _model
                                                  .passwordVisibility =
                                              !_model
                                                  .passwordVisibility,
                                            ),
                                            focusNode: FocusNode(
                                                skipTraversal: true),
                                            child: Icon(
                                              _model.passwordVisibility
                                                  ? Icons
                                                  .visibility_outlined
                                                  : Icons
                                                  .visibility_off_outlined,
                                              color: const Color(
                                                  0xFF57636C),
                                              size: 24.0,
                                            ),
                                          ),
                                        ),
                                        style: FlutterFlowTheme.of(
                                            context)
                                            .bodyMedium
                                            .override(
                                          font: GoogleFonts
                                              .plusJakartaSans(
                                            fontWeight:
                                            FontWeight.w500,
                                            fontStyle:
                                            FlutterFlowTheme.of(
                                                context)
                                                .bodyMedium
                                                .fontStyle,
                                          ),
                                          color: const Color(
                                              0xFF101213),
                                          fontSize: 14.0,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                          FontWeight.w500,
                                          fontStyle:
                                          FlutterFlowTheme.of(
                                              context)
                                              .bodyMedium
                                              .fontStyle,
                                        ),
                                        validator: _model
                                            .passwordTextControllerValidator
                                            .asValidator(context),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                    const EdgeInsetsDirectional
                                        .fromSTEB(0.0, 0.0, 0.0, 16.0),
                                    child: FFButtonWidget(
                                      onPressed:
                                      _submitting ? null : _doLogin,
                                      text: _submitting
                                          ? 'Signing in…'
                                          : 'Sign In',
                                      options: FFButtonOptions(
                                        width: 370.0,
                                        height: 44.0,
                                        padding:
                                        const EdgeInsetsDirectional
                                            .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                        iconPadding:
                                        const EdgeInsetsDirectional
                                            .fromSTEB(
                                            0.0, 0.0, 0.0, 0.0),
                                        color: const Color(0xFF398FEF),
                                        textStyle:
                                        FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .override(
                                          font: GoogleFonts
                                              .plusJakartaSans(
                                            fontWeight:
                                            FontWeight.w500,
                                            fontStyle:
                                            FlutterFlowTheme.of(
                                                context)
                                                .titleSmall
                                                .fontStyle,
                                          ),
                                          color: Colors.white,
                                          fontSize: 16.0,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                          FontWeight.w500,
                                          fontStyle:
                                          FlutterFlowTheme.of(
                                              context)
                                              .titleSmall
                                              .fontStyle,
                                        ),
                                        elevation: 3.0,
                                        borderSide: const BorderSide(
                                            color: Colors.transparent,
                                            width: 1.0),
                                        borderRadius:
                                        BorderRadius.circular(12.0),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 342.2,
                                    height: 51.29,
                                    decoration: BoxDecoration(
                                      color:
                                      FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                    ),
                                    child: Padding(
                                      padding:
                                      const EdgeInsetsDirectional
                                          .fromSTEB(0.0, 12.0, 0.0, 12.0),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor:
                                        Colors.transparent,
                                        onTap: () async {
                                          context.pushNamed(
                                              ForgotPasswordOrFirstAccessWidget
                                                  .routeName);
                                        },
                                        child: RichText(
                                          textScaler:
                                          MediaQuery.of(context)
                                              .textScaler,
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text:
                                                'Forgot password / First access',
                                                style: FlutterFlowTheme
                                                    .of(context)
                                                    .bodyMedium
                                                    .override(
                                                  font: GoogleFonts
                                                      .plusJakartaSans(
                                                    fontWeight:
                                                    FontWeight
                                                        .w600,
                                                    fontStyle:
                                                    FlutterFlowTheme.of(
                                                        context)
                                                        .bodyMedium
                                                        .fontStyle,
                                                  ),
                                                  color:
                                                  const Color(
                                                      0xFF4B39EF),
                                                  fontSize: 16.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  fontStyle:
                                                  FlutterFlowTheme.of(
                                                      context)
                                                      .bodyMedium
                                                      .fontStyle,
                                                ),
                                              )
                                            ],
                                            style: FlutterFlowTheme.of(
                                                context)
                                                .labelLarge
                                                .override(
                                              font: GoogleFonts
                                                  .plusJakartaSans(
                                                fontWeight:
                                                FontWeight.w500,
                                                fontStyle:
                                                FlutterFlowTheme.of(
                                                    context)
                                                    .labelLarge
                                                    .fontStyle,
                                              ),
                                              color: const Color(
                                                  0xFF57636C),
                                              fontSize: 16.0,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                              FontWeight.w500,
                                              fontStyle:
                                              FlutterFlowTheme.of(
                                                  context)
                                                  .labelLarge
                                                  .fontStyle,
                                            ),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (responsiveVisibility(context: context, phone: false, tablet: false))
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      width: 100.0,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        image: const DecorationImage(
                          fit: BoxFit.cover,
                          image: CachedNetworkImageProvider(
                            'https://images.unsplash.com/photo-1514924013411-cbf25faa35bb?auto=format&fit=crop&w=1380&q=80',
                          ),
                        ),
                        borderRadius: BorderRadius.circular(16.0),
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
