import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mitsubishi/car_request/car_request_model.dart';
import 'package:mitsubishi/driver_requests/incident_report_form_modal.dart';
import 'package:mitsubishi/utils/car_request_status_ui.dart';

import '/backend/api_requests/api_calls.dart' as API;
import '/backend/api_requests/api_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/menu/app_drawer.dart';
import '/widgets/notifications/app_notifications.dart';

const bool kDisableLoadingOverlays = false;

enum _DActions { details, imHere, start, extend, incident, finish, finalKm }

class _DriverFlags {
  final bool driverAtDeparture;
  final bool hasIncident;
  final int startKm;
  final int endKm;
  final int carKm;
  const _DriverFlags({
    required this.driverAtDeparture,
    required this.hasIncident,
    required this.startKm,
    required this.endKm,
    required this.carKm,
  });
}

T? _gf<T>(dynamic d, String path) {
  final v = getJsonField(d, path);
  if (v == null) return null;
  if (T == int) {
    if (v is num) return v.toInt() as T;
    if (v is String) return int.tryParse(v) as T?;
  }
  if (T == double) {
    if (v is num) return v.toDouble() as T;
    if (v is String) return double.tryParse(v) as T?;
  }
  if (T == String) return v.toString() as T;
  if (T == bool) {
    if (v is bool) return v as T;
    if (v is String) {
      final s = v.toLowerCase();
      return (s == 'true' || s == '1') as T;
    }
    if (v is num) return (v != 0) as T;
  }
  return v as T?;
}

class DriverRequestsWidget extends StatelessWidget {
  const DriverRequestsWidget({super.key});

  static const String routeName = 'DriverRequests';
  static const String routePath = '/driver-requests';

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
        title: Text('Driver Requests', style: titleStyle),
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0.5,
      ),
      drawer: const AppDrawer(
        onGoCarRequest: _noop,
        onGoDrivers: _noop,
        onGoCars: _noop,
      ),
      body: const _DriverRequestsListPage(),
    );
  }
}

void _noop() {}

class _DriverRequestsListPage extends StatefulWidget {
  const _DriverRequestsListPage();

  @override
  State<_DriverRequestsListPage> createState() =>
      _DriverRequestsListPageState();
}

class _DriverRequestsListPageState extends State<_DriverRequestsListPage> {
  int _page = 1;
  final int _pageSize = 10;
  bool _hasNext = false;

  final List<CarRequestViewModel> _items = [];
  List<CarRequestViewModel> _pageRaw = const [];
  List<CarRequestViewModel> _allRaw = const [];

  final Map<String, int> _incidentIndex = {};

  final TextEditingController _searchCtl = TextEditingController();
  String _search = '';
  Timer? _debounce;

  final ScrollController _scrollController = ScrollController();
  bool _isFetching = false;
  bool _suppressScrollFetch = false;

  String? _error;
  OverlayEntry? _listLoadingOverlay;

  late DateTime _fromDate;
  late DateTime _toDate;

  void _resetDefaultPeriod() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _fromDate = today.subtract(const Duration(days: 7));
    _toDate = today.add(const Duration(days: 7));
  }

  @override
  void initState() {
    super.initState();
    _resetDefaultPeriod();
    Future.microtask(() => _fetchPage(1, jumpToTop: true));
  }

  @override
  void dispose() {
    _hideListLoadingOverlay();
    _debounce?.cancel();
    _searchCtl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().padLeft(4, '0')}';

  String _fmtDateRange(DateTime from, DateTime to) =>
      '${_fmtDate(from)}  —  ${_fmtDate(to)}';

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Filter by period',
      cancelText: 'Cancel',
      confirmText: 'Apply',
      saveText: 'Apply',
    );
    if (picked == null) return;

    setState(() {
      _fromDate =
          DateTime(picked.start.year, picked.start.month, picked.start.day);
      _toDate = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });

    _refreshEverything();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _searchCtl.text = '';
      _search = '';
      _resetDefaultPeriod();
    });
    _refreshEverything();
  }

  void _showListLoadingOverlay() {
    if (kDisableLoadingOverlays) return;
    if (!mounted || _listLoadingOverlay != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;
    _listLoadingOverlay = OverlayEntry(
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
    overlay.insert(_listLoadingOverlay!);
  }

  void _hideListLoadingOverlay() {
    if (kDisableLoadingOverlays) return;
    _listLoadingOverlay?.remove();
    _listLoadingOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final list = _items;

    final listContent = (_error != null)
        ? ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
      children: [
        const SizedBox(height: 40),
        Center(child: Text(_error!)),
        const SizedBox(height: 12),
      ],
    )
        : NotificationListener<ScrollNotification>(
      onNotification: (sn) {
        if (_isFetching || _suppressScrollFetch) return false;
        if (sn is ScrollUpdateNotification) {
          final m = sn.metrics;
          final delta = sn.scrollDelta ?? 0.0;
          if (delta > 0) {
            if (m.pixels >= (m.maxScrollExtent - 140)) _goNextPage();
          } else if (delta < 0) {
            if (m.pixels <= 20) _goPrevPage();
          }
        }
        return false;
      },
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final r = list[i];
          return _DriverCard(
            data: r,
            onTap: () => _openActionsSheet(r),
          );
        },
      ),
    );

    return Column(
      children: [
        _buildSearchBar(context),
        const SizedBox(height: 8),
        _buildDateFilterRow(context),
        const SizedBox(height: 12),
        Expanded(child: Stack(children: [listContent])),
      ],
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
          hintText: 'Search by ID, name, plate, destination…',
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

  Widget _buildDateFilterRow(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _pickDateRange,
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Period',
                  prefixIcon: const Icon(Icons.date_range),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                    BorderSide(color: theme.alternate.withOpacity(0.25)),
                  ),
                ),
                child: Text(
                  _fmtDateRange(_fromDate, _toDate),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Clear filters',
            child: OutlinedButton(
              onPressed: _clearFilters,
              style: ButtonStyle(
                shape: MaterialStateProperty.all(const CircleBorder()),
                padding: MaterialStateProperty.all(const EdgeInsets.all(12)),
                minimumSize:
                MaterialStateProperty.all(const Size(48, 48)),
                side: MaterialStateProperty.resolveWith<BorderSide?>((states) {
                  final base =
                  Theme.of(context).colorScheme.outline.withOpacity(0.25);
                  if (states.contains(MaterialState.pressed) ||
                      states.contains(MaterialState.hovered) ||
                      states.contains(MaterialState.focused)) {
                    return BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    );
                  }
                  return BorderSide(color: base, width: 1);
                }),
                overlayColor:
                MaterialStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(MaterialState.pressed)) {
                    return Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.10);
                  }
                  if (states.contains(MaterialState.hovered) ||
                      states.contains(MaterialState.focused)) {
                    return Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.06);
                  }
                  return null;
                }),
              ),
              child: const Icon(Icons.filter_alt_off),
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _search = v.trim().toLowerCase();
      setState(_applyFilterInternal);
    });
  }

  void _applyFilterInternal() {
    final q = _search;
    final filtered = (q.isEmpty)
        ? _pageRaw
        : _pageRaw.where((r) => _matches(r, q)).toList();
    _items
      ..clear()
      ..addAll(filtered);
  }

  bool _matches(CarRequestViewModel r, String q) {
    bool contains(String? s) => (s ?? '').toLowerCase().contains(q);
    final idOk = contains('${r.id}') || contains('#${r.id}');
    final destOk = r.destinations.any((d) => contains(d));
    return idOk ||
        contains(r.userName) ||
        contains(r.driverName) ||
        contains(r.licensePlate) ||
        contains(r.model) ||
        contains(r.routeDeparture) ||
        destOk ||
        contains(r.notes);
  }

  void _goNextPage() {
    if (_isFetching) return;
    if (!_hasNext) return;
    _fetchPage(_page + 1, jumpToTop: true);
  }

  void _goPrevPage() {
    if (_isFetching) return;
    if (_page <= 1) return;
    _fetchPage(_page - 1, jumpToBottom: true);
  }
  Future<void> _fetchPage(
      int page, {
        bool jumpToTop = false,
        bool jumpToBottom = false,
      }) async {
    if (!_ensureAuthOrRedirect()) return;
    if (_isFetching) return;

    _isFetching = true;
    _showListLoadingOverlay();
    try {
      final token = ApiManager.accessToken!;
      if (_allRaw.isEmpty) {
        final res = await API.CarRequestsHistoryCall.call(
          bearerToken: token,
          from: _fromDate,
          to: _toDate,
          userId: 0,
          finishedOnly: false,
        );

        if (!mounted) return;

        if (!res.succeeded) {
          if (res.statusCode == 401) {
            _handleUnauthorized();
            return;
          }
          setState(() => _error = 'Failed to load (${res.statusCode}).');
          return;
        }

        final raw = res.jsonBody;
        final list = (raw is List) ? raw : <dynamic>[];

        _incidentIndex.clear();
        for (final e in list) {
          final id = '${getJsonField(e, r'$.id')}';
          final tidDyn = getJsonField(e, r'$.trafficIncidentId');
          final tid = int.tryParse('${tidDyn ?? ''}') ?? 0;
          _incidentIndex[id] = tid;
        }

        _allRaw = list
            .map(_mapHistoryItem)
            .whereType<CarRequestViewModel>()
            .where((x) => x.status != API.DetailedCarRequestStatus.draft)
            .toList()
          ..sort((a, b) => (b.periodFrom).compareTo(a.periodFrom));
      }

      final start = (page - 1) * _pageSize;
      final end = (start + _pageSize).clamp(0, _allRaw.length);
      final slice = (start >= 0 && start < _allRaw.length)
          ? _allRaw.sublist(start, end)
          : <CarRequestViewModel>[];

      setState(() {
        _pageRaw = slice;
        _hasNext = end < _allRaw.length;
        _page = page;
        _error = null;
        _applyFilterInternal();
      });

      if (jumpToTop) {
        _markSuppressScrollFetch();
        _safeJumpTo(0);
      } else if (jumpToBottom) {
        _markSuppressScrollFetch();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          final max = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(max);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      _hideListLoadingOverlay();
      _isFetching = false;
    }
  }

  void _refreshEverything() {
    _allRaw = const [];
    _incidentIndex.clear();
    _fetchPage(1, jumpToTop: true);
  }

  Future<_DriverFlags> _computeFlags(CarRequestViewModel r) async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      return const _DriverFlags(
        driverAtDeparture: false,
        hasIncident: false,
        startKm: 0,
        endKm: 0,
        carKm: 0,
      );
    }

    try {
      final det = await API.CarRequestsDetailsCall.call(
        bearerToken: token,
        id: r.id,
      );

      if (!det.succeeded) {
        return const _DriverFlags(
          driverAtDeparture: false,
          hasIncident: false,
          startKm: 0,
          endKm: 0,
          carKm: 0,
        );
      }

      final j = det.jsonBody;

      final driverAtDeparture =
          (getJsonField(j, r'$.driverIsAtThePlaceDeparture') as bool?) ?? false;

      final startKm = API.CarRequestsDetailsCall.startKm(j) ?? 0;
      final endKm = API.CarRequestsDetailsCall.endKm(j) ?? 0;

      final carKm =
          (getJsonField(j, r'$.carDto.km') as num?)?.toInt() ??
              (getJsonField(j, r'$.car.km') as num?)?.toInt() ??
              0;

      final tidFromHistory = _incidentIndex[r.id] ?? 0;
      final dynamic rawTid =
          getJsonField(j, r'$.trafficIncidentId') ??
              getJsonField(j, r'$.carRequest.trafficIncidentId') ??
              getJsonField(j, r'$.TrafficIncidentId') ??
              tidFromHistory;
      final tid = int.tryParse('${rawTid ?? ''}') ?? 0;

      final hadIncidentBool =
          (getJsonField(j, r'$.hadIncident') as bool?) ??
              (getJsonField(j, r'$.carRequest.hadIncident') as bool?) ??
              false;

      final hasIncident = tid > 0 || hadIncidentBool;

      return _DriverFlags(
        driverAtDeparture: driverAtDeparture,
        hasIncident: hasIncident,
        startKm: startKm,
        endKm: endKm,
        carKm: carKm,
      );
    } catch (_) {
      return const _DriverFlags(
        driverAtDeparture: false,
        hasIncident: false,
        startKm: 0,
        endKm: 0,
        carKm: 0,
      );
    }
  }

  bool _statusAllowsIncidentRegister(API.DetailedCarRequestStatus _) => true;

  bool _statusAllowsIncidentView(API.DetailedCarRequestStatus s) {
    return s == API.DetailedCarRequestStatus.confirmed ||
        s == API.DetailedCarRequestStatus.inProgress ||
        s == API.DetailedCarRequestStatus.pending ||
        s == API.DetailedCarRequestStatus.finished;
  }

  Set<_DActions> _visibleDriverActions(
      API.DetailedCarRequestStatus status,
      _DriverFlags f,
      ) {
    final s = <_DActions>{_DActions.details};

    if (status == API.DetailedCarRequestStatus.confirmed) {
      if (!f.driverAtDeparture) {
        s.add(_DActions.imHere);
      } else {
        s.add(_DActions.start);
      }
    }

    if (status == API.DetailedCarRequestStatus.inProgress) {
      s..add(_DActions.extend)..add(_DActions.finish);
    }

    if (status == API.DetailedCarRequestStatus.pending &&
        (f.endKm <= f.startKm)) {
      s.add(_DActions.finalKm);
    }

    if (f.hasIncident && _statusAllowsIncidentView(status)) {
      s.add(_DActions.incident);
    } else if (!f.hasIncident && _statusAllowsIncidentRegister(status)) {
      s.add(_DActions.incident);
    }

    return s;
  }

  Future<void> _openActionsSheet(CarRequestViewModel r) async {
    _showListLoadingOverlay();
    final flags = await _computeFlags(r);
    _hideListLoadingOverlay();
    if (!mounted) return;

    final actions = _visibleDriverActions(r.status, flags);
    final Color incidentColor =
    flags.hasIncident ? const Color(0xFF2563EB) : const Color(0xFFF59E0B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: SafeArea(
            top: false,
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
                Text('#${r.id} — ${r.userName}',
                    style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(
                  runSpacing: 10,
                  children: [
                    _pillButton('DETAILS',
                        bg: const Color(0xFF3B82F6),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _openDetails(r);
                        }),
                    if (actions.contains(_DActions.imHere))
                      _pillButton('I\'M HERE',
                          bg: const Color(0xFF2563EB),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _imHere(r);
                          }),
                    if (actions.contains(_DActions.start))
                      _pillButton('START',
                          bg: const Color(0xFF10B981),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _startTrip(r, currentCarKm: flags.carKm);
                          }),
                    if (actions.contains(_DActions.extend))
                      _pillButton('EXTEND',
                          bg: const Color(0xFF8BB9FF),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _extendPeriod(r);
                          }),
                    if (actions.contains(_DActions.incident))
                      _pillButton('INCIDENT',
                          bg: incidentColor,
                          onPressed: () async {
                            Navigator.pop(sheetCtx);
                            flags.hasIncident
                                ? await _openIncident(r)
                                : _openIncidentForm(r);
                          }),
                    if (actions.contains(_DActions.finish))
                      _pillButton('FINISH',
                          bg: const Color(0xFFE34A48),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _finishTrip(r, hasIncidentAlready: flags.hasIncident);
                          }),
                    if (actions.contains(_DActions.finalKm))
                      _pillButton('FINAL KM',
                          bg: const Color(0xFF6B7280),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _fillFinalKm(r);
                          }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDetails(CarRequestViewModel r) async {
    Future.microtask(
          () => AppNotifications.showCarRequestDetailsModal(
        context,
        id: r.id,
        userName: r.userName,
        periodFrom: r.periodFrom,
        periodTo: r.periodTo,
        driver: r.driverName,
        model: r.model,
        childSeat: r.childSeat,
        licensePlate: r.licensePlate,
        hadIncident: false,
        departure: r.routeDeparture,
        destinations: r.destinations.isNotEmpty ? r.destinations : <String>[],
        notes: r.notes,
      ),
    );
  }

  Future<void> _imHere(CarRequestViewModel r) async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) return _handleUnauthorized();

    final reqId = int.tryParse(r.id);
    if (reqId == null) {
      AppNotifications.error(context, 'Invalid request id (${r.id}).');
      return;
    }

    final res = await API.DriverImHereCall.call(
      bearerToken: token,
      id: reqId,
    );

    if (!mounted) return;
    if (res.succeeded) {
      AppNotifications.success(context, 'Passenger informed successfully!');
      _refreshCurrentPage();
    } else {
      AppNotifications.error(
        context,
        'Failed to notify passenger (${res.statusCode}).',
      );
    }
  }

  Future<void> _startTrip(CarRequestViewModel r, {required int currentCarKm}) async {
    final enteredKm = await AppNotifications().showDriverStartKmModal(context, fixedKm: currentCarKm);
    if (enteredKm == null) return;

    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) return _handleUnauthorized();

    final reqId = int.tryParse(r.id);
    if (reqId == null) {
      AppNotifications.error(context, 'Invalid request ID (${r.id}).');
      return;
    }

    final res = await API.DriverStartCall.call(
      bearerToken: token,
      id: reqId,
      startKm: enteredKm,
    );

    if (res.succeeded) {
      AppNotifications.success(context, 'Trip started!');
      _refreshCurrentPage();
    } else {
      AppNotifications.error(context, 'Failed to start (${res.statusCode}).');
    }
  }

  Future<void> _extendPeriod(CarRequestViewModel r) async {
    final newEnd = await AppNotifications().showDriverExtendPeriodModal(
      context,
      initialEnd: r.periodTo ?? r.periodFrom.add(const Duration(hours: 1)),
    );
    if (newEnd == null) return;

    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) return _handleUnauthorized();

    final res = await API.CarRequestsExtendPeriodCall.call(
      bearerToken: token,
      id: r.id,
      newEnd: newEnd,
    );
    if (!mounted) return;
    if (res.succeeded) {
      AppNotifications.success(context, 'Period extended');
      _refreshCurrentPage();
    } else {
      AppNotifications.error(context, 'Failed to extend (${res.statusCode}).');
    }
  }

  int _durationMinutes(DateTime start, DateTime end) {
    final a = start.isBefore(end) ? start : end;
    final b = start.isBefore(end) ? end   : start;
    return b.difference(a).inMinutes;
  }

  Future<void> _finishTrip(
      CarRequestViewModel r, {
        required bool hasIncidentAlready,
      }) async {
    final nowLocal = DateTime.now().toLocal();
    final startDate = r.periodFrom;

    final DateTime safeEnd = nowLocal.isBefore(startDate)
    ? (r.periodTo ?? startDate.add(const Duration(hours: 1)))
        : nowLocal;

    final result = await AppNotifications().showDriverFinishTripModal(
    context,
    initialFrom: r.periodFrom,
    initialTo:   safeEnd,
    onOpenIncident: () => _openIncidentForm(r),
    existingIncident: hasIncidentAlready,
    );
    if (result == null) return;

    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) return _handleUnauthorized();

    final totalMinutes = _durationMinutes(result.start, result.end);
    if (totalMinutes >= 20 * 60) {
      AppNotifications.warning(context, 'Period must be less than 20 hours.');
      return;
    }

    if (result.hadIncident && !hasIncidentAlready) {
      final verify = await API.TrafficIncidentVerifyExistsByCarRequestCall.call(
        bearerToken: token,
        carRequestId: r.id,
      );
      final exists = verify.succeeded &&
          API.TrafficIncidentVerifyExistsByCarRequestCall.exists(verify);
      if (!exists) {
        AppNotifications.warning(
          context,
          'Register the incident before finishing.',
        );
        _openIncidentForm(r);
        return;
      }
    }

    final res = await API.CarRequestsFinishPeriodCall.call(
      bearerToken: token,
      id: r.id,
      realStart: result.start,
      realEnd: result.end,
    );
    if (!mounted) return;

    if (res.succeeded) {
      AppNotifications.success(context, 'Trip finished');
      _refreshCurrentPage();
    } else if (res.statusCode == 401) {
      _handleUnauthorized();
    } else {
      AppNotifications.error(
        context,
        'Failed to finish (${res.statusCode}).',
      );
    }
  }

  Future<void> _fillFinalKm(CarRequestViewModel r) async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      return _handleUnauthorized();
    }

    int carKm = 0;
    try {
      final resp = await API.CarRequestsGetCall.call(
        bearerToken: token,
        id: r.id,
      );
      if (!resp.succeeded) {
        AppNotifications.error(context, 'Failed (${resp.statusCode}).');
        return;
      }
      final j = resp.jsonBody;
      carKm = _gf<int>(j, r'$.carDto.km') ?? _gf<int>(j, r'$.car.km') ?? 0;
    } catch (_) {
      AppNotifications.error(context, 'Error loading request data.');
      return;
    }

    final km = await AppNotifications.showDriverFinalKmModal(
      context,
      initialKm: carKm,
      minKm: carKm,
    );
    if (km == null) return;

    if (km <= carKm) {
      AppNotifications.warning(
        context,
        'Final km ($km) must be greater than start km ($carKm).',
      );
      return;
    }

    final res = await API.CarRequestsFinishKmCall.call(
      bearerToken: token,
      id: r.id,
      endKm: km,
    );

    if (!mounted) return;
    if (res.succeeded) {
      AppNotifications.success(context, 'Final KM saved');
      _refreshCurrentPage();
    } else {
      AppNotifications.error(context, 'Failed to save (${res.statusCode}).');
    }
  }

  Future<void> _openIncidentForm(CarRequestViewModel r) async {
    final beforeHadIncident = (_incidentIndex[r.id] ?? 0) > 0;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => IncidentReportFormModal(request: r),
    );

    if (saved == true && mounted) {
      _refreshCurrentPage();
      return;
    }

    final token = ApiManager.accessToken;
    if (!mounted || token == null || token.isEmpty) return;

    try {
      final verify = await API.TrafficIncidentVerifyExistsByCarRequestCall.call(
        bearerToken: token,
        carRequestId: r.id,
      );
      final exists = verify.succeeded &&
          API.TrafficIncidentVerifyExistsByCarRequestCall.exists(verify);

      final afterHadIncident = exists == true;
      if (mounted && afterHadIncident != beforeHadIncident) {
        _refreshCurrentPage();
      }
    } catch (_) {}
  }

  Future<void> _openIncident(CarRequestViewModel r) async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      return;
    }

    final reqId = int.tryParse(r.id);
    if (reqId == null) {
      AppNotifications.error(context, 'Invalid request id.');
      return;
    }

    _showListLoadingOverlay();
    try {
      final res = await API.TrafficIncidentByCarRequestCall.call(
        bearerToken: token,
        carRequestId: reqId,
      );
      if (!mounted) return;

      if (!res.succeeded) {
        _hideListLoadingOverlay();
        AppNotifications.error(
          context,
          'Failed to load incident (${res.statusCode}).',
        );
        return;
      }

      final rawPhotos = API.TrafficIncidentByCarRequestCall.photos(res);
      final images = <IncidentImage>[];

      for (final e in rawPhotos) {
        final name = (e['fileName'] ?? '').toString().trim();
        final rawB64 = (e['base64'] ?? '').toString();
        if (rawB64.isEmpty) continue;

        final bytes = _decodeIncidentBase64(rawB64);
        if (bytes == null) continue;

        images.add(
          IncidentImage(
            fileName: name.isEmpty ? 'image' : name,
            bytes: bytes,
          ),
        );
      }

      _hideListLoadingOverlay();

      await AppNotifications.showTrafficIncidentModal(
        context: context,
        title: 'Traffic Incident',
        incidentId: API.TrafficIncidentByCarRequestCall.id(res) ?? 0,
        carRequestId:
        API.TrafficIncidentByCarRequestCall.carRequestId(res) ?? reqId,
        driverName: API.TrafficIncidentByCarRequestCall.driverName(res),
        creationAt: API.TrafficIncidentByCarRequestCall.creationAt(res),
        incidentAt: API.TrafficIncidentByCarRequestCall.incidentAt(res),
        hasInjuries: API.TrafficIncidentByCarRequestCall.hadInjuries(res),
        injuriesDetails:
        API.TrafficIncidentByCarRequestCall.injuriesDetails(res),
        incidentLocation:
        API.TrafficIncidentByCarRequestCall.incidentLocation(res),
        incidentSummary:
        API.TrafficIncidentByCarRequestCall.incidentSummary(res),
        damagePlate: API.TrafficIncidentByCarRequestCall.damagePlate(res),
        damageSummary: API.TrafficIncidentByCarRequestCall.damageSummary(res),
        passengers: API.TrafficIncidentByCarRequestCall.passengers(res),
        images: images,
      );
    } catch (e) {
      if (!mounted) return;
      _hideListLoadingOverlay();
      AppNotifications.error(context, 'Error loading incident.');
    }
  }

  bool _ensureAuthOrRedirect() {
    final token = ApiManager.accessToken;
    final ok = token != null && token.trim().isNotEmpty;
    if (!ok) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      if (mounted) context.goNamed('Login');
    }
    return ok;
  }

  void _handleUnauthorized() {
    AppNotifications.error(
        context, 'Your session expired (401). Please sign in again.');
    if (mounted) context.goNamed('Login');
  }

  void _refreshCurrentPage() {
    _allRaw = const [];
    _fetchPage(_page);
  }

  void _safeJumpTo(double offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final clamped = offset.clamp(pos.minScrollExtent, pos.maxScrollExtent);
      _scrollController.jumpTo(clamped);
    });
  }

  void _markSuppressScrollFetch() {
    _suppressScrollFetch = true;
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _suppressScrollFetch = false;
    });
  }

  Widget _pillButton(
      String label, {
        required VoidCallback onPressed,
        Color bg = const Color(0xFF8BB9FF),
      }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: Colors.black12,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.data, required this.onTap});
  final CarRequestViewModel data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${data.id}',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF222222))),
                    const SizedBox(height: 6),
                    Text(data.userName,
                        style: GoogleFonts.inter(
                            fontSize: 14, color: const Color(0xFF5B5B5B))),
                    const SizedBox(height: 6),
                    Text(_fmtPeriod(data.periodFrom, data.periodTo),
                        style: GoogleFonts.inter(fontSize: 14)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: data.status.uiColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                data.status.uiLabel,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          _kv('Departure', data.routeDeparture),
          if (data.destinations.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Destination(s)',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            ...data.destinations.take(2).map((d) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [const Text('• '), Expanded(child: Text(d))],
            )),
            if (data.destinations.length > 2)
              const Text('+ more', style: TextStyle(color: Colors.black54)),
          ],
        ]),
      ),
    );
  }
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 160,
            child:
            Text(k, style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Expanded(child: Text(v)),
      ],
    ),
  );
}

String _fmtPeriod(DateTime from, DateTime? to) {
  final f =
      '${from.day.toString().padLeft(2, '0')}/${from.month.toString().padLeft(2, '0')} '
      '${from.hour.toString().padLeft(2, '0')}:${from.minute.toString().padLeft(2, '0')}';
  if (to == null) return f;
  final t =
      '${to.day.toString().padLeft(2, '0')}/${to.month.toString().padLeft(2, '0')} '
      '${to.hour.toString().padLeft(2, '0')}:${to.minute.toString().padLeft(2, '0')}';
  return '$f  —  $t';
}

Uint8List? _decodeIncidentBase64(String raw) {
  try {
    final normalized = raw.split(',').last.trim();
    return base64Decode(normalized);
  } catch (_) {
    return null;
  }
}

CarRequestViewModel? _mapHistoryItem(dynamic d) {
  String _s(dynamic v) => v?.toString() ?? '';
  int? _i(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  DateTime? _dt(dynamic v) {
    final s = _s(v).trim();
    if (s.isEmpty) return null;
    final dt = DateTime.tryParse(s);
    if (dt == null) return null;
    return dt.isUtc ? dt.toLocal() : dt;
  }

  final id = _s(getJsonField(d, r'$.id'));
  final userId =
      _i(getJsonField(d, r'$.userId')) ??
          _i(getJsonField(d, r'$.requirerId')) ??
          _i(getJsonField(d, r'$.requirerDto.id'));

  final driverId =
      _i(getJsonField(d, r'$.driverId')) ??
          _i(getJsonField(d, r'$.driverUserId')) ??
          _i(getJsonField(d, r'$.driverDto.id')) ??
          _i(getJsonField(d, r'$.driver.id')) ??
          _i(getJsonField(d, r'$.driver.userId')) ??
          _i(getJsonField(d, r'$.assignedDriverId'));

  final carId =
      _i(getJsonField(d, r'$.carId')) ??
          _i(getJsonField(d, r'$.carDto.id'));

  final userName = _s(getJsonField(d, r'$.userDto.fullName')).isNotEmpty
      ? _s(getJsonField(d, r'$.userDto.fullName'))
      : _s(getJsonField(d, r'$.requirerDto.fullName'));

  final from = _dt(getJsonField(d, r'$.startDateTime')) ??
      _dt(getJsonField(d, r'$.start')) ??
      _dt(getJsonField(d, r'$.periodFrom'));
  if (id.isEmpty || from == null) return null;

  DateTime? end = _dt(getJsonField(d, r'$.endDateTime')) ??
      _dt(getJsonField(d, r'$.end')) ??
      _dt(getJsonField(d, r'$.periodTo'));

  String departure = [
    _s(getJsonField(d, r'$.routeDeparture')),
    _s(getJsonField(d, r'$.startAddress')),
    _s(getJsonField(d, r'$.fromAddress')),
    _s(getJsonField(d, r'$.sourceAddress')),
  ].firstWhere((e) => e.isNotEmpty, orElse: () => '-');

  List<String> destinations = [];
  final list = getJsonField(d, r'$.carRequestDests');
  if (list is List) {
    destinations = list
        .map((e) => [
      _s(getJsonField(e, r'$.address')),
      _s(getJsonField(e, r'$.formattedAddress')),
      _s(getJsonField(e, r'$.destAddress')),
      _s(getJsonField(e, r'$.routeDestination')),
    ].firstWhere((x) => x.isNotEmpty, orElse: () => ''))
        .where((s) => s.isNotEmpty)
        .cast<String>()
        .toList();
  }

  String notes = [
    _s(getJsonField(d, r'$.notes')),
    _s(getJsonField(d, r'$.description')),
    _s(getJsonField(d, r'$.note')),
  ].firstWhere((e) => e.isNotEmpty, orElse: () => '');

  final driverName = _s(getJsonField(d, r'$.driverDto.fullName')).isNotEmpty
      ? _s(getJsonField(d, r'$.driverDto.fullName'))
      : _s(getJsonField(d, r'$.driver.fullName'));

  final model = [
    _s(getJsonField(d, r'$.car.description')),
    _s(getJsonField(d, r'$.car.model')),
    _s(getJsonField(d, r'$.carDto.description')),
  ].firstWhere((e) => e.isNotEmpty, orElse: () => '-');

  final license = [
    _s(getJsonField(d, r'$.car.licensePlate')),
    _s(getJsonField(d, r'$.carDto.licensePlate')),
    _s(getJsonField(d, r'$.licensePlate')),
  ].firstWhere((e) => e.isNotEmpty, orElse: () => '-');

  final childSeat = (getJsonField(d, r'$.childSeat') as bool?) ?? false;

  final rawStatus = getJsonField(d, r'$.requestStatus') ??
      getJsonField(d, r'$.status') ??
      getJsonField(d, r'$.statusName');
  final detailed = API.parseDetailedCarRequestStatus(rawStatus);

  return CarRequestViewModel(
    id: id,
    userId: userId,
    carId: carId,
    driverId: driverId,
    userName: userName.isEmpty ? '-' : userName,
    periodFrom: from,
    periodTo: end,
    routeDeparture: departure.isEmpty ? '-' : departure,
    destinations: destinations,
    notes: notes,
    driverName: driverName.isEmpty ? '-' : driverName,
    model: model.isEmpty ? '-' : model,
    childSeat: childSeat,
    licensePlate: license.isEmpty ? '-' : license,
    status: detailed,
  );
}
