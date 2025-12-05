import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mitsubishi/backend/api_requests/api_manager.dart';
import 'package:mitsubishi/widgets/notifications/car_request_period_modals.dart';
import '/backend/api_requests/api_calls.dart' as API;

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/menu/app_drawer.dart';
import '/widgets/add_fab_button.dart';

import 'package:mitsubishi/car_request/car_request_model.dart';
import 'package:mitsubishi/car_request/car_request_wizard.dart' as W;

import 'package:mitsubishi/utils/car_request_status_ui.dart';
import '/widgets/notifications/app_notifications.dart'
    show AppNotifications, IncidentImage;


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
  var b64 = raw.trim();
  final i = b64.indexOf(',');
  if (i > 0 && b64.substring(0, i).contains('base64')) {
    b64 = b64.substring(i + 1);
  }
  b64 = b64.replaceAll(RegExp(r'\s'), '');

  try {
    return base64Decode(base64.normalize(b64));
  } catch (_) {
    try {
      b64 = b64.replaceAll('-', '+').replaceAll('_', '/');
      return base64Decode(base64.normalize(b64));
    } catch (_) {
      return null;
    }
  }
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().padLeft(4, '0')}';

String _fmtDateRange(DateTime from, DateTime to) =>
    '${_fmtDate(from)}  —  ${_fmtDate(to)}';

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(k, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(v)),
      ],
    ),
  );
}

String? _rawStatusFromListItem(dynamic d) {
  final candidates = <dynamic>[
    getJsonField(d, r'$.statusName'),
    getJsonField(d, r'$.requestStatusName'),
    getJsonField(d, r'$.status'),
    getJsonField(d, r'$.requestStatus'),
  ];
  for (final v in candidates) {
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
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
String _extractSpecialFromJson(dynamic j) {
  if (j == null) return '';
  String s = (getJsonField(j, r'$.specialCarInfo') ?? '').toString().trim();
  if (s.isEmpty) {
    s = (getJsonField(j, r'$.carDto.specialCarInfo') ?? '').toString().trim();
  }
  if (s.isEmpty) {
    s = (getJsonField(j, r'$.car.specialCarInfo') ?? '').toString().trim();
  }
  if (s.isEmpty) {
    s = (getJsonField(j, r'$.carRequest.specialCarInfo') ?? '').toString().trim();
  }
  return s;
}

DateTime? _tryParseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toLocal();

  if (v is String) {
    final s = v.trim();

    final msMatch = RegExp(r'\/Date\((\d+)\)\/').firstMatch(s);
    if (msMatch != null) {
      final ms = int.tryParse(msMatch.group(1)!);
      if (ms != null) {
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
      }
      return null;
    }

    final dt = DateTime.tryParse(s);
    if (dt == null) return null;
    return dt.isUtc ? dt.toLocal() : dt;
  }

  if (v is int) {
    if (v > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
    }
    if (v > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true).toLocal();
    }
  }

  if (v is num) {
    final iv = v.toInt();
    if (iv > 0) return _tryParseDate(iv);
  }

  return null;
}

DateTime? _gdt(dynamic j, List<String> paths) {
  for (final p in paths) {
    final v = getJsonField(j, p);
    final dt = _tryParseDate(v);
    if (dt != null) return dt;
  }
  return null;
}

class CarRequestWidget extends StatefulWidget {
  const CarRequestWidget({super.key});

  static String routeName = 'CarRequest';
  static String routePath = '/car-request';

  @override
  State<CarRequestWidget> createState() => _CarRequestWidgetState();
}

class _CarRequestWidgetState extends State<CarRequestWidget> {
  final TextEditingController _searchCtrl = TextEditingController();

  static const bool kHitAdminIndexForTest = false;

  String? _error;
  bool _isFetching = false;
  int _page = 1;
  final int _pageSize = 10;
  bool _isLastPage = false;
  final List<CarRequestViewModel> _requests = [];

  late DateTime _fromDate;
  late DateTime _toDate;

  OverlayEntry? _listLoadingOverlay;
  void _showListLoadingOverlay() {
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
    _listLoadingOverlay?.remove();
    _listLoadingOverlay = null;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _fromDate = today.subtract(const Duration(days: 7));
    _toDate   = today.add(const Duration(days: 7));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirstPage());
  }

  @override
  void dispose() {
    _hideListLoadingOverlay();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final initial = DateTimeRange(start: _fromDate, end: _toDate);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Filter by period',
      cancelText: 'Cancel',
      confirmText: 'Apply',
      saveText: 'Apply',
    );
    if (picked != null) {
      final start =
      DateTime(picked.start.year, picked.start.month, picked.start.day);
      final end = DateTime(picked.end.year, picked.end.month, picked.end.day);
      setState(() {
        _fromDate = start;
        _toDate = end;
      });
      await _loadFirstPage();
    }
  }

  Future<void> _clearFilters() async {
    final now = DateTime.now();
    setState(() {
      _searchCtrl.text = '';
      final today = DateTime(now.year, now.month, now.day);
      _fromDate = today.subtract(const Duration(days: 7));
      _toDate   = today.add(const Duration(days: 7));
    });
    await _loadFirstPage();
  }

  bool _ensureAuth() {
    final token = ApiManager.accessToken;
    if (token == null || token.trim().isEmpty) {
      _error = 'Session expired. Please sign in again.';
      AppNotifications.error(context, _error!);
      return false;
    }
    return true;
  }

  bool _canEdit(CarRequestViewModel r) {
    final s = r.status;
    return s == API.DetailedCarRequestStatus.draft ||
        s == API.DetailedCarRequestStatus.waiting ||
        s == API.DetailedCarRequestStatus.confirmed;
  }

  bool _canCancel(CarRequestViewModel r) {
    return !r.status.isCanceled;
  }

  bool _canFinish(CarRequestViewModel r) =>
      r.status == API.DetailedCarRequestStatus.inProgress;

  bool _canExtend(CarRequestViewModel r) =>
      r.status == API.DetailedCarRequestStatus.inProgress;

  String _explainCancelBlock(CarRequestViewModel r) {
    if (r.status.isCanceled) return 'Request is already canceled.';
    if (!_canCancel(r)) {
      return 'Cancellation is not allowed for the current status.';
    }
    return 'Cancellation not allowed.';
  }

  Future<bool> _confirmEditChangeToDraft(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirm edit'),
        content: const Text(
          'Editing will change the request status to Draft. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _handleEditTap(CarRequestViewModel r, BuildContext ctx) async {
    if (!_canEdit(r)) {
      return;
    }
    final proceed = await _confirmEditChangeToDraft(ctx);
    if (proceed) {
      await _goToEdit(r);
    }
  }
  Future<void> _loadFirstPage({bool showOverlay = true}) async {
    if (_isFetching) return;
    if (!_ensureAuth()) {
      setState(() {});
      return;
    }
    _isFetching = true;

    if (mounted) {
      setState(() {
        _error = null;
        _page = 1;
        _isLastPage = false;
        _requests.clear();
      });
    }
    if (showOverlay) _showListLoadingOverlay();

    try {
      final res = kHitAdminIndexForTest
          ? await API.CarRequestsListAdminCall.call(
        bearerToken: ApiManager.accessToken,
        from: _fromDate,
        to: _toDate,
      )
          : await API.CarRequestsListCall.call(
        bearerToken: ApiManager.accessToken,
        from: _fromDate,
        to: _toDate,
        page: _page,
        pageSize: _pageSize,
      );

      if (!mounted) return;

      final newItems = (kHitAdminIndexForTest
          ? API.CarRequestsListAdminCall.items(res)
          : API.CarRequestsListCall.items(res))
          .map(_mapItem)
          .whereType<CarRequestViewModel>()
          .toList();

      setState(() {
        _requests.addAll(newItems);
        _isLastPage = kHitAdminIndexForTest
            ? true
            : (!API.CarRequestsListCall.hasNext(res) ||
            newItems.length < _pageSize);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error loading requests.');
    } finally {
      _isFetching = false;
      if (showOverlay) _hideListLoadingOverlay();
    }
  }

  Future<void> _loadMore() async {
    if (kHitAdminIndexForTest) return;
    if (_isFetching || _isLastPage) return;
    if (!_ensureAuth()) return;

    _isFetching = true;
    final nextPage = _page + 1;
    _showListLoadingOverlay();

    try {
      final res = await API.CarRequestsListCall.call(
        bearerToken: ApiManager.accessToken,
        from: _fromDate,
        to: _toDate,
        page: nextPage,
        pageSize: _pageSize,
      );

      if (!mounted) return;

      if (res.succeeded) {
        final newItems = API.CarRequestsListCall.items(res)
            .map(_mapItem)
            .whereType<CarRequestViewModel>()
            .toList();

        setState(() {
          _page = nextPage;
          _requests.addAll(newItems);
          _isLastPage = !API.CarRequestsListCall.hasNext(res) ||
              newItems.length < _pageSize;
        });
      } else {
        setState(
                () => _error = 'Failed to load requests (${res.statusCode}).');
      }
    } catch (_) {
    } finally {
      _isFetching = false;
      _hideListLoadingOverlay();
    }
  }

  CarRequestViewModel? _mapItem(dynamic d) {
    final id = API.CarRequestsListCall.id(d);
    final userName = API.CarRequestsListCall.userName(d) ?? '-';
    final from = API.CarRequestsListCall.startAt(d);
    if (id == null || from == null) return null;

    return CarRequestViewModel(
      id: id,
      userId: null,
      carId: null,
      driverId: null,
      userName: userName,
      driverName: API.CarRequestsListCall.driverName(d) ?? '-',
      model: API.CarRequestsListCall.model(d) ?? '-',
      licensePlate: API.CarRequestsListCall.licensePlate(d) ?? '-',
      periodFrom: from,
      periodTo: API.CarRequestsListCall.endAt(d),
      routeDeparture: API.CarRequestsListCall.departure(d) ?? '-',
      destinations: API.CarRequestsListCall.destinations(d),
      notes: API.CarRequestsListCall.notes(d),
      childSeat: API.CarRequestsListCall.childSeat(d),
      status: API.CarRequestsListCall.detailedStatus(d),
      statusName: _rawStatusFromListItem(d),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final titleStyle = theme.bodyMedium.override(
      font: GoogleFonts.inter(fontWeight: FontWeight.w600),
      color: theme.primaryText,
      fontSize: 20,
    );

    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _requests.where((r) {
      return r.id.toLowerCase().contains(q) ||
          r.userName.toLowerCase().contains(q) ||
          r.driverName.toLowerCase().contains(q) ||
          r.model.toLowerCase().contains(q) ||
          r.licensePlate.toLowerCase().contains(q);
    }).toList();

    final listContent = (_error != null)
        ? ListView(
      children: [
        const SizedBox(height: 40),
        Center(child: Text(_error!)),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => _loadFirstPage(),
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      ],
    )
        : NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (_isFetching || _isLastPage) return false;
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          _loadMore();
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, c) {
          final isCompact = c.maxWidth < 1000;
          if (filtered.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 40),
              Center(child: Text('No requests found')),
            ]);
          }
          if (isCompact) {
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 110),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final r = filtered[i];
                return _CarRequestCard(
                  data: r,
                  onTap: () => _openRequestSheet(r),
                );
              },
            );
          } else {
            return _CarRequestsTable(
              items: filtered,
              onRowTap: _openRequestSheet,
            );
          }
        },
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        title: Text('Car Requests', style: titleStyle),
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0.5,
      ),
      drawer: AppDrawer(
        onGoCarRequest: () => context.goNamed(CarRequestWidget.routeName),
        onGoDrivers: () => context.goNamed('Drivers'),
        onGoCars: () => context.goNamed('Cars'),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 12, bottom: 12),
        child: AddFabButton(
          heroTag: 'carRequestAddFab',
          onTap: _onAddRequest,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search car requests',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                    borderSide: BorderSide(color: theme.alternate.withOpacity(0.25)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                            borderSide: BorderSide(color: theme.alternate.withOpacity(0.25)),
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
                        minimumSize: MaterialStateProperty.all(const Size(48, 48)),
                        side: MaterialStateProperty.resolveWith<BorderSide?>((states) {
                          final base = Theme.of(context).colorScheme.outline.withOpacity(0.25);
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
                        overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(MaterialState.pressed)) {
                            return Theme.of(context).colorScheme.primary.withOpacity(0.10);
                          }
                          if (states.contains(MaterialState.hovered) ||
                              states.contains(MaterialState.focused)) {
                            return Theme.of(context).colorScheme.primary.withOpacity(0.06);
                          }
                          return null;
                        }),
                      ),
                      child: const Icon(Icons.filter_alt_off),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: listContent),
            ],
          ),
        ),
      ),
    );
  }

  Future<CarRequestViewModel> _fetchFullRequest(CarRequestViewModel fallback) async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) return fallback;

    try {
      final resp = await API.CarRequestsGetCall.call(
        bearerToken: token,
        id: fallback.id,
      );
      if (resp.succeeded) {
        return CarRequestViewModel.fromApiJson(resp.jsonBody);
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _goToEdit(CarRequestViewModel r) async {
    _showListLoadingOverlay();

    CarRequestViewModel initial;
    try {
      initial = await _fetchFullRequest(r);
    } catch (_) {
      initial = r;
    } finally {
      _hideListLoadingOverlay();
    }
    if (!mounted) return;

    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => W.CarRequestWizard(
          mode: W.CarRequestFormMode.edit,
          initial: initial,
          fetchUsers: _fetchUsersForWizard,
          fetchUserCostAllocs: _fetchUserCostAllocsForWizard,
          submitCarRequest: _submitCarRequestForWizard,
        ),
      ),
    );

    if (edited == true && mounted) {
      await _loadFirstPage();
      AppNotifications.success(context, 'Request updated');
    }
  }

  Future<void> _onAddRequest() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => W.CarRequestWizard(
          mode: W.CarRequestFormMode.create,
          fetchUsers: _fetchUsersForWizard,
          fetchUserCostAllocs: _fetchUserCostAllocsForWizard,
          submitCarRequest: _submitCarRequestForWizard,
        ),
      ),
    );

    if (created == true && mounted) {
      await _loadFirstPage();
      AppNotifications.success(context, 'Request created');
    }
  }

  Future<void> _cancelRequest(CarRequestViewModel r) async {
    final latest = await _fetchFullRequest(r);
    if (!_canCancel(latest)) {
      if (!mounted) return;
      AppNotifications.error(
        context,
        _explainCancelBlock(latest).isEmpty
            ? 'Cancellation is not allowed at the moment.'
            : _explainCancelBlock(latest),
      );
      return;
    }

    final reason = await AppNotifications.showCancelRequestModal(context);
    if (reason == null) return;

    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      return;
    }

    _showListLoadingOverlay();
    try {
      final res = await API.CarRequestsCancelCall.call(
        bearerToken: token,
        id: r.id,
        reason: reason,
      );
      if (!mounted) return;

      if (res.succeeded) {
        AppNotifications.success(context, 'Request canceled');
        await _loadFirstPage(showOverlay: false);
      } else {
        AppNotifications.error(context, 'Failed to cancel (${res.statusCode}).');
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifications.error(context, 'Failed to cancel request.');
    } finally {
      _hideListLoadingOverlay();
    }
  }

  Future<bool> _submitCarRequestForWizard(
      Map<String, dynamic> body, {
        int? id,
        bool useAdminUpdate = false,
      }) async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      if (mounted) {
        AppNotifications.error(context, 'Session expired. Please sign in again.');
      }
      return false;
    }

    try {
      if (id != null && useAdminUpdate) {
        final res = await API.CarRequestsUpdateAdminCall.call(
          bearerToken: token,
          id: id,
          carId: body['CarId'] as int?,
          passengersId: (body['PassengersId'] as List?)?.cast<int>(),
          carRequestsCostAllocs:
          (body['CarRequestsCostAllocs'] as List?)?.cast<Map<String, dynamic>>() ??
              const [],
          carRequestDests:
          (body['CarRequestDests'] as List?)?.cast<Map<String, dynamic>>(),
          note: body['Note'] as String?,
          specialCarInfo: body['SpecialCarInfo'] as String?,
          passanger1: body['Passanger1'] as String?,
          passanger2: body['Passanger2'] as String?,
          passanger3: body['Passanger3'] as String?,
          childSeat: body['ChildSeat'] as bool?,
        );

        if (res.succeeded) return true;
        if (mounted) {
          AppNotifications.error(
            context,
            'Failed to update (admin) (${res.statusCode}).',
          );
        }
        return false;
      }

      final res = (id == null)
          ? await API.CarRequestsCreateCall.call(
        body: body,
        bearerToken: token,
      )
          : await API.CarRequestsUpdateCall.call(
        id: id,
        body: body,
        bearerToken: token,
      );

      if (res.succeeded) return true;

      if (mounted) {
        AppNotifications.error(
          context,
          'Failed to save request (${res.statusCode}).',
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        AppNotifications.error(context, 'Error saving request.');
      }
      return false;
    }
  }

  DateTimeRange _safeRange(
      DateTime a,
      DateTime b, {
        Duration minSpan = const Duration(minutes: 1),
      }) {
    if (b.isBefore(a)) b = a.add(minSpan);
    return DateTimeRange(start: a, end: b);
  }
  Future<void> _repeatRequest(CarRequestViewModel r) async {
    _showListLoadingOverlay();
    CarRequestViewModel full;
    try {
      full = await _fetchFullRequest(r);
    } catch (_) {
      full = r;
    } finally {
      _hideListLoadingOverlay();
    }
    if (!mounted) return;

    final start = full.periodFrom;
    final end = full.periodTo ?? start.add(const Duration(hours: 1));

    final picked = await PeriodModals.showRepeatRequestModal(
      context,
      originalId: full.id,
      originalStart: start,
      originalEnd: end,
    );
    if (picked == null) return;

    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      return;
    }

    _showListLoadingOverlay();
    try {
      final res = await API.CarRequestsRepeatCall.call(
        bearerToken: token,
        originalId: full.id,
        newStart: picked.start,
        newEnd: picked.end,
      );
      if (!mounted) return;
      if (res.succeeded) {
        AppNotifications.success(context, 'Request duplicated');
        await _loadFirstPage(showOverlay: false);
      } else {
        AppNotifications.error(context, 'New period is equal to original period.');
      }
    } finally {
      _hideListLoadingOverlay();
    }
  }

  Future<DateTimeRange> _resolveRevTimeInitialRange(CarRequestViewModel r) async {
    DateTime start = r.realStartDateTime ?? r.periodFrom;
    DateTime end   = r.realEndDateTime ?? r.periodTo ?? r.periodFrom.add(const Duration(hours: 1));

    if (r.realStartDateTime != null && r.realEndDateTime != null) {
      return _safeRange(start, end);
    }

    final token = ApiManager.accessToken;
    if (token != null && token.isNotEmpty) {
      try {
        final det = await API.CarRequestsDetailsCall.call(
          bearerToken: token,
          id: r.id,
        );
        if (det.succeeded) {
          final j = det.jsonBody;

          final startFromApi =
              _gdt(j, [
                r'$.realStartDateTime', r'$.realStart', r'$.realStartAt',
                r'$.realPeriod.start', r'$.reportStart', r'$.startedAt',
                r'$.carRequest.realStart', r'$.carRequest.realStartAt',
              ]) ??
                  _gdt(j, [
                    r'$.startAt', r'$.startDateTime',
                    r'$.carRequest.startAt', r'$.carRequest.startDateTime',
                  ]);

          final endFromApi =
              _gdt(j, [
                r'$.realEndDateTime', r'$.realEnd', r'$.realEndAt',
                r'$.realPeriod.end', r'$.reportEnd', r'$.endedAt',
                r'$.carRequest.realEnd', r'$.carRequest.realEndAt',
              ]) ??
                  _gdt(j, [
                    r'$.endAt', r'$.endDateTime',
                    r'$.carRequest.endAt', r'$.carRequest.endDateTime',
                  ]);

          if (startFromApi != null) start = startFromApi;
          if (endFromApi != null)   end   = endFromApi;
        }
      } catch (_) {}
    }

    return _safeRange(start, end);
  }

  int _durationMinutes(DateTime start, DateTime end) {
    final a = start.isBefore(end) ? start : end;
    final b = start.isBefore(end) ? end   : start;
    return b.difference(a).inMinutes;
  }

  Future<void> _finishPeriod(CarRequestViewModel r) async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      return;
    }

    final startFallback = r.realStartDateTime ?? r.periodFrom;
    final endFallback   = r.realEndDateTime ?? r.periodTo ?? r.periodFrom.add(const Duration(hours: 1));
    DateTimeRange initial = _safeRange(startFallback, endFallback);

    _showListLoadingOverlay();
    try {
      final resolved = await _resolveRevTimeInitialRange(r);
      initial = resolved;
    } catch (_) {
    } finally {
      _hideListLoadingOverlay();
    }
    if (!mounted) return;

    final nowLocal = DateTime.now().toLocal();

    final picked = await PeriodModals.showFinishPeriodModal(
      context,
      requestId: r.id,
      currentStart: initial.start,
      currentEnd: nowLocal,
    );
    if (picked == null) return;

    final totalMinutes = _durationMinutes(picked.start, picked.end);
    if (totalMinutes >= 20 * 60) {
      AppNotifications.warning(context, 'Period must be less than 20 hours.');
      return;
    }

    _showListLoadingOverlay();
    try {
      final res = await API.CarRequestsFinishPeriodCall.call(
        bearerToken: token,
        id: r.id,
        realStart: picked.start,
        realEnd: picked.end,
      );

      if (res.succeeded) {
        AppNotifications.success(context, 'Period saved');
        await _loadFirstPage(showOverlay: false);
      } else {
        AppNotifications.error(context, 'Failed to save period (${res.statusCode}).');
      }
    } catch (_) {
      AppNotifications.error(context, 'Error saving period.');
    } finally {
      _hideListLoadingOverlay();
    }
  }

  Future<void> _extendPeriod(CarRequestViewModel r) async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      return;
    }

    _showListLoadingOverlay();
    late DateTimeRange initial;
    try {
      initial = await _resolveRevTimeInitialRange(r);
    } catch (_) {
      final start = r.realStartDateTime ?? r.periodFrom;
      final end   = r.realEndDateTime ?? r.periodTo ?? r.periodFrom.add(const Duration(hours: 1));
      initial     = _safeRange(start, end);
    } finally {
      _hideListLoadingOverlay();
    }
    if (!mounted) return;

    final picked = await PeriodModals.showExtendPeriodModal(
      context,
      requestId: r.id,
      currentStart: initial.start,
      currentEnd: initial.end,
    );
    if (picked == null) return;

    _showListLoadingOverlay();
    try {
      final res = await API.CarRequestsExtendPeriodCall.call(
        bearerToken: token,
        id: r.id,
        newEnd: picked.end,
      );

      if (res.succeeded) {
        AppNotifications.success(context, 'Request extended');
        await _loadFirstPage(showOverlay: false);
      } else {
        AppNotifications.error(context, 'Failed to extend (${res.statusCode}).');
      }
    } catch (_) {
      AppNotifications.error(context, 'Error extending request.');
    } finally {
      _hideListLoadingOverlay();
    }
  }

  Future<void> _finalKm(CarRequestViewModel r) async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      return;
    }

    _showListLoadingOverlay();
    int carKm = 0;
    try {
      final resp = await API.CarRequestsGetCall.call(
        bearerToken: token,
        id: r.id,
      );
      if (!resp.succeeded) {
        _hideListLoadingOverlay();
        AppNotifications.error(context, 'Failed (${resp.statusCode}).');
        return;
      }

      final j = resp.jsonBody;
      carKm = _gf<int>(j, r'$.carDto.km') ?? _gf<int>(j, r'$.car.km') ?? 0;
    } catch (_) {
      _hideListLoadingOverlay();
      AppNotifications.error(context, 'Error loading request data.');
      return;
    }
    _hideListLoadingOverlay();

    final value = await AppNotifications.showDriverFinalKmModal(
      context,
      initialKm: carKm,
      minKm: carKm,
    );
    if (value == null) return;

    if (value <= carKm) {
      AppNotifications.warning(
        context,
        'Final km ($value) must be greater than start km ($carKm).',
      );
      return;
    }

    _showListLoadingOverlay();
    try {
      final res = await API.CarRequestsFinishKmCall.call(
        bearerToken: token,
        id: r.id,
        endKm: value,
      );
      if (!mounted) return;

      if (res.succeeded) {
        AppNotifications.success(context, 'Final km saved');
        await _loadFirstPage(showOverlay: false);
      } else {
        AppNotifications.error(context, 'Failed (${res.statusCode}).');
      }
    } catch (_) {
      if (!mounted) return;
      AppNotifications.error(context, 'Error saving final km.');
    } finally {
      _hideListLoadingOverlay();
    }
  }

  Future<void> _confirmPending(CarRequestViewModel r) async {
    _showListLoadingOverlay();
    try {
      String? confirmId = (r.confirmationId ?? '').trim();
      if (confirmId.isEmpty) {
        final token = ApiManager.accessToken ?? '';
        final getById = await API.CarRequestsGetCall.call(
          bearerToken: token,
          id: r.id,
        );
        if (!getById.succeeded) {
          _hideListLoadingOverlay();
          AppNotifications.error(context, 'Failed to load confirmation (#${r.id}).');
          return;
        }
        confirmId = API.CarRequestsGetCall.confirmationId(getById)?.trim();
      }

      if (confirmId == null || confirmId.isEmpty) {
        _hideListLoadingOverlay();
        AppNotifications.warning(context, 'There is no pending confirmation for this request.');
        return;
      }

      final getRes = await API.CarRequestsGetConfirmationCall.call(confirmId: confirmId);
      if (!getRes.succeeded) {
        _hideListLoadingOverlay();
        AppNotifications.error(context, 'Failed to load confirmation data (${getRes.statusCode}).');
        return;
      }

      final reqId      = API.CarRequestsGetConfirmationCall.id(getRes) ?? r.id;
      final userName   = API.CarRequestsGetConfirmationCall.userName(getRes) ?? r.userName;
      final driver     = API.CarRequestsGetConfirmationCall.driver(getRes) ?? r.driverName ?? '';
      final departure  = API.CarRequestsGetConfirmationCall.departure(getRes) ?? r.routeDeparture;
      final destinations = API.CarRequestsGetConfirmationCall.destinations(getRes).isNotEmpty
          ? API.CarRequestsGetConfirmationCall.destinations(getRes)
          : (r.destinations ?? const <String>[]);
      final from = API.CarRequestsGetConfirmationCall.startAt(getRes) ?? r.periodFrom;
      final to   = API.CarRequestsGetConfirmationCall.endAt(getRes) ??
          (r.periodTo ?? r.periodFrom.add(const Duration(hours: 1)));

      _hideListLoadingOverlay();

      final confirmed = await AppNotifications.showConfirmPeriodModal(
        context,
        requestId: reqId,
        userName: userName,
        driver: driver,
        departure: departure,
        destinations: destinations,
        periodFrom: from,
        periodTo: to,
      );
      if (confirmed == null) return;

      if (confirmed == true) {
        _showListLoadingOverlay();
        try {
          final res = await API.CarRequestsConfirmByTokenCall.call(
            confirmId: confirmId,
            txtReason: null,
          );
          if (!mounted) return;
          if (res.succeeded) {
            AppNotifications.success(context, 'Period confirmed!');
            await _loadFirstPage(showOverlay: false);
          } else {
            AppNotifications.error(context, 'Failed to confirm (${res.statusCode}).');
          }
        } finally {
          _hideListLoadingOverlay();
        }
        return;
      }

      final reason = await AppNotifications.showDisagreeReasonModal(context);
      final reasonToSend = (reason == null || reason.trim().isEmpty)
          ? 'User disagreed (no reason provided)'
          : reason.trim();

      _showListLoadingOverlay();
      try {
        final res = await API.CarRequestsConfirmByTokenCall.call(
          confirmId: confirmId,
          txtReason: reasonToSend,
        );
        if (!mounted) return;
        if (res.succeeded) {
          AppNotifications.info(context, 'Disagreement has been recorded.');
          await _loadFirstPage(showOverlay: false);
        } else {
          AppNotifications.error(context, 'Failed to record disagreement (${res.statusCode}).');
        }
      } finally {
        _hideListLoadingOverlay();
      }
    } catch (e) {
      _hideListLoadingOverlay();
      AppNotifications.error(context, 'Error while processing confirmation.');
    }
  }

  Future<void> _revisePendingPeriod(CarRequestViewModel r) async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      return;
    }

    _showListLoadingOverlay();
    late DateTimeRange initial;
    try {
      initial = await _resolveRevTimeInitialRange(r);
    } catch (_) {
      final start = r.realStartDateTime ?? r.periodFrom;
      final end   = r.realEndDateTime ?? r.periodTo ?? r.periodFrom.add(const Duration(hours: 1));
      initial     = _safeRange(start, end);
    } finally {
      _hideListLoadingOverlay();
    }
    if (!mounted) return;

    final picked = await PeriodModals.showRevisePeriodModal(
      context,
      requestId: r.id,
      recordedStart: initial.start,
      recordedEnd: initial.end,
    );
    if (picked == null) return;

    _showListLoadingOverlay();
    try {
      final res = await API.CarRequestsFinishPeriodCall.call(
        bearerToken: token,
        id: r.id,
        realStart: picked.start,
        realEnd: picked.end,
      );
      if (res.succeeded) {
        AppNotifications.success(context, 'Period revised');
        await _loadFirstPage(showOverlay: false);
      } else {
        AppNotifications.error(context, 'Failed to revise (${res.statusCode}).');
      }
    } catch (_) {
      AppNotifications.error(context, 'Error revising period.');
    } finally {
      _hideListLoadingOverlay();
    }
  }

  Future<void> _revTimeFinished(CarRequestViewModel r) async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      return;
    }

    final startFallback = r.realStartDateTime ?? r.periodFrom;
    final endFallback   = r.realEndDateTime ?? r.periodTo ?? r.periodFrom.add(const Duration(hours: 1));
    DateTimeRange initial = _safeRange(startFallback, endFallback);

    _showListLoadingOverlay();
    try {
      final resolved = await _resolveRevTimeInitialRange(r);
      initial = resolved;
    } catch (_) {
    } finally {
      _hideListLoadingOverlay();
    }
    if (!mounted) return;

    final picked = await PeriodModals.showFinishPeriodModal(
      context,
      requestId: r.id,
      currentStart: initial.start,
      currentEnd: initial.end,
    );
    if (picked == null) return;

    final hours = picked.end.difference(picked.start).inHours;
    if (hours >= 20) {
      AppNotifications.error(context, 'Period must be less than 20 hours.');
      return;
    }

    _showListLoadingOverlay();
    try {
      final res = await API.CarRequestsFinishPeriodCall.call(
        bearerToken: token,
        id: r.id,
        realStart: picked.start,
        realEnd: picked.end,
      );
      if (res.succeeded) {
        AppNotifications.success(context, 'Period saved');
        await _loadFirstPage(showOverlay: false);
      } else {
        AppNotifications.error(context, 'Failed to save period (${res.statusCode}).');
      }
    } catch (_) {
      AppNotifications.error(context, 'Error saving period.');
    } finally {
      _hideListLoadingOverlay();
    }
  }

  Future<void> _adjustFinished(CarRequestViewModel r) async {
    _showListLoadingOverlay();

    CarRequestViewModel initial;
    try {
      initial = await _fetchFullRequest(r);
    } catch (_) {
      initial = r;
    } finally {
      _hideListLoadingOverlay();
    }
    if (!mounted) return;

    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => W.CarRequestWizard(
          mode: W.CarRequestFormMode.adjust,
          initial: initial,
          isAdmin: true,
          fetchUsers: _fetchUsersForWizard,
          fetchUserCostAllocs: _fetchUserCostAllocsForWizard,
          submitCarRequest: _submitCarRequestForWizard,
        ),
      ),
    );

    if (edited == true && mounted) {
      await _loadFirstPage();
      AppNotifications.success(context, 'Request adjusted');
    }
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

    String _s(dynamic v) => v?.toString() ?? '';

    _showListLoadingOverlay();
    try {
      final res = await API.TrafficIncidentByCarRequestCall.call(
        bearerToken: token,
        carRequestId: reqId,
      );
      if (!mounted) return;

      if (!res.succeeded) {
        _hideListLoadingOverlay();
        AppNotifications.error(context, 'Failed to load incident (${res.statusCode}).');
        return;
      }

      final j = res.jsonBody;

      final otherPassengers = <String>[];
      final p1 = _s(getJsonField(j, r'$.passanger1')).trim();
      final p2 = _s(getJsonField(j, r'$.passanger2')).trim();
      final p3 = _s(getJsonField(j, r'$.passanger3')).trim();
      if (p1.isNotEmpty) otherPassengers.add(p1);
      if (p2.isNotEmpty) otherPassengers.add(p2);
      if (p3.isNotEmpty) otherPassengers.add(p3);

      List<String> registeredPassengers =
          API.TrafficIncidentByCarRequestCall.passengers(res) ?? const <String>[];

      if (registeredPassengers.isEmpty) {
        try {
          final cr = await API.CarRequestsGetCall.call(
            bearerToken: token,
            id: r.id,
          );
          if (cr.succeeded) {
            final csv = API.CarRequestsGetCall.passengersCsv(cr);
            if (csv != null && csv.trim().isNotEmpty) {
              registeredPassengers.addAll(
                csv.split(RegExp(r'[;,]'))
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty),
              );
            }

            final ids = API.CarRequestsGetCall.passengersIds(cr);
            if (ids.isNotEmpty) {
              try {
                final api = const API.CarRequestsApi();
                final backendUsers = await api.getUsers();
                final byId = {
                  for (final u in backendUsers) u.id: u.fullName,
                };
                for (final id in ids) {
                  final name = byId[id];
                  if (name != null && name.trim().isNotEmpty) {
                    registeredPassengers.add(name.trim());
                  }
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      final rawPhotos = API.TrafficIncidentByCarRequestCall.photos(res);
      final images = <IncidentImage>[];
      for (final e in rawPhotos) {
        final baseName = _s(e['fileName']).trim();
        final ext      = _s(e['extension']).trim();
        final fileName = (baseName + ext).trim().isEmpty ? 'image' : (baseName + ext);

        final rawB64 = _s(e['base64']).trim().isEmpty
            ? _s(e['base64Content']).trim()
            : _s(e['base64']).trim();
        if (rawB64.isEmpty) continue;

        final bytes = _decodeIncidentBase64(rawB64);
        if (bytes == null) continue;

        images.add(IncidentImage(fileName: fileName, bytes: bytes));
      }

      _hideListLoadingOverlay();

      await AppNotifications.showTrafficIncidentModal(
        context: context,
        title: 'Traffic Incident',
        incidentId: API.TrafficIncidentByCarRequestCall.id(res) ?? 0,
        carRequestId: API.TrafficIncidentByCarRequestCall.carRequestId(res) ?? reqId,
        driverName: API.TrafficIncidentByCarRequestCall.driverName(res),
        creationAt: API.TrafficIncidentByCarRequestCall.creationAt(res),
        incidentAt: API.TrafficIncidentByCarRequestCall.incidentAt(res),
        hasInjuries: API.TrafficIncidentByCarRequestCall.hadInjuries(res),
        injuriesDetails: API.TrafficIncidentByCarRequestCall.injuriesDetails(res),
        incidentLocation: API.TrafficIncidentByCarRequestCall.incidentLocation(res),
        incidentSummary: API.TrafficIncidentByCarRequestCall.incidentSummary(res),
        damagePlate: API.TrafficIncidentByCarRequestCall.damagePlate(res),
        damageSummary: API.TrafficIncidentByCarRequestCall.damageSummary(res),
        passengers: API.TrafficIncidentByCarRequestCall.passengers(res),
        otherPassengers: API.TrafficIncidentByCarRequestCall.otherPassengers(res),
        images: images,
      );
    } catch (e) {
      if (!mounted) return;
      _hideListLoadingOverlay();
      AppNotifications.error(context, 'Error loading incident.');
    }
  }


  Future<void> _openDetails(CarRequestViewModel r) async {
    final parentCtx = context;
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(parentCtx, 'Session expired. Please sign in again.');
      return;
    }

    _showListLoadingOverlay();
    try {
      final det = await API.CarRequestsDetailsCall.call(
        bearerToken: token,
        id: r.id,
      );

      if (!mounted) return;

      if (det.succeeded) {
        final jj = det.jsonBody;

        final int? statusCode = API.CarRequestsDetailsCall.curStatus(jj);
        final status = API.parseDetailedCarRequestStatus(statusCode);

        final realFrom = API.CarRequestsDetailsCall.realStart(jj);
        final realTo   = API.CarRequestsDetailsCall.realEnd(jj);
        final startKm  = API.CarRequestsDetailsCall.startKm(jj);
        final endKm    = API.CarRequestsDetailsCall.endKm(jj);
        final finalKmOk = (startKm != null && endKm != null && endKm > startKm);
        final periodConfirmedOk =
            (API.CarRequestsDetailsCall.confirmationId(jj) ?? '').isEmpty;

        final comp = API.CarRequestsDetailsCall.company(jj);

        Future.microtask(() => AppNotifications.showCarRequestDetailsModal(
          parentCtx,
          id: API.CarRequestsDetailsCall.id(jj) ?? r.id,
          userName: API.CarRequestsDetailsCall.userName(jj) ?? r.userName,
          periodFrom: API.CarRequestsDetailsCall.startAt(jj) ?? r.periodFrom,
          periodTo: API.CarRequestsDetailsCall.endAt(jj) ?? r.periodTo,

          driver: API.CarRequestsDetailsCall.driver(jj) ?? r.driverName,
          company: comp,
          model: API.CarRequestsDetailsCall.model(jj) ?? r.model,

          childSeat: API.CarRequestsDetailsCall.childSeat(jj),

          licensePlate: (() {
            final sci = (getJsonField(jj, r'$.specialCarInfo') ??
                getJsonField(jj, r'$.carDto.specialCarInfo') ??
                getJsonField(jj, r'$.car.specialCarInfo'))
                ?.toString()
                .trim();
            final lp  = API.CarRequestsDetailsCall.license(jj) ?? r.licensePlate;
            return (sci != null && sci.isNotEmpty) ? sci : lp;
          })(),

          hadIncident: API.CarRequestsDetailsCall.hadIncident(jj),
          departure: API.CarRequestsDetailsCall.departure(jj) ?? r.routeDeparture,
          destinations: API.CarRequestsDetailsCall.destinations(jj).isNotEmpty
              ? API.CarRequestsDetailsCall.destinations(jj)
              : r.destinations,
          notes: API.CarRequestsDetailsCall.notes(jj) ?? r.notes,

          statusText: status.uiLabel,
          statusColor: status.uiColor,

          realPeriodFrom: realFrom,
          realPeriodTo: realTo,
          startKm: startKm,
          endKm: endKm,
          cancelReason: API.CarRequestsDetailsCall.cancelReason(jj),
          disacordReason: API.CarRequestsDetailsCall.disacordReason(jj),
          periodConfirmedOk: periodConfirmedOk,
          finalKmOk: finalKmOk,
          costAllocs: API.CarRequestsDetailsCall.costAllocs(jj),
          flights: API.CarRequestsDetailsCall.flights(jj),
          passengersCsv: API.CarRequestsDetailsCall.passengersCsv(jj),
        ));
      } else {
        AppNotifications.error(
          parentCtx,
          'Failed to load details (${det.statusCode}).',
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppNotifications.error(parentCtx, 'Failed to load details.');
    } finally {
      _hideListLoadingOverlay();
    }
  }

  Future<void> _openRequestSheet(CarRequestViewModel r) async {
    final parentCtx = context;

    _showListLoadingOverlay();
    _RequestSheetPayload? payload;
    try {
      payload = await _preloadRequestForSheet(r);
    } finally {
      _hideListLoadingOverlay();
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: parentCtx,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final hasFull = payload != null;
        final flags = payload?.flags ??
            const _ComputedFlags(
              canFinalKm: false,
              showConfirm: false,
              showRevise: false,
              isFinished: false,
              hasIncident: false,
            );

        final String licenseOrSpec = (() {
          final fromPayload = _extractSpecialFromJson(payload?.json);
          if (fromPayload.isNotEmpty) return fromPayload;
          final fromModel = (r.specialCarInfo ?? '').trim();
          if (fromModel.isNotEmpty) return fromModel;
          return r.licensePlate;
        })();

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
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
                Text('#${r.id} — ${r.userName}',
                    style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _kv('Scheduled Period', _fmtPeriod(r.periodFrom, r.periodTo)),
                _kv('Driver', r.driverName),
                _kv('Model',
                    '${r.model}  |  Child Seat: ${r.childSeat ? 'Yes' : 'No'}'),
                _kv('License Plate', licenseOrSpec),
                if (r.notes != null && r.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Notes', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(r.notes!),
                ],
                const SizedBox(height: 12),
                _pillButton(
                  'DETAILS',
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    Future.microtask(() => _openDetails(r));
                  },
                  bg: const Color(0xFF3B82F6),
                ),
                const SizedBox(height: 10),

                if (_canEdit(r)) ...[
                  _pillButton(
                    'EDIT REQUEST',
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Future.microtask(() => _handleEditTap(r, parentCtx));
                    },
                    bg: const Color(0xFF8BB9FF),
                  ),
                  const SizedBox(height: 10),
                ],

                if (_canCancel(r)) ...[
                  _pillButton(
                    'CANCEL REQUEST',
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Future.microtask(() => _cancelRequest(r));
                    },
                    bg: const Color(0xFFE34A48),
                  ),
                  const SizedBox(height: 10),
                ],

                if (_canFinish(r)) ...[
                  _pillButton(
                    'FINISH',
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Future.microtask(() => _finishPeriod(r));
                    },
                    bg: const Color(0xFF059669),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_canExtend(r)) ...[
                  _pillButton(
                    'EXTEND',
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Future.microtask(() => _extendPeriod(r));
                    },
                    bg: const Color(0xFF34D399),
                  ),
                  const SizedBox(height: 10),
                ],

                if (hasFull && flags.canFinalKm) ...[
                  _pillButton(
                    'FINAL KM',
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Future.microtask(() => _finalKm(r));
                    },
                    bg: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 10),
                ],

                if (hasFull && flags.showConfirm) ...[
                  _pillButton(
                    'CONFIRM',
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Future.microtask(() => _confirmPending(r));
                    },
                    bg: const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 10),
                ],

                if (hasFull && flags.showRevise) ...[
                  _pillButton(
                    'REVISE',
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Future.microtask(() => _revisePendingPeriod(r));
                    },
                    bg: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 10),
                ],

                if (hasFull && flags.isFinished) ...[
                  _pillButton(
                    'REV TIME',
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Future.microtask(() => _revTimeFinished(r));
                    },
                    bg: const Color(0xFFEAB308),
                  ),
                  const SizedBox(height: 10),
                  _pillButton(
                    'ADJUST',
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Future.microtask(() => _adjustFinished(r));
                    },
                    bg: const Color(0xFFD97706),
                  ),
                  const SizedBox(height: 10),
                ],

                if (hasFull && flags.hasIncident) ...[
                  _pillButton(
                    'INCIDENT',
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Future.microtask(() => _openIncident(r));
                    },
                    bg: const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 10),
                ],

                _pillButton(
                  'REPEAT REQUEST',
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    Future.microtask(() => _repeatRequest(r));
                  },
                  bg: const Color(0xFF2563EB),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pillButton(
      String label, {
        VoidCallback? onPressed,
        Color bg = const Color(0xFF8BB9FF),
        String? tooltip,
      }) {
    final isDisabled = onPressed == null;

    Color fgFor(Color bg) {
      return isDisabled ? Colors.white70 : Colors.white;
    }

    final style = ButtonStyle(
      backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.disabled)) {
          return HSLColor.fromColor(bg).withLightness(0.78).toColor();
        }
        if (states.contains(MaterialState.pressed)) {
          return HSLColor.fromColor(bg).withLightness(0.40).toColor();
        }
        if (states.contains(MaterialState.hovered) ||
            states.contains(MaterialState.focused)) {
          return HSLColor.fromColor(bg).withLightness(0.52).toColor();
        }
        return bg;
      }),
      foregroundColor:
      MaterialStateProperty.resolveWith<Color>((_) => fgFor(bg)),
      overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
        if (states.contains(MaterialState.pressed)) {
          return Colors.black.withOpacity(0.08);
        }
        if (states.contains(MaterialState.hovered) ||
            states.contains(MaterialState.focused)) {
          return Colors.black.withOpacity(0.04);
        }
        return null;
      }),
      elevation: MaterialStateProperty.resolveWith<double>(
            (states) => states.contains(MaterialState.disabled) ? 0 : 6,
      ),
      shadowColor: MaterialStateProperty.resolveWith<Color?>(
            (states) => states.contains(MaterialState.disabled)
            ? Colors.transparent
            : Colors.black12,
      ),
      padding: MaterialStateProperty.all<EdgeInsets>(
        const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      ),
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      minimumSize:
      MaterialStateProperty.all<Size>(const Size.fromHeight(48)),
      animationDuration: const Duration(milliseconds: 120),
    );

    final button = SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    if (tooltip != null && tooltip.trim().isNotEmpty && isDisabled) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}

class _RequestSheetPayload {
  final dynamic json;
  final _ComputedFlags flags;
  const _RequestSheetPayload({required this.json, required this.flags});
}

Future<_RequestSheetPayload?> _preloadRequestForSheet(CarRequestViewModel r) async {
  final token = ApiManager.accessToken;
  if (token == null || token.isEmpty) return null;

  try {
    final resp = await API.CarRequestsGetCall.call(
      bearerToken: token,
      id: r.id,
    );
    if (!resp.succeeded) return null;

    final j = resp.jsonBody;

    var flags = _computeFlagsFromFullJson(j, r.status);

    if (!flags.hasIncident) {
      try {
        final inc = await API.TrafficIncidentByCarRequestCall.call(
          bearerToken: token,
          carRequestId: int.parse(r.id),
        );
        if (inc.succeeded) {
          final incId = API.TrafficIncidentByCarRequestCall.id(inc) ?? 0;
          if (incId > 0) {
            flags = _ComputedFlags(
              canFinalKm: flags.canFinalKm,
              showConfirm: flags.showConfirm,
              showRevise: flags.showRevise,
              isFinished: flags.isFinished,
              hasIncident: true,
            );
          }
        }
      } catch (_) {
      }
    }

    return _RequestSheetPayload(json: j, flags: flags);
  } catch (_) {
    return null;
  }
}

class _CarRequestCard extends StatelessWidget {
  const _CarRequestCard({
    required this.data,
    required this.onTap,
  });

  final CarRequestViewModel data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget pill(String text, Color bg, {Color? fg}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg ?? Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final statusLabel = data.status.uiLabelFromRaw(data.statusName);
    final statusBg = data.status.uiColorFromRaw(data.statusName);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  ],
                ),
              ),
              pill(statusLabel, statusBg),
            ]),
            const SizedBox(height: 10),
            _kv('Departure', data.routeDeparture),
            if (data.destinations.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Destination(s)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ...data.destinations.take(2).map(
                    (d) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [const Text('• '), Expanded(child: Text(d))],
                ),
              ),
              if (data.destinations.length > 2)
                const Text('+ more', style: TextStyle(color: Colors.black54)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CarRequestsTable extends StatelessWidget {
  const _CarRequestsTable({
    required this.items,
    required this.onRowTap,
  });

  final List<CarRequestViewModel> items;
  final void Function(CarRequestViewModel) onRowTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: DataTable(
        headingRowColor: MaterialStatePropertyAll(theme.secondaryBackground),
        columns: const [
          DataColumn(label: Text('Nr')),
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Scheduled Period')),
          DataColumn(label: Text('Route')),
          DataColumn(label: Text('Driver')),
          DataColumn(label: Text('Model')),
          DataColumn(label: Text('License Plate')),
          DataColumn(label: Text('Status')),
        ],
        rows: items.map((r) {
          final statusChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: r.status.uiColorFromRaw(r.statusName),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              r.status.uiLabelFromRaw(r.statusName),
              style: const TextStyle(color: Colors.white),
            ),
          );

          final routePreview = [
            'Departure: ${r.routeDeparture}',
            if (r.destinations.isNotEmpty)
              'Destinations: ${r.destinations.take(2).join(' • ')}',
          ].join('\n');

          return DataRow(
            onSelectChanged: (_) => onRowTap(r),
            cells: [
              DataCell(Text(r.id)),
              DataCell(Text(r.userName)),
              DataCell(Text(_fmtPeriod(r.periodFrom, r.periodTo))),
              DataCell(Text(routePreview)),
              DataCell(Text(r.driverName)),
              DataCell(Text(
                  '${r.model}  |  Child Seat: ${r.childSeat ? 'Yes' : 'No'}')),
              DataCell(Text(r.specification)),
              DataCell(statusChip),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ComputedFlags {
  final bool canFinalKm;
  final bool showConfirm;
  final bool showRevise;
  final bool isFinished;
  final bool hasIncident;

  const _ComputedFlags({
    required this.canFinalKm,
    required this.showConfirm,
    required this.showRevise,
    required this.isFinished,
    required this.hasIncident,
  });
}

_ComputedFlags _computeFlagsFromFullJson(
    dynamic j,
    API.DetailedCarRequestStatus status,
    ) {
  final isFinished = status == API.DetailedCarRequestStatus.finished;

  final hasConfirmId = ((getJsonField(j, r'$.confirmationId') ??
      getJsonField(j, r'$.carRequest.confirmationId'))
      ?.toString() ?? '')
      .trim()
      .isNotEmpty;

  final disacord = ((getJsonField(j, r'$.disacordReason') ??
      getJsonField(j, r'$.carRequest.disacordReason'))
      ?.toString() ?? '')
      .trim();
  final showRevise = disacord.isNotEmpty;

  final startKm = _gf<int>(j, r'$.startKm') ?? _gf<int>(j, r'$.carRequest.startKm');
  final endKm   = _gf<int>(j, r'$.endKm')   ?? _gf<int>(j, r'$.carRequest.endKm');
  final canFinalKm = status == API.DetailedCarRequestStatus.pending &&
      startKm != null && endKm != null && endKm <= startKm;

  final trafficIncidentId =
      _gf<num>(j, r'$.trafficIncidentId') ??
          _gf<num>(j, r'$.TrafficIncidentId') ??
          _gf<num>(j, r'$.carRequest.trafficIncidentId');
  final hasIncident = (trafficIncidentId != null && trafficIncidentId > 0);

  return _ComputedFlags(
    canFinalKm: canFinalKm,
    showConfirm: hasConfirmId,
    showRevise: showRevise,
    isFinished: isFinished,
    hasIncident: hasIncident,
  );
}

Future<List<W.UserLite>> _fetchUsersForWizard() async {
  try {
    final api = const API.CarRequestsApi();
    final backendUsers = await api.getUsers();
    return backendUsers
        .map((u) => W.UserLite(id: u.id, fullName: u.fullName))
        .toList();
  } catch (_) {
    AppNotifications.error(
        appNavigatorKey.currentContext!, 'Failed to load users.');
    return <W.UserLite>[];
  }
}

Future<List<W.CostAllocLite>> _fetchUserCostAllocsForWizard(int ownerId) async {
  final token = ApiManager.accessToken;
  if (token == null || token.isEmpty) {
    AppNotifications.error(appNavigatorKey.currentContext!,
        'Session expired. Please sign in again.');
    return <W.CostAllocLite>[];
  }

  try {
    final res = await API.CostAllocationsByUserCall.call(
      userId: ownerId,
      bearerToken: token,
    );
    if (!res.succeeded) {
      AppNotifications.error(appNavigatorKey.currentContext!,
          'Failed to load cost centers (${res.statusCode}).');
      return <W.CostAllocLite>[];
    }

    final items = API.CostAllocationsByUserCall.items(res);
    return items
        .map((it) {
      final id = API.CostAllocationsByUserCall.id(it);
      final name =
      (API.CostAllocationsByUserCall.name(it) ?? '').trim();
      if (id == null || name.isEmpty) return null;
      return W.CostAllocLite(id: id, name: name);
    })
        .whereType<W.CostAllocLite>()
        .toList();
  } catch (_) {
    AppNotifications.error(
        appNavigatorKey.currentContext!, 'Error loading cost centers.');
    return <W.CostAllocLite>[];
  }
}
