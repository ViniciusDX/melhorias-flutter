import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mitsubishi/widgets/notifications/local_prefs.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_widgets.dart';


class ModalSuccessDeviceSmsValidation extends StatefulWidget {
  final String userName;
  const ModalSuccessDeviceSmsValidation({super.key, required this.userName});

  @override
  State<ModalSuccessDeviceSmsValidation> createState() =>
      _ModalSuccessDeviceSmsValidationState();
}

class _ModalSuccessDeviceSmsValidationState
    extends State<ModalSuccessDeviceSmsValidation> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primary,
        body: SafeArea(
          top: true,
          child: Container(
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(36.0, 0.0, 36.0, 0.0),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 100.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/success.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 8.0),
                            child: Text(
                              'Eba! Aparelho autorizado com sucesso!',
                              textAlign: TextAlign.center,
                              style: FlutterFlowTheme.of(context).headlineMedium.override(
                                font: GoogleFonts.roboto(
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .headlineMedium
                                      .fontStyle,
                                ),
                                color: Colors.black,
                                fontSize: 24.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.bold,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .headlineMedium
                                    .fontStyle,
                              ),
                            ),
                          ),
                          Container(
                            width: 300.0,
                            decoration: const BoxDecoration(color: Colors.white),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: _ModalBodyText(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 36.0),
                        child: Container(
                          decoration: const BoxDecoration(color: Color(0x00FFFFFF)),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              FFButtonWidget(
                                onPressed: () async {
                                  await LocalPrefs.setDeviceValidated(true);
                                  if (mounted) Navigator.of(context).pop();
                                },
                                text: 'VOLTAR PARA CONTA',
                                options: FFButtonOptions(
                                  width: double.infinity,
                                  height: 46.0,
                                  padding: const EdgeInsets.all(8.0),
                                  iconPadding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                  color: FlutterFlowTheme.of(context).primary,
                                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                    font: GoogleFonts.roboto(
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context).primaryBackground,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                  ),
                                  borderSide: const BorderSide(color: Colors.transparent),
                                  borderRadius: BorderRadius.circular(24.0),
                                ),
                                showLoadingIndicator: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModalBodyText extends StatelessWidget {
  const _ModalBodyText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Agora você já consegue realizar as suas transações de forma segura utilizando sua conta.',
      textAlign: TextAlign.center,
      style: FlutterFlowTheme.of(context).bodyMedium.override(
        font: GoogleFonts.roboto(
          fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
        ),
        color: const Color(0xFF4A2EB1),
        fontSize: 16.0,
        letterSpacing: 0.0,
        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
      ),
    );
  }
}
