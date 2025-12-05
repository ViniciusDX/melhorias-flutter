// lib/register_preferences/favorite_places_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_place/google_place.dart';
import 'package:url_launcher/url_launcher.dart';

import '/backend/api_requests/api_calls.dart' as API;
import '/backend/api_requests/api_manager.dart';
import '/widgets/notifications/app_notifications.dart';
import '../secrets.dart';
import '../services/google_places_service.dart';
import 'rp_models.dart';

class FavoritePlacesScreen extends StatefulWidget {
  const FavoritePlacesScreen({super.key});

  @override
  State<FavoritePlacesScreen> createState() => _FavoritePlacesScreenState();
}

class _FavoritePlacesScreenState extends State<FavoritePlacesScreen> {
  final _gmapsCtrl = TextEditingController();
  final _gmapsFocus = FocusNode();
  final _autocompleteLink = LayerLink();
  final _gmapsFieldKey = GlobalKey();
  OverlayEntry? _overlay;
  double _gmapsFieldWidth = 0;
  double _gmapsFieldHeight = 0;

  final _tableSearchCtrl = TextEditingController();

  int _mode = 0;
  bool _strictBounds = true;

  late final GooglePlacesService _placesApi;
  Timer? _debounce;
  List<AutocompletePrediction> _predictions = [];

  final double _spLat = -23.550520;
  final double _spLng = -46.633308;
  final int _strictBoundsRadiusMeters = 90000;

  final double _kRowHeight = 56.0;
  final int _kMaxVisibleRows = 4;
  late final double _kMaxPopupHeight = _kRowHeight * _kMaxVisibleRows;

  final List<_PlaceVM> _places = [];

  OverlayEntry? _pageLoadingOverlay;
  bool _bootstrapped = false;
  String? _error;

  int? _userId;

  @override
  void initState() {
    super.initState();
    _placesApi = GooglePlacesService(kGoogleApiKey);
    _gmapsFocus.addListener(() {
      if (_gmapsFocus.hasFocus) {
        _measureGmapsField();
        _showOrUpdateOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _resolveUserIdFromJwt();
        await _loadPlaces();
      });
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _debounce?.cancel();
    _gmapsFocus.dispose();
    _gmapsCtrl.dispose();
    _tableSearchCtrl.dispose();
    _hideLoadingOverlay();
    super.dispose();
  }

  Future<void> _resolveUserIdFromJwt() async {
    try {
      final token = ApiManager.accessToken;
      if (token == null || token.split('.').length != 3) return;
      final payloadB64 = token.split('.')[1];
      final normalized = base64Url.normalize(payloadB64);
      final payload = json.decode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      final nameId1 = payload['nameid'];
      final nameId2 = payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'];
      final sub = payload['sub'];
      final idStr = (nameId1 ?? nameId2 ?? sub)?.toString();
      _userId = int.tryParse(idStr ?? '');
    } catch (_) {}
  }

  void _showLoadingOverlay() {
    if (!mounted || _pageLoadingOverlay != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    final entry = OverlayEntry(
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

    final phase = SchedulerBinding.instance.schedulerPhase;
    final building = phase != SchedulerPhase.idle;
    if (building) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pageLoadingOverlay != null) return;
        overlay.insert(entry);
        _pageLoadingOverlay = entry;
      });
    } else {
      overlay.insert(entry);
      _pageLoadingOverlay = entry;
    }
  }

  void _hideLoadingOverlay() {
    _pageLoadingOverlay?.remove();
    _pageLoadingOverlay = null;
  }

  Future<void> _loadPlaces() async {
    if (_userId == null) {
      setState(() {
        _places.clear();
        _error = 'Could not resolve user id.';
      });
      return;
    }
    _showLoadingOverlay();
    _error = null;
    try {
      final res = await API.UsersGetFavoritePlacesCall.call(
        userId: _userId!,
        bearerToken: ApiManager.accessToken,
      );

      if (!mounted) return;

      if (!res.succeeded) {
        setState(() {
          _places.clear();
          _error = res.statusCode == 401
              ? 'Your session expired (401). Please sign in again.'
              : 'Failed to load favorite places (${res.statusCode}).';
        });
        return;
      }

      final items = API.UsersGetFavoritePlacesCall.items(res);
      final mapped = <_PlaceVM>[];

      for (final it in items) {
        final id = API.UsersGetFavoritePlacesCall.id(it);
        if (id == null) continue;

        final name = API.UsersGetFavoritePlacesCall.name(it);
        final addr = API.UsersGetFavoritePlacesCall.address(it);
        final shared = API.UsersGetFavoritePlacesCall.shared(it);
        final sharedOnIso = API.UsersGetFavoritePlacesCall.sharedOnIso(it);

        mapped.add(
          _PlaceVM(
            id: id,
            name: name.trim().isEmpty ? 'Favorite place' : name.trim(),
            address: addr,
            shared: shared,
            sharedOn: (sharedOnIso != null && sharedOnIso.isNotEmpty)
                ? DateTime.tryParse(sharedOnIso)
                : null,
          ),
        );
      }

      setState(() {
        _places
          ..clear()
          ..addAll(mapped);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _places.clear();
        _error = 'Unexpected error: $e';
      });
    } finally {
      _hideLoadingOverlay();
    }
  }

  List<_PlaceVM> get _filtered {
    final q = _tableSearchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _places;
    return _places
        .where((p) =>
    p.name.toLowerCase().contains(q) ||
        p.address.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _searchPanel(),
            const Divider(height: 0),
            Expanded(
              child: _filtered.isEmpty
                  ? ListView(
                padding: const EdgeInsets.fromLTRB(12, 48, 12, 96),
                children: const [
                  Center(child: Text('No favorite places found.')),
                ],
              )
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                itemBuilder: (_, i) => _placeTile(_filtered[i]),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: _filtered.length,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _searchPanel() {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _mode == 0,
                onSelected: (_) {
                  setState(() => _mode = 0);
                  _triggerAutocomplete();
                },
              ),
              ChoiceChip(
                label: const Text('Establishments'),
                selected: _mode == 1,
                onSelected: (_) {
                  setState(() => _mode = 1);
                  _triggerAutocomplete();
                },
              ),
              ChoiceChip(
                label: const Text('Addresses'),
                selected: _mode == 2,
                onSelected: (_) {
                  setState(() => _mode = 2);
                  _triggerAutocomplete();
                },
              ),
              ChoiceChip(
                label: const Text('Geocodes'),
                selected: _mode == 3,
                onSelected: (_) {
                  setState(() => _mode = 3);
                  _triggerAutocomplete();
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Strict Bounds'),
                selected: _strictBounds,
                onSelected: (v) {
                  setState(() => _strictBounds = v);
                  _triggerAutocomplete();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withOpacity(0.35), width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: CompositedTransformTarget(
                    link: _autocompleteLink,
                    child: SizedBox(
                      height: 50,
                      key: _gmapsFieldKey,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: _gmapsCtrl,
                          focusNode: _gmapsFocus,
                          onChanged: _onGoogleChanged,
                          decoration: inputDecoration(
                            'Enter a location',
                            prefixIcon: const Icon(Icons.search),
                          ).copyWith(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _onAddFromSearchField,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Add'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(0.35), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              height: 50,
              child: TextField(
                controller: _tableSearchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: inputDecoration(
                  'Search favorites',
                  prefixIcon: const Icon(Icons.filter_list_rounded),
                ).copyWith(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeTile(_PlaceVM p) {
    final subtitle = <Widget>[
      Text(p.address),
      if (p.shared && p.sharedOn != null)
        Text(
          'Shared on: ${fmtDateTime(p.sharedOn!)}',
          style: const TextStyle(color: Colors.green),
        ),
      if (p.shared && p.sharedOn == null)
        const Text('Shared', style: TextStyle(color: Colors.green)),
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: () => _openPlaceSheet(p),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: subtitle,
        ),
        trailing: IconButton(
          tooltip: 'Options',
          icon: const Icon(Icons.more_horiz),
          onPressed: () => _openPlaceSheet(p),
        ),
      ),
    );
  }

  void _openPlaceSheet(_PlaceVM p) {
    final parentCtx = context;

    showModalBottomSheet(
      context: parentCtx,
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
                p.name,
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _kv('Address', p.address),
              _kv('Shared', p.shared ? 'Yes' : 'No'),
              if (p.shared && p.sharedOn != null) _kv('Shared on', fmtDateTime(p.sharedOn!)),
              const SizedBox(height: 20),
              _pillButton(
                'EDIT PLACE',
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  await _editPlace(p);
                },
                bg: const Color(0xFF8BB9FF),
              ),
              const SizedBox(height: 10),
              _pillButton(
                p.shared ? 'STOP SHARING' : 'SHARE PLACE',
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  if (p.shared) {
                    await _stopShare(p);
                  } else {
                    await _share(p);
                  }
                },
                bg: const Color(0xFF34D399),
              ),
              const SizedBox(height: 10),
              _pillButton(
                'DELETE PLACE',
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  await _deletePlace(p);
                },
                bg: const Color(0xFFE34A48),
              ),
              const SizedBox(height: 10),
              _pillButton(
                'VIEW ON MAP',
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  _openMap(p.address);
                },
                bg: const Color(0xFF3B82F6),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kv(String k, String? v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(color: const Color(0xFF111827), fontSize: 14),
          children: [
            TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: v ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _pillButton(
      String label, {
        required VoidCallback onPressed,
        required Color bg,
      }) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Future<void> _onAddFromSearchField() async {
    final query = _gmapsCtrl.text.trim();
    _removeOverlay();
    await _onAddPlace(prefilledAddress: query.isNotEmpty ? query : null);
  }

  Future<void> _onAddPlace({String? prefilledAddress}) async {
    final initial = FavoritePlace(
      name: '',
      address: prefilledAddress ?? '',
      shared: false,
      sharedOn: null,
    );
    final place = await AppNotifications.showFavoritePlaceModal(
      context,
      title: 'Add favorite place',
      initial: initial,
    );
    if (place == null) return;
    await _savePlace(place: place, id: 0);
    setState(() {
      _predictions.clear();
      _gmapsCtrl.clear();
    });
    _placesApi.resetSession();
    _gmapsFocus.unfocus();
  }

  Future<void> _editPlace(_PlaceVM p) async {
    _showLoadingOverlay();
    try {
      final res = await API.UsersGetFavoritePlaceCall.call(
        placeId: p.id,
        bearerToken: ApiManager.accessToken,
      );

      _hideLoadingOverlay();

      Map<String, dynamic> server = {};
      if (res.succeeded) {
        server = API.UsersGetFavoritePlaceCall.map(res);
      }

      final initial = FavoritePlace(
        name: (server['placeName'] ?? server['name'] ?? p.name)?.toString() ?? p.name,
        address: (server['address'] ?? p.address)?.toString() ?? p.address,
        shared: p.shared,
        sharedOn: p.sharedOn,
      );

      final edited = await AppNotifications.showFavoritePlaceModal(
        context,
        title: 'Edit favorite place',
        initial: initial,
      );
      if (edited == null) return;

      await _savePlace(place: edited, id: p.id);
    } catch (e) {
      _hideLoadingOverlay();
      AppNotifications.error(context, 'Error loading place: $e');
    }
  }

  Future<void> _savePlace({required FavoritePlace place, required int id}) async {
    if (_userId == null) return;
    _showLoadingOverlay();
    try {
      final body = <String, dynamic>{
        'id': id,
        'userId': _userId,
        'placeName': place.name,
        'address': place.address,
      };

      final res = await API.UsersAddOrEditPlaceCall.call(
        placeBody: body,
        bearerToken: ApiManager.accessToken,
      );

      if (!res.succeeded) {
        AppNotifications.error(
          context,
          res.statusCode == 401
              ? 'Your session expired (401). Please sign in again.'
              : 'Failed to save place.',
        );
        return;
      }

      await _loadPlaces();
      AppNotifications.success(context, id == 0 ? 'Place added.' : 'Place updated.');
    } catch (e) {
      AppNotifications.error(context, 'Error saving place: $e');
    } finally {
      _hideLoadingOverlay();
    }
  }

  Future<void> _share(_PlaceVM p) async {
    final ok = await AppNotifications.confirmDanger(
      context,
      title: 'Share this place?',
      message: 'This place will be visible to shared users.',
      cancelLabel: 'Abort',
      confirmLabel: 'Share',
    );
    if (!ok) return;

    _showLoadingOverlay();
    try {
      final res = await API.UsersSharePlaceCall.call(
        placeId: p.id,
        bearerToken: ApiManager.accessToken,
      );

      if (!res.succeeded) {
        AppNotifications.error(
          context,
          res.statusCode == 401
              ? 'Your session expired (401). Please sign in again.'
              : 'Failed to share place.',
        );
        return;
      }

      await _loadPlaces();
      AppNotifications.success(context, 'Place shared.');
    } catch (e) {
      AppNotifications.error(context, 'Error sharing place: $e');
    } finally {
      _hideLoadingOverlay();
    }
  }

  Future<void> _stopShare(_PlaceVM p) async {
    final ok = await AppNotifications.confirmDanger(
      context,
      title: 'Stop sharing?',
      message: 'This place will no longer be shared.',
      cancelLabel: 'Abort',
      confirmLabel: 'Stop',
    );
    if (!ok) return;

    _showLoadingOverlay();
    try {
      final res = await API.UsersStopSharePlaceCall.call(
        placeId: p.id,
        bearerToken: ApiManager.accessToken,
      );

      if (!res.succeeded) {
        AppNotifications.error(
          context,
          res.statusCode == 401
              ? 'Your session expired (401). Please sign in again.'
              : 'Failed to stop sharing.',
        );
        return;
      }

      await _loadPlaces();
      AppNotifications.success(context, 'Sharing removed.');
    } catch (e) {
      AppNotifications.error(context, 'Error stopping share: $e');
    } finally {
      _hideLoadingOverlay();
    }
  }

  Future<void> _deletePlace(_PlaceVM p) async {
    final ok = await AppNotifications.confirmDanger(
      context,
      title: 'Delete place',
      message: 'Remove "${p.name}" from favorites?',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
    );
    if (!ok) return;

    _showLoadingOverlay();
    try {
      final res = await API.UsersDeletePlaceCall.call(
        placeId: p.id,
        bearerToken: ApiManager.accessToken,
      );

      if (!res.succeeded) {
        AppNotifications.error(
          context,
          res.statusCode == 401
              ? 'Your session expired (401). Please sign in again.'
              : 'Failed to delete place.',
        );
        return;
      }

      await _loadPlaces();
      AppNotifications.success(context, 'Place deleted.');
    } catch (e) {
      AppNotifications.error(context, 'Error deleting place: $e');
    } finally {
      _hideLoadingOverlay();
    }
  }

  void _onGoogleChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _triggerAutocomplete);
  }

  void _measureGmapsField() {
    final ctx = _gmapsFieldKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box != null) {
      _gmapsFieldWidth = box.size.width;
      _gmapsFieldHeight = box.size.height;
    }
  }

  double _computePopupHeight(bool openUp, double space) {
    final int visibleRows = math.min(_predictions.length, _kMaxVisibleRows);
    final double content = _kRowHeight * visibleRows.toDouble();
    final double maxBySpace = math.max(0.0, space - 12.0);
    return math.min(content, math.min(_kMaxPopupHeight, maxBySpace));
  }

  void _showOrUpdateOverlay() {
    if (!_gmapsFocus.hasFocus || _predictions.isEmpty) {
      _removeOverlay();
      return;
    }
    _measureGmapsField();

    final rb = (_gmapsFieldKey.currentContext?.findRenderObject() as RenderBox?)!;
    final topLeft = rb.localToGlobal(Offset.zero);
    final screen = MediaQuery.of(context).size;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    final fieldTop = topLeft.dy;
    final spaceAbove = fieldTop - safeTop;
    final spaceBelow = screen.height - (fieldTop + _gmapsFieldHeight) - safeBottom;

    final openUp = spaceBelow < 180 && spaceAbove > spaceBelow;
    final height = _computePopupHeight(openUp, openUp ? spaceAbove : spaceBelow);

    Widget entryBuilder(BuildContext ctx) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          CompositedTransformFollower(
            link: _autocompleteLink,
            showWhenUnlinked: false,
            offset: openUp ? Offset(0, -height - 6) : Offset(0, _gmapsFieldHeight + 6),
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: _gmapsFieldWidth,
                height: height,
                child: _buildPredictionsList(),
              ),
            ),
          ),
        ],
      );
    }

    if (_overlay == null) {
      _overlay = OverlayEntry(builder: entryBuilder);
      Overlay.of(context).insert(_overlay!);
    } else {
      _overlay!.markNeedsBuild();
    }
  }

  Widget _buildPredictionsList() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(.3)),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: _predictions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = _predictions[i];
            final main = p.structuredFormatting?.mainText ?? p.description ?? '';
            final sec = p.structuredFormatting?.secondaryText ?? '';
            return SizedBox(
              height: _kRowHeight,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.place_outlined),
                title: Text(main, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: sec.isEmpty ? null : Text(sec),
                onTap: () => _onPredictionTap(p),
              ),
            );
          },
        ),
      ),
    );
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Future<void> _triggerAutocomplete() async {
    final q = _gmapsCtrl.text.trim();
    if (q.isEmpty) {
      if (_predictions.isNotEmpty) {
        setState(() => _predictions = []);
        _removeOverlay();
      }
      return;
    }

    double? lat;
    double? lng;
    if (_strictBounds) {
      lat = _spLat;
      lng = _spLng;
    }

    final results = await _placesApi.autocomplete(
      q,
      mode: _mode,
      strictBounds: _strictBounds,
      lat: lat,
      lng: lng,
      radiusMeters: _strictBounds ? _strictBoundsRadiusMeters : null,
    );

    if (!mounted) return;
    setState(() => _predictions = results);
    _showOrUpdateOverlay();
  }

  Future<void> _onPredictionTap(AutocompletePrediction p) async {
    final id = p.placeId;
    if (id == null) return;

    final d = await _placesApi.details(id);

    final initial = FavoritePlace(
      name: d?.name ?? p.structuredFormatting?.mainText ?? 'Place',
      address: d?.formattedAddress ?? p.description ?? '',
      sharedOn: null,
      shared: false,
    );

    _removeOverlay();

    final saved = await AppNotifications.showFavoritePlaceModal(
      context,
      title: 'Add favorite place',
      initial: initial,
    );

    if (saved != null) {
      await _savePlace(place: saved, id: 0);
      setState(() {
        _predictions.clear();
        _gmapsCtrl.clear();
      });
      _placesApi.resetSession();
      _gmapsFocus.unfocus();
    }
  }

  Future<void> _openMap(String address) async {
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        AppNotifications.error(context, 'Could not open map.');
      }
    }
  }
}

InputDecoration inputDecoration(
    String label, {
      Widget? prefixIcon,
    }) {
  return InputDecoration(
    labelText: label,
    prefixIcon: prefixIcon,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      borderSide: const BorderSide(color: Color(0x22000000)),
    ),
  );
}

class _PlaceVM {
  _PlaceVM({
    required this.id,
    required this.name,
    required this.address,
    required this.shared,
    required this.sharedOn,
  });

  final int id;
  String name;
  String address;
  bool shared;
  DateTime? sharedOn;
}
