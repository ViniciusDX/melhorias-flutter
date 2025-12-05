import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mitsubishi/register_preferences/rp_models.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'modal_success_device_sms_validation.dart';

class FinishResult {
  final DateTime start;
  final DateTime end;
  final bool hadIncident;
  const FinishResult({
    required this.start,
    required this.end,
    required this.hadIncident,
  });
}

class IncidentImage {
  final String fileName;
  final Uint8List bytes;
  IncidentImage({required this.fileName, required this.bytes});
}
class DriverChangeOption {
  final int id;
  final String name;
  const DriverChangeOption({required this.id, required this.name});
}
enum PeriodModalMode {
  repeat,
  finishPeriod,
  extend,
  reviewTime,
  generic,
}

class AppNotifications {
  static void success(BuildContext context,
      String message, {
        String? actionLabel,
        VoidCallback? onAction,
      }) {
    final theme = FlutterFlowTheme.of(context);
    _showSnack(
      context,
      message,
      background: theme.primary,
      icon: Icons.check_circle_rounded,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void info(BuildContext context,
      String message, {
        String? actionLabel,
        VoidCallback? onAction,
      }) {
    final theme = FlutterFlowTheme.of(context);
    _showSnack(
      context,
      message,
      background: theme.secondary,
      icon: Icons.info_rounded,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void warning(BuildContext context,
      String message, {
        String? actionLabel,
        VoidCallback? onAction,
      }) {
    _showSnack(
      context,
      message,
      background: Colors.amber.shade700,
      icon: Icons.warning_amber_rounded,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void error(BuildContext context,
      String message, {
        String? actionLabel,
        VoidCallback? onAction,
      }) {
    _showSnack(
      context,
      message,
      background: Theme
          .of(context)
          .colorScheme
          .error,
      icon: Icons.error_rounded,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void _showSnack(BuildContext context,
      String message, {
        required Color background,
        IconData? icon,
        String? actionLabel,
        VoidCallback? onAction,
      }) {
    Color _foregroundFor(Color bg) =>
        bg.computeLuminance() < 0.5 ? Colors.white : Colors.black87;

    final fg = _foregroundFor(background);
    final theme = FlutterFlowTheme.of(context);

    final bottomSafe = MediaQuery
        .of(context)
        .viewPadding
        .bottom;
    final margin =
    EdgeInsets.fromLTRB(16, 0, 16, 16 + (bottomSafe > 0 ? 8 : 0));

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 12,
      margin: margin,
      backgroundColor: background,
      duration: const Duration(seconds: 3),
      dismissDirection: DismissDirection.horizontal,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: fg),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              message,
              style: theme.bodyMedium.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      action: (actionLabel != null)
          ? SnackBarAction(
        label: actionLabel,
        textColor: fg,
        onPressed: onAction ?? () {},
      )
          : null,
    );

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(snackBar);
  }

  static Future<void> showDeviceValidatedModal(BuildContext context, {
    required String userName,
    bool barrierDismissible = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => ModalSuccessDeviceSmsValidation(userName: userName),
    );
  }

  static Future<bool> confirmDanger(BuildContext context, {
    required String title,
    required String message,
    String cancelLabel = 'Cancel',
    String confirmLabel = 'Delete',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          _ConfirmDangerScreen(
            title: title,
            message: message,
            cancelLabel: cancelLabel,
            confirmLabel: confirmLabel,
          ),
    );
    return result ?? false;
  }

  static Future<bool> confirmRescheduleStatus(
      BuildContext context, {
        required bool approving,
        required String requestNumber,
        String? message,
      }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RescheduleStatusConfirmDialog(
        approving: approving,
        requestNumber: requestNumber,
        message: message,
      ),
    );

    return result ?? false;
  }

  static Future<void> showPresidenceConflictModal(BuildContext context, {
    required String driverName,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          _InfoModalScreen(
            title: 'Attention please!',
            message:
            'There is already a driver $driverName for the President scheduled for that day.\n\n'
                'If you want that day for that driver, you will need to deallocate the current driver for that day.',
            buttonLabel: 'Abort',
            icon: Icons.warning_amber_rounded,
            accentColor: Colors.red.shade600,
            bubbleColor: Colors.red.shade50,
          ),
    );
  }
  static Future<int?> showChangeDriverModal(
      BuildContext context, {
        required List<DriverChangeOption> drivers,
        int? currentDriverId,
      }) {
    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ChangeDriverDialog(
        drivers: drivers,
        currentDriverId: currentDriverId,
      ),
    );
  }
  static Future<void> showAlert(BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          _InfoModalScreen(
            title: title,
            message: message,
            buttonLabel: buttonLabel,
            icon: Icons.info_rounded,
            accentColor: FlutterFlowTheme
                .of(context)
                .secondary,
            bubbleColor: const Color(0xFFEFF6FF),
          ),
    );
  }

  static Future<String?> showCancelRequestModal(BuildContext context, {
    String title = 'Are you sure to cancel this Car Request?',
    String reasonLabel = 'Reason',
    String reasonHint = 'Please, inform the reason...',
    String abortLabel = 'Abort',
    String confirmLabel = 'Confirm cancel',
    String? initialReason,
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          _CancelRequestScreen(
            title: title,
            reasonLabel: reasonLabel,
            reasonHint: reasonHint,
            abortLabel: abortLabel,
            confirmLabel: confirmLabel,
            initialReason: initialReason,
          ),
    );
  }

  static Future<void> showCarRequestDetailsModal(BuildContext context, {
    String title = 'Car Request Details',
    required String id,
    required String userName,
    required DateTime periodFrom,
    DateTime? periodTo,
    required String driver,
    String? company,
    required String model,
    required bool childSeat,
    required String licensePlate,
    required bool hadIncident,
    required String departure,
    List<String> destinations = const [],
    String? notes,

    String? statusText,
    Color? statusColor,
    DateTime? realPeriodFrom,
    DateTime? realPeriodTo,
    int? startKm,
    int? endKm,
    bool? finalKmOk,
    bool? periodConfirmedOk,
    String? disacordReason,
    String? cancelReason,
    List<Map<String, dynamic>>? costAllocs,
    List<Map<String, dynamic>>? flights,
    String? passengersCsv,
  }) {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (_) => _RequestDetailsDialog(
        title: title,
        id: id,
        userName: userName,
        periodFrom: periodFrom,
        periodTo: periodTo,
        driver: driver,
        company: company,
        model: model,
        childSeat: childSeat,
        licensePlate: licensePlate,
        hadIncident: hadIncident,
        departure: departure,
        destinations: destinations,
        notes: notes,
        statusText: statusText,
        statusColor: statusColor,
        realPeriodFrom: realPeriodFrom,
        realPeriodTo: realPeriodTo,
        startKm: startKm,
        endKm: endKm,
        finalKmOk: finalKmOk,
        periodConfirmedOk: periodConfirmedOk,
        disacordReason: disacordReason,
        cancelReason: cancelReason,
        costAllocs: costAllocs,
        flights: flights,
        passengersCsv: passengersCsv,
      ),
    );
  }

  static Future<int?> showChangeDriverModal(
      BuildContext context, {
        required List<DriverChangeOption> drivers,
        int? currentDriverId,
      }) {
    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ChangeDriverDialog(
        drivers: drivers,
        currentDriverId: currentDriverId,
      ),
    );
  }

  Future<int?> showDriverStartKmModal(BuildContext context, {required int fixedKm}) {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DriverStartKmDialog(fixedKm: fixedKm),
    );
  }

  Future<DateTime?> showDriverExtendPeriodModal(BuildContext context, {
    required DateTime initialEnd,
  }) {
    return showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _DriverExtendDialog(initialEnd: initialEnd),
    );
  }

  Future<FinishResult?> showDriverFinishTripModal(
      BuildContext context, {
        required DateTime initialFrom,
        required DateTime initialTo,
        VoidCallback? onOpenIncident,
        bool existingIncident = false,
      }) {
    return showDialog<FinishResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DriverFinishDialog(
        initialFrom: initialFrom,
        initialTo: initialTo,
        onOpenIncident: onOpenIncident,
        existingIncident: existingIncident,
      ),
    );
  }

  static Future<int?> showDriverFinalKmModal(
      BuildContext context, {
        required int initialKm,
        int? minKm,
      }) {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DriverFinalKmDialog(
        initialKm: initialKm,
        minKm: minKm,
      ),
    );
  }

  static Future<bool?> showConfirmPeriodModal(BuildContext context, {
    String title = 'Car Request Period Confirmation',
    required String requestId,
    required String userName,
    required String driver,
    required String departure,
    List<String> destinations = const [],
    required DateTime periodFrom,
    required DateTime periodTo,
  }) async {
    final choice = await showDialog<_ConfirmChoice>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          _ConfirmPeriodDialog(
            title: title,
            requestId: requestId,
            userName: userName,
            driver: driver,
            departure: departure,
            destinations: destinations,
            periodFrom: periodFrom,
            periodTo: periodTo,
          ),
    );
    if (choice == null) return null;
    return choice == _ConfirmChoice.confirm;
  }

  static Future<String?> showDisagreeReasonModal(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _DisagreeReasonDialog(),
    );
  }

  static Future<CostAllocationDetail?> showCostAllocationDetailModal(
      BuildContext context, {
        String title = 'Cost Allocation Detail',
        CostAllocationDetail? initial,
      }) {
    return showDialog<CostAllocationDetail>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          _CostAllocationDetailModal(
            title: title,
            initial: initial,
          ),
    );
  }

  static Future<String?> showRenameGroupModal(BuildContext context, {
    String title = 'Cost Allocation',
    String label = 'Name',
    String? initial,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          _RenameGroupScreen(
            title: title,
            label: label,
            initial: initial ?? '',
          ),
    );
  }

  static Future<FavoritePlace?> showFavoritePlaceModal(BuildContext context, {
    String title = 'Favorite Place',
    FavoritePlace? initial,
  }) {
    return showDialog<FavoritePlace>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          _FavoritePlaceModalScreen(
            title: title,
            initial: initial,
          ),
    );
  }

  static Future<FlightInfo?> showFlightInfoModal(BuildContext context, {
    required bool isDeparture,
    required String selectedPlace,
    FlightInfo? initial,
  }) {
    return showDialog<FlightInfo>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          _FlightInfoModal(
            isDeparture: isDeparture,
            selectedPlace: selectedPlace,
            initial: initial,
          ),
    );
  }

  static Future<void> showTrafficIncidentModal({
    required BuildContext context,
    required String title,
    required int incidentId,
    required int carRequestId,
    String? driverName,
    DateTime? creationAt,
    DateTime? incidentAt,
    required bool hasInjuries,
    String? injuriesDetails,
    String? incidentLocation,
    String? incidentSummary,
    String? damagePlate,
    String? damageSummary,
    List<String>? passengers,
    List<String>? otherPassengers,
    required List<IncidentImage> images,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _IncidentDetailsDialog(
        title: title,
        incidentId: incidentId,
        carRequestId: carRequestId,
        driverName: driverName,
        creationAt: creationAt,
        incidentAt: incidentAt,
        hasInjuries: hasInjuries,
        injuriesDetails: injuriesDetails,
        incidentLocation: incidentLocation,
        incidentSummary: incidentSummary,
        damagePlate: damagePlate,
        damageSummary: damageSummary,
        passengers: passengers ?? const [],
        otherPassengers: otherPassengers ?? const [],
        images: images,
      ),
    );
  }

}
// ===== Flight info model =====
class FlightInfo {
  final bool isDeparture;
  final String airport;
  final TimeOfDay? time;
  final String sourceAirport;
  final String destinationAirport;
  final String flightNumber;

  const FlightInfo({
    required this.isDeparture,
    required this.airport,
    this.time,
    this.sourceAirport = '',
    this.destinationAirport = '',
    this.flightNumber = '',
  });

  FlightInfo copyWith({
    bool? isDeparture,
    String? airport,
    TimeOfDay? time,
    String? sourceAirport,
    String? destinationAirport,
    String? flightNumber,
  }) {
    return FlightInfo(
      isDeparture: isDeparture ?? this.isDeparture,
      airport: airport ?? this.airport,
      time: time ?? this.time,
      sourceAirport: sourceAirport ?? this.sourceAirport,
      destinationAirport: destinationAirport ?? this.destinationAirport,
      flightNumber: flightNumber ?? this.flightNumber,
    );
  }
}

class _ConfirmDangerScreen extends StatefulWidget {
  const _ConfirmDangerScreen({
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;

  @override
  State<_ConfirmDangerScreen> createState() => _ConfirmDangerScreenState();
}

class _ConfirmDangerScreenState extends State<_ConfirmDangerScreen> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primary,
        body: SafeArea(
          top: true,
          child: Container(
            decoration: BoxDecoration(color: theme.secondaryBackground),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(36, 0, 36, 0),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Padding(
                      padding:
                      const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 120),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 72,
                              color: Colors.red.shade600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                0, 24, 0, 8),
                            child: Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: theme.headlineMedium.copyWith(
                                color: Colors.red.shade600,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            width: 320,
                            decoration:
                            const BoxDecoration(color: Colors.white),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                widget.message,
                                textAlign: TextAlign.center,
                                style: theme.bodyMedium.copyWith(
                                  color: const Color(0xFF333333),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0, 0, 0, 36),
                        child: Column(
                          children: [
                            FFButtonWidget(
                              onPressed: () =>
                                  Navigator.of(context).pop(false),
                              text: widget.cancelLabel,
                              options: FFButtonOptions(
                                width: double.infinity,
                                height: 46,
                                padding: const EdgeInsets.all(8),
                                iconPadding:
                                const EdgeInsetsDirectional.fromSTEB(
                                    0, 0, 0, 0),
                                color: const Color(0xFFD4D4D4),
                                textStyle: theme.titleSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                borderSide: const BorderSide(
                                    color: Colors.transparent),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              showLoadingIndicator: false,
                            ),
                            const SizedBox(height: 10),
                            FFButtonWidget(
                              onPressed: () =>
                                  Navigator.of(context).pop(true),
                              text: widget.confirmLabel,
                              options: FFButtonOptions(
                                width: double.infinity,
                                height: 46,
                                padding: const EdgeInsets.all(8),
                                iconPadding:
                                const EdgeInsetsDirectional.fromSTEB(
                                    0, 0, 0, 0),
                                color: Colors.red.shade600,
                                textStyle: theme.titleSmall.copyWith(
                                  color: theme.primaryBackground,
                                  fontWeight: FontWeight.w700,
                                ),
                                borderSide: const BorderSide(
                                    color: Colors.transparent),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              showLoadingIndicator: false,
                            ),
                          ],
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

class _RescheduleStatusConfirmDialog extends StatelessWidget {
  const _RescheduleStatusConfirmDialog({
    required this.approving,
    required this.requestNumber,
    this.message,
  });

  final bool approving;
  final String requestNumber;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final accent = approving ? theme.success : theme.error;
    final bubbleColor = accent.withOpacity(0.12);
    final icon = approving
        ? Icons.check_circle_rounded
        : Icons.highlight_off_rounded;
    final title = approving
        ? 'Approve rescheduling'
        : 'Reject rescheduling';

    final trimmedRequest = requestNumber.trim();
    final formattedRequest = trimmedRequest.isEmpty
        ? ''
        : (trimmedRequest.startsWith('#')
<<<<<<< HEAD
        ? trimmedRequest
        : '#$trimmedRequest');
=======
            ? trimmedRequest
            : '#$trimmedRequest');
>>>>>>> 7443e160bdf6869c7fcb515d0c70a50fd3697edd
    final targetLabel = formattedRequest.isNotEmpty
        ? 'request $formattedRequest'
        : 'this request';

    final body = message ??
        'Do you want to ${approving ? 'approve' : 'reject'} the rescheduling for $targetLabel?';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: bubbleColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.headlineMedium.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.bodyMedium.copyWith(
                color: theme.primaryText,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 28),
            FFButtonWidget(
              onPressed: () => Navigator.of(context).pop(false),
              text: 'Cancel',
              options: FFButtonOptions(
                width: double.infinity,
                height: 46,
                padding: const EdgeInsets.all(8),
                color: const Color(0xFFD4D4D4),
                textStyle: theme.titleSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                borderSide: const BorderSide(color: Colors.transparent),
                borderRadius: BorderRadius.circular(24),
              ),
              showLoadingIndicator: false,
            ),
            const SizedBox(height: 12),
            FFButtonWidget(
              onPressed: () => Navigator.of(context).pop(true),
              text: approving ? 'Approve' : 'Reject',
              options: FFButtonOptions(
                width: double.infinity,
                height: 46,
                padding: const EdgeInsets.all(8),
                color: accent,
                textStyle: theme.titleSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                borderSide: const BorderSide(color: Colors.transparent),
                borderRadius: BorderRadius.circular(24),
              ),
              showLoadingIndicator: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoModalScreen extends StatelessWidget {
  const _InfoModalScreen({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.icon,
    required this.accentColor,
    required this.bubbleColor,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final IconData icon;
  final Color accentColor;
  final Color bubbleColor;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primary,
      body: SafeArea(
        top: true,
        child: Container(
          decoration: BoxDecoration(color: theme.secondaryBackground),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(36, 0, 36, 0),
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(color: Colors.white),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 72, color: accentColor),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.headlineMedium.copyWith(
                            color: accentColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: theme.bodyMedium.copyWith(
                              color: const Color(0xFF333333),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FFButtonWidget(
                          onPressed: () => Navigator.of(context).pop(),
                          text: buttonLabel,
                          options: FFButtonOptions(
                            width: 220,
                            height: 46,
                            padding: const EdgeInsets.all(8),
                            color: accentColor,
                            textStyle: theme.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            borderSide:
                            const BorderSide(color: Colors.transparent),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          showLoadingIndicator: false,
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
    );
  }
}

class _CancelRequestScreen extends StatefulWidget {
  const _CancelRequestScreen({
    required this.title,
    required this.reasonLabel,
    required this.reasonHint,
    required this.abortLabel,
    required this.confirmLabel,
    this.initialReason,
  });

  final String title;
  final String reasonLabel;
  final String reasonHint;
  final String abortLabel;
  final String confirmLabel;
  final String? initialReason;

  @override
  State<_CancelRequestScreen> createState() => _CancelRequestScreenState();
}

class _CancelRequestScreenState extends State<_CancelRequestScreen> {
  late final TextEditingController _reasonCtrl =
  TextEditingController(text: widget.initialReason ?? '');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        backgroundColor: theme.primary,
        body: SafeArea(
          top: true,
          child: Container(
            decoration: BoxDecoration(color: theme.secondaryBackground),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(36, 0, 36, 0),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 120),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 72,
                                color: Colors.red.shade600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: theme.headlineMedium.copyWith(
                                color: Colors.red.shade600,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 18),

                            Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      widget.reasonLabel,
                                      textAlign: TextAlign.left,
                                      style: theme.bodyMedium.copyWith(
                                        color: const Color(0xFF333333),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _reasonCtrl,
                                      autofocus: true,
                                      decoration: InputDecoration(
                                        hintText: widget.reasonHint,
                                        isDense: true,
                                        filled: true,
                                        fillColor: Colors.white,
                                        prefixIcon: const Icon(
                                            Icons.edit_note_rounded),
                                        suffixIcon: const Icon(
                                            Icons.help_outline_rounded),
                                        contentPadding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                              color: Colors.black12),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(14),
                                          borderSide: BorderSide(
                                            color: theme.alternate
                                                .withOpacity(0.25),
                                          ),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null ||
                                            v.trim().isEmpty) {
                                          return 'Please, inform the reason.';
                                        }
                                        return null;
                                      },
                                      onChanged: (_) => setState(() {}),
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

                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0, 0, 0, 36),
                        child: Column(
                          children: [
                            FFButtonWidget(
                              onPressed: () =>
                                  Navigator.of(context).pop<String?>(null),
                              text: widget.abortLabel,
                              options: FFButtonOptions(
                                width: double.infinity,
                                height: 46,
                                padding: const EdgeInsets.all(8),
                                color: const Color(0xFFD4D4D4),
                                textStyle: theme.titleSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                borderSide: const BorderSide(
                                    color: Colors.transparent),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              showLoadingIndicator: false,
                            ),
                            const SizedBox(height: 10),
                            FFButtonWidget(
                              onPressed: (_reasonCtrl.text.trim().isNotEmpty)
                                  ? () {
                                if (_formKey.currentState?.validate() ??
                                    false) {
                                  Navigator.of(context).pop<String>(
                                      _reasonCtrl.text.trim());
                                }
                              }
                                  : null,
                              text: widget.confirmLabel,
                              options: FFButtonOptions(
                                width: double.infinity,
                                height: 46,
                                padding: const EdgeInsets.all(8),
                                color: Colors.red.shade600,
                                disabledColor: Colors.red.shade200,
                                textStyle: theme.titleSmall.copyWith(
                                  color: theme.primaryBackground,
                                  fontWeight: FontWeight.w700,
                                ),
                                borderSide: const BorderSide(
                                    color: Colors.transparent),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              showLoadingIndicator: false,
                            ),
                          ],
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

class _RepeatRequestScreen extends StatefulWidget {
  const _RepeatRequestScreen({
    required this.title,
    required this.originalId,
    required this.originalStart,
    required this.originalEnd,
    this.mode = PeriodModalMode.repeat,
    this.sectionTitleOverride,
    this.originalIdLabelOverride,
    this.originalPeriodLabelOverride,
    this.primaryCtaLabelOverride,
    this.showOriginalId = true,
  });

  final String title;
  final String originalId;
  final DateTime originalStart;
  final DateTime originalEnd;

  final PeriodModalMode mode;
  final String? sectionTitleOverride;
  final String? originalIdLabelOverride;
  final String? originalPeriodLabelOverride;
  final String? primaryCtaLabelOverride;
  final bool showOriginalId;

  @override
  State<_RepeatRequestScreen> createState() => _RepeatRequestScreenState();
}

class _RepeatRequestScreenState extends State<_RepeatRequestScreen> {
  late DateTime _start;
  late DateTime _end;
  late final TextEditingController _rangeCtrl;

  late _ResolvedLabels _labels;

  @override
  void initState() {
    super.initState();
    _start = widget.originalStart;
    _end = widget.originalEnd;
    _rangeCtrl = TextEditingController();
    _labels = _resolveLabels();
    _syncText(updateState: false);
  }

  @override
  void dispose() {
    _rangeCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy  $hh:$mi';
  }

  void _syncText({bool updateState = true}) {
    _rangeCtrl.text = '${_fmt(_start)} - ${_fmt(_end)}';
    if (updateState && mounted) setState(() {});
  }

  void _shiftDays(int days) {
    setState(() {
      _start = _start.add(Duration(days: days));
      _end = _end.add(Duration(days: days));
      _syncText(updateState: false);
    });
  }

  Future<void> _pickRange() async {
    final startDate = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (startDate == null) return;

    final startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _start.hour, minute: _start.minute),
    );
    if (startTime == null) return;

    final newStart = DateTime(
      startDate.year, startDate.month, startDate.day,
      startTime.hour, startTime.minute,
    );

    final endDate = await showDatePicker(
      context: context,
      initialDate: _end.isAfter(newStart) ? _end : newStart,
      firstDate: newStart,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (endDate == null) return;

    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _end.hour, minute: _end.minute),
    );
    if (endTime == null) return;

    final newEnd = DateTime(
      endDate.year, endDate.month, endDate.day,
      endTime.hour, endTime.minute,
    );

    if (!newEnd.isAfter(newStart)) {
      if (mounted) {
        AppNotifications.error(context, 'End must be after start.');
      }
      return;
    }

    setState(() {
      _start = newStart;
      _end = newEnd;
      _syncText(updateState: false);
    });
  }

  _ResolvedLabels _resolveLabels() {
    String title = widget.title;
    String originalIdLabel = 'Original Request:';
    String originalPeriodLabel = 'Original Period:';
    String sectionTitle = 'New Request Period';
    String primaryCtaLabel = 'Create Request';

    switch (widget.mode) {
      case PeriodModalMode.repeat:
        title = (widget.title.isEmpty) ? 'Repeat Request' : widget.title;
        originalIdLabel = 'Original Request:';
        originalPeriodLabel = 'Original Period:';
        sectionTitle = 'New Request Period';
        primaryCtaLabel = 'Create Request';
        break;

      case PeriodModalMode.finishPeriod:
        title = (widget.title.isEmpty) ? 'Review Time' : widget.title;
        originalIdLabel = 'Request:';
        originalPeriodLabel = 'Current Period:';
        sectionTitle = 'Real Period';
        primaryCtaLabel = 'Save Period';
        break;

      case PeriodModalMode.extend:
        title = (widget.title.isEmpty) ? 'Extend Period' : widget.title;
        originalIdLabel = 'Request:';
        originalPeriodLabel = 'Current Period:';
        sectionTitle = 'New Period';
        primaryCtaLabel = 'Extend';
        break;

      case PeriodModalMode.reviewTime:
        title = (widget.title.isEmpty) ? 'Rev Time' : widget.title;
        originalIdLabel = 'Request:';
        originalPeriodLabel = 'Recorded Period:';
        sectionTitle = 'Adjust Real Period';
        primaryCtaLabel = 'Save';
        break;

      case PeriodModalMode.generic:
        break;
    }

    if ((widget.sectionTitleOverride ?? '').trim().isNotEmpty) {
      sectionTitle = widget.sectionTitleOverride!.trim();
    }
    if ((widget.originalIdLabelOverride ?? '').trim().isNotEmpty) {
      originalIdLabel = widget.originalIdLabelOverride!.trim();
    }
    if ((widget.originalPeriodLabelOverride ?? '').trim().isNotEmpty) {
      originalPeriodLabel = widget.originalPeriodLabelOverride!.trim();
    }
    if ((widget.primaryCtaLabelOverride ?? '').trim().isNotEmpty) {
      primaryCtaLabel = widget.primaryCtaLabelOverride!.trim();
    }

    if (widget.title.trim().isNotEmpty) {
      title = widget.title.trim();
    }

    return _ResolvedLabels(
      title: title,
      originalIdLabel: originalIdLabel,
      originalPeriodLabel: originalPeriodLabel,
      sectionTitle: sectionTitle,
      primaryCtaLabel: primaryCtaLabel,
    );
  }

  Widget _greyHeader(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF6B7280),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Text(
        text,
        style: FlutterFlowTheme.of(context).titleSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            elevation: 16,
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _labels.title,
                      style: theme.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (widget.showOriginalId) ...[
                      RichText(
                        text: TextSpan(
                          style: theme.bodyMedium
                              .copyWith(color: const Color(0xFF111827)),
                          children: [
                            TextSpan(
                              text: '${_labels.originalIdLabel} ',
                              style:
                              const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: '#${widget.originalId}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],

                    RichText(
                      text: TextSpan(
                        style: theme.bodyMedium
                            .copyWith(color: const Color(0xFF111827)),
                        children: [
                          TextSpan(
                            text: '${_labels.originalPeriodLabel} ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text:
                            '${_fmt(widget.originalStart)}  -  ${_fmt(widget.originalEnd)}',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _greyHeader(context, _labels.sectionTitle),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _shiftDays(1),
                                        child: const Text('+1 day'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _shiftDays(7),
                                        child: const Text('+1 week'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _shiftDays(30),
                                        child: const Text('+1 month'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _rangeCtrl,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText:
                                    'DD/MM/YYYY HH:mm - DD/MM/YYYY HH:mm',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Colors.black12,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color:
                                        theme.alternate.withOpacity(0.25),
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: 'Pick period',
                                      icon: const Icon(
                                        Icons.access_time_rounded,
                                      ),
                                      onPressed: _pickRange,
                                    ),
                                  ),
                                  onTap: _pickRange,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _pillButton(
                      label: _labels.primaryCtaLabel,
                      color: const Color(0xFF22C55E),
                      onPressed: () {
                        if (_end.isAfter(_start)) {
                          Navigator.of(context).pop<DateTimeRange>(
                            DateTimeRange(start: _start, end: _end),
                          );
                        } else {
                          AppNotifications.error(
                            context,
                            'End must be after start.',
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    _pillButton(
                      label: 'Close',
                      color: theme.primary,
                      onPressed: () =>
                          Navigator.of(context).pop<DateTimeRange?>(null),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      width: double.infinity,
      child: FFButtonWidget(
        onPressed: onPressed,
        text: label,
        options: FFButtonOptions(
          width: double.infinity,
          height: 50,
          padding: const EdgeInsets.all(8),
          color: color,
          textStyle: theme.titleSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          borderSide: const BorderSide(color: Colors.transparent),
          borderRadius: BorderRadius.circular(28),
          elevation: 6,
        ),
        showLoadingIndicator: false,
      ),
    );
  }
}

class _ResolvedLabels {
  final String title;
  final String originalIdLabel;
  final String originalPeriodLabel;
  final String sectionTitle;
  final String primaryCtaLabel;

  _ResolvedLabels({
    required this.title,
    required this.originalIdLabel,
    required this.originalPeriodLabel,
    required this.sectionTitle,
    required this.primaryCtaLabel,
  });
}


// ==================== _RequestDetailsDialog (UI nova) ====================
class _RequestDetailsDialog extends StatelessWidget {
  const _RequestDetailsDialog({
    required this.title,
    required this.id,
    required this.userName,
    required this.periodFrom,
    required this.driver,
    this.company,
    required this.model,
    required this.childSeat,
    required this.licensePlate,
    required this.hadIncident,
    required this.departure,
    required this.destinations,
    this.periodTo,
    this.notes,
    this.statusText,
    this.statusColor,
    this.realPeriodFrom,
    this.realPeriodTo,
    this.startKm,
    this.endKm,
    this.finalKmOk,
    this.periodConfirmedOk,
    this.disacordReason,
    this.cancelReason,
    this.costAllocs,
    this.flights,
    this.passengersCsv,
  });

  final String title;
  final String id;
  final String userName;
  final DateTime periodFrom;
  final DateTime? periodTo;
  final String driver;
  final String? company;
  final String model;
  final bool childSeat;
  final String licensePlate;
  final bool hadIncident;
  final String departure;
  final List<String> destinations;
  final String? notes;

  final String? statusText;
  final Color? statusColor;
  final DateTime? realPeriodFrom;
  final DateTime? realPeriodTo;
  final int? startKm;
  final int? endKm;
  final bool? finalKmOk;
  final bool? periodConfirmedOk;
  final String? disacordReason;
  final String? cancelReason;
  final List<Map<String, dynamic>>? costAllocs;
  final List<Map<String, dynamic>>? flights;
  final String? passengersCsv;


  String _fmt(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy  $hh:$mi';
  }

  String _fmtPeriod(DateTime from, DateTime? to) {
    final f = _fmt(from);
    if (to == null) return f;
    return '$f  -  ${_fmt(to)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final base = theme.bodyMedium.copyWith(
      color: const Color(0xFF111827),
      fontSize: 15,
      height: 1.25,
    );
    final bold = base.copyWith(fontWeight: FontWeight.w700);

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: RichText(
        text: TextSpan(style: base, children: [
          TextSpan(text: '$label: ', style: bold),
          TextSpan(text: value),
        ]),
      ),
    );

    Widget bullet(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const Text('•  '), Expanded(child: Text(text, style: base))],
      ),
    );

    Widget yesNo(String label, bool? ok) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: bold),
          Icon(
            (ok ?? false) ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: (ok ?? false) ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
        ],
      ),
    );

    final mq = MediaQuery.of(context);
    final double maxDialogWidth = 520;
    final double maxDialogHeight = (mq.size.height * 0.90).clamp(360.0, double.infinity);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxDialogWidth, maxHeight: maxDialogHeight),
          child: Material(
            color: Colors.white,
            elevation: 16,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          style: theme.headlineSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if ((statusText ?? '').isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor ?? const Color(0xFF6B7280),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusText!,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        const Divider(height: 20),


                        line('Request', '#$id'),

                        line('Requirer', (userName.split(' ').isNotEmpty ? userName.split(' ').first : userName)),

                        line('Period', _fmtPeriod(periodFrom, periodTo)),

                        line('Driver', driver),

                        if ((company ?? '').trim().isNotEmpty)
                          line('Company', company!.trim()),

                        line('Model', model),

                        line('License Plate', licensePlate),

                        if ((costAllocs?.isNotEmpty ?? false)) ...[
                          const SizedBox(height: 10),
                          Text('Cost Allocation', style: bold),
                          const SizedBox(height: 4),
                          ...costAllocs!.map((c) {
                            final user = (c['userName'] ?? '').toString();
                            final alloc = (c['costAllocName'] ?? '').toString();
                            final pct = (c['percent'] is num)
                                ? (c['percent'] as num).toStringAsFixed(1)
                                : (c['percent']?.toString() ?? '');
                            return bullet('$user - $alloc - $pct%');
                          }),
                        ],

                        if (realPeriodFrom != null || realPeriodTo != null || startKm != null || endKm != null) ...[
                          const SizedBox(height: 10),
                          Text('Finalized Data', style: bold),
                          const SizedBox(height: 4),
                          if (realPeriodFrom != null || realPeriodTo != null)
                            line('Real Period', _fmtPeriod(realPeriodFrom ?? periodFrom, realPeriodTo)),
                          if (startKm != null || endKm != null)
                            line('KM', '${(startKm ?? 0)} - ${(endKm ?? 0)}'),
                        ],
                        if (finalKmOk != null || periodConfirmedOk != null || (disacordReason?.trim().isNotEmpty ?? false)) ...[
                          const SizedBox(height: 10),
                          Text('Pending Checks', style: bold),
                          const SizedBox(height: 4),
                          if (finalKmOk != null) yesNo('Final KM', finalKmOk),
                          if (periodConfirmedOk != null) yesNo('Period Confirmed', periodConfirmedOk),
                          if ((disacordReason?.trim().isNotEmpty ?? false))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: line('Disagree reason', disacordReason!.trim()),
                            ),
                        ],
                        if ((cancelReason?.trim().isNotEmpty ?? false)) ...[
                          const SizedBox(height: 10),
                          Text('Cancel reason', style: bold),
                          const SizedBox(height: 4),
                          Text(cancelReason!.trim(), style: base),
                        ],

                        line('Departure', departure),

                        if (destinations.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Destinations', style: bold),
                          const SizedBox(height: 4),
                          ...destinations.map(bullet),
                        ],

                        if ((flights?.isNotEmpty ?? false)) ...[
                          const SizedBox(height: 10),
                          Text('Flight informations', style: bold),
                          const SizedBox(height: 4),
                          ...List.generate(flights!.length, (i) {
                            final f = flights![i];
                            final dest = (f['destination'] ?? '').toString();
                            final time = (f['time'] ?? '').toString();
                            final srcA = (f['sourceAirport'] ?? '').toString();
                            final dstA = (f['destinationAirport'] ?? '').toString();
                            final numF = (f['flightNumber'] ?? '').toString();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('- ${i + 1}° Flight information', style: base.copyWith(fontWeight: FontWeight.w700)),
                                  if (dest.isNotEmpty) bullet('Destination: $dest'),
                                  if (time.isNotEmpty) bullet('Time: $time'),
                                  if (srcA.isNotEmpty) bullet('Source Airport: $srcA'),
                                  if (dstA.isNotEmpty) bullet('Destination Airport: $dstA'),
                                  if (numF.isNotEmpty) bullet('Flight number: $numF'),
                                ],
                              ),
                            );
                          }),
                        ],

                        line('Child Seat', childSeat ? 'Yes' : 'No'),

                        if (notes != null && notes!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text('Note', style: bold),
                          const SizedBox(height: 4),
                          Text(notes!, style: base),
                        ],

                        if ((passengersCsv?.trim().isNotEmpty ?? false)) ...[
                          const SizedBox(height: 10),
                          line('Passengers', passengersCsv!.trim()),
                        ],
                      ],
                    ),
                  ),
                ),

                SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + mq.padding.bottom),
                    child: SizedBox(
                      width: double.infinity,
                      child: FFButtonWidget(
                        onPressed: () => Navigator.of(context).pop(),
                        text: 'Close',
                        options: FFButtonOptions(
                          width: double.infinity,
                          height: 50,
                          padding: const EdgeInsets.all(8),
                          color: theme.primary,
                          textStyle: theme.titleSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          borderSide: const BorderSide(color: Colors.transparent),
                          borderRadius: BorderRadius.circular(28),
                          elevation: 6,
                        ),
                        showLoadingIndicator: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CostAllocationDetailModal extends StatefulWidget {
  const _CostAllocationDetailModal({
    required this.title,
    this.initial,
  });

  final String title;
  final CostAllocationDetail? initial;

  @override
  State<_CostAllocationDetailModal> createState() =>
      _CostAllocationDetailModalState();
}

class _CostAllocationDetailModalState
    extends State<_CostAllocationDetailModal> {
  late final TextEditingController _codeCtrl =
  TextEditingController(text: widget.initial?.code ?? '');
  late final TextEditingController _percCtrl =
  TextEditingController(text: (widget.initial?.percent ?? 0).toString());

  late final String _origCode = _codeCtrl.text;
  late final String _origPerc = _percCtrl.text;

  final _codeFocus = FocusNode();
  final _percFocus = FocusNode();

  @override
  void dispose() {
    _codeCtrl.dispose();
    _percCtrl.dispose();
    _codeFocus.dispose();
    _percFocus.dispose();
    super.dispose();
  }

  double? _parsePercent(String v) {
    final txt = v.replaceAll(',', '.').trim();
    return double.tryParse(txt);
  }

  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.black12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide:
      BorderSide(color: FlutterFlowTheme.of(context).alternate),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final mq = MediaQuery.of(context);
    final size = mq.size;

    final double maxW = size.width >= 720 ? 560 : (size.width - 24);
    final double frameMaxH = size.height * 0.90;

    final double keyboard = mq.viewInsets.bottom;
    final double maxH = (frameMaxH - keyboard).clamp(240.0, frameMaxH);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          child: Material(
            elevation: 16,
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: theme.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeCtrl,
                      focusNode: _codeFocus,
                      decoration: _input('BU'),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _percFocus.requestFocus(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _percCtrl,
                      focusNode: _percFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                      decoration: _input('Percentage (%)'),
                    ),
                    const SizedBox(height: 20),

                    FFButtonWidget(
                      onPressed: () {
                        _codeCtrl.text = _origCode;
                        _percCtrl.text = _origPerc;
                        AppNotifications.info(context, 'Fields restored.');
                      },
                      text: 'Reset',
                      options: FFButtonOptions(
                        width: double.infinity,
                        height: 50,
                        padding: const EdgeInsets.all(8),
                        color: const Color(0xFFD4D4D4),
                        textStyle: theme.titleSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        borderSide:
                        const BorderSide(color: Colors.transparent),
                        borderRadius: BorderRadius.circular(28),
                        elevation: 6,
                      ),
                      showLoadingIndicator: false,
                    ),
                    const SizedBox(height: 10),
                    FFButtonWidget(
                      onPressed: () {
                        final code = _codeCtrl.text.trim();
                        final p = _parsePercent(_percCtrl.text);
                        if (code.isEmpty) {
                          AppNotifications.warning(context, 'Informe o BU.');
                          return;
                        }
                        if (p == null || p.isNaN) {
                          AppNotifications.error(
                              context, 'Percentual inválido.');
                          return;
                        }
                        Navigator.of(context).pop<CostAllocationDetail>(
                          CostAllocationDetail(code: code, percent: p),
                        );
                      },
                      text: 'Submit',
                      options: FFButtonOptions(
                        width: double.infinity,
                        height: 50,
                        padding: const EdgeInsets.all(8),
                        color: theme.primary,
                        textStyle: theme.titleSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        borderSide:
                        const BorderSide(color: Colors.transparent),
                        borderRadius: BorderRadius.circular(28),
                        elevation: 6,
                      ),
                      showLoadingIndicator: false,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context)
                            .pop<CostAllocationDetail?>(null),
                        child: const Text('Close'),
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RenameGroupScreen extends StatefulWidget {
  const _RenameGroupScreen({
    required this.title,
    required this.label,
    required this.initial,
  });

  final String title;
  final String label;
  final String initial;

  @override
  State<_RenameGroupScreen> createState() => _RenameGroupScreenState();
}

class _RenameGroupScreenState extends State<_RenameGroupScreen> {
  late final TextEditingController _ctrl =
  TextEditingController(text: widget.initial);
  late final String _original = widget.initial;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.black12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide:
      BorderSide(color: FlutterFlowTheme.of(context).alternate),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final safe = MediaQuery.of(context).viewPadding.bottom;
    final kb = MediaQuery.of(context).viewInsets.bottom;

    const buttonsBlockHeight = 200.0;
    final bottomContentPadding = buttonsBlockHeight + kb + safe;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Material(
            color: Colors.white,
            elevation: 16,
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, bottomContentPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: theme.headlineSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.label,
                        style: theme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _ctrl,
                        autofocus: true,
                        decoration: _input(widget.label),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20 + safe,
                  child: Column(
                    children: [
                      FFButtonWidget(
                        onPressed: () => setState(() => _ctrl.text = _original),
                        text: 'Reset',
                        options: FFButtonOptions(
                          width: double.infinity,
                          height: 50,
                          padding: const EdgeInsets.all(8),
                          color: const Color(0xFFD4D4D4),
                          textStyle: theme.titleSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          borderSide: const BorderSide(color: Colors.transparent),
                          borderRadius: BorderRadius.circular(28),
                          elevation: 6,
                        ),
                        showLoadingIndicator: false,
                      ),
                      const SizedBox(height: 10),
                      FFButtonWidget(
                        onPressed: () {
                          final v = _ctrl.text.trim();
                          if (v.isEmpty) {
                            AppNotifications.warning(
                              context,
                              'Please, inform the name.',
                            );
                            return;
                          }
                          Navigator.of(context).pop<String>(v);
                        },
                        text: 'Submit',
                        options: FFButtonOptions(
                          width: double.infinity,
                          height: 50,
                          padding: const EdgeInsets.all(8),
                          color: FlutterFlowTheme.of(context).primary,
                          textStyle: theme.titleSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          borderSide: const BorderSide(color: Colors.transparent),
                          borderRadius: BorderRadius.circular(28),
                          elevation: 6,
                        ),
                        showLoadingIndicator: false,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop<String?>(null),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoritePlaceModalScreen extends StatefulWidget {
  const _FavoritePlaceModalScreen({
    required this.title,
    this.initial,
  });

  final String title;
  final FavoritePlace? initial;

  @override
  State<_FavoritePlaceModalScreen> createState() => _FavoritePlaceModalScreenState();
}

class _FavoritePlaceModalScreenState extends State<_FavoritePlaceModalScreen> {
  late final TextEditingController _nameCtrl =
  TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _addrCtrl =
  TextEditingController(text: widget.initial?.address ?? '');

  late final String _origName = _nameCtrl.text;
  late final String _origAddr = _addrCtrl.text;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  InputDecoration _input(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: FlutterFlowTheme.of(context).alternate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final mq = MediaQuery.of(context);
    final double maxW = mq.size.width >= 720 ? 560 : (mq.size.width - 24);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Colors.transparent,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Material(
              elevation: 16,
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.title,
                        style: theme.headlineSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameCtrl,
                        decoration: _input(context, 'Place'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addrCtrl,
                        decoration: _input(context, 'Address'),
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 16),
                      FFButtonWidget(
                        onPressed: () {
                          _nameCtrl.text = _origName;
                          _addrCtrl.text = _origAddr;
                          AppNotifications.info(context, 'Fields restored.');
                        },
                        text: 'Reset',
                        options: FFButtonOptions(
                          width: double.infinity,
                          height: 50,
                          padding: const EdgeInsets.all(8),
                          color: const Color(0xFFD4D4D4),
                          textStyle: theme.titleSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          borderSide: const BorderSide(color: Colors.transparent),
                          borderRadius: BorderRadius.circular(28),
                          elevation: 6,
                        ),
                        showLoadingIndicator: false,
                      ),
                      const SizedBox(height: 10),
                      FFButtonWidget(
                        onPressed: () {
                          final name = _nameCtrl.text.trim();
                          final addr = _addrCtrl.text.trim();
                          if (name.isEmpty || addr.isEmpty) {
                            AppNotifications.warning(context, 'Fill name and address.');
                            return;
                          }
                          Navigator.of(context).pop<FavoritePlace>(
                            FavoritePlace(name: name, address: addr),
                          );
                        },
                        text: 'Submit',
                        options: FFButtonOptions(
                          width: double.infinity,
                          height: 50,
                          padding: const EdgeInsets.all(8),
                          color: theme.primary,
                          textStyle: theme.titleSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          borderSide: const BorderSide(color: Colors.transparent),
                          borderRadius: BorderRadius.circular(28),
                          elevation: 6,
                        ),
                        showLoadingIndicator: false,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop<FavoritePlace?>(null),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlightInfoModal extends StatefulWidget {
  const _FlightInfoModal({
    required this.isDeparture,
    required this.selectedPlace,
    this.initial,
  });

  final bool isDeparture;
  final String selectedPlace;
  final FlightInfo? initial;

  @override
  State<_FlightInfoModal> createState() => _FlightInfoModalState();
}

class _FlightInfoModalState extends State<_FlightInfoModal> {
  late final TextEditingController _placeCtrl;
  late final TextEditingController _srcCtrl;
  late final TextEditingController _dstCtrl;
  late final TextEditingController _numCtrl;
  late final TextEditingController _timeCtrl;

  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    _placeCtrl = TextEditingController(text: widget.selectedPlace);
    _srcCtrl = TextEditingController(text: widget.initial?.sourceAirport ?? '');
    _dstCtrl = TextEditingController(text: widget.initial?.destinationAirport ?? '');
    _numCtrl = TextEditingController(text: widget.initial?.flightNumber ?? '');
    _time = widget.initial?.time;
    _timeCtrl = TextEditingController(text: _fmtTime(_time));
  }

  @override
  void dispose() {
    _placeCtrl.dispose();
    _srcCtrl.dispose();
    _dstCtrl.dispose();
    _numCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay? t) =>
      t == null ? '--:--' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx!).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _time = picked;
        _timeCtrl.text = _fmtTime(_time);
      });
    }
  }

  InputDecoration _input(BuildContext ctx, String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: FlutterFlowTheme.of(ctx).alternate),
      ),
      suffixIcon: suffix,
    );
  }

  Widget _flightCard({required String header, required Widget child}) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF6B7280),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Text(
              header,
              style: theme.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final mq = MediaQuery.of(context);

    final double maxW = mq.size.width >= 980 ? 920 : (mq.size.width - 24);
    final double maxH = mq.size.height * 0.70;
    final double keyboardSpace = mq.viewInsets.bottom;

    final leftCard = _flightCard(
      header: widget.isDeparture ? 'Departure' : 'Destination',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _placeCtrl,
            readOnly: true,
            scrollPadding: EdgeInsets.only(bottom: keyboardSpace + 80),
            decoration: _input(context, widget.isDeparture ? 'Departure airport' : 'Destination airport'),
          ),
          const SizedBox(height: 8),
          TextField(
            readOnly: true,
            controller: _timeCtrl,
            scrollPadding: EdgeInsets.only(bottom: keyboardSpace + 80),
            decoration: _input(
              context,
              'Time',
              suffix: IconButton(
                tooltip: 'Pick time',
                icon: const Icon(Icons.access_time_rounded),
                onPressed: _pickTime,
              ),
            ),
            onTap: _pickTime,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _srcCtrl,
            scrollPadding: EdgeInsets.only(bottom: keyboardSpace + 80),
            decoration: _input(context, 'Source airport'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _dstCtrl,
            scrollPadding: EdgeInsets.only(bottom: keyboardSpace + 80),
            decoration: _input(context, 'Destination airport'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _numCtrl,
            scrollPadding: EdgeInsets.only(bottom: keyboardSpace + 80),
            decoration: _input(context, 'Flight number'),
          ),
        ],
      ),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Material(
            elevation: 16,
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.only(bottom: 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Flight Information',
                              style: theme.headlineSmall.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111111),
                              ),
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (ctx, c) {
                                final isWide = c.maxWidth >= 820;
                                return isWide
                                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: leftCard)])
                                    : leftCard;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + mq.padding.bottom),
                        child: Column(
                          children: [
                            FFButtonWidget(
                              onPressed: () {
                                Navigator.of(context).pop<FlightInfo>(
                                  FlightInfo(
                                    isDeparture: widget.isDeparture,
                                    airport: _placeCtrl.text.trim(),
                                    time: _time,
                                    sourceAirport: _srcCtrl.text.trim(),
                                    destinationAirport: _dstCtrl.text.trim(),
                                    flightNumber: _numCtrl.text.trim(),
                                  ),
                                );
                              },
                              text: 'Save',
                              options: FFButtonOptions(
                                width: double.infinity,
                                height: 50,
                                padding: const EdgeInsets.all(8),
                                color: theme.primary,
                                textStyle: theme.titleSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                borderSide: const BorderSide(color: Colors.transparent),
                                borderRadius: BorderRadius.circular(28),
                                elevation: 6,
                              ),
                              showLoadingIndicator: false,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop<FlightInfo?>(null),
                              child: const Text('Close'),
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
      ),
    );
  }
}

class _ChangeDriverDialog extends StatefulWidget {
  final List<DriverChangeOption> drivers;
  final int? currentDriverId;

  const _ChangeDriverDialog({
    required this.drivers,
    this.currentDriverId,
  });

  @override
  State<_ChangeDriverDialog> createState() => _ChangeDriverDialogState();
}

class _ChangeDriverDialogState extends State<_ChangeDriverDialog> {
  late int? _selected;

  @override
  void initState() {
    super.initState();
    final current = widget.currentDriverId;
    if (current != null && widget.drivers.any((d) => d.id == current)) {
      _selected = current;
    } else {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.white,
            elevation: 16,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Change Driver',
                    style: theme.headlineSmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select the driver who will take over this request.',
                    style: theme.bodyMedium.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    value: _selected,
                    items: widget.drivers
                        .map(
                          (d) => DropdownMenuItem<int>(
                            value: d.id,
                            child: Text(d.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selected = value),
                    decoration: InputDecoration(
                      labelText: 'Driver',
                      labelStyle: theme.labelLarge.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: () =>
                              Navigator.of(context).pop<int?>(null),
                          text: 'Cancel',
                          options: FFButtonOptions(
                            height: 46,
                            color: theme.secondary,
                            textStyle: theme.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          showLoadingIndicator: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: (_selected == null)
                              ? null
                              : () =>
                                  Navigator.of(context).pop<int>(_selected!),
                          text: 'Change',
                          options: FFButtonOptions(
                            height: 46,
                            color: theme.primary,
                            textStyle: theme.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            disabledColor: const Color(0xFF9CA3AF),
                          ),
                          showLoadingIndicator: false,
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

class _DriverStartKmDialog extends StatefulWidget {
  final int fixedKm;
  const _DriverStartKmDialog({required this.fixedKm});

  @override
  State<_DriverStartKmDialog> createState() => _DriverStartKmDialogState();
}

class _DriverStartKmDialogState extends State<_DriverStartKmDialog> {
  late int _value;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _value = widget.fixedKm;
    _ctrl.text = '$_value';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _inc() {
    setState(() {
      _value += 1;
      _ctrl.text = '$_value';
    });
  }

  void _dec() {
    if (_value <= widget.fixedKm) return;
    setState(() {
      _value -= 1;
      _ctrl.text = '$_value';
    });
  }

  void _applyText(String t) {
    final v = int.tryParse(t);
    final min = widget.fixedKm;
    final newVal = (v == null) ? min : (v < min ? min : v);
    if (newVal != _value) {
      setState(() => _value = newVal);
    }
    if (_ctrl.text != '$newVal') {
      _ctrl.text = '$newVal';
      _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final canDecrement = _value > widget.fixedKm;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.white,
            elevation: 16,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Start Request', style: theme.headlineSmall.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6B7280),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Text('KM', style: theme.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            enableInteractiveSelection: false,
                            onChanged: _applyText,
                            onSubmitted: _applyText,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'KM',
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_drop_up, size: 22),
                                onPressed: _inc,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 36, height: 28),
                                splashRadius: 18,
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_drop_down, size: 22),
                                onPressed: canDecrement ? _dec : null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 36, height: 28),
                                splashRadius: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: () => Navigator.pop<int?>(context, null),
                          text: 'Close',
                          options: FFButtonOptions(
                            height: 46,
                            color: theme.primary,
                            textStyle: theme.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: () => Navigator.pop<int>(context, _value),
                          text: 'Save',
                          options: FFButtonOptions(
                            height: 46,
                            color: const Color(0xFF22C55E),
                            textStyle: theme.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                            borderRadius: BorderRadius.circular(24),
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

class _DriverExtendDialog extends StatefulWidget {
  const _DriverExtendDialog({required this.initialEnd});
  final DateTime initialEnd;

  @override
  State<_DriverExtendDialog> createState() => _DriverExtendDialogState();
}
class _DriverExtendDialogState extends State<_DriverExtendDialog> {
  late DateTime _end = widget.initialEnd;
  final _ctrl = TextEditingController();
  @override
  void initState() { super.initState(); _sync(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _sync() {
    _ctrl.text =
    '${_end.day.toString().padLeft(2, '0')}/${_end.month.toString().padLeft(2, '0')}/${_end.year.toString()} '
        '${_end.hour.toString().padLeft(2, '0')}:${_end.minute.toString().padLeft(2, '0')}';
    setState(() {});
  }

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_end),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c!).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t == null) return;
    _end = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.white, elevation: 16, borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Extend Period', style: theme.headlineSmall.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: const BoxDecoration(color: Color(0xFF6B7280),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Text('End Time', style: theme.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                TextField(
                  controller: _ctrl, readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'DD/MM/YYYY HH:mm', isDense: true, filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
                    suffixIcon: IconButton(icon: const Icon(Icons.access_time_rounded), onPressed: _pick),
                  ),
                  onTap: _pick,
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: FFButtonWidget(
                    onPressed: () => Navigator.pop<DateTime?>(context, null),
                    text: 'Cancel',
                    options: FFButtonOptions(height: 46, color: const Color(0xFFD4D4D4),
                      textStyle: theme.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: FFButtonWidget(
                    onPressed: () => Navigator.pop<DateTime>(context, _end),
                    text: 'Extend',
                    options: FFButtonOptions(height: 46, color: const Color(0xFFF59E0B),
                      textStyle: theme.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  )),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverFinishDialog extends StatefulWidget {
  const _DriverFinishDialog({
    required this.initialFrom,
    required this.initialTo,
    this.onOpenIncident,
    this.existingIncident = false,
  });

  final DateTime initialFrom;
  final DateTime initialTo;
  final VoidCallback? onOpenIncident;
  final bool existingIncident;

  @override
  State<_DriverFinishDialog> createState() => _DriverFinishDialogState();
}

class _DriverFinishDialogState extends State<_DriverFinishDialog> {
  late DateTime _start = widget.initialFrom;
  late DateTime _end   = widget.initialTo;

  late bool _incident = widget.existingIncident;
  late final bool _incidentLocked = widget.existingIncident;

  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _sync() {
    _ctrl.text = '${_fmt(_start)} - ${_fmt(_end)}';
    setState(() {});
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (c, ch) => MediaQuery(
        data: MediaQuery.of(c!).copyWith(alwaysUse24HourFormat: true),
        child: ch!,
      ),
    );
  }

  Future<DateTime?> _pickDate(DateTime initial) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select date',
    );
    return picked;
  }

  Future<void> _pick() async {
    final startDate = await _pickDate(_start);
    if (startDate == null) return;

    final startTime = await _pickTime(TimeOfDay.fromDateTime(_start));
    if (startTime == null) return;

    final newStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    );

    final endDate = await _pickDate(_end);
    if (endDate == null) return;

    final endTime = await _pickTime(TimeOfDay.fromDateTime(_end));
    if (endTime == null) return;

    final newEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      endTime.hour,
      endTime.minute,
    );

    if (!newEnd.isAfter(newStart)) {
      AppNotifications.error(context, 'End time must be after start time.');
      return;
    }

    _start = newStart;
    _end   = newEnd;
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: Colors.white,
            elevation: 16,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Finish', style: theme.headlineSmall.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6B7280),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Text(
                      'Date and Time Range',
                      style: theme.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 6),

                  TextField(
                    controller: _ctrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'DD/MM/YYYY HH:mm - DD/MM/YYYY HH:mm',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.event),
                        onPressed: _pick,
                      ),
                    ),
                    onTap: _pick,
                  ),

                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6B7280),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Text(
                      'Traffic Incident',
                      style: theme.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Yes'),
                        selected: _incident,
                        onSelected: _incidentLocked ? null : (_) => setState(() => _incident = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('No'),
                        selected: !_incident,
                        onSelected: _incidentLocked ? null : (_) => setState(() => _incident = false),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (_incident && _incidentLocked) ...[
                    Text(
                      'There is already exist an incident registered.',
                      style: theme.titleSmall.copyWith(
                        color: const Color(0xFFF59E0B),
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else if (_incident) ...[
                    FFButtonWidget(
                      onPressed: () => widget.onOpenIncident?.call(),
                      text: 'Register Incident',
                      options: FFButtonOptions(
                        height: 40,
                        color: const Color(0xFFF59E0B),
                        textStyle: theme.titleSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: () => Navigator.pop<FinishResult?>(context, null),
                          text: 'Close',
                          options: FFButtonOptions(
                            height: 46,
                            color: const Color(0xFFD4D4D4),
                            textStyle: theme.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: () {
                            if (!_end.isAfter(_start)) {
                              AppNotifications.error(context, 'End must be after start.');
                              return;
                            }
                            final hadIncident = _incidentLocked ? true : _incident;
                            Navigator.pop<FinishResult>(
                              context,
                              FinishResult(start: _start, end: _end, hadIncident: hadIncident),
                            );
                          },
                          text: 'Save',
                          options: FFButtonOptions(
                            height: 46,
                            color: const Color(0xFF22C55E),
                            textStyle: theme.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            borderRadius: BorderRadius.circular(24),
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

class KmThousandsFormatter extends TextInputFormatter {
  KmThousandsFormatter({this.locale = 'pt_BR'});
  final String locale;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }

    final n = int.parse(digits);
    final f = NumberFormat.decimalPattern(locale);
    final formatted = f.format(n);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _DriverFinalKmDialog extends StatefulWidget {
  final int initialKm;
  final int? minKm;

  const _DriverFinalKmDialog({
    required this.initialKm,
    this.minKm,
  });

  @override
  State<_DriverFinalKmDialog> createState() => _DriverFinalKmDialogState();
}

class _DriverFinalKmDialogState extends State<_DriverFinalKmDialog> {
  int? _value;
  final _ctrl = TextEditingController();

  int get _min => widget.minKm ?? widget.initialKm;

  @override
  void initState() {
    super.initState();
    _value = widget.initialKm;
    _ctrl.text = '${widget.initialKm}';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _inc() {
    setState(() {
      final base = _value ?? _min;
      _value = base + 1;
      _ctrl.text = '$_value';
      _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length),
      );
    });
  }

  void _dec() {
    final current = _value ?? _min;
    if (current <= _min) return;
    setState(() {
      _value = current - 1;
      _ctrl.text = '$_value';
      _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length),
      );
    });
  }

  void _applyText(String t) {
    if (t.isEmpty) {
      if (_value != null) setState(() => _value = null);
      return;
    }
    final v = int.tryParse(t);
    if (v != _value) setState(() => _value = v);
  }

  void _onSave(BuildContext context) {
    final typed = int.tryParse(_ctrl.text);
    final toSave = (typed == null || typed < _min) ? _min : typed;
    Navigator.pop<int>(context, toSave);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final canDecrement = (_value ?? _min) > _min;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.white,
            elevation: 16,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Final KM',
                    style: theme.headlineSmall.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6B7280),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Text(
                      'KM',
                      style: theme.titleSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: false,
                              decimal: false,
                            ),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            enableInteractiveSelection: true,
                            onChanged: _applyText,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Enter the final odometer (km)...',
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_drop_up, size: 22),
                                onPressed: _inc,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 36, height: 28),
                                splashRadius: 18,
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_drop_down, size: 22),
                                onPressed: canDecrement ? _dec : null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 36, height: 28),
                                splashRadius: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: () => Navigator.pop<int?>(context, null),
                          text: 'Close',
                          options: FFButtonOptions(
                            height: 46,
                            color: theme.primary,
                            textStyle: theme.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: () => _onSave(context),
                          text: 'Save',
                          options: FFButtonOptions(
                            height: 46,
                            color: const Color(0xFF22C55E),
                            textStyle: theme.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            borderRadius: BorderRadius.circular(24),
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

enum _ConfirmChoice { confirm, disagree }

class _ConfirmPeriodDialog extends StatelessWidget {
  const _ConfirmPeriodDialog({
    required this.title,
    required this.requestId,
    required this.userName,
    required this.driver,
    required this.departure,
    required this.destinations,
    required this.periodFrom,
    required this.periodTo,
  });

  final String title;
  final String requestId;
  final String userName;
  final String driver;
  final String departure;
  final List<String> destinations;
  final DateTime periodFrom;
  final DateTime periodTo;

  String _fmt(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final base = theme.bodyMedium.copyWith(
      color: const Color(0xFF111827),
      fontSize: 15,
      height: 1.25,
    );
    final bold = base.copyWith(fontWeight: FontWeight.w700);

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: RichText(
        text: TextSpan(style: base, children: [
          TextSpan(text: '$label: ', style: bold),
          TextSpan(text: value),
        ]),
      ),
    );

    final mq = MediaQuery.of(context);
    final double maxDialogWidth =
    mq.size.width >= 480 ? 420 : (mq.size.width - 24);
    final double maxDialogHeight =
    (mq.size.height * 0.90).clamp(360.0, double.infinity);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxDialogWidth,
            maxHeight: maxDialogHeight,
          ),
          child: Material(
            color: Colors.white,
            elevation: 16,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: theme.headlineSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 20),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                            border:
                            Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text('Car Request $requestId', style: bold),
                        ),
                        const SizedBox(height: 12),

                        Text('Hello $userName,', style: base),
                        const SizedBox(height: 8),
                        Text(
                          'The driver $driver just finished car request #$requestId.',
                          style: base,
                        ),
                        const SizedBox(height: 12),

                        line('Departure', departure),

                        if (destinations.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('Destination(s):', style: bold),
                          const SizedBox(height: 4),
                          ...destinations.map(
                                (d) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('•  '),
                                  Expanded(child: Text(d, style: base)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        line('Period', '${_fmt(periodFrom)}~${_fmt(periodTo)}'),
                        const SizedBox(height: 12),

                        Text('Could you confirm this period?', style: base),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        20, 8, 20, 20 + mq.padding.bottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FFButtonWidget(
                          onPressed: () => Navigator.of(context)
                              .pop<_ConfirmChoice>(_ConfirmChoice.confirm),
                          text: 'Confirm',
                          options: FFButtonOptions(
                            height: 50,
                            color: const Color(0xFF22C55E),
                            textStyle: theme.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            borderSide:
                            const BorderSide(color: Colors.transparent),
                            borderRadius: BorderRadius.circular(28),
                            elevation: 6,
                          ),
                          showLoadingIndicator: false,
                        ),
                        const SizedBox(height: 10),
                        FFButtonWidget(
                          onPressed: () => Navigator.of(context)
                              .pop<_ConfirmChoice>(_ConfirmChoice.disagree),
                          text: 'Disagree',
                          options: FFButtonOptions(
                            height: 50,
                            color: const Color(0xFFE34A48),
                            textStyle: theme.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            borderSide:
                            const BorderSide(color: Colors.transparent),
                            borderRadius: BorderRadius.circular(28),
                            elevation: 6,
                          ),
                          showLoadingIndicator: false,
                        ),
                        const SizedBox(height: 10),
                        FFButtonWidget(
                          onPressed: () =>
                              Navigator.of(context).pop<_ConfirmChoice?>(null),
                          text: 'Close',
                          options: FFButtonOptions(
                            height: 50,
                            color: const Color(0xFFD4D4D4),
                            textStyle: theme.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            borderSide:
                            const BorderSide(color: Colors.transparent),
                            borderRadius: BorderRadius.circular(28),
                            elevation: 6,
                          ),
                          showLoadingIndicator: false,
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
    );
  }
}
class _ChangeDriverDialog extends StatefulWidget {
  final List<DriverChangeOption> drivers;
  final int? currentDriverId;

  const _ChangeDriverDialog({
    required this.drivers,
    this.currentDriverId,
  });

  @override
  State<_ChangeDriverDialog> createState() => _ChangeDriverDialogState();
}

class _ChangeDriverDialogState extends State<_ChangeDriverDialog> {
  late int? _selected;

  @override
  void initState() {
    super.initState();
    final current = widget.currentDriverId;
    if (current != null && widget.drivers.any((d) => d.id == current)) {
      _selected = current;
    } else {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.white,
            elevation: 16,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Change Driver',
                    style: theme.headlineSmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select the driver who will take over this request.',
                    style: theme.bodyMedium.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    value: _selected,
                    items: widget.drivers
                        .map(
                          (d) => DropdownMenuItem<int>(
                        value: d.id,
                        child: Text(d.name),
                      ),
                    )
                        .toList(),
                    onChanged: (value) => setState(() => _selected = value),
                    decoration: InputDecoration(
                      labelText: 'Driver',
                      labelStyle: theme.labelLarge.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: () =>
                              Navigator.of(context).pop<int?>(null),
                          text: 'Cancel',
                          options: FFButtonOptions(
                            height: 46,
                            color: theme.secondary,
                            textStyle: theme.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          showLoadingIndicator: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: (_selected == null)
                              ? null
                              : () =>
                              Navigator.of(context).pop<int>(_selected!),
                          text: 'Change',
                          options: FFButtonOptions(
                            height: 46,
                            color: theme.primary,
                            textStyle: theme.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            disabledColor: const Color(0xFF9CA3AF),
                          ),
                          showLoadingIndicator: false,
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
class _DisagreeReasonDialog extends StatefulWidget {
  const _DisagreeReasonDialog();
  @override
  State<_DisagreeReasonDialog> createState() => _DisagreeReasonDialogState();
}

class _DisagreeReasonDialogState extends State<_DisagreeReasonDialog> {
  final _ctrl = TextEditingController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final mq = MediaQuery.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: Colors.white,
            elevation: 16,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + mq.padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Disagree reason (optional)',
                      style: theme.headlineSmall
                          .copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ctrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Describe the reason (optional)...',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: () =>
                              Navigator.pop<String?>(context, null),
                          text: 'Skip',
                          options: FFButtonOptions(
                            height: 46,
                            color: const Color(0xFFD4D4D4),
                            textStyle: theme.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            borderSide:
                            const BorderSide(color: Colors.transparent),
                            borderRadius: BorderRadius.circular(24),
                            elevation: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: () => Navigator.pop<String>(
                              context, _ctrl.text.trim()),
                          text: 'Submit',
                          options: FFButtonOptions(
                            height: 46,
                            color: theme.primary,
                            textStyle: theme.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            borderSide:
                            const BorderSide(color: Colors.transparent),
                            borderRadius: BorderRadius.circular(24),
                            elevation: 6,
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

class _IncidentDetailsDialog extends StatelessWidget {
  const _IncidentDetailsDialog({
    required this.title,
    required this.incidentId,
    required this.carRequestId,
    this.driverName,
    this.creationAt,
    this.incidentAt,
    required this.hasInjuries,
    this.injuriesDetails,
    this.incidentLocation,
    this.incidentSummary,
    this.damagePlate,
    this.damageSummary,
    required this.passengers,
    required this.otherPassengers,
    required this.images,
  });

  final String title;
  final int incidentId;
  final int carRequestId;
  final String? driverName;
  final DateTime? creationAt;
  final DateTime? incidentAt;
  final bool hasInjuries;
  final String? injuriesDetails;
  final String? incidentLocation;
  final String? incidentSummary;
  final String? damagePlate;
  final String? damageSummary;
  final List<String> passengers;
  final List<String> otherPassengers;
  final List<IncidentImage> images;

  static void _showFullImage(BuildContext parent, IncidentImage img) {
    showDialog(
      context: parent,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.memory(
                img.bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Colors.black12,
                  child: Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(parent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy  $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final base = theme.bodyMedium.copyWith(
      color: const Color(0xFF111827),
      fontSize: 15,
      height: 1.25,
    );
    final bold = base.copyWith(fontWeight: FontWeight.w700);

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: RichText(
        text: TextSpan(style: base, children: [
          TextSpan(text: '$label: ', style: bold),
          TextSpan(text: value),
        ]),
      ),
    );

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(text, style: bold),
    );

    Widget bullet(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const Text('•  '), Expanded(child: Text(text, style: base))],
      ),
    );

    final mq = MediaQuery.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: Colors.white,
            elevation: 16,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title, style: theme.headlineSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111111),
                        )),
                        const Divider(height: 20),

                        line('Nr', '#$incidentId'),
                        line('Car Request Id', '#$carRequestId'),
                        line('Creation date', _fmt(creationAt)),
                        line('Injuries', hasInjuries ? 'Yes' : 'No'),
                        if ((injuriesDetails ?? '').trim().isNotEmpty)
                          line('Details of injuries', injuriesDetails!.trim()),

                        sectionTitle('People involved'),
                        if ((driverName ?? '').trim().isNotEmpty)
                          line('Driver\'s name', (driverName ?? '').trim()),

                        Text('Passenger(s):', style: bold),
                        const SizedBox(height: 4),
                        if (passengers.isNotEmpty)
                          ...passengers.map(bullet)
                        else
                          Row(children: const [
                            Icon(Icons.info_outline, size: 16, color: Colors.black54),
                            SizedBox(width: 6),
                            Text('No registered users'),
                          ]),

                        const SizedBox(height: 8),
                        Text('Others Passenger(s):', style: bold),
                        const SizedBox(height: 4),
                        if (otherPassengers.isNotEmpty)
                          ...otherPassengers.map(bullet)
                        else
                          Row(children: const [
                            Icon(Icons.info_outline, size: 16, color: Colors.black54),
                            SizedBox(width: 6),
                            Text('No additional passengers'),
                          ]),

                        sectionTitle('Incident'),
                        line('Incident date', _fmt(incidentAt)),
                        if ((incidentLocation ?? '').trim().isNotEmpty)
                          line('Incident place', incidentLocation!.trim()),
                        if ((incidentSummary ?? '').trim().isNotEmpty)
                          line('Incident summary', incidentSummary!.trim()),

                        sectionTitle('Car damage'),
                        if ((damagePlate ?? '').trim().isNotEmpty)
                          line('Damage car plate', damagePlate!.trim()),
                        if ((damageSummary ?? '').trim().isNotEmpty)
                          line('Damage car summary', damageSummary!.trim()),

                        sectionTitle('Incident Images:'),
                        if (images.isNotEmpty)
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: images.length,
                            itemBuilder: (_, i) {
                              final img = images[i];
                              return InkWell(
                                onTap: () => _showFullImage(context, img),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          img.bytes,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const ColoredBox(
                                            color: Colors.black12,
                                            child: Center(child: Icon(Icons.broken_image)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      img.fileName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: base.copyWith(fontSize: 12, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        else
                          const Text('No Images'),
                      ],
                    ),
                  ),
                ),

                SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + mq.padding.bottom),
                    child: SizedBox(
                      width: double.infinity,
                      child: FFButtonWidget(
                        onPressed: () => Navigator.of(context).pop(),
                        text: 'Close',
                        options: FFButtonOptions(
                          width: double.infinity,
                          height: 50,
                          padding: const EdgeInsets.all(8),
                          color: theme.primary,
                          textStyle: theme.titleSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          borderSide: const BorderSide(color: Colors.transparent),
                          borderRadius: BorderRadius.circular(28),
                          elevation: 6,
                        ),
                        showLoadingIndicator: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

