import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/api_requests/api_calls.dart' as api;
import '/backend/api_requests/api_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/menu/app_drawer.dart';
import '/widgets/notifications/app_notifications.dart';

const bool kDisableLoadingOverlays = false;

int? _tryParseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String _stringOrEmpty(dynamic value) => value?.toString() ?? '';

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty) return false;
    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'y' ||
        text == 'sim';
  }
  return false;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  if (value is num) {
    final milliseconds = value.toInt();
    if (milliseconds > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true)
          .toLocal();
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds * 1000,
        isUtc: true)
        .toLocal();
  }
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final unixMatch = RegExp(r"/Date\((\d+)\)/").firstMatch(text);
    if (unixMatch != null) {
      final unix = int.tryParse(unixMatch.group(1)!);
      if (unix != null) {
        return DateTime.fromMillisecondsSinceEpoch(unix, isUtc: true)
            .toLocal();
      }
    }
    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }
  }
  return null;
}

DateTime? _normalizeDateTime(DateTime? value) {
  if (value == null) return null;
  if (value.year <= 1) return null;
  return value;
}

String _formatDate(DateTime d) {
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  final year = d.year.toString().padLeft(4, '0');
  final hour = d.hour.toString().padLeft(2, '0');
  final minute = d.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

String _formatRange(DateTime? start, DateTime? end) {
  final normalizedStart = _normalizeDateTime(start);
  final normalizedEnd = _normalizeDateTime(end);
  if (normalizedStart == null) {
    return '';
  }

  final startStr = _formatDate(normalizedStart);
  if (normalizedEnd == null) {
    return startStr;
  }

  final endStr = _formatDate(normalizedEnd);
  return '$startStr - $endStr';
}

enum RescheduleStatus { pending, approved, rejected, expired, unknown }

extension RescheduleStatusDisplay on RescheduleStatus {
  String get label {
    switch (this) {
      case RescheduleStatus.pending:
        return 'Pending';
      case RescheduleStatus.approved:
        return 'Approved';
      case RescheduleStatus.rejected:
        return 'Rejected';
      case RescheduleStatus.expired:
        return 'Expired';
      case RescheduleStatus.unknown:
      default:
        return 'Unknown';
    }
  }

  String get apiValue {
    switch (this) {
      case RescheduleStatus.pending:
        return 'Pending';
      case RescheduleStatus.approved:
        return 'Approved';
      case RescheduleStatus.rejected:
        return 'Rejected';
      case RescheduleStatus.expired:
        return 'Expired';
      case RescheduleStatus.unknown:
      default:
        return 'Unknown';
    }
  }

  bool get isPending => this == RescheduleStatus.pending;

  Color backgroundColor(FlutterFlowTheme theme) {
    switch (this) {
      case RescheduleStatus.pending:
        return theme.warning;
      case RescheduleStatus.approved:
        return theme.success;
      case RescheduleStatus.rejected:
        return theme.error;
      case RescheduleStatus.expired:
        return theme.secondaryText;
      case RescheduleStatus.unknown:
      default:
        return theme.secondary;
    }
  }

  Color foregroundColor(FlutterFlowTheme theme) {
    switch (this) {
      case RescheduleStatus.pending:
        return Colors.black87;
      case RescheduleStatus.approved:
      case RescheduleStatus.rejected:
        return Colors.white;
      case RescheduleStatus.expired:
        return theme.primaryText;
      case RescheduleStatus.unknown:
      default:
        return Colors.white;
    }
  }
}

RescheduleStatus _parseStatus(dynamic value) {
  if (value is RescheduleStatus) return value;
  if (value is num) {
    switch (value.toInt()) {
      case 0:
        return RescheduleStatus.pending;
      case 1:
        return RescheduleStatus.approved;
      case 2:
        return RescheduleStatus.rejected;
      case 3:
        return RescheduleStatus.expired;
    }
  }
  final text = _stringOrEmpty(value).toLowerCase();
  switch (text) {
    case 'pending':
      return RescheduleStatus.pending;
    case 'approved':
      return RescheduleStatus.approved;
    case 'rejected':
      return RescheduleStatus.rejected;
    case 'expired':
      return RescheduleStatus.expired;
  }
  return RescheduleStatus.unknown;
}

class RentalRescheduleRequestVm {
  RentalRescheduleRequestVm({
    required this.id,
    required this.carRequestId,
    required this.requestNumber,
    required this.driverName,
    required this.sourceAddress,
    required this.destinations,
    required this.currentPeriod,
    required this.newPeriod,
    required this.newStart,
    required this.driverAvailable,
    required this.status,
    required this.creationDate,
  });

  final int id;
  final int? carRequestId;
  final String requestNumber;
  final String driverName;
  final String sourceAddress;
  final List<String> destinations;
  final String currentPeriod;
  final String newPeriod;
  final DateTime? newStart;
  final bool driverAvailable;
  final RescheduleStatus status;
  final DateTime? creationDate;

  bool get isActionable =>
      status.isPending && newStart != null && newStart!.isAfter(DateTime.now());

  bool get canApprove => isActionable && driverAvailable;
  bool get canReject => isActionable;

  bool get needsExpiration =>
      status.isPending && newStart != null && newStart!.isBefore(DateTime.now());

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    bool contains(String? value) => (value ?? '').toLowerCase().contains(q);

    if (contains(requestNumber)) return true;
    if (contains('#$requestNumber')) return true;
    if (carRequestId != null && contains('${carRequestId!}')) return true;
    if (contains(driverName)) return true;
    if (contains(sourceAddress)) return true;
    if (destinations.any(contains)) return true;
    if (contains(currentPeriod)) return true;
    if (contains(newPeriod)) return true;
    if (contains(status.label)) return true;
    return false;
  }

  static RentalRescheduleRequestVm? tryParse(dynamic json) {
    try {
      return RentalRescheduleRequestVm.fromJson(json);
    } catch (error, stack) {
      debugPrint('Failed to parse reschedule request: $error\n$stack');
      return null;
    }
  }

  factory RentalRescheduleRequestVm.fromJson(dynamic json) {
    final rawCarRequest = getJsonField(json, r'$.carRequest') ??
        getJsonField(json, r'$.CarRequest') ??
        getJsonField(json, r'$.carRequestDto') ??
        getJsonField(json, r'$.CarRequestDto');
    final Map<String, dynamic>? carRequestMap =
    rawCarRequest is Map ? Map<String, dynamic>.from(rawCarRequest) : null;
    final effectiveCarRequest = carRequestMap ?? <String, dynamic>{};

    String _extractString(List<String> paths) {
      for (final path in paths) {
        final value = getJsonField(effectiveCarRequest, path);
        final text = _stringOrEmpty(value).trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    String _stringFromMap(Map<String, dynamic> map, List<String> keys) {
      for (final key in keys) {
        if (map.containsKey(key)) {
          final text = _stringOrEmpty(map[key]).trim();
          if (text.isNotEmpty) {
            return text;
          }
        }
      }
      return '';
    }

    final id = _tryParseInt(getJsonField(json, r'$.id')) ??
        _tryParseInt(getJsonField(json, r'$.Id')) ??
        0;

    final carRequestId = _tryParseInt(getJsonField(json, r'$.carRequestId')) ??
        _tryParseInt(getJsonField(json, r'$.CarRequestId'));

    final requestNumber = _extractString([
      r'$.id',
      r'$.Id',
    ]);

    String driverName = _stringOrEmpty(
      getJsonField(json, r'$.driverName') ??
          getJsonField(json, r'$.DriverName'),
    ).trim();
    if (driverName.isEmpty) {
      driverName = _extractString([
        r'$.driverDto.fullName',
        r'$.driverDto.FullName',
        r'$.DriverDto.FullName',
        r'$.driver.fullName',
        r'$.Driver.FullName',
      ]);
    }

    String sourceAddress = '';
    if (carRequestMap != null) {
      sourceAddress =
          _stringFromMap(carRequestMap, ['sourceAddress', 'SourceAddress']);
    }
    if (sourceAddress.isEmpty) {
      sourceAddress = _extractString([
        r'$.sourceAddress',
        r'$.SourceAddress',
      ]);
    }
    if (sourceAddress.isEmpty) {
      sourceAddress = _stringOrEmpty(
        getJsonField(json, r'$.carRequest.sourceAddress') ??
            getJsonField(json, r'$.carRequest.SourceAddress') ??
            getJsonField(json, r'$.carRequestDto.sourceAddress') ??
            getJsonField(json, r'$.carRequestDto.SourceAddress') ??
            getJsonField(json, r'$.CarRequestDto.sourceAddress') ??
            getJsonField(json, r'$.CarRequestDto.SourceAddress') ??
            getJsonField(json, r'$.SourceAddress') ??
            getJsonField(json, r'$.sourceAddress'),
      ).trim();
    }

    final destinations = <String>[];
    if (carRequestMap != null) {
      final rawDests = carRequestMap['carRequestDests'] ??
          carRequestMap['CarRequestDests'];
      if (rawDests is List) {
        for (final dest in rawDests) {
          String address = '';
          if (dest is Map) {
            final destMap = (dest as Map).cast<String, dynamic>();
            address = _stringFromMap(
              destMap,
              ['destAddress', 'DestAddress', 'address', 'Address'],
            );
          }
          if (address.isEmpty) {
            address = _stringOrEmpty(
              getJsonField(dest, r'$.destAddress') ??
                  getJsonField(dest, r'$.DestAddress') ??
                  getJsonField(dest, r'$.address') ??
                  getJsonField(dest, r'$.Address'),
            ).trim();
          }
          if (address.isNotEmpty) destinations.add(address);
        }
      }
    }
    if (destinations.isEmpty) {
      final destinationsJson = getJsonField(effectiveCarRequest,
          r'$.carRequestDests') ??
          getJsonField(effectiveCarRequest, r'$.CarRequestDests') ??
          getJsonField(json, r'$.carRequest.carRequestDests') ??
          getJsonField(json, r'$.carRequest.CarRequestDests') ??
          getJsonField(json, r'$.carRequestDto.carRequestDests') ??
          getJsonField(json, r'$.carRequestDto.CarRequestDests') ??
          getJsonField(json, r'$.CarRequestDto.carRequestDests') ??
          getJsonField(json, r'$.CarRequestDto.CarRequestDests') ??
          getJsonField(json, r'$.CarRequest.CarRequestDests') ??
          getJsonField(json, r'$.CarRequestDests') ??
          [];

      if (destinationsJson is List) {
        for (final dest in destinationsJson) {
          final address = _stringOrEmpty(
            getJsonField(dest, r'$.destAddress') ??
                getJsonField(dest, r'$.DestAddress') ??
                getJsonField(dest, r'$.address') ??
                getJsonField(dest, r'$.Address'),
          ).trim();
          if (address.isNotEmpty) destinations.add(address);
        }
      }
    }

    final rawCurrentRange = _stringOrEmpty(
      getJsonField(json, r'$.currentDateTimeRange') ??
          getJsonField(json, r'$.CurrentDateTimeRange'),
    );

    final rawNewRange = _stringOrEmpty(
      getJsonField(json, r'$.newDateTimeRange') ??
          getJsonField(json, r'$.NewDateTimeRange'),
    );

    final currentStart = _normalizeDateTime(_parseDateTime(
      getJsonField(json, r'$.currentScheduledStartDate') ??
          getJsonField(json, r'$.CurrentScheduledStartDate'),
    ));
    final currentEnd = _normalizeDateTime(_parseDateTime(
      getJsonField(json, r'$.currentScheduledEndDate') ??
          getJsonField(json, r'$.CurrentScheduledEndDate'),
    ));

    final newStart = _normalizeDateTime(_parseDateTime(
      getJsonField(json, r'$.newScheduledStartDate') ??
          getJsonField(json, r'$.NewScheduledStartDate'),
    ));
    final newEnd = _normalizeDateTime(_parseDateTime(
      getJsonField(json, r'$.newScheduledEndDate') ??
          getJsonField(json, r'$.NewScheduledEndDate'),
    ));

    final currentPeriod = rawCurrentRange.isNotEmpty
        ? rawCurrentRange
        : _formatRange(currentStart, currentEnd);

    final newPeriod = rawNewRange.isNotEmpty
        ? rawNewRange
        : _formatRange(newStart, newEnd);

    final driverAvailable = _parseBool(
      getJsonField(json, r'$.isDriverAvailable') ??
          getJsonField(json, r'$.IsDriverAvailable'),
    );

    final status = _parseStatus(
      getJsonField(json, r'$.rescheduleStatus') ??
          getJsonField(json, r'$.RescheduleStatus'),
    );

    final creationDate = _normalizeDateTime(_parseDateTime(
      getJsonField(json, r'$.creationDate') ??
          getJsonField(json, r'$.CreationDate'),
    ));

    final formattedRequestNumber = requestNumber.isNotEmpty
        ? requestNumber
        : carRequestId?.toString() ?? id.toString();

    return RentalRescheduleRequestVm(
      id: id,
      carRequestId: carRequestId,
      requestNumber: formattedRequestNumber,
      driverName: driverName,
      sourceAddress: sourceAddress,
      destinations: destinations,
      currentPeriod: currentPeriod,
      newPeriod: newPeriod,
      newStart: newStart,
      driverAvailable: driverAvailable,
      status: status,
      creationDate: creationDate,
    );
  }
}

class RentalRescheduleRequestsWidget extends StatefulWidget {
  const RentalRescheduleRequestsWidget({super.key});

  static const String routeName = 'RentalRescheduleRequests';
  static const String routePath = '/rental/request-rescheduling';

  @override
  State<RentalRescheduleRequestsWidget> createState() =>
      _RentalRescheduleRequestsWidgetState();
}

class _RentalRescheduleRequestsWidgetState
    extends State<RentalRescheduleRequestsWidget> {
  final GlobalKey<_RentalRescheduleListPageState> _listKey =
  GlobalKey<_RentalRescheduleListPageState>();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final titleStyle = theme.bodyMedium.override(
      font: GoogleFonts.inter(fontWeight: FontWeight.w700),
      color: theme.primaryText,
      fontSize: 20,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        title: Text('Request for Rescheduling', style: titleStyle),
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0.5,
      ),
      drawer: const AppDrawer(
        onGoCarRequest: _noop,
        onGoDrivers: _noop,
        onGoCars: _noop,
      ),
      body: _RentalRescheduleListPage(key: _listKey),
    );
  }
}

class _RentalRescheduleListPage extends StatefulWidget {
  const _RentalRescheduleListPage({super.key});

  @override
  State<_RentalRescheduleListPage> createState() =>
      _RentalRescheduleListPageState();
}

class _RentalRescheduleListPageState
    extends State<_RentalRescheduleListPage> {
  List<RentalRescheduleRequestVm> _allItems = const [];
  List<RentalRescheduleRequestVm> _visibleItems = const [];
  bool _isFetching = false;
  bool _pendingRefresh = false;
  String? _error;
  final Set<int> _processingIds = <int>{};
  Timer? _expireTimer;
  OverlayEntry? _loadingOverlay;
  final TextEditingController _searchCtl = TextEditingController();
  String _search = '';
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();
  bool _suppressScrollFetch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRequests();
    });
    _expireTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _expirePending());
  }

  @override
  void dispose() {
    _expireTimer?.cancel();
    _debounce?.cancel();
    _searchCtl.dispose();
    _scrollController.dispose();
    _hideLoadingOverlay();
    super.dispose();
  }

  Future<void> refresh() => _fetchRequests(showLoader: false);

  void _showLoadingOverlay() {
    if (kDisableLoadingOverlays) return;
    if (_loadingOverlay != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;
    _loadingOverlay = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: AbsorbPointer(
          absorbing: true,
          child: Container(
            color: Colors.black.withOpacity(0.25),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
    overlay.insert(_loadingOverlay!);
  }

  void _hideLoadingOverlay() {
    if (kDisableLoadingOverlays) return;
    _loadingOverlay?.remove();
    _loadingOverlay = null;
  }

  void _recomputeVisibleItems() {
    final query = _search.trim();
    if (query.isEmpty) {
      _visibleItems = _allItems;
      return;
    }
    final lowerQuery = query.toLowerCase();
    _visibleItems = _allItems
        .where((item) => item.matchesQuery(lowerQuery))
        .toList(growable: false);
  }

  Future<void> _fetchRequests({bool showLoader = true}) async {
    if (!mounted) return;
    if (_isFetching) {
      _pendingRefresh = true;
      return;
    }

    _isFetching = true;

    if (showLoader) {
      _showLoadingOverlay();
    }

    setState(() {
      _error = null;
    });

    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _allItems = const [];
        _visibleItems = const [];
        _error = 'Authentication token not found. Please sign in again.';
      });
      AppNotifications.error(
        context,
        'Authentication token not found. Please sign in again.',
      );
      _isFetching = false;
      _hideLoadingOverlay();
      return;
    }

    try {
      final response =
      await api.RescheduleCarRequestListCall.call(bearerToken: token);
      final rawItems = api.RescheduleCarRequestListCall.items(response);
      final parsed = <RentalRescheduleRequestVm>[];
      for (final raw in rawItems) {
        final item = RentalRescheduleRequestVm.tryParse(raw);
        if (item != null) parsed.add(item);
      }

      const statusOrder = <RescheduleStatus, int>{
        RescheduleStatus.pending: 0,
        RescheduleStatus.approved: 1,
        RescheduleStatus.rejected: 2,
        RescheduleStatus.expired: 3,
        RescheduleStatus.unknown: 4,
      };

      parsed.sort((a, b) {
        final statusComparison =
            (statusOrder[a.status] ?? 99) - (statusOrder[b.status] ?? 99);
        if (statusComparison != 0) return statusComparison;

        final left = a.creationDate ?? a.newStart ?? DateTime(1900);
        final right = b.creationDate ?? b.newStart ?? DateTime(1900);
        return right.compareTo(left);
      });

      if (!mounted) return;
      setState(() {
        _allItems = parsed;
        _recomputeVisibleItems();
      });
    } catch (error, stack) {
      debugPrint('Error loading reschedule requests: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _allItems = const [];
        _visibleItems = const [];
        _error = 'Unable to load reschedule requests. Please try again.';
      });
      AppNotifications.error(
        context,
        'Unable to load reschedule requests. Please try again.',
      );
    } finally {
      if (!mounted) return;
      _isFetching = false;
      _hideLoadingOverlay();
      if (_pendingRefresh) {
        _pendingRefresh = false;
        Future.microtask(() => _fetchRequests(showLoader: showLoader));
      }
    }

    if (mounted) {
      Future.microtask(_expirePending);
    }
  }

  Future<void> _triggerScrollRefresh() async {
    if (!mounted) return;
    if (_isFetching || _suppressScrollFetch) return;
    _suppressScrollFetch = true;
    try {
      await _fetchRequests(showLoader: false);
    } finally {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _suppressScrollFetch = false;
      });
    }
  }

  void _goNextPage() {
    unawaited(_triggerScrollRefresh());
  }

  void _goPrevPage() {
    unawaited(_triggerScrollRefresh());
  }

  Future<void> _expirePending() async {
    if (!mounted) return;
    if (_isFetching) return;
    if (_processingIds.isNotEmpty) return;

    RentalRescheduleRequestVm? candidate;
    for (final item in _allItems) {
      if (item.needsExpiration) {
        candidate = item;
        break;
      }
    }

    if (candidate == null) return;

    await _changeStatus(candidate, RescheduleStatus.expired, auto: true);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _search = value.trim().toLowerCase();
        _recomputeVisibleItems();
      });
    });
  }

  Future<void> _confirmStatusChange(
      RentalRescheduleRequestVm item,
      RescheduleStatus target, {
        BuildContext? sheetContext,
      }) async {
    if (!mounted) return;
    final isApprove = target == RescheduleStatus.approved;

    final confirmed = await AppNotifications.confirmRescheduleStatus(
      context,
      approving: isApprove,
      requestNumber: item.requestNumber,
    );

    if (confirmed) {
      if (sheetContext != null) {
        Navigator.of(sheetContext).pop();
      }
      await _changeStatus(item, target, auto: false);
    }
  }

  Future<void> _changeStatus(
      RentalRescheduleRequestVm item,
      RescheduleStatus target, {
        required bool auto,
      }) async {
    if (!mounted) return;
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(
        context,
        'Authentication token not found. Please sign in again.',
      );
      return;
    }

    if (!auto) {
      _showLoadingOverlay();
    }

    setState(() {
      _processingIds.add(item.id);
    });

    try {
      final response = await api.RescheduleCarRequestUpdateStatusCall.call(
        bearerToken: token,
        rescheduleId: item.id,
        status: target.apiValue,
      );

      final ok = api.RescheduleCarRequestUpdateStatusCall.success(response);
      final message =
      api.RescheduleCarRequestUpdateStatusCall.message(response);

      if (ok) {
        if (!mounted) return;
        if (auto) {
          AppNotifications.info(
            context,
            message ?? 'Reschedule request automatically set to expired.',
          );
        } else {
          AppNotifications.success(
            context,
            message ?? 'Reschedule request updated successfully.',
          );
        }
        await _fetchRequests(showLoader: false);
      } else {
        if (!mounted) return;
        AppNotifications.error(
          context,
          message ?? 'Unable to update the reschedule status.',
        );
      }
    } catch (error, stack) {
      debugPrint('Error updating reschedule status: $error\n$stack');
      if (!mounted) return;
      AppNotifications.error(
        context,
        'Unable to update the reschedule status. Please try again.',
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _processingIds.remove(item.id);
      });
      if (!auto) {
        _hideLoadingOverlay();
      }
    }
  }

  void _openSheet(RentalRescheduleRequestVm item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final theme = FlutterFlowTheme.of(sheetCtx);
        final status = item.status;
        final isProcessing = _processingIds.contains(item.id);

        Widget buildRow(String label, String value) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    label,
                    style: theme.bodySmall.override(
                      font: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      color: theme.secondaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value.isNotEmpty ? value : '—',
                    style: theme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }

        final destinations = item.destinations;

        Widget buildRouteRow() {
          final inlineLabelStyle = theme.bodySmall.override(
            font: GoogleFonts.inter(fontWeight: FontWeight.w700),
            color: theme.primaryText,
          );

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    'Route',
                    style: theme.bodySmall.override(
                      font: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      color: theme.secondaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RouteDescription(
                    departure: item.sourceAddress,
                    destinations: destinations,
                    labelStyle: inlineLabelStyle,
                    valueStyle: theme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }

        Widget buildActionButton({
          required String label,
          required Color background,
          required VoidCallback? onPressed,
          String? tooltip,
        }) {
          final button = SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: background,
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: Colors.black12,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          );

          if (tooltip != null && tooltip.isNotEmpty) {
            return Tooltip(
              message: tooltip,
              preferBelow: false,
              child: button,
            );
          }

          return button;
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    '#${item.carRequestId ?? item.requestNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatusPill(status: status),
                  const SizedBox(height: 16),
                  buildRow('Driver', item.driverName),
                  buildRow('Current schedule', item.currentPeriod),
                  buildRow('New schedule', item.newPeriod),
                  buildRouteRow(),
                  const SizedBox(height: 16),
                  _AvailabilityBadge(available: item.driverAvailable),
                  const SizedBox(height: 20),
                  if (item.isActionable)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        buildActionButton(
                          label: 'Approve',
                          background: theme.success,
                          onPressed: (!item.driverAvailable || isProcessing)
                              ? null
                              : () => _confirmStatusChange(
                            item,
                            RescheduleStatus.approved,
                            sheetContext: sheetCtx,
                          ),
                          tooltip: item.driverAvailable
                              ? 'Approve this rescheduling request.'
                              : 'First, allocate an available driver to approve the rescheduling.',
                        ),
                        const SizedBox(height: 12),
                        buildActionButton(
                          label: 'Reject',
                          background: theme.error,
                          onPressed: isProcessing
                              ? null
                              : () => _confirmStatusChange(
                            item,
                            RescheduleStatus.rejected,
                            sheetContext: sheetCtx,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'No actions are available for this rescheduling request.',
                      style: theme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: TextField(
        controller: _searchCtl,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by request, driver, or destination…',
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: (_search.isEmpty)
              ? null
              : IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _searchCtl.clear();
              _onSearchChanged('');
            },
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.secondaryBackground),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.secondaryBackground),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.primary),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final list = _visibleItems;

    final listContent = (_error != null)
        ? ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
      children: [
        const SizedBox(height: 40),
        Center(
          child: Text(
            _error!,
            style: theme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
      ],
    )
        : NotificationListener<ScrollNotification>(
      onNotification: (sn) {
        if (_isFetching || _suppressScrollFetch) return false;
        if (sn is ScrollUpdateNotification) {
          final metrics = sn.metrics;
          final delta = sn.scrollDelta ?? 0.0;
          if (delta > 0) {
            if (metrics.pixels >= (metrics.maxScrollExtent - 140)) {
              _goNextPage();
            }
          } else if (delta < 0) {
            if (metrics.pixels <= 20) {
              _goPrevPage();
            }
          }
        }
        return false;
      },
      child: (list.isEmpty)
          ? ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
        children: const [
          SizedBox(height: 40),
          Center(child: Text('No matching records found')),
          SizedBox(height: 12),
        ],
      )
          : ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final item = list[index];
          return _RescheduleCard(
            item: item,
            onTap: () => _openSheet(item),
          );
        },
      ),
    );

    return Column(
      children: [
        _buildSearchBar(context),
        const SizedBox(height: 8),
        const SizedBox(height: 12),
        Expanded(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () => _fetchRequests(showLoader: false),
                child: listContent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RescheduleCard extends StatelessWidget {
  const _RescheduleCard({
    required this.item,
    required this.onTap,
  });

  final RentalRescheduleRequestVm item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    Widget buildKeyValue(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(
                label,
                style: theme.bodySmall.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  color: theme.secondaryText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value.isNotEmpty ? value : '—',
                style: theme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final destinations = item.destinations;

    Widget buildRouteRow() {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(
                'Route',
                style: theme.bodySmall.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  color: theme.secondaryText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RouteDescription(
                departure: item.sourceAddress,
                destinations: destinations,
                labelStyle: theme.bodySmall.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  color: theme.primaryText,
                ),
                valueStyle: theme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${item.carRequestId ?? item.requestNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.driverName.isNotEmpty ? item.driverName : '—',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF5B5B5B),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    _StatusPill(status: item.status),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            buildKeyValue('Current schedule', item.currentPeriod),
            buildKeyValue('New schedule', item.newPeriod),
            buildRouteRow(),
            const SizedBox(height: 12),
            Row(
              children: [
                _AvailabilityBadge(available: item.driverAvailable),
                const Spacer(),
              ],
            ),
            if (item.isActionable) ...[
              const SizedBox(height: 6),
              Text(
                'Tap to approve or reject this rescheduling request.',
                style: theme.bodySmall.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  color: theme.secondaryText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteDescription extends StatelessWidget {
  const _RouteDescription({
    required this.departure,
    required this.destinations,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String departure;
  final List<String> destinations;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Departure:', style: labelStyle),
        const SizedBox(height: 4),
        Text(departure.isNotEmpty ? departure : '—', style: valueStyle),
        const SizedBox(height: 12),
        Text('Destination(s):', style: labelStyle),
        if (destinations.isNotEmpty) ...[
          const SizedBox(height: 4),
          for (final dest in destinations)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•', style: valueStyle),
                  const SizedBox(width: 6),
                  Expanded(child: Text(dest, style: valueStyle)),
                ],
              ),
            ),
        ] else ...[
          const SizedBox(height: 4),
          Text('—', style: valueStyle),
        ],
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final RescheduleStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.backgroundColor(theme),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: theme.bodySmall.override(
          font: GoogleFonts.inter(fontWeight: FontWeight.w700),
          color: status.foregroundColor(theme),
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final background = available
        ? theme.success.withOpacity(0.15)
        : theme.error.withOpacity(0.12);
    final foreground = available ? theme.success : theme.error;
    final text = available
        ? 'Driver available'
        : 'Driver unavailable for the requested period.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: foreground.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: FlutterFlowTheme.of(context).bodySmall.override(
          font: GoogleFonts.inter(fontWeight: FontWeight.w600),
          color: foreground,
        ),
      ),
    );
  }
}

void _noop() {}