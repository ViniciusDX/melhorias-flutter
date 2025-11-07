import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/menu/app_drawer.dart';
import '/widgets/add_fab_button.dart';

import '/backend/api_requests/api_calls.dart';
import '/backend/api_requests/api_manager.dart';
import 'package:mitsubishi/widgets/notifications/app_notifications.dart';
import 'package:mitsubishi/widgets/notifications/modal_success_device_sms_validation_model.dart';

import 'car_form_widget.dart';

void _carsLog(Object msg) => debugPrint('[CarsWidget] $msg');
String _mask(String? t) {
  if (t == null || t.isEmpty) return '<empty>';
  final head = t.length >= 10 ? t.substring(0, 10) : t;
  final tail = t.length >= 5 ? t.substring(t.length - 5) : '';
  return '$head…$tail';
}

enum CarCurStatus { available, unavailable, timeRestriction }

extension CarCurStatusUi on CarCurStatus {
  String get label {
    switch (this) {
      case CarCurStatus.available:
        return 'Available';
      case CarCurStatus.unavailable:
        return 'Unavailable';
      case CarCurStatus.timeRestriction:
        return 'Time Restriction';
    }
  }

  Color get color {
    switch (this) {
      case CarCurStatus.available:
        return const Color(0xFF2ECC71);
      case CarCurStatus.unavailable:
        return const Color(0xFFE74C3C);
      case CarCurStatus.timeRestriction:
        return const Color(0xFFF59E0B);
    }
  }
}

class CarsWidget extends StatefulWidget {
  const CarsWidget({super.key});

  static String routeName = 'Cars';
  static String routePath = '/cars';

  @override
  State<CarsWidget> createState() => _CarsWidgetState();
}

class _CarsWidgetState extends State<CarsWidget> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final ModalSuccessDeviceSmsValidationModel _loadingModel;

  String? _error;
  int _page = 1;
  final int _pageSize = 10;
  bool _isLastPage = false;

  final List<CarViewModel> _cars = [];
  final Set<String> _ids = {};

  bool _isFetching = false;

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

  Timer? _searchDebounce;
  String _searchQuery = '';
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadingModel = ModalSuccessDeviceSmsValidationModel()
      ..addListener(_onLoadingChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadingModel.setLoading(true);
      await _loadFirstPage(showOverlay: false);
      _loadingModel.setLoading(false);
    });
  }

  void _onLoadingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hideListLoadingOverlay();
    _searchDebounce?.cancel();
    _loadingModel.removeListener(_onLoadingChanged);
    _loadingModel.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _sortCars() {
    _cars.sort((a, b) => a.model.toLowerCase().compareTo(b.model.toLowerCase()));
  }

  Future<void> _loadFirstPage({bool showOverlay = true}) async {
    if (_isFetching) return;
    _isFetching = true;

    _carsLog(
      'loadFirstPage(pageSize: $_pageSize) token: ${_mask(ApiManager.accessToken)}',
    );

    if (mounted) {
      setState(() {
        _error = null;
        _page = 1;
        _isLastPage = false;
        _cars.clear();
        _ids.clear();
      });
    }

    if (showOverlay) _showListLoadingOverlay();

    try {
      final res = await CarsListCall.call(
        bearerToken: ApiManager.accessToken,
        page: _page,
        pageSize: _pageSize,
      );

      if (!mounted) return;

      if (res.succeeded) {
        final newItems = _parseItems(res);
        for (final c in newItems) {
          if (_ids.add(c.id)) _cars.add(c);
        }
        setState(() {
          _isLastPage = newItems.length < _pageSize;
          _sortCars();
        });
      } else {
        setState(() {
          _error = 'Failed to load cars (${res.statusCode}).';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error loading cars.');
    } finally {
      _isFetching = false;
      if (showOverlay) _hideListLoadingOverlay();
    }
  }

  Future<bool> _applyFlags(
      CarViewModel car, {
        bool? active,
        bool? presidence,
      }) async {
    final idNum = int.tryParse(car.id);
    if (idNum == null) return false;

    final res = await CarsUpdateCall.call(
      id: idNum,
      description: car.model,
      km: car.km,
      licensePlate: car.licensePlate,
      active: active ?? car.isActive,
      presidenceCar: presidence ?? car.isPresidence,
      carColorId: car.colorId,
      carColor: car.colorName,
    );

    _carsLog('updateFlags($idNum) -> ${res.statusCode}');
    return res.succeeded;
  }

  Future<void> _loadMore() async {
    if (_isFetching || _isLastPage || _searchQuery.isNotEmpty) return;
    _isFetching = true;

    final nextPage = _page + 1;
    _carsLog('loadMore -> page: $nextPage, size: $_pageSize');

    _showListLoadingOverlay();

    try {
      final res = await CarsListCall.call(
        bearerToken: ApiManager.accessToken,
        page: nextPage,
        pageSize: _pageSize,
      );

      if (!mounted) return;

      if (res.succeeded) {
        final newItems = _parseItems(res);
        int appended = 0;
        for (final c in newItems) {
          if (_ids.add(c.id)) {
            _cars.add(c);
            appended++;
          }
        }
        setState(() {
          _page = nextPage;
          _isLastPage = newItems.length < _pageSize;
          _sortCars();
        });
        _carsLog(
            'loadMore ok: received=${newItems.length} appended=$appended last=$_isLastPage');
      } else {
        _carsLog('loadMore fail: status=${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _carsLog('loadMore exception: $e');
    } finally {
      _isFetching = false;
      _hideListLoadingOverlay();
    }
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  CarCurStatus _parseCurStatus({
    required dynamic curStatusValue,
    required String? curStatusName,
    required bool timeRestrictionFlag,
    required bool? isAvailable,
  }) {
    final code = _asInt(curStatusValue);
    if (code != null) {
      switch (code) {
        case 0:
          return CarCurStatus.available;
        case 1:
          return CarCurStatus.unavailable;
        case 2:
          return CarCurStatus.timeRestriction;
      }
    }

    final name = (curStatusName ?? curStatusValue?.toString() ?? '')
        .trim()
        .toLowerCase();
    if (name.isNotEmpty) {
      if (name == 'available') return CarCurStatus.available;
      if (name == 'unavailable') return CarCurStatus.unavailable;
      if (name == 'timerestriction' ||
          name == 'time restriction' ||
          name.contains('time') && name.contains('restriction')) {
        return CarCurStatus.timeRestriction;
      }
    }

    if (timeRestrictionFlag) return CarCurStatus.timeRestriction;

    if (isAvailable == true) return CarCurStatus.available;

    return CarCurStatus.unavailable;
  }

  List<CarViewModel> _parseItems(ApiCallResponse res) {
    final items = CarsListCall.items(res);
    return items.map((e) {
      final id = (CarsListCall.id(e) ?? '').toString();
      final bool isActive = (getJsonField(e, r'$.active') as bool?) ?? true;
      final bool isAvailable = CarsListCall.available(e);

      final dynamic curStatusVal =
          getJsonField(e, r'$.curStatus') ?? getJsonField(e, r'$.CurStatus');
      final String? curStatusName =
      (getJsonField(e, r'$.curStatusName') ??
          getJsonField(e, r'$.CurStatusName'))
          ?.toString();

      final bool timeRestrictionFlag =
          (getJsonField(e, r'$.timeRestriction') as bool?) ??
              (getJsonField(e, r'$.TimeRestriction') as bool?) ??
              (getJsonField(e, r'$.hasTimeRestriction') as bool?) ??
              false;

      final curStatus = _parseCurStatus(
        curStatusValue: curStatusVal,
        curStatusName: curStatusName,
        timeRestrictionFlag: timeRestrictionFlag,
        isAvailable: isAvailable,
      );

      return CarViewModel(
        id: id,
        model: CarsListCall.model(e) ?? CarsListCall.description(e) ?? '-',
        km: (CarsListCall.km(e) ?? 0),
        licensePlate: CarsListCall.licensePlate(e) ?? '-',
        colorName: CarsListCall.colorName(e) ?? '-',
        colorId: CarsListCall.colorId(e),
        isActive: isActive,
        isAvailable: isAvailable,
        isPresidence: CarsListCall.presidence(e),
        curStatus: curStatus,
      );
    }).toList();
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final q = value.trim().toLowerCase();
      if (q == _searchQuery) return;

      _searchQuery = q;
      _searchGeneration++;

      if (_searchQuery.isEmpty) {
        _loadFirstPage();
      } else {
        _runCrossPageSearch(_searchQuery, _searchGeneration);
      }
    });
  }

  bool _matchesQuery(CarViewModel c, String q) {
    if (q.isEmpty) return true;
    return c.model.toLowerCase().contains(q) ||
        c.licensePlate.toLowerCase().contains(q) ||
        c.colorName.toLowerCase().contains(q) ||
        c.curStatus.label.toLowerCase().contains(q);
  }

  Future<void> _runCrossPageSearch(String q, int gen) async {
    if (_isFetching) return;
    _isFetching = true;

    setState(() {
      _error = null;
      _page = 1;
      _isLastPage = false;
      _cars.clear();
      _ids.clear();
    });

    _showListLoadingOverlay();

    try {
      while (mounted && gen == _searchGeneration && !_isLastPage) {
        final res = await CarsListCall.call(
          bearerToken: ApiManager.accessToken,
          page: _page,
          pageSize: _pageSize,
        );

        if (!mounted || gen != _searchGeneration) break;

        if (!res.succeeded) {
          setState(() => _error = 'Failed to load cars (${res.statusCode}).');
          break;
        }

        final pageItems = _parseItems(res);
        final matches = pageItems.where((c) => _matchesQuery(c, q));

        for (final c in matches) {
          if (_ids.add(c.id)) _cars.add(c);
        }

        final last = pageItems.length < _pageSize;
        setState(() {
          _isLastPage = last;
          _page = _page + 1;
          _sortCars();
        });

        if (last) break;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error loading cars.');
    } finally {
      _isFetching = false;
      _hideListLoadingOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final titleStyle = theme.bodyMedium.override(
      font: GoogleFonts.inter(fontWeight: FontWeight.w600),
      color: theme.primaryText,
      fontSize: 20,
    );

    final itemsToRender = _cars;

    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: _handleSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search for cars',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
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
            ),
            const SizedBox(height: 12),

            Expanded(
              child: (_error != null)
                  ? _ErrorView(message: _error!, onRetry: () => _loadFirstPage())
                  : NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (_isFetching ||
                      _isLastPage ||
                      _searchQuery.isNotEmpty) {
                    return false;
                  }
                  if (n.metrics.pixels >=
                      n.metrics.maxScrollExtent - 200) {
                    _loadMore();
                  }
                  return false;
                },
                child: LayoutBuilder(
                  builder: (context, c) {
                    final isCompact = c.maxWidth < 900;
                    if (itemsToRender.isEmpty) {
                      return ListView(
                        children: const [
                          SizedBox(height: 40),
                          Center(child: Text('No cars found')),
                        ],
                      );
                    }
                    if (isCompact) {
                      final count = itemsToRender.length;
                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: 110),
                        itemCount: count,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final car = itemsToRender[i];
                          return _buildSwipeToDelete(
                            car: car,
                            child: _CarCard(
                              data: car,
                              onTap: () => _openCarSheet(car),
                            ),
                          );
                        },
                      );
                    } else {
                      return _CarsTable(
                        items: itemsToRender,
                        onRowTap: _openCarSheet,
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        title: Text('Register Car', style: titleStyle),
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0.5,
      ),
      drawer: AppDrawer(
        onGoCarRequest: () => context.goNamed('CarRequest'),
        onGoDrivers: () => context.goNamed('Drivers'),
        onGoCars: () => context.goNamed('Cars'),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 12, bottom: 12),
        child: AddFabButton(
          heroTag: 'carsAddFab',
          onTap: _onAddCar,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _loadingModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : content,
    );
  }

  Future<void> _onAddCar() async {
    final created = await Navigator.of(context).push<CarViewModel>(
      MaterialPageRoute(
        builder: (_) => const CarFormWidget(mode: CarFormMode.create),
      ),
    );
    if (created != null) {
      await _loadFirstPage();
      if (!mounted) return;
      AppNotifications.success(context, 'Car created successfully');
    }
  }

  Future<void> _goToEdit(CarViewModel c) async {
    final edited = await Navigator.of(context).push<CarViewModel>(
      MaterialPageRoute(
        builder: (_) => CarFormWidget(
          mode: CarFormMode.edit,
          initial: c,
        ),
      ),
    );
    if (edited != null && mounted) {
      await _loadFirstPage();
      AppNotifications.success(context, 'Car updated');
    }
  }

  Widget _buildSwipeToDelete({
    required CarViewModel car,
    required Widget child,
  }) {
    const red = Color(0xFFE34A48);

    return Dismissible(
      key: ValueKey('car-${car.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration:
        BoxDecoration(color: red, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_forever, color: Colors.white),
            SizedBox(width: 8),
            Text('Delete',
                style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(car),
      onDismissed: (_) async {
        final ok = await _deleteOnBackend(car);
        if (!ok) {
          await _loadFirstPage();
          if (!mounted) return;
          AppNotifications.error(context, 'Failed to delete on server.');
          return;
        }
        await _loadFirstPage();
        if (!mounted) return;
        AppNotifications.success(context, 'Car deleted');
      },
      child: child,
    );
  }

  Future<bool> _deleteOnBackend(CarViewModel c) async {
    final idNum = int.tryParse(c.id);
    if (idNum == null) return false;

    final res = await CarsDeleteCall.call(id: idNum);
    _carsLog('delete($idNum) -> status ${res.statusCode}');
    return res.succeeded;
  }

  Future<bool> _confirmDelete(CarViewModel c) {
    return AppNotifications.confirmDanger(
      context,
      title: 'Attention please!!!',
      message:
      'Are you sure to delete this car? These data cannot be recovered!',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
    );
  }

  void _openCarSheet(CarViewModel c) {
    bool _sheetDidMutate = false;

    final bsFuture = showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool isActive = c.isActive;
        bool isPresidence = c.isPresidence;

        const kBlueOn = Color(0xFF84B6FF);
        const kGreenOn = Color(0xFF8EE57F);
        const kGreyOff = Color(0xFFE5E7EB);
        const kRedOff = Color(0xFFFF7A78);

        Widget toggleRowCupertino({
          required String label,
          required bool value,
          required ValueChanged<bool> onChanged,
          required Color onColor,
          required Color offColor,
        }) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF636363),
                    )),
                CupertinoSwitch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: onColor,
                  trackColor: offColor,
                ),
              ],
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
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
                    c.model,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text('License Plate:',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF636363),
                      )),
                  const SizedBox(height: 4),
                  Text(c.licensePlate,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xFF333333),
                      )),
                  const SizedBox(height: 12),

                  Text('Km:',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF636363),
                      )),
                  const SizedBox(height: 4),
                  Text('${c.km}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xFF333333),
                      )),
                  const SizedBox(height: 12),

                  Text('Color:',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF636363),
                      )),
                  const SizedBox(height: 4),
                  Text(c.colorName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xFF333333),
                      )),

                  const SizedBox(height: 10),

                  toggleRowCupertino(
                    label: 'Presidence',
                    value: isPresidence,
                    onChanged: (v) async {
                      final old = isPresidence;
                      setModalState(() => isPresidence = v);
                      final ok = await _applyFlags(c, presidence: v);
                      if (!ok && mounted) {
                        setModalState(() => isPresidence = old);
                        AppNotifications.error(
                            context, 'Failed to update Presidence.');
                      } else {
                        c.isPresidence = v;
                        _sheetDidMutate = true;
                      }
                    },
                    onColor: kBlueOn,
                    offColor: kGreyOff,
                  ),
                  const SizedBox(height: 6),
                  toggleRowCupertino(
                    label: 'Active',
                    value: isActive,
                    onChanged: (v) async {
                      final old = isActive;
                      setModalState(() => isActive = v);
                      final ok = await _applyFlags(c, active: v);
                      if (!ok && mounted) {
                        setModalState(() => isActive = old);
                        AppNotifications.error(
                            context, 'Failed to update Active.');
                      } else {
                        c.isActive = v;
                        _sheetDidMutate = true;
                      }
                    },
                    onColor: kGreenOn,
                    offColor: kRedOff,
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Future.microtask(() => _goToEdit(c));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8BB9FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('EDIT CAR'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4D4D4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    bsFuture.whenComplete(() async {
      if (!_sheetDidMutate) return;
      await _loadFirstPage();
    });
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 40),
        Center(child: Text(message)),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

class CarViewModel {
  CarViewModel({
    required this.id,
    required this.model,
    required this.km,
    required this.licensePlate,
    required this.colorName,
    this.colorId,
    this.isActive = true,
    this.isAvailable = true,
    this.isPresidence = false,
    this.curStatus = CarCurStatus.available,
  });

  final String id;
  final String model;
  final int km;
  final String licensePlate;
  final String colorName;
  final String? colorId;

  bool isActive;
  bool isAvailable;
  bool isPresidence;
  CarCurStatus curStatus;
}

class _CarsTable extends StatelessWidget {
  const _CarsTable({
    required this.items,
    required this.onRowTap,
  });

  final List<CarViewModel> items;
  final void Function(CarViewModel) onRowTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    Widget statusCell(CarViewModel c) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c.curStatus.label,
            style: GoogleFonts.inter(
              color: c.curStatus.color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (c.isPresidence)
            Text(
              'Presidence',
              style: GoogleFonts.inter(
                color: const Color(0xFF2E9AFE),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(theme.secondaryBackground),
        columns: const [
          DataColumn(label: Text('Model')),
          DataColumn(label: Text('Km')),
          DataColumn(label: Text('License Plate')),
          DataColumn(label: Text('Color')),
          DataColumn(label: Text('Current Status')),
        ],
        rows: items.map((c) {
          return DataRow(
            cells: [
              DataCell(Text(c.model), onTap: () => onRowTap(c)),
              DataCell(Text('${c.km}'), onTap: () => onRowTap(c)),
              DataCell(Text(c.licensePlate), onTap: () => onRowTap(c)),
              DataCell(Text(c.colorName), onTap: () => onRowTap(c)),
              DataCell(statusCell(c), onTap: () => onRowTap(c)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  const _CarCard({
    required this.data,
    this.onTap,
  });

  final CarViewModel data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget pill(String text, Color bg, {Color? fg}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: fg ?? Colors.white, fontWeight: FontWeight.w700)),
    );

    final statusBg = data.curStatus.color;
    final statusLabel = data.curStatus.label;

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
        child: Row(
          children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.model,
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF222222))),
                    const SizedBox(height: 6),
                    Text('Km: ${data.km} • Plate: ${data.licensePlate}',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: const Color(0xFF5B5B5B))),
                    const SizedBox(height: 6),
                    Text('Color: ${data.colorName}',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: const Color(0xFF5B5B5B))),
                  ]),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                pill(statusLabel, statusBg),
                const SizedBox(height: 6),
                if (data.isPresidence)
                  pill('Presidence', const Color(0xFFDCEBFF),
                      fg: const Color(0xFF2E9AFE)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
