import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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

import 'driver_form_widget.dart';
import 'car_preference_widget.dart';
import 'scala_presidence_widget.dart';

void _driversLog(Object msg) => debugPrint('[DriversWidget] $msg');
String _mask(String? t) {
  if (t == null || t.isEmpty) return '<empty>';
  final head = t.length >= 10 ? t.substring(0, 10) : t;
  final tail = t.length >= 5 ? t.substring(t.length - 5) : '';
  return '$head…$tail';
}

Uint8List? decodeDriverPhoto(String? dataUriOrBase64) {
  if (dataUriOrBase64 == null || dataUriOrBase64.isEmpty) return null;
  final parts = dataUriOrBase64.split(',');
  final base64Part = parts.length > 1 ? parts[1] : parts[0];
  try {
    return base64Decode(base64Part);
  } catch (_) {
    return null;
  }
}

class DriverAvatar extends StatelessWidget {
  const DriverAvatar({super.key, required this.driverItem, this.size = 48});

  final dynamic driverItem;
  final double size;

  @override
  Widget build(BuildContext context) {
    String? b64;
    try {
      b64 = DriversListCall.photoBase64(driverItem);
    } catch (_) {
      try {
        final v = getJsonField(driverItem, r'$.base64DriverProfilePicture');
        b64 = v?.toString();
      } catch (_) {
        if (driverItem is Map<String, dynamic>) {
          final v = driverItem['base64DriverProfilePicture'];
          if (v is String) b64 = v;
        }
      }
    }

    final bytes = decodeDriverPhoto(b64);

    if (bytes == null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey.shade200,
        child: Icon(Icons.person, size: size * 0.55),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
        ),
      ),
    );
  }
}

class DriversWidget extends StatefulWidget {
  const DriversWidget({super.key});

  static String routeName = 'Drivers';
  static String routePath = '/drivers';

  @override
  State<DriversWidget> createState() => _DriversWidgetState();
}

class _DriversWidgetState extends State<DriversWidget> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final ModalSuccessDeviceSmsValidationModel _loadingModel;

  String? _error;
  int _page = 1;
  final int _pageSize = 10;
  bool _isLastPage = false;

  final List<DriverViewModel> _drivers = [];
  final Set<String> _ids = {};
  final Map<String, Uint8List?> _photoCache = {};

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

  Future<void> _loadFirstPage({bool showOverlay = true, String? search}) async {
    if (_isFetching) return;
    _isFetching = true;

    final searchTerm = search?.trim() ?? _searchQuery;

    _driversLog(
      'loadFirstPage(pageSize: $_pageSize, search: ${_mask(searchTerm)}) token: ${_mask(ApiManager.accessToken)}',
    );

    if (mounted) {
      setState(() {
        _error = null;
        _page = 1;
        _isLastPage = false;
        _drivers.clear();
        _ids.clear();
        _photoCache.clear();
        _searchQuery = searchTerm;
      });
    }

    if (showOverlay) _showListLoadingOverlay();

    try {
      final res = await DriversListCall.call(
        bearerToken: ApiManager.accessToken,
        page: _page,
        pageSize: _pageSize,
        search: searchTerm.isEmpty ? null : searchTerm,
      );

      if (!mounted) return;

      if (res.succeeded) {
        final newItems = _parseItems(res);
        for (final d in newItems) {
          if (_ids.add(d.id)) _drivers.add(d);
        }
        setState(() {
          _isLastPage = newItems.length < _pageSize;
        });
      } else {
        setState(() {
          _error = 'Failed to load drivers (${res.statusCode}).';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error loading drivers.');
    } finally {
      _isFetching = false;
      if (showOverlay) _hideListLoadingOverlay();
    }
  }

  Future<void> _loadMore() async {
    if (_isFetching || _isLastPage) return;
    _isFetching = true;

    final nextPage = _page + 1;
    _driversLog(
        'loadMore -> page: $nextPage, size: $_pageSize, search: ${_mask(_searchQuery)}');

    _showListLoadingOverlay();

    try {
      final res = await DriversListCall.call(
        bearerToken: ApiManager.accessToken,
        page: nextPage,
        pageSize: _pageSize,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (!mounted) return;

      if (res.succeeded) {
        final newItems = _parseItems(res);
        int appended = 0;
        for (final d in newItems) {
          if (_ids.add(d.id)) {
            _drivers.add(d);
            appended++;
          }
        }
        final nothingNew = appended == 0 && newItems.isNotEmpty;

        setState(() {
          _page = nextPage;
          _isLastPage = nothingNew || newItems.length < _pageSize;
        });
        _driversLog(
            'loadMore ok: received=${newItems.length} appended=$appended last=$_isLastPage');
      } else {
        _driversLog('loadMore fail: status=${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _driversLog('loadMore exception: $e');
    } finally {
      _isFetching = false;
      _hideListLoadingOverlay();
    }
  }

  String? _extractBase64Photo(dynamic item) {
    try {
      final v = DriversListCall.photoBase64(item);
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    } catch (_) {}
    try {
      final v = getJsonField(item, r'$.base64DriverProfilePicture');
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    } catch (_) {}
    if (item is Map<String, dynamic>) {
      final v = item['base64DriverProfilePicture'];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  Uint8List? _photoFor(DriverViewModel d) {
    final cached = _photoCache[d.id];
    if (cached != null || _photoCache.containsKey(d.id)) return cached;

    final decoded = decodeDriverPhoto(d.base64Photo);
    _photoCache[d.id] = decoded;
    return decoded;
  }

  List<DriverViewModel> _parseItems(ApiCallResponse res) {
    final items = DriversListCall.items(res);
    return items.map((e) {
      final id = (DriversListCall.id(e) ?? '').toString();
      final b64 = _extractBase64Photo(e);
      return DriverViewModel(
        id: id,
        name: DriversListCall.name(e) ?? '-',
        email: DriversListCall.email(e) ?? '',
        rg: DriversListCall.rg(e),
        phone: DriversListCall.phone(e),
        phone2: DriversListCall.phone2(e),
        company: DriversListCall.company(e),
        companyId: DriversListCall.companyId(e),
        active: DriversListCall.active(e),
        presidenceDriver: DriversListCall.presidence(e),
        backupDriver: DriversListCall.backup(e),
        speaksJpn: DriversListCall.japanese(e),
        speaksEng: DriversListCall.english(e),
        base64Photo: b64,
      );
    }).toList();
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final q = value.trim();
      if (q == _searchQuery) return;

      _loadFirstPage(search: q);
    });
  }

  Future<Map<String, dynamic>> _prepareFullBody(
      DriverViewModel d, {
        bool? active,
        bool? presidence,
        bool? backup,
        bool? jpn,
        bool? eng,
      }) async {
    final body = <String, dynamic>{
      'fullName': d.name,
      'email': d.email,
      'phoneNumber': d.phone,
      'phoneNumber2': d.phone2,
      'rg': d.rg,
      'active': active ?? d.active,
      'presidenceDriver': presidence ?? d.presidenceDriver,
      'backupDriver': backup ?? d.backupDriver,
      'japanese': jpn ?? d.speaksJpn,
      'english': eng ?? d.speaksEng,
      'companyId': d.companyId,
    };

    final needsDetail = body['companyId'] == null ||
        body['phoneNumber2'] == null ||
        body['rg'] == null ||
        body['phoneNumber'] == null;

    if (needsDetail) {
      final idNum = int.tryParse(d.id);
      if (idNum != null) {
        final res = await DriverGetCall.call(id: idNum);
        if (res.succeeded) {
          body['fullName'] = DriverGetCall.fullName(res) ?? body['fullName'];
          body['email'] = DriverGetCall.email(res) ?? body['email'];
          body['phoneNumber'] =
              DriverGetCall.phone(res) ?? body['phoneNumber'];
          body['phoneNumber2'] =
              DriverGetCall.phone2(res) ?? body['phoneNumber2'];
          body['rg'] = DriverGetCall.rg(res) ?? body['rg'];
          body['companyId'] =
              DriverGetCall.companyId(res) ?? body['companyId'];

          final b64 = DriverGetCall.base64Photo(res);
          if (b64 != null && b64.trim().isNotEmpty) {
            body['base64DriverProfilePicture'] = b64;
          }
        }
      }
    }
    return body;
  }

  Future<bool> _persistDriverFlags(
      DriverViewModel d, {
        bool? active,
        bool? presidence,
        bool? backup,
        bool? jpn,
        bool? eng,
      }) async {
    final idNum = int.tryParse(d.id);
    if (idNum == null) return false;

    final body = await _prepareFullBody(
      d,
      active: active,
      presidence: presidence,
      backup: backup,
      jpn: jpn,
      eng: eng,
    );

    final res = await DriverUpdateCall.call(id: idNum, body: body);
    _driversLog(
        'quickUpdate($idNum) -> status ${res.statusCode} succeeded=${res.succeeded}');
    return res.succeeded;
  }

  Future<void> _onAddDriver() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const DriverFormWidget(mode: DriverFormMode.create),
      ),
    );
    if (created == true && mounted) {
      await _loadFirstPage();
      AppNotifications.success(context, 'Driver created successfully');
    }
  }

  Future<void> _goToEdit(DriverViewModel d) async {
    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DriverFormWidget(
          mode: DriverFormMode.edit,
          initial: d,
        ),
      ),
    );
    if (edited == true && mounted) {
      await _loadFirstPage();
      AppNotifications.success(context, 'Driver updated');
    }
  }

  Future<void> _goToCarPreference(DriverViewModel driver) async {
    final driverId = int.tryParse(driver.id);
    if (driverId == null) {
      AppNotifications.error(context, 'Driver ID is not a valid number.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CarPreferenceWidget(driverId: driverId),
      ),
    );
  }

  Future<void> _goToScalaPresidence(DriverViewModel d) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScalaPresidenceWidget(driver: d)),
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

    final itemsToRender = _drivers;

    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: _handleSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search drivers by name',
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
                  ? _ErrorView(
                  message: _error!, onRetry: () => _loadFirstPage())
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
                          Center(child: Text('No matching records found')),
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
                          final d = itemsToRender[i];
                          return _buildSwipeToDelete(
                            driver: d,
                            child: _DriverCard(
                              data: d,
                              avatarBytes: _photoFor(d),
                              onTap: () => _openDriverSheet(d),
                            ),
                          );
                        },
                      );
                    } else {
                      return _DriversTable(
                        items: itemsToRender,
                        onRowTap: _openDriverSheet,
                        photoFor: _photoFor,
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
        title: Text('Register Driver', style: titleStyle),
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
          heroTag: 'driversAddFab',
          onTap: _onAddDriver,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _loadingModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : content,
    );
  }

  Widget _buildSwipeToDelete({
    required DriverViewModel driver,
    required Widget child,
  }) {
    const red = Color(0xFFE34A48);

    return Dismissible(
      key: ValueKey('driver-${driver.id}'),
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
      confirmDismiss: (_) => _confirmDelete(driver),
      onDismissed: (_) async {
        final ok = await _deleteOnBackend(driver);
        if (!ok) {
          await _loadFirstPage();
          if (!mounted) return;
          AppNotifications.error(context, 'Failed to delete on server.');
          return;
        }
        await _loadFirstPage();
        if (!mounted) return;
        AppNotifications.success(context, 'Driver deleted');
      },
      child: child,
    );
  }

  Future<bool> _deleteOnBackend(DriverViewModel d) async {
    final idNum = int.tryParse(d.id);
    if (idNum == null) return false;

    final res = await DriversDeleteCall.call(id: idNum);
    _driversLog('delete($idNum) -> status ${res.statusCode}');
    return res.succeeded;
  }

  Future<bool> _confirmDelete(DriverViewModel d) {
    return AppNotifications.confirmDanger(
      context,
      title: 'Attention please!!!',
      message:
      'Are you sure to delete this driver? These data cannot be recovered!',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
    );
  }

  void _openDriverSheet(DriverViewModel d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool active = d.active;
        bool pres = d.presidenceDriver;
        bool backup = d.backupDriver;
        bool jpn = d.speaksJpn;
        bool eng = d.speaksEng;

        const kBlueOn = Color(0xFF84B6FF);
        const kGreenOn = Color(0xFF8EE57F);
        const kGreyOff = Color(0xFFE5E7EB);
        const kRedOff = Color(0xFFFF7A78);

        Future<void> _toggleAndPersist({
          bool? newActive,
          bool? newPres,
          bool? newBackup,
          bool? newJpn,
          bool? newEng,
          required void Function() setLocal,
          required void Function() revertLocal,
        }) async {
          setLocal();
          final ok = await _persistDriverFlags(
            d,
            active: newActive,
            presidence: newPres,
            backup: newBackup,
            jpn: newJpn,
            eng: newEng,
          );
          if (!ok) {
            revertLocal();
            AppNotifications.error(context, 'Failed to update driver.');
          } else {
            setState(() {});
            AppNotifications.success(context, 'Updated.');
          }
        }

        Widget toggleRow({
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
          builder: (context, setModal) {
            final bottom = MediaQuery.of(context).viewInsets.bottom + 20;
            final avatarBytes = _photoFor(d);

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                    Center(
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: const Color(0xFFE5E7EB),
                        child: ClipOval(
                          child: (avatarBytes == null)
                              ? const Icon(Icons.person,
                              size: 34, color: Color(0xFF9CA3AF))
                              : Image.memory(
                            avatarBytes,
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.low,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      d.name,
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(d.email,
                        style: GoogleFonts.inter(
                            fontSize: 16, color: const Color(0xFF333333))),
                    if ((d.phone ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Phone: ${d.phone!}',
                          style: GoogleFonts.inter(fontSize: 16)),
                    ],
                    if ((d.company ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Company: ${d.company!}',
                          style: GoogleFonts.inter(fontSize: 16)),
                    ],
                    const SizedBox(height: 10),

                    toggleRow(
                      label: 'Presidence Driver',
                      value: pres,
                      onColor: kBlueOn,
                      offColor: kGreyOff,
                      onChanged: (v) {
                        _toggleAndPersist(
                          newPres: v,
                          setLocal: () => setModal(() {
                            pres = v;
                            d.presidenceDriver = v;
                          }),
                          revertLocal: () => setModal(() {
                            pres = !v;
                            d.presidenceDriver = !v;
                          }),
                        );
                      },
                    ),
                    toggleRow(
                      label: 'Backup Driver',
                      value: backup,
                      onColor: kBlueOn,
                      offColor: kGreyOff,
                      onChanged: (v) {
                        _toggleAndPersist(
                          newBackup: v,
                          setLocal: () => setModal(() {
                            backup = v;
                            d.backupDriver = v;
                          }),
                          revertLocal: () => setModal(() {
                            backup = !v;
                            d.backupDriver = !v;
                          }),
                        );
                      },
                    ),
                    toggleRow(
                      label: 'Active',
                      value: active,
                      onColor: kGreenOn,
                      offColor: kRedOff,
                      onChanged: (v) {
                        _toggleAndPersist(
                          newActive: v,
                          setLocal: () => setModal(() {
                            active = v;
                            d.active = v;
                          }),
                          revertLocal: () => setModal(() {
                            active = !v;
                            d.active = !v;
                          }),
                        );
                      },
                    ),
                    toggleRow(
                      label: 'Japanese',
                      value: jpn,
                      onColor: kBlueOn,
                      offColor: kGreyOff,
                      onChanged: (v) {
                        _toggleAndPersist(
                          newJpn: v,
                          setLocal: () => setModal(() {
                            jpn = v;
                            d.speaksJpn = v;
                          }),
                          revertLocal: () => setModal(() {
                            jpn = !v;
                            d.speaksJpn = !v;
                          }),
                        );
                      },
                    ),
                    toggleRow(
                      label: 'English',
                      value: eng,
                      onColor: kBlueOn,
                      offColor: kGreyOff,
                      onChanged: (v) {
                        _toggleAndPersist(
                          newEng: v,
                          setLocal: () => setModal(() {
                            eng = v;
                            d.speaksEng = v;
                          }),
                          revertLocal: () => setModal(() {
                            eng = !v;
                            d.speaksEng = !v;
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.pop(context);
                              Future.microtask(() => _goToCarPreference(d));
                            },
                            icon: const Icon(Icons.directions_car_filled_outlined),
                            label: const Text('CAR PREFERENCE'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        if (pres) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.pop(context);
                                Future.microtask(() => _goToScalaPresidence(d));
                              },
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: const Text('SCALA PRESIDENCE'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Future.microtask(() => _goToEdit(d));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8BB9FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('EDIT DRIVER'),
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
              ),
            );
          },
        );
      },
    );
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

class DriverViewModel {
  DriverViewModel({
    required this.id,
    required this.name,
    required this.email,
    this.rg,
    this.phone,
    this.phone2,
    this.company,
    this.companyId,
    this.active = true,
    this.presidenceDriver = false,
    this.backupDriver = false,
    this.speaksJpn = false,
    this.speaksEng = false,
    this.base64Photo,
    Uint8List? photoBytes,
  }) : photoBytes = photoBytes;

  final String id;
  final String name;
  final String email;
  final String? rg;
  final String? phone;
  final String? phone2;
  final String? company;
  final int? companyId;

  final String? base64Photo;

  final Uint8List? photoBytes;

  bool active;
  bool presidenceDriver;
  bool backupDriver;
  bool speaksJpn;
  bool speaksEng;
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.data,
    required this.onTap,
    this.avatarBytes,
  });

  final DriverViewModel data;
  final VoidCallback onTap;
  final Uint8List? avatarBytes;

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

    final statusBg =
    data.active ? const Color(0xFF7EDC83) : const Color(0xFFFF7A78);
    final statusLabel = data.active ? 'Active' : 'Inactive';

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFE5E7EB),
              child: ClipOval(
                child: (avatarBytes == null)
                    ? const Icon(Icons.person,
                    size: 22, color: Color(0xFF9CA3AF))
                    : Image.memory(
                  avatarBytes!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.name,
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF222222))),
                    const SizedBox(height: 6),
                    Text(data.email,
                        style: GoogleFonts.inter(
                            fontSize: 14, color: const Color(0xFF5B5B5B))),
                    if ((data.phone ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Phone: ${data.phone}',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: const Color(0xFF5B5B5B))),
                    ],
                  ]),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                pill(statusLabel, statusBg),
                const SizedBox(height: 6),
                if (data.presidenceDriver)
                  pill('Presidence', const Color(0xFFDCEBFF),
                      fg: const Color(0xFF2E9AFE)),
                if (data.backupDriver) ...[
                  const SizedBox(height: 6),
                  pill('Backup', const Color(0xFFFFEDD5),
                      fg: const Color(0xFFFB923C)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DriversTable extends StatelessWidget {
  const _DriversTable({
    required this.items,
    required this.onRowTap,
    required this.photoFor,
  });

  final List<DriverViewModel> items;
  final void Function(DriverViewModel) onRowTap;
  final Uint8List? Function(DriverViewModel) photoFor;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(theme.secondaryBackground),
        columns: const [
          DataColumn(label: Text('Photo')),
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Phone')),
          DataColumn(label: Text('Company')),
          DataColumn(label: Text('Jpn')),
          DataColumn(label: Text('Eng')),
          DataColumn(label: Text('Status')),
        ],
        rows: items.map((d) {
          final statusChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: d.active ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(d.active ? 'Active' : 'Inactive',
                style: const TextStyle(color: Colors.white)),
          );
          final photo = photoFor(d);
          return DataRow(
            onSelectChanged: (_) => onRowTap(d),
            cells: [
              DataCell(
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE5E7EB),
                  child: ClipOval(
                    child: (photo == null)
                        ? const Icon(Icons.person,
                        size: 16, color: Color(0xFF9CA3AF))
                        : Image.memory(
                      photo,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                ),
              ),
              DataCell(Text(d.name)),
              DataCell(Text(d.email)),
              DataCell(Text(d.phone ?? '')),
              DataCell(Text(d.company ?? '')),
              DataCell(Text(d.speaksJpn ? 'Yes' : 'No')),
              DataCell(Text(d.speaksEng ? 'Yes' : 'No')),
              DataCell(statusChip),
            ],
          );
        }).toList(),
      ),
    );
  }
}
