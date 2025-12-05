import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mitsubishi/backend/api_requests/api_calls.dart';
import 'package:mitsubishi/backend/api_requests/api_manager.dart';
import 'package:mitsubishi/car_request/car_request_model.dart';
import 'package:mitsubishi/services/google_places_service.dart';
import 'package:mitsubishi/secrets.dart';
import 'package:mitsubishi/widgets/notifications/app_notifications.dart';

class IncidentReportFormModal extends StatefulWidget {
  const IncidentReportFormModal({super.key, required this.request});
  final CarRequestViewModel request;

  static Future<void> openIfNotExists({
    required BuildContext context,
    required CarRequestViewModel request,
  }) async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      return;
    }

    final verify = await TrafficIncidentVerifyExistsByCarRequestCall.call(
      bearerToken: token,
      carRequestId:
      IncidentReportFormModal._resolveCarRequestIdFromRequest(request)
          .toString(),
    );

    if (verify.succeeded &&
        TrafficIncidentVerifyExistsByCarRequestCall.exists(verify)) {
      AppNotifications.info(
        context,
        'An incident is already registered for this request.',
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => IncidentReportFormModal(request: request),
    );
  }

  static int _resolveCarRequestIdFromRequest(CarRequestViewModel req) {
    try {
      final v = (req as dynamic).id;
      if (v is int) return v;
      final p = int.tryParse(v?.toString() ?? '');
      if (p != null) return p;
    } catch (_) {}
    try {
      final alt = (req as dynamic).carRequestId;
      if (alt is int) return alt;
      final p = int.tryParse(alt?.toString() ?? '');
      if (p != null) return p;
    } catch (_) {}
    return 0;
  }

  @override
  State<IncidentReportFormModal> createState() =>
      _IncidentReportFormModalState();
}

class _LocalImage {
  final XFile file;
  final Uint8List bytes;
  _LocalImage(this.file, this.bytes);
}

class _PlaceSuggestion {
  final String primary;
  final String secondary;
  const _PlaceSuggestion(this.primary, this.secondary);
}

class _IncidentReportFormModalState extends State<IncidentReportFormModal> {
  late final DateTime _createdAt;
  late DateTime _incidentAt;

  bool _hasInjuries = false;
  final _injuryDetailsCtl = TextEditingController();

  late final TextEditingController _driverCtl;

  final Map<int, String> _passengerUsers = <int, String>{};
  final List<String> _otherPassengers = ['', '', '']; // fixo 3

  final _placeCtl = TextEditingController();
  final _summaryCtl = TextEditingController();

  late final TextEditingController _plateCtl;
  final _damageSummaryCtl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<_LocalImage> _pickedImages = [];

  late final GooglePlacesService _placesApi;
  static const double _spLat = -23.550520, _spLng = -46.633308;
  static const int _strictBoundsRadiusMeters = 50000;
  bool _strictBounds = true;

  final _formKey = GlobalKey<FormState>();

  final LayerLink _placeLink = LayerLink();
  final FocusNode _placeFocus = FocusNode();
  final GlobalKey _placeFieldBoxKey = GlobalKey();
  OverlayEntry? _placeOverlay;
  List<_PlaceSuggestion> _predictions = <_PlaceSuggestion>[];

  double _placeFieldWidth = 0;
  double _placeFieldHeight = 0;

  static const double _rowHeight = 56.0;
  static const int _maxVisibleRows = 4;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _createdAt = DateTime.now();
    _incidentAt = DateTime.now();

    _driverCtl = TextEditingController(text: widget.request.driverName);
    _plateCtl = TextEditingController(text: widget.request.licensePlate);
    _placeCtl.text = widget.request.routeDeparture;

    _placesApi = GooglePlacesService(kGoogleApiKey);

    _placeFocus.addListener(() {
      if (!_placeFocus.hasFocus) _hidePlaceOverlay();
    });
  }

  @override
  void dispose() {
    _injuryDetailsCtl.dispose();
    _driverCtl.dispose();
    _placeCtl.dispose();
    _summaryCtl.dispose();
    _plateCtl.dispose();
    _damageSummaryCtl.dispose();
    _placeFocus.dispose();
    _placeOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: mq.size.height * 0.9,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topBar(context),
                const SizedBox(height: 8),

                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('Creation date:'),
                        _readonlyBox(_fmtDateTime(_createdAt)),

                        const SizedBox(height: 16),
                        _sectionHeader('Injuries'),
                        Row(
                          children: [
                            Checkbox(
                              value: _hasInjuries,
                              onChanged: (v) =>
                                  setState(() => _hasInjuries = v ?? false),
                              materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                            ),
                            const SizedBox(width: 6),
                            const Flexible(
                              child:
                              Text('There are injuries in the incident?'),
                            ),
                          ],
                        ),
                        _fieldLabel('Details of injuries:'),
                        _multiline(
                          controller: _injuryDetailsCtl,
                          enabled: _hasInjuries,
                          hint: 'Describe injuries…',
                        ),

                        const SizedBox(height: 18),
                        _sectionHeader('People involved'),

                        _subHeader("Driver's name"),
                        _iconText(
                          controller: _driverCtl,
                          icon: Icons.person,
                          readOnly: true,
                        ),

                        const SizedBox(height: 12),
                        _subHeader("Passenger's name"),

                        Text('Users',
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in _passengerUsers.entries)
                              Chip(
                                label: Text(entry.value.isNotEmpty
                                    ? entry.value
                                    : 'User #${entry.key}'),
                                onDeleted: () => setState(
                                        () => _passengerUsers.remove(entry.key)),
                              ),
                            ActionChip(
                              label: const Text('Add user'),
                              avatar: const Icon(
                                  Icons.person_add_alt_1_outlined),
                              onPressed: _addPassengerUser,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        Text('Others',
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ...List.generate(3, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _box(
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: _otherPassengers[i],
                                      onChanged: (v) =>
                                      _otherPassengers[i] = v,
                                      decoration: const InputDecoration(
                                        hintText: 'Passenger',
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 18),
                        _sectionHeader('Incident'),

                        _fieldLabel('Incident date:'),
                        _dateTimePickerBox(
                          label: _fmtDateTime(_incidentAt),
                          onTap: _pickIncidentDateTime,
                        ),

                        const SizedBox(height: 10),
                        _fieldLabel('Incident Place:'),

                        Row(
                          children: [
                            Expanded(
                              child: CompositedTransformTarget(
                                link: _placeLink,
                                child: Container(
                                  key: _placeFieldBoxKey,
                                  child: _box(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.search),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: _placeCtl,
                                            focusNode: _placeFocus,
                                            onChanged: (_) =>
                                                _updatePredictions(),
                                            decoration:
                                            const InputDecoration(
                                              hintText: 'Enter a location',
                                              border: InputBorder.none,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Clear',
                                          icon: const Icon(Icons.clear,
                                              size: 18),
                                          padding: EdgeInsets.zero,
                                          constraints:
                                          const BoxConstraints.tightFor(
                                              width: 40, height: 40),
                                          onPressed: () {
                                            _placeCtl.clear();
                                            _updatePredictions();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),

                        const SizedBox(height: 10),
                        _fieldLabel('Incident summary:'),
                        _multiline(
                            controller: _summaryCtl, hint: 'Brief summary…'),

                        const SizedBox(height: 18),
                        _sectionHeader('Car Damage'),

                        _fieldLabel('Damaged car plate:'),
                        _iconText(
                            controller: _plateCtl,
                            icon: Icons.directions_car,
                            readOnly: true),

                        const SizedBox(height: 10),
                        _fieldLabel('Car damage summary:'),
                        _multiline(
                            controller: _damageSummaryCtl,
                            hint: 'Describe damage…'),

                        const SizedBox(height: 18),
                        _sectionHeader('Incident Images'),
                        Text('Please insert clear and legible images',
                            style: GoogleFonts.inter(fontSize: 12)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ..._pickedImages
                                .asMap()
                                .entries
                                .map((e) => Stack(
                              children: [
                                Container(
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                    BorderRadius.circular(8),
                                    color: const Color(0xFFEDEDED),
                                    image: DecorationImage(
                                      image: MemoryImage(
                                          e.value.bytes),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -6,
                                  top: -6,
                                  child: IconButton(
                                    icon: const Icon(Icons.close,
                                        size: 18),
                                    onPressed: () => setState(() =>
                                        _pickedImages
                                            .removeAt(e.key)),
                                  ),
                                ),
                              ],
                            )),
                            OutlinedButton.icon(
                              onPressed: _pickImages,
                              icon: const Icon(Icons.add),
                              label: const Text('Add image'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        SafeArea(
                          top: false,
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed:
                              _submitting ? null : _handleSubmitTap,
                              child: _submitting
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Text('Register'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
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

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8),
        Text('Traffic Incident Report',
            style:
            GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    );
  }

  void _measurePlaceField() {
    final ctx = _placeFieldBoxKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box != null) {
      _placeFieldWidth = box.size.width;
      _placeFieldHeight = box.size.height;
    }
  }

  double _computePopupHeight(bool openUp, double space) {
    final int visibleRows = math.min(_predictions.length, _maxVisibleRows);
    final double content = _rowHeight * visibleRows.toDouble();
    final double maxBySpace = math.max(0.0, space - 12.0);
    return math.min(content, maxBySpace);
  }

  void _showOrUpdatePlaceOverlay() {
    if (!_placeFocus.hasFocus || _predictions.isEmpty) {
      _hidePlaceOverlay();
      return;
    }
    _measurePlaceField();

    final rb =
    (_placeFieldBoxKey.currentContext?.findRenderObject() as RenderBox?)!;
    final topLeft = rb.localToGlobal(Offset.zero);
    final screen = MediaQuery.of(context).size;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    final fieldTop = topLeft.dy;
    final spaceAbove = fieldTop - safeTop;
    final spaceBelow =
        screen.height - (fieldTop + _placeFieldHeight) - safeBottom;

    final openUp = spaceBelow < 180 && spaceAbove > spaceBelow;
    final height =
    _computePopupHeight(openUp, openUp ? spaceAbove : spaceBelow);

    Widget entryBuilder(BuildContext ctx) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _hidePlaceOverlay,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          CompositedTransformFollower(
            link: _placeLink,
            showWhenUnlinked: false,
            offset: openUp
                ? Offset(0, -height - 6)
                : Offset(0, _placeFieldHeight + 6),
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: _placeFieldWidth,
                height: height,
                child: _buildPredictionsList(),
              ),
            ),
          ),
        ],
      );
    }

    if (_placeOverlay == null) {
      _placeOverlay = OverlayEntry(builder: entryBuilder);
      Overlay.of(context).insert(_placeOverlay!);
    } else {
      _placeOverlay!.markNeedsBuild();
    }
  }

  Widget _buildPredictionsList() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0x22000000)),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: _predictions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final s = _predictions[i];
            return SizedBox(
              height: _rowHeight,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.place_outlined),
                title: Text(
                  s.primary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: s.secondary.isEmpty
                    ? null
                    : Text(
                  s.secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  final full = s.secondary.isNotEmpty
                      ? '${s.primary} - ${s.secondary}'
                      : s.primary;
                  _placeCtl.text = full;
                  _predictions = [];
                  _hidePlaceOverlay();
                  setState(() {});
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _hidePlaceOverlay() {
    _placeOverlay?.remove();
    _placeOverlay = null;
  }

  Future<void> _updatePredictions() async {
    final q = _placeCtl.text.trim();
    if (q.length < 2 || !_placeFocus.hasFocus) {
      setState(() => _predictions = []);
      _hidePlaceOverlay();
      return;
    }

    try {
      final results = await _placesApi.autocomplete(
        q,
        mode: 0,
        strictBounds: _strictBounds,
        lat: _strictBounds ? _spLat : null,
        lng: _strictBounds ? _spLng : null,
        radiusMeters: _strictBounds ? _strictBoundsRadiusMeters : null,
      );

      final list = results.map((p) {
        final main = (p.structuredFormatting?.mainText ??
            (p.description ?? '').split(' - ').first)
            .trim();

        String secondary =
        (p.structuredFormatting?.secondaryText ?? '').trim();

        if (secondary.isEmpty) {
          final desc = (p.description ?? '').trim();
          if (desc.isNotEmpty && desc.length > main.length) {
            final idx = desc.indexOf(main);
            if (idx >= 0) {
              secondary = desc
                  .replaceFirst(main, '')
                  .replaceFirst(RegExp(r'^\s*-\s*'), '')
                  .trim();
            } else {
              final parts = desc.split(' - ');
              if (parts.length > 1) {
                secondary = parts.skip(1).join(' - ').trim();
              }
            }
          }
        }

        return _PlaceSuggestion(main, secondary);
      }).where((sug) => sug.primary.isNotEmpty).toList();

      setState(() => _predictions = list);
      _showOrUpdatePlaceOverlay();
    } catch (_) {
      setState(() => _predictions = []);
      _hidePlaceOverlay();
    }
  }

  Future<void> _addPassengerUser() async {
    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      return;
    }

    final users = await _fetchPassengersSelect(token);
    if (users.isEmpty) {
      AppNotifications.info(context, 'No users found.');
      return;
    }

    users.sort((a, b) => a['name']
        .toString()
        .toLowerCase()
        .compareTo(b['name'].toString().toLowerCase()));

    if (!mounted) return;

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final u = users[i];
                return ListTile(
                  leading: const Icon(Icons.person_add_alt_1_outlined),
                  title: Text(u['name']),
                  subtitle: (u['email'] as String?)?.isNotEmpty == true
                      ? Text(u['email'])
                      : null,
                  onTap: () => Navigator.of(_, rootNavigator: true).pop(u),
                );
              },
            ),
          ),
        );
      },
    );

    if (picked != null) {
      final id = picked['id'] as int;
      final name = picked['name'] as String;
      setState(() => _passengerUsers[id] = name);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPassengersSelect(String token) async {
    try {
      final res =
      await TrafficIncidentPassengersSelectCall.call(bearerToken: token);
      if (!res.succeeded) return [];
      final items = TrafficIncidentPassengersSelectCall.items(res);
      final out = <Map<String, dynamic>>[];
      for (final it in items) {
        final id = TrafficIncidentPassengersSelectCall.value(it);
        final name =
        (TrafficIncidentPassengersSelectCall.text(it) ?? '').trim();
        final mail =
        (TrafficIncidentPassengersSelectCall.email(it) ?? '').trim();
        if (id != null && name.isNotEmpty) {
          out.add({'id': id, 'name': name, 'email': mail});
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> _handleSubmitTap() async {
    if (_submitting) return;

    FocusScope.of(context).unfocus();
    _hidePlaceOverlay();

    final errors = _validateForm();
    if (errors.isNotEmpty) {
      FocusScope.of(context).unfocus();
      _hidePlaceOverlay();
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Please review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: errors.map((e) => Text('• $e')).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _onSubmit();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked.isEmpty) return;
      final loaded = <_LocalImage>[];
      for (final x in picked) {
        final bytes = await x.readAsBytes();
        loaded.add(_LocalImage(x, bytes));
      }
      setState(() => _pickedImages.addAll(loaded));
    } catch (e) {
      AppNotifications.error(context, 'Error picking images: $e');
    }
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    _hidePlaceOverlay();

    final token = ApiManager.accessToken;
    if (token == null || token.isEmpty) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      return;
    }

    final carRequestId =
    IncidentReportFormModal._resolveCarRequestIdFromRequest(widget.request);
    if (carRequestId == 0) {
      AppNotifications.error(
          context, 'Invalid request identifier (CarRequestId).');
      return;
    }

    final int? driverId = _tryGetDriverId(widget.request);
    if (driverId == null) {
      AppNotifications.error(context, 'Driver identifier is missing.');
      return;
    }

    final p1 =
    _otherPassengers[0].trim().isEmpty ? null : _otherPassengers[0].trim();
    final p2 =
    _otherPassengers[1].trim().isEmpty ? null : _otherPassengers[1].trim();
    final p3 =
    _otherPassengers[2].trim().isEmpty ? null : _otherPassengers[2].trim();

    final photos = _pickedImages
        .map((img) {
      final name = img.file.name.toLowerCase();
      final isPng = name.endsWith('.png');
      return (
      filename: img.file.name,
      bytes: img.bytes,
      contentType: isPng ? 'image/png' : 'image/jpeg',
      );
    })
        .toList();

    final res = await TrafficIncidentCreateMultipartCall.call(
      bearerToken: token,
      carRequestId: carRequestId,
      driverId: driverId,
      creationAt: _createdAt,
      incidentAt: _incidentAt,
      hasInjuries: _hasInjuries,
      injuriesDetails: _injuryDetailsCtl.text.trim(),
      incidentLocation: _placeCtl.text.trim(),
      incidentBriefSummary: _summaryCtl.text.trim(),
      carDamagePlate: _plateCtl.text.trim(),
      carDamageBriefSummary: _damageSummaryCtl.text.trim(),
      passengersIds: _passengerUsers.keys.toList(),
      passanger1: p1,
      passanger2: p2,
      passanger3: p3,
      photos: photos,
    );

    if (res.succeeded) {
      AppNotifications.success(context, 'Incident registered successfully.');
      if (mounted) {
        _hidePlaceOverlay();
        Navigator.of(context, rootNavigator: true).pop();
      }
    } else {
      AppNotifications.error(
        context,
        'Failed to register (${res.statusCode}).',
      );
    }
  }

  List<String> _validateForm() {
    final errs = <String>[];

    if (_placeCtl.text.trim().isEmpty) {
      errs.add('Incident location is required.');
    }
    if (_summaryCtl.text.trim().isEmpty) {
      errs.add('Incident brief summary is required.');
    }
    if (_damageSummaryCtl.text.trim().isEmpty) {
      errs.add('Car damage brief summary is required.');
    }
    if (_hasInjuries && _injuryDetailsCtl.text.trim().isEmpty) {
      errs.add('Injuries details are required when injuries are reported.');
    }
    final anyPassenger = _passengerUsers.isNotEmpty ||
        _otherPassengers.any((e) => e.trim().isNotEmpty);
    if (!anyPassenger) {
      errs.add('At least one passenger must be specified.');
    }
    if (_pickedImages.isEmpty) {
      errs.add('At least one photo of the incident is required.');
    }
    final carRequestId =
    IncidentReportFormModal._resolveCarRequestIdFromRequest(widget.request);
    if (carRequestId == 0) {
      errs.add('Invalid request identifier (CarRequestId).');
    }
    if (_tryGetDriverId(widget.request) == null) {
      errs.add('Driver identifier is missing.');
    }

    return errs;
  }

  static int? _tryGetDriverId(CarRequestViewModel req) {
    try {
      final v = (req as dynamic).driverId;
      if (v is int) return v;
      final p = int.tryParse(v?.toString() ?? '');
      return p;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickIncidentDateTime() async {
    final ctx = context;
    final d = await showDatePicker(
      context: ctx,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _incidentAt,
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.fromDateTime(_incidentAt),
    );
    if (t == null) return;
    setState(() =>
    _incidentAt = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Widget _sectionHeader(String t) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFE9ECEF),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      t,
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w800,
        color: const Color(0xFF444444),
      ),
    ),
  );

  Widget _subHeader(String t) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF6C757D),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      t,
      style: GoogleFonts.inter(
          fontWeight: FontWeight.w800, color: Colors.white),
    ),
  );

  Widget _fieldLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
  );

  Widget _readonlyBox(String text) => Container(
    width: double.infinity,
    padding:
    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F5F7),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE3E5E8)),
    ),
    child: Text(text),
  );

  Widget _iconText({
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF4F5F7) : Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE3E5E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE3E5E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
      ),
    );
  }

  Widget _multiline({
    required TextEditingController controller,
    String? hint,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: 3,
      maxLines: 6,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE3E5E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE3E5E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
      ),
    );
  }

  Widget _dateTimePickerBox({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE3E5E8)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

String _fmtDateTime(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final y = dt.year.toString().padLeft(4, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$d/$m/$y $hh:$mm';
}

Widget _box({Key? key, EdgeInsets? padding, required Widget child}) {
  return Container(
    key: key,
    padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14), // borda igual ao ref
      border: Border.all(color: const Color(0xFFE3E5E8)),
    ),
    child: child,
  );
}
