import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mitsubishi/car_request/car_request_model.dart';
import 'package:mitsubishi/car_request/car_request_wizard.dart' as W;
import 'package:mitsubishi/utils/car_request_status_ui.dart';
import 'package:mitsubishi/widgets/notifications/car_request_period_modals.dart';
import '/backend/api_requests/api_calls.dart' as API;
import '/backend/api_requests/api_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/auth/custom_auth/session_utils.dart';
import '/menu/app_drawer.dart';
import '/widgets/add_fab_button.dart';
import '/widgets/notifications/app_notifications.dart';

DateTime _asLocal(DateTime d) => d.isUtc ? d.toLocal() : d;
DateTime? _asLocalOpt(DateTime? d) => d == null ? null : _asLocal(d);

DateTime? _parseDateFlexible(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.isUtc ? v.toLocal() : v;
  if (v is String) {
    final s = v.trim();
    final msMatch = RegExp(r'\/Date\((\d+)\)\/').firstMatch(s);
    if (msMatch != null) {
      final ms = int.tryParse(msMatch.group(1)!);
      if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt.isUtc ? dt.toLocal() : dt;
  }
  if (v is int) {
    if (v > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
    if (v > 1000000000) return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true).toLocal();
  }
  if (v is num) return _parseDateFlexible(v.toInt());
  return null;
}

String _fmtDtShort(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _fmtPeriod(DateTime from, DateTime? to) {
  final f = '${from.day.toString().padLeft(2, '0')}/${from.month.toString().padLeft(2, '0')} ${from.hour.toString().padLeft(2, '0')}:${from.minute.toString().padLeft(2, '0')}';
  if (to == null) return f;
  final t = '${to.day.toString().padLeft(2, '0')}/${to.month.toString().padLeft(2, '0')} ${to.hour.toString().padLeft(2, '0')}:${to.minute.toString().padLeft(2, '0')}';
  return '$f  —  $t';
}

bool _isReschedPending(dynamic raw) {
  if (raw == null) return false;
  if (raw is num) return raw.toInt() == 0;
  final s = raw.toString().trim();
  final n = int.tryParse(s);
  if (n != null) return n == 0;
  return s.toLowerCase() == 'pending';
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 160, child: Text(k, style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
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

String? _rawConfirmIdFromListItem(dynamic d) {
  final s = (getJsonField(d, r'$.confirmationId') ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

class _PendingResched {
  final DateTime start;
  final DateTime end;
  final DateTime? createdAt;
  const _PendingResched({required this.start, required this.end, this.createdAt});
}

_PendingResched? _extractPendingFromAny(dynamic root) {
  List<dynamic> _asList(dynamic x) => (x is List) ? x : const [];
  final all = <dynamic>[];
  all.addAll(_asList(getJsonField(root, r'$.reschedules')));
  all.addAll(_asList(getJsonField(root, r'$.Reschedules')));
  all.addAll(_asList(getJsonField(root, r'$.carRequest.reschedules')));
  all.addAll(_asList(getJsonField(root, r'$.carRequest.Reschedules')));
  if (all.isEmpty) return null;
  final candidates = <Map<String, dynamic>>[];
  for (final e in all) {
    final st = getJsonField(e, r'$.rescheduleStatus') ?? getJsonField(e, r'$.RescheduleStatus');
    if (!_isReschedPending(st)) continue;
    final s = _parseDateFlexible(getJsonField(e, r'$.newScheduledStartDate') ?? getJsonField(e, r'$.NewScheduledStartDate'));
    final t = _parseDateFlexible(getJsonField(e, r'$.newScheduledEndDate') ?? getJsonField(e, r'$.NewScheduledEndDate'));
    final c = _parseDateFlexible(getJsonField(e, r'$.creationDate') ?? getJsonField(e, r'$.CreationDate'));
    if (s != null && t != null) candidates.add({'s': s, 't': t, 'c': c});
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) {
    final A = (a['c'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final B = (b['c'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return B.compareTo(A);
  });
  final top = candidates.first;
  return _PendingResched(
    start: _asLocal(top['s'] as DateTime),
    end: _asLocal(top['t'] as DateTime),
    createdAt: top['c'] as DateTime?,
  );
}

Widget _emptyListMessage({ScrollController? controller}) {
  return ListView(
    controller: controller,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
    children: const [
      SizedBox(height: 40),
      Center(
        child: Text(
          'No data available in table',
          style: TextStyle(fontSize: 16),
        ),
      ),
      SizedBox(height: 12),
    ],
  );
}

class _ActionPerms {
  final bool details;
  final bool edit;
  final bool cancel;
  final bool extend;
  final bool confirm;
  final bool repeat;
  final bool change;
  const _ActionPerms({
    this.details = true,
    this.edit = false,
    this.cancel = false,
    this.extend = false,
    this.confirm = false,
    this.repeat = false,
    this.change = false,
  });
}

class MyRequestsWidget extends StatelessWidget {
  const MyRequestsWidget({super.key});
  static const String routeName = 'MyRequests';
  static const String routePath = '/my-requests';

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final titleStyle = theme.bodyMedium.override(
      font: GoogleFonts.inter(fontWeight: FontWeight.w700),
      color: theme.primaryText,
      fontSize: 20,
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F2),
        appBar: AppBar(
          title: Text('My Requests', style: titleStyle),
          backgroundColor: theme.secondaryBackground,
          foregroundColor: theme.primaryText,
          elevation: 0.5,
          bottom: TabBar(
            isScrollable: true,
            labelColor: theme.primaryText,
            unselectedLabelColor: theme.secondaryText,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
            indicatorColor: theme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'Booked'),
              Tab(text: 'By Others'),
              Tab(text: 'Passenger'),
            ],
          ),
        ),
        drawer: AppDrawer(
          onGoCarRequest: () => context.goNamed('CarRequest'),
          onGoDrivers: () => context.goNamed('Drivers'),
          onGoCars: () => context.goNamed('Cars'),
        ),
        floatingActionButton: Builder(
          builder: (innerCtx) => Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 12),
            child: AddFabButton(
              heroTag: 'myReqAddFab',
              onTap: () async {
                final created = await Navigator.of(innerCtx).push<bool>(
                  MaterialPageRoute(builder: (_) => const _W_CreatorLauncher()),
                );
                final ctrl = DefaultTabController.maybeOf(innerCtx);
                if (ctrl != null) _MyRequestsTabBus.instance.reloadTab(ctrl.index);
                if (created == true) AppNotifications.success(innerCtx, 'Request created');
              },
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: const TabBarView(
          children: [
            _RequestsListPage(kind: _ListKind.bookedCars),
            _RequestsListPage(kind: _ListKind.bookedByOthers),
            _RequestsListPage(kind: _ListKind.bookedAsPassenger),
          ],
        ),
      ),
    );
  }
}

class _W_CreatorLauncher extends StatefulWidget {
  const _W_CreatorLauncher({super.key});
  @override
  State<_W_CreatorLauncher> createState() => _W_CreatorLauncherState();
}

class _W_CreatorLauncherState extends State<_W_CreatorLauncher> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const W.CarRequestWizard(
            mode: W.CarRequestFormMode.create,
            fetchUsers: _fetchUsersForWizard,
            fetchUserCostAllocs: _fetchUserCostAllocsForWizard,
            submitCarRequest: _submitCarRequestForWizard,
          ),
        ),
      );
      if (!mounted) return;
      if (created == true) AppNotifications.success(context, 'Request created');
      Navigator.of(context).pop(created == true);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _MyRequestsTabBus {
  _MyRequestsTabBus._();
  static final instance = _MyRequestsTabBus._();
  final _reloadControllers = <int, StreamController<void>>{};
  Stream<void> streamForIndex(int i) =>
      (_reloadControllers[i] ??= StreamController<void>.broadcast()).stream;
  void reloadTab(int i) => _reloadControllers[i]?.add(null);
}

Future<List<W.UserLite>> _fetchUsersForWizard() async {
  try {
    final api = const API.CarRequestsApi();
    final backendUsers = await api.getUsers();
    return backendUsers.map((u) => W.UserLite(id: u.id, fullName: u.fullName)).toList();
  } catch (_) {
    final ctx = appNavigatorKey.currentContext;
    if (ctx != null) AppNotifications.error(ctx, 'Failed to load users.');
    return <W.UserLite>[];
  }
}

Future<List<W.CostAllocLite>> _fetchUserCostAllocsForWizard(int ownerId) async {
  final token = ApiManager.accessToken;
  final ctx = appNavigatorKey.currentContext;
  if (token == null || token.isEmpty) {
    if (ctx != null) AppNotifications.error(ctx, 'Session expired. Please sign in again.');
    return <W.CostAllocLite>[];
  }
  try {
    final res = await API.CostAllocationsByUserCall.call(
      userId: ownerId,
      bearerToken: token,
    );
    if (!res.succeeded) {
      if (ctx != null) AppNotifications.error(ctx, 'Failed to load cost centers (${res.statusCode}).');
      return <W.CostAllocLite>[];
    }
    final items = API.CostAllocationsByUserCall.items(res);
    return items
        .map((it) {
      final id = API.CostAllocationsByUserCall.id(it);
      final name = (API.CostAllocationsByUserCall.name(it) ?? '').trim();
      if (id == null || name.isEmpty) return null;
      return W.CostAllocLite(id: id, name: name);
    })
        .whereType<W.CostAllocLite>()
        .toList();
  } catch (_) {
    if (ctx != null) AppNotifications.error(ctx, 'Error loading cost centers.');
    return <W.CostAllocLite>[];
  }
}

Future<bool> _submitCarRequestForWizard(
    Map<String, dynamic> body, {
      int? id,
      bool useAdminUpdate = false,
    }) async {
  final token = ApiManager.accessToken;
  final ctx = appNavigatorKey.currentContext;
  if (token == null || token.isEmpty) {
    if (ctx != null) AppNotifications.error(ctx, 'Session expired. Please sign in again.');
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
        (body['CarRequestsCostAllocs'] as List?)?.cast<Map<String, dynamic>>() ?? const [],
        carRequestDests: (body['CarRequestDests'] as List?)?.cast<Map<String, dynamic>>(),
        note: body['Note'] as String?,
        specialCarInfo: body['SpecialCarInfo'] as String?,
        passanger1: body['Passanger1'] as String?,
        passanger2: body['Passanger2'] as String?,
        passanger3: body['Passanger3'] as String?,
        childSeat: body['ChildSeat'] as bool?,
      );
      if (res.succeeded) return true;
      if (ctx != null) AppNotifications.error(ctx, 'Failed to update (admin) (${res.statusCode}).');
      return false;
    }
    final res = (id == null)
        ? await API.CarRequestsCreateCall.call(body: body, bearerToken: token)
        : await API.CarRequestsUpdateCall.call(id: id, body: body, bearerToken: token);
    if (res.succeeded) return true;
    if (ctx != null) AppNotifications.error(ctx, 'Failed to save request (${res.statusCode}).');
    return false;
  } catch (_) {
    if (ctx != null) AppNotifications.error(ctx, 'Error saving request.');
    return false;
  }
}

enum _ListKind { bookedCars, bookedByOthers, bookedAsPassenger }

class _RequestsListPage extends StatefulWidget {
  const _RequestsListPage({required this.kind});
  final _ListKind kind;
  @override
  State<_RequestsListPage> createState() => _RequestsListPageState();
}

class _RequestsListPageState extends State<_RequestsListPage> {
  int _page = 1;
  final int _pageSize = 10;
  int _totalPages = 1;
  bool get _hasPrev => _page > 1;
  bool get _hasNext => _page < _totalPages;
  final List<CarRequestViewModel> _items = [];
  List<CarRequestViewModel> _pageRaw = const [];
  final Map<String, _PendingResched> _pendingById = {};
  final TextEditingController _searchCtl = TextEditingController();
  String _search = '';
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();
  bool _isFetching = false;
  bool _lockPageNav = false;
  bool _suppressScrollFetch = false;
  String? _error;
  OverlayEntry? _listLoadingOverlay;
  StreamSubscription<void>? _reloadSub;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchPage(1, jumpToTop: true));
    final tabIndex = switch (widget.kind) {
      _ListKind.bookedCars => 0,
      _ListKind.bookedByOthers => 1,
      _ListKind.bookedAsPassenger => 2,
    };
    _reloadSub =
        _MyRequestsTabBus.instance.streamForIndex(tabIndex).listen((_) => _fetchPage(1, jumpToTop: true));
  }

  @override
  void dispose() {
    _hideListLoadingOverlay();
    _reloadSub?.cancel();
    _debounce?.cancel();
    _searchCtl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
  Widget build(BuildContext context) {
    final list = _items;

    final bool _isInvalidArgError =
        _error != null &&
            _error!.toLowerCase().contains('invalid argument');

    final listContent = (_error != null && !_isInvalidArgError)
        ? ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
      children: [
        const SizedBox(height: 40),
        Center(child: Text(_error!)),
        const SizedBox(height: 12),
      ],
    )
        : (_isInvalidArgError || (list.isEmpty && !_isFetching))
        ? _emptyListMessage(controller: _scrollController)
        : NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final r = list[i];
          return _CarRequestCard(
            data: r,
            pending: _pendingById[r.id],
            onTap: () => _openRequestSheet(r),
          );
        },
      ),
    );

    return Column(
      children: [
        _buildSearchBar(context),
        const SizedBox(height: 8),
        Expanded(child: Stack(children: [listContent])),
      ],
    );
  }

  bool _onScrollNotification(ScrollNotification sn) {
    if (_isFetching || _lockPageNav || _suppressScrollFetch) return false;
    if (sn is ScrollEndNotification) {
      final m = sn.metrics;
      const edge = 80.0;
      if (_hasNext && m.extentAfter < edge) {
        _goNextPage();
        return true;
      }
      if (_hasPrev && m.extentBefore < edge) {
        _goPrevPage();
        return true;
      }
    }
    return false;
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _search = v.trim().toLowerCase();
      setState(_applyFilterInternal);
    });
  }

  void _applyFilterInternal() {
    final q = _search;
    final filtered = (q.isEmpty) ? _pageRaw : _pageRaw.where((r) => _matches(r, q)).toList();
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
    if (_isFetching || _lockPageNav) return;
    if (!_hasNext) return;
    _lockPageNav = true;
    _markSuppressScrollFetch();
    _fetchPage(_page + 1, jumpToTop: true).whenComplete(() {
      _lockPageNav = false;
    });
  }

  void _goPrevPage() {
    if (_isFetching || _lockPageNav) return;
    if (!_hasPrev) return;
    _lockPageNav = true;
    _markSuppressScrollFetch();
    _fetchPage(_page - 1, jumpToBottom: true).whenComplete(() {
      _lockPageNav = false;
    });
  }

  void _markSuppressScrollFetch() {
    _suppressScrollFetch = true;
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) _suppressScrollFetch = false;
    });
  }

  void _safeJumpTo(double offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final clamped = offset.clamp(pos.minScrollExtent, pos.maxScrollExtent);
      _scrollController.jumpTo(clamped);
    });
  }

  _ActionPerms _permsFor(
      _ListKind kind,
      API.DetailedCarRequestStatus status, {
        required bool hasConfirmId,
        DateTime? startAt,
      }) {
    bool edit = false, cancel = false, extend = false, confirm = false, repeat = false, change = false;
    switch (kind) {
      case _ListKind.bookedCars:
        repeat = true;
        if (status == API.DetailedCarRequestStatus.draft || status == API.DetailedCarRequestStatus.waiting) {
          edit = true;
        }
        if (status == API.DetailedCarRequestStatus.draft ||
            status == API.DetailedCarRequestStatus.waiting ||
            status == API.DetailedCarRequestStatus.confirmed) {
          cancel = true;
        }
        if (status == API.DetailedCarRequestStatus.inProgress) {
          extend = true;
        }
        if (status == API.DetailedCarRequestStatus.pending && hasConfirmId) {
          confirm = true;
        }
        if (status == API.DetailedCarRequestStatus.confirmed && startAt != null) {
          final now = DateTime.now();
          final localStart = _asLocal(startAt);
          change = localStart.isAfter(now);
        }
        break;
      case _ListKind.bookedByOthers:
        repeat = false;
        if (status == API.DetailedCarRequestStatus.draft || status == API.DetailedCarRequestStatus.waiting) {
          edit = true;
        }
        if (status == API.DetailedCarRequestStatus.draft ||
            status == API.DetailedCarRequestStatus.waiting ||
            status == API.DetailedCarRequestStatus.confirmed) {
          cancel = true;
        }
        if (status == API.DetailedCarRequestStatus.pending && hasConfirmId) {
          confirm = true;
        }
        if (status == API.DetailedCarRequestStatus.inProgress) {
          extend = true;
        }
        if (status == API.DetailedCarRequestStatus.confirmed && startAt != null) {
          final now = DateTime.now();
          final localStart = _asLocal(startAt);
          change = localStart.isAfter(now);
        }
        break;
      case _ListKind.bookedAsPassenger:
        repeat = false;
        edit = false;
        cancel = false;
        extend = false;
        confirm = false;
        change = false;
        break;
    }
    return _ActionPerms(
      details: true,
      edit: edit,
      cancel: cancel,
      extend: extend,
      confirm: confirm,
      repeat: repeat,
      change: change,
    );
  }
}

extension _Fetch on _RequestsListPageState {
  Future<void> _fetchPage(
      int page, {
        bool jumpToTop = false,
        bool jumpToBottom = false,
      }) async {
    if (!_ensureAuthOrRedirect()) return;
    if (_isFetching) return;

    setState(() {
      _isFetching = true;
      _error = null;
    });
    _showListLoadingOverlay();

    try {
      final token = ApiManager.accessToken!;
      API.ApiCallResponse res;
      List<dynamic> rawItems;

      switch (widget.kind) {
        case _ListKind.bookedCars:
          res = await API.CarRequestsBookedCarsCall.call(
            bearerToken: token,
            page: page,
            pageSize: _pageSize,
          );
          rawItems = API.CarRequestsBookedCarsCall.items(res);
          break;
        case _ListKind.bookedByOthers:
          res = await API.CarRequestsBookedByOthersCall.call(
            bearerToken: token,
            page: page,
            pageSize: _pageSize,
          );
          rawItems = API.CarRequestsBookedByOthersCall.items(res);
          break;
        case _ListKind.bookedAsPassenger:
          res = await API.CarRequestsBookedAsPassengerCall.call(
            bearerToken: token,
            page: page,
            pageSize: _pageSize,
          );
          rawItems = API.CarRequestsBookedAsPassengerCall.items(res);
          break;
      }

      if (!mounted) return;

      if (res.succeeded) {
        _pendingById.clear();

        final mapped = rawItems
            .map(_mapItemFromAnyList)
            .whereType<CarRequestViewModel>()
            .toList();

        final current = switch (widget.kind) {
          _ListKind.bookedCars =>
              API.CarRequestsBookedCarsCall.pageNumber(res),
          _ListKind.bookedByOthers =>
              API.CarRequestsBookedByOthersCall.pageNumber(res),
          _ListKind.bookedAsPassenger =>
              API.CarRequestsBookedAsPassengerCall.pageNumber(res),
        } ?? page;

        final total = switch (widget.kind) {
          _ListKind.bookedCars =>
              API.CarRequestsBookedCarsCall.totalPages(res),
          _ListKind.bookedByOthers =>
              API.CarRequestsBookedByOthersCall.totalPages(res),
          _ListKind.bookedAsPassenger =>
              API.CarRequestsBookedAsPassengerCall.totalPages(res),
        } ?? 1;

        setState(() {
          _pageRaw = mapped;
          _page = current.clamp(1, total);
          _totalPages = total < 1 ? 1 : total;
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
      } else {
        if (res.statusCode == 401) {
          _handleUnauthorized();
          return;
        }
        setState(() => _error = 'Failed to load (${res.statusCode}).');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      _hideListLoadingOverlay();
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
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
    AppNotifications.error(context, 'Your session expired (401). Please sign in again.');
    if (mounted) context.goNamed('Login');
  }
}

extension _Map on _RequestsListPageState {
  _PendingResched? _extractPendingFromListItem(dynamic d) => _extractPendingFromAny(d);

  CarRequestViewModel? _mapItemFromAnyList(dynamic d) {
    final idRaw = API.CarRequestsListCall.id(d);
    final id = idRaw?.toString();
    final userName = API.CarRequestsListCall.userName(d) ?? '-';
    final from = _asLocalOpt(API.CarRequestsListCall.startAt(d));
    if (id == null || from == null) return null;

    final dynamic rawCur = getJsonField(d, r'$.curStatus');
    final status = API.parseDetailedCarRequestStatus(
      rawCur ?? getJsonField(d, r'$.requestStatus') ?? getJsonField(d, r'$.status') ?? getJsonField(d, r'$.statusName'),
    );

    final pending = _extractPendingFromListItem(d);
    if (pending != null) _pendingById[id] = pending;

    final flights = () {
      final raw = getJsonField(d, r'$.flightsInformations') ??
          getJsonField(d, r'$.flightInformations') ??
          getJsonField(d, r'$.FlightsInformations') ??
          getJsonField(d, r'$.FlightInformations');
      if (raw is List) {
        return raw
            .map((e) => FlightInformationVM.fromApiJson(e))
            .toList();
      }
      return const <FlightInformationVM>[];
    }();


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
      periodTo: _asLocalOpt(API.CarRequestsListCall.endAt(d)),
      routeDeparture: API.CarRequestsListCall.departure(d) ?? '-',
      destinations: API.CarRequestsListCall.destinations(d),
      notes: API.CarRequestsListCall.notes(d),
      childSeat: API.CarRequestsListCall.childSeat(d),
      status: status,
      statusName: _rawStatusFromListItem(d),
      confirmationId: _rawConfirmIdFromListItem(d),
      flightsInformations: flights,
    );
  }
}

extension _PassengerDetailsGuard on _RequestsListPageState {
  Future<bool> _shouldShowDetailsForPassenger(CarRequestViewModel r) async {
    if (widget.kind != _ListKind.bookedAsPassenger) return true;
    if (Session.isAdmin()) return true;

    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final det = await API.CarRequestsDetailsCall.call(
        bearerToken: token,
        id: r.id,
      );

      if (det.succeeded) return true;

      if (det.statusCode == 401) return false;

      return true;
    } catch (_) {
      return true;
    }
  }
}

extension _Sheet on _RequestsListPageState {
  void _openRequestSheet(CarRequestViewModel r) async {
    final hasConfirmId = (r.confirmationId ?? '').trim().isNotEmpty;

    final perms = _permsFor(
      widget.kind,
      r.status,
      hasConfirmId: hasConfirmId,
      startAt: r.periodFrom,
    );

    bool showDetailsButton = true;

    if (widget.kind == _ListKind.bookedAsPassenger) {
      showDetailsButton = await _shouldShowDetailsForPassenger(r);

      if (Session.isAdmin()) {
        showDetailsButton = false;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final buttons = <Widget>[
          if (showDetailsButton)
            _pillButton(
              'DETAILS',
              onPressed: () {
                Navigator.pop(sheetCtx);
                _openDetails(r);
              },
              bg: const Color(0xFF3B82F6),
            ),
          if (perms.edit) ...[
            const SizedBox(height: 10),
            _pillButton(
              'EDIT REQUEST',
              onPressed: () {
                Navigator.pop(sheetCtx);
                _goEdit(r);
              },
              bg: const Color(0xFF8BB9FF),
            ),
          ],
          if (perms.cancel) ...[
            const SizedBox(height: 10),
            _pillButton(
              'CANCEL REQUEST',
              onPressed: () {
                Navigator.pop(sheetCtx);
                _cancelRequest(r);
              },
              bg: const Color(0xFFE34A48),
            ),
          ],
          if (perms.extend) ...[
            const SizedBox(height: 10),
            _pillButton(
              'EXTEND',
              onPressed: () {
                Navigator.pop(sheetCtx);
                _extendPeriod(r);
              },
              bg: const Color(0xFF34D399),
            ),
          ],
          if (perms.change) ...[
            const SizedBox(height: 10),
            _pillButton(
              'CHANGE',
              onPressed: () {
                Navigator.pop(sheetCtx);
                _rescheduleRequest(r);
              },
              bg: const Color(0xFF22C55E),
            ),
          ],
          if (perms.confirm && hasConfirmId) ...[
            const SizedBox(height: 10),
            _pillButton(
              'CONFIRM',
              onPressed: () {
                Navigator.pop(sheetCtx);
                _confirmPending(r);
              },
              bg: const Color(0xFF10B981),
            ),
          ],
          if (perms.repeat) ...[
            const SizedBox(height: 10),
            _pillButton(
              'REPEAT REQUEST',
              onPressed: () {
                Navigator.pop(sheetCtx);
                _repeatRequest(r);
              },
              bg: const Color(0xFF2563EB),
            ),
          ],
        ];

        final statusLabel = r.status.uiLabelFromRaw(r.statusName);
        final statusColor = r.status.uiColorFromRaw(r.statusName);

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
                Text(
                  '#${r.id} — ${r.userName}',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                _kv('Scheduled Period', _fmtPeriod(r.periodFrom, r.periodTo)),
                _kv('Driver', r.driverName),
                _kv('Model', '${r.model}  |  Child Seat: ${r.childSeat ? 'Yes' : 'No'}'),
                _kv('License Plate', r.licensePlate),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (r.notes != null && r.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Notes',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(r.notes!),
                ],
                const SizedBox(height: 12),
                ...buttons,
              ],
            ),
          ),
        );
      },
    );
  }
}

  Widget _pillButton(
      String label, {
        VoidCallback? onPressed,
        Color bg = const Color(0xFF8BB9FF),
      }) {
    final isDisabled = onPressed == null;
    Color fgFor(Color bg) => isDisabled ? Colors.white70 : Colors.white;

    final style = ButtonStyle(
      backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.disabled)) {
          return HSLColor.fromColor(bg).withLightness(0.78).toColor();
        }
        if (states.contains(MaterialState.pressed)) {
          return HSLColor.fromColor(bg).withLightness(0.40).toColor();
        }
        if (states.contains(MaterialState.hovered) || states.contains(MaterialState.focused)) {
          return HSLColor.fromColor(bg).withLightness(0.52).toColor();
        }
        return bg;
      }),
      foregroundColor: MaterialStateProperty.resolveWith<Color>((_) => fgFor(bg)),
      overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
        if (states.contains(MaterialState.pressed)) return Colors.black.withOpacity(0.08);
        if (states.contains(MaterialState.hovered) || states.contains(MaterialState.focused)) {
          return Colors.black.withOpacity(0.04);
        }
        return null;
      }),
      elevation: MaterialStateProperty.resolveWith<double>(
            (states) => states.contains(MaterialState.disabled) ? 0 : 6,
      ),
      shadowColor: MaterialStateProperty.resolveWith<Color?>(
            (states) => states.contains(MaterialState.disabled) ? Colors.transparent : Colors.black12,
      ),
      padding: MaterialStateProperty.all<EdgeInsets>(
        const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      ),
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      minimumSize: MaterialStateProperty.all<Size>(const Size.fromHeight(48)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      animationDuration: const Duration(milliseconds: 120),
    );

    return SizedBox(
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
  }


extension _Handlers on _RequestsListPageState {
  Future<void> _openDetails(CarRequestViewModel r) async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      return;
    }
    _showListLoadingOverlay();
    try {
      final resp = await API.CarRequestsGetCall.call(
        bearerToken: token,
        id: r.id,
      );
      if (!mounted) return;
      if (resp.succeeded) {
        final j = resp.jsonBody;
        final pf = _asLocalOpt(API.CarRequestsDetailsCall.startAt(j)) ?? r.periodFrom;
        final pt = _asLocalOpt(API.CarRequestsDetailsCall.endAt(j)) ?? r.periodTo;
        final rf = _asLocalOpt(API.CarRequestsDetailsCall.realStart(j));
        final rt = _asLocalOpt(API.CarRequestsDetailsCall.realEnd(j));
        Future.microtask(
              () => AppNotifications.showCarRequestDetailsModal(
            context,
            id: API.CarRequestsDetailsCall.id(j) ?? r.id,
            userName: API.CarRequestsDetailsCall.userName(j) ?? r.userName,
            periodFrom: pf,
            periodTo: pt,
            driver: API.CarRequestsDetailsCall.driver(j) ?? r.driverName,
            model: API.CarRequestsDetailsCall.model(j) ?? r.model,
            childSeat: API.CarRequestsDetailsCall.childSeat(j),
            licensePlate: API.CarRequestsDetailsCall.license(j) ?? r.licensePlate,
            hadIncident: API.CarRequestsDetailsCall.hadIncident(j),
            departure: API.CarRequestsDetailsCall.departure(j) ?? r.routeDeparture,
            destinations: API.CarRequestsDetailsCall.destinations(j).isNotEmpty
                ? API.CarRequestsDetailsCall.destinations(j)
                : r.destinations,
            notes: API.CarRequestsDetailsCall.notes(j) ?? r.notes,
            realPeriodFrom: rf,
            realPeriodTo: rt,
            startKm: API.CarRequestsDetailsCall.startKm(j),
            endKm: API.CarRequestsDetailsCall.endKm(j),
            cancelReason: API.CarRequestsDetailsCall.cancelReason(j),
            disacordReason: API.CarRequestsDetailsCall.disacordReason(j),
            periodConfirmedOk: (API.CarRequestsDetailsCall.confirmationId(j) ?? '').isEmpty,
            finalKmOk: (() {
              final sk = API.CarRequestsDetailsCall.startKm(j);
              final ek = API.CarRequestsDetailsCall.endKm(j);
              return (sk != null && ek != null && ek > sk);
            })(),
            costAllocs: API.CarRequestsDetailsCall.costAllocs(j),
            flights: API.CarRequestsDetailsCall.flights(j),
            passengersCsv: API.CarRequestsDetailsCall.passengersCsv(j),
          ),
        );
      } else {
        AppNotifications.error(context, 'Failed to load details (${resp.statusCode}).');
      }
    } finally {
      _hideListLoadingOverlay();
    }
  }

  Future<void> _goEdit(CarRequestViewModel r) async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm edit'),
        content: const Text('Editing will change the request status to Draft. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok != true) return;

    _showListLoadingOverlay();
    CarRequestViewModel initial = r;
    try {
      final resp = await API.CarRequestsGetCall.call(
        bearerToken: token,
        id: r.id,
      );
      if (resp.succeeded) {
        initial = CarRequestViewModel.fromApiJson(resp.jsonBody);
      }
    } catch (_) {} finally {
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
      AppNotifications.success(context, 'Request updated');
      await _fetchPage(1, jumpToTop: true);
    }
  }

  Future<void> _cancelRequest(CarRequestViewModel r) async {
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
        await _fetchPage(1, jumpToTop: true);
      } else {
        AppNotifications.error(context, 'Failed to cancel (${res.statusCode}).');
      }
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

    DateTime start = _asLocal(r.periodFrom);
    DateTime end = _asLocalOpt(r.periodTo) ?? _asLocal(r.periodFrom.add(const Duration(hours: 1)));
    try {
      final det = await API.CarRequestsDetailsCall.call(
        bearerToken: token,
        id: r.id,
      );
      if (det.succeeded) {
        start = _asLocalOpt(API.CarRequestsDetailsCall.realStart(det)) ?? start;
        end = _asLocalOpt(API.CarRequestsDetailsCall.realEnd(det)) ?? end;
      }
    } catch (_) {}

    final picked = await PeriodModals.showExtendPeriodModal(
      context,
      requestId: r.id,
      currentStart: start,
      currentEnd: end,
    );
    if (picked == null) return;

    _showListLoadingOverlay();
    try {
      final res = await API.CarRequestsExtendPeriodCall.call(
        bearerToken: token,
        id: r.id,
        newEnd: picked.end,
      );
      if (!mounted) return;
      if (res.succeeded) {
        AppNotifications.success(context, 'Request extended');
        await _fetchPage(_page);
      } else {
        AppNotifications.error(context, 'Failed to extend (${res.statusCode}).');
      }
    } finally {
      _hideListLoadingOverlay();
    }
  }

  Future<void> _rescheduleRequest(CarRequestViewModel r) async {
    final picked = await PeriodModals.showChangeRequestModal(
      context,
      requestId: r.id,
      currentStart: r.periodFrom,
      currentEnd: r.periodTo ?? r.periodFrom.add(const Duration(hours: 1)),
    );
    if (picked == null) return;

    DateTime norm(DateTime d) => DateTime(d.year, d.month, d.day, d.hour, d.minute);
    final now = norm(DateTime.now());
    final start = norm(picked.start);
    final end = norm(picked.end);

    if (!start.isAfter(now)) {
      AppNotifications.error(context, 'The selected start time has already passed.');
      return;
    }
    if (!end.isAfter(start)) {
      AppNotifications.error(context, 'End must be after start.');
      return;
    }

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
      final res = await API.RescheduleCarRequestCall.call(
        bearerToken: token,
        carRequestId: reqId,
        newStart: start,
        newEnd: end,
      );

      if (!mounted) return;
      if (res.succeeded) {
        AppNotifications.success(context, 'Reschedule request submitted');
        await _fetchPage(_page);
      } else {
        String msg = 'Failed to reschedule (${res.statusCode}).';
        try {
          final j = res.jsonBody;
          final m = (getJsonField(j, r'$.message') ?? '').toString().trim();
          if (m.isNotEmpty) msg = m;
        } catch (_) {}
        AppNotifications.error(context, msg);
      }
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

      final reqId = API.CarRequestsGetConfirmationCall.id(getRes) ?? r.id;
      final userName = API.CarRequestsGetConfirmationCall.userName(getRes) ?? r.userName;
      final driver = API.CarRequestsGetConfirmationCall.driver(getRes) ?? (r.driverName);
      final departure = API.CarRequestsGetConfirmationCall.departure(getRes) ?? r.routeDeparture;
      final destinations = API.CarRequestsGetConfirmationCall.destinations(getRes).isNotEmpty
          ? API.CarRequestsGetConfirmationCall.destinations(getRes)
          : r.destinations;
      final from = _asLocalOpt(API.CarRequestsGetConfirmationCall.startAt(getRes)) ?? r.periodFrom;
      final to = _asLocalOpt(API.CarRequestsGetConfirmationCall.endAt(getRes)) ??
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

      final reasonToSend = confirmed ? null : (await AppNotifications.showDisagreeReasonModal(context))?.trim();

      _showListLoadingOverlay();
      try {
        final res = await API.CarRequestsConfirmByTokenCall.call(
          confirmId: confirmId,
          txtReason: confirmed
              ? null
              : (reasonToSend?.isEmpty ?? true)
              ? 'User disagreed (no reason provided)'
              : reasonToSend,
        );
        if (!mounted) return;
        if (res.succeeded) {
          confirmed
              ? AppNotifications.success(context, 'Period confirmed!')
              : AppNotifications.info(context, 'Disagreement has been recorded.');
          await _fetchPage(_page);
        } else {
          AppNotifications.error(context, 'Failed (${res.statusCode}).');
        }
      } finally {
        _hideListLoadingOverlay();
      }
    } catch (_) {
      _hideListLoadingOverlay();
      AppNotifications.error(context, 'Error while processing confirmation.');
    }
  }

  Future<void> _repeatRequest(CarRequestViewModel r) async {
    _showListLoadingOverlay();
    CarRequestViewModel full;
    try {
      final token = ApiManager.accessToken;
      if (token != null && token.isNotEmpty) {
        final resp = await API.CarRequestsGetCall.call(
          bearerToken: token,
          id: r.id,
        );
        full = resp.succeeded ? CarRequestViewModel.fromApiJson(resp.jsonBody) : r;
      } else {
        full = r;
      }
    } catch (_) {
      full = r;
    } finally {
      _hideListLoadingOverlay();
    }
    if (!mounted) return;

    final start = _asLocal(full.periodFrom);
    final end = _asLocalOpt(full.periodTo) ?? start.add(const Duration(hours: 1));

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
        await _fetchPage(1, jumpToTop: true);
      } else {
        AppNotifications.error(context, 'New period is equal to original period.');
      }
    } finally {
      _hideListLoadingOverlay();
    }
  }
}

class _CarRequestCard extends StatelessWidget {
  const _CarRequestCard({
    required this.data,
    required this.onTap,
    this.pending,
  });
  final CarRequestViewModel data;
  final VoidCallback onTap;
  final _PendingResched? pending;

  @override
  Widget build(BuildContext context) {
    final statusLabel = data.status.uiLabelFromRaw(data.statusName);
    final statusBg = data.status.uiColorFromRaw(data.statusName);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('#${data.id}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF222222))),
                const SizedBox(height: 6),
                Text(data.userName, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF5B5B5B))),
                const SizedBox(height: 6),
                Text(_fmtPeriod(data.periodFrom, data.periodTo), style: GoogleFonts.inter(fontSize: 14)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (data.flightsInformations.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '* This car order contains recorded flight information.',
                    style: GoogleFonts.inter(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          _kv('Departure', data.routeDeparture),
          if (data.destinations.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Destination(s)', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            ...data.destinations.take(2).map(
                  (d) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [const Text('• '), Expanded(child: Text(d))],
              ),
            ),
            if (data.destinations.length > 2) const Text('+ more', style: TextStyle(color: Colors.black54)),
          ],
          if (pending != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '* This car request contains rescheduling requests pending approval.',
                    style: GoogleFonts.inter(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: GoogleFonts.inter(color: Colors.red.shade700),
                children: [
                  const TextSpan(text: '* New schedule requested: '),
                  TextSpan(
                    text: '${_fmtDtShort(pending!.start)} - ${_fmtDtShort(pending!.end)}',
                    style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
