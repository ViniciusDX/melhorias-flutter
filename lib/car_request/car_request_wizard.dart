import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mitsubishi/backend/api_requests/api_calls.dart' as Api;
import 'package:mitsubishi/car_request/car_request_model.dart';
import 'package:mitsubishi/flutter_flow/flutter_flow_util.dart';
import 'package:mitsubishi/secrets.dart';
import 'package:mitsubishi/services/google_places_service.dart';
import 'package:mitsubishi/widgets/notifications/app_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import '/auth/custom_auth/session_utils.dart';

typedef FetchUsersFn = Future<List<UserLite>> Function();
typedef FetchUserCostAllocsFn = Future<List<CostAllocLite>> Function(int ownerId);
typedef SubmitCarRequestFn = Future<bool> Function(
    Map<String, dynamic> body, {int? id, bool useAdminUpdate}
    );
typedef FetchDriversFn = Future<List<DriverLite>> Function();
typedef FetchCarsFn = Future<List<CarLite>> Function();
enum CarRequestFormMode { create, edit , adjust }
class UserLite {
  final int id;
  final String fullName;
  const UserLite({required this.id, required this.fullName});
}
class CostAllocLite {
  final int id;
  final String name;
  const CostAllocLite({required this.id, required this.name});
}

class DriverLite {
  final int id;
  final String fullName;
  const DriverLite({required this.id, required this.fullName});
}

class _FavPlace {
  final String name;
  final String address;
  const _FavPlace(this.name, this.address);

  String display([bool withName = true]) =>
      (withName && name.trim().isNotEmpty) ? '$name — $address' : address;
}

String _nz(String? v) => (v ?? '').trim();

class CarLite {
  final int id;
  final String name;
  final String? plate;
  const CarLite({required this.id, required this.name, this.plate});
}

class CarRequestWizard extends StatefulWidget {
  const CarRequestWizard({
    super.key,
    required this.mode,
    this.initial,
    this.fetchUsers,
    this.fetchUserCostAllocs,
    this.submitCarRequest,
    this.fetchDrivers,
    this.fetchCars,
    this.isAdmin = false,
    this.currentUserId,
    this.currentUserName,
  });

  final bool isAdmin;
  final int? currentUserId;
  final String? currentUserName;
  final CarRequestFormMode mode;
  final CarRequestViewModel? initial;

  final FetchUsersFn? fetchUsers;
  final FetchUserCostAllocsFn? fetchUserCostAllocs;
  final SubmitCarRequestFn? submitCarRequest;

  final FetchDriversFn? fetchDrivers;
  final FetchCarsFn? fetchCars;

  @override
  State<CarRequestWizard> createState() => _CarRequestWizardState();
}

class _CarRequestWizardState extends State<CarRequestWizard> {

  final _page = PageController();
  int _carTypeIdx = 0;
  final _specialCarInfoCtrl = TextEditingController();
  OverlayEntry? _finishLoadingOverlay;
  static const List<String> _carTypeLabels = [
    'Outlander', 'Mini Van', 'Van', 'Sedan', 'SUV'
  ];
  bool get _isAdmin => widget.isAdmin || Session.isAdmin();

  bool get _isAdjust => widget.mode == CarRequestFormMode.adjust;

  bool get _canAssignInEdit => _isAdmin && widget.mode == CarRequestFormMode.edit;

  bool get _canAssignCarInAdjust => _isAdmin && widget.mode == CarRequestFormMode.adjust;

  bool get _canAssignDriverCar =>
      _isAdmin && (widget.mode == CarRequestFormMode.edit || widget.mode == CarRequestFormMode.adjust);
  bool get _isExistingRequest {
    final raw = widget.initial?.id;
    final id = raw == null ? null : int.tryParse(raw);
    return id != null && id > 0;
  }
  bool get _showSpecialCarInfo =>
      _isAdmin && _isExistingRequest && (_isAdjust || _carTypeIdx != 0);

  bool get _needsSpecialCarInfo =>
      _isAdmin && _isExistingRequest && _isAdjust;
  int? get _loggedUserId {
    final s = Session.userId();
    return s == null ? null : int.tryParse(s);
  }

  late final GooglePlacesService _placesApi;
  static const _spLat = -23.550520, _spLng = -46.633308;
  static const _strictBoundsRadiusMeters = 90000;

  final _userCtrl = TextEditingController();
  final _departureCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();

  DateTime _from = DateTime.now();
  DateTime? _to = DateTime.now().add(const Duration(hours: 2));
  bool _childSeat = false;
  bool _bookNow = false;

  final _userFieldKey = GlobalKey<FormFieldState<String>>();
  final _userFieldBoxKey = GlobalKey();
  final _userLink = LayerLink();
  OverlayEntry? _userEntry;

  final _placeCtrl = TextEditingController();
  final _placeFocus = FocusNode();
  final _placeLink = LayerLink();
  final _placeFieldBoxKey = GlobalKey();
  OverlayEntry? _placeEntry;
  final _carTypeBoxKey = GlobalKey();
  final _carTypeLink = LayerLink();
  OverlayEntry? _carTypeEntry;

  final _driverBoxKey = GlobalKey();
  final _driverLink = LayerLink();
  OverlayEntry? _driverEntry;

  final _carBoxKey = GlobalKey();
  final _carLink = LayerLink();
  OverlayEntry? _carEntry;

  int _placeMode = 0;
  bool _strictBounds = true;
  bool _onlyFavorites = false;

  List<_FavPlace> _favoritePlaces = const [];

  bool _favoritePlacesLoaded = false;
  bool _favoritePlacesLoading = false;

  List<String> _predictions = [];
  int? _selectedUserId;
  final List<int> _passengerUsersIds = [];
  List<UserLite> _users = [];
  bool _usersLoading = false;
  bool _usersLoadedOnce = false;

  int? _selectedDriverId;
  int? _selectedCarId;

  List<DriverLite> _drivers = [];
  bool _driversLoading = false;
  bool _driversLoadedOnce = false;

  List<CarLite> _cars = [];
  bool _carsLoading = false;
  bool _carsLoadedOnce = false;

  final Map<int, List<CostAllocLite>> _userCostAllocCache = {};

  final List<String> _destinations = [];
  final List<Key> _destKeys = [];
  final List<String> _passengerUsers = [];
  final List<String> _otherPassengers = ["", "", ""];

  final List<_CostAllocationEntry> _allocs = [];
  double get _allocTotal => _allocs.fold(0, (p, e) => p + (e.percent ?? 0));

  FlightInfo? _depFlight;
  final List<FlightInfo?> _destFlights = [];

  int _step = 0;
  int get _totalSteps => 6;

  @override
  void initState() {
    super.initState();
    _placesApi = GooglePlacesService(kGoogleApiKey);
    _hydrateFromInitial();
    _ensureAtLeastOneDestination();
    _loadUsersIfNeeded().whenComplete(_prefillLoggedUserIfCreate);
    _placeFocus.addListener(() {
      if (_placeFocus.hasFocus) {
        _showOrUpdatePlaceOverlay();
      } else {
        _closePlaceOverlay();
      }
    });
  }

  void _showFinishLoadingOverlay() {
    if (!mounted || _finishLoadingOverlay != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;
    _finishLoadingOverlay = OverlayEntry(
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
    overlay.insert(_finishLoadingOverlay!);
  }

  void _hideFinishLoadingOverlay() {
    _finishLoadingOverlay?.remove();
    _finishLoadingOverlay = null;
  }

  void _hydrateFromInitial() {
    final i = widget.initial;
    if (i != null) {
      _carTypeIdx = ((i.carType ?? 0).clamp(0, _carTypeLabels.length - 1));
      _specialCarInfoCtrl.text = i.specialCarInfo ?? '';

      _otherPassengers[0] = i.passanger1 ?? '';
      _otherPassengers[1] = i.passanger2 ?? '';
      _otherPassengers[2] = i.passanger3 ?? '';

      _selectedUserId = i.userId;
      _userCtrl.text = i.userName;

      _modelCtrl.text = _matchCarType(i.model);
      _from = i.periodFrom;
      _to = i.periodTo;
      _departureCtrl.text = i.routeDeparture;

      _destinations
        ..clear()
        ..addAll(i.destinations);
      _destKeys
        ..clear()
        ..addAll(List.generate(_destinations.length, (_) => UniqueKey()));

      _notesCtrl.text = i.notes ?? '';
      _childSeat = i.childSeat;

      _bookNow = i.bookNow;

      _selectedDriverId = i.driverId;
      _selectedCarId = i.carId;

      _passengerUsersIds
        ..clear()
        ..addAll(i.passengersIds ?? const []);

      _allocs
        ..clear()
        ..addAll(i.costAllocs.map<_CostAllocationEntry>((c) {
          return _CostAllocationEntry(
            ownerId: c.ownerId,
            ownerName: _nz(c.ownerName),
            costAllocId: c.costAllocId,
            costAllocName: _nz(c.costAllocName),
            percent: (c.percent).clamp(0.0, 100.0),
          );
        }));

      _depFlight = null;
      _destFlights
        ..clear()
        ..addAll(List.generate(_destinations.length, (_) => null));

      for (final f in i.flightsInformations) {
        final fi = FlightInfo(
          isDeparture: f.isDeparture,
          airport: f.isDeparture ? f.sourceAirport : f.destinationAirport,
          time: f.time,
          sourceAirport: f.sourceAirport,
          destinationAirport: f.destinationAirport,
          flightNumber: f.flightNumber,
        );

        if (f.isDeparture) {
          _depFlight = fi;
        } else {
          final destKey = (f.destination).trim().toLowerCase();
          if (destKey.isNotEmpty) {
            final idx = _destinations.indexWhere(
                  (d) => d.trim().toLowerCase() == destKey,
            );
            if (idx != -1) {
              while (_destFlights.length < _destinations.length) {
                _destFlights.add(null);
              }
              _destFlights[idx] = fi;
            }
          }
        }
      }

      final needNames =
          (_selectedUserId != null && _userCtrl.text.trim().isEmpty) ||
              _allocs.any((a) => (a.ownerId != null && _nz(a.ownerName).isEmpty)) ||
              (_passengerUsersIds.isNotEmpty && _passengerUsers.isEmpty);

      if (needNames) {
        if (_usersLoadedOnce) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _backfillNamesFromUsers());
        } else {
          _loadUsersIfNeeded().whenComplete(() {
            if (mounted) _backfillNamesFromUsers();
          });
        }
      }
    } else {
      _modelCtrl.text = _carTypes.first;
    }
    _ensureAtLeastOneDestination();
  }

  @override
  void dispose() {
    _page.dispose();
    _userCtrl.dispose();
    _departureCtrl.dispose();
    _notesCtrl.dispose();
    _modelCtrl.dispose();
    _closeUserOverlay();
    _closeCarTypeOverlay();
    _closeDriverOverlay();
    _closeCarOverlay();
    _placeCtrl.dispose();
    _placeFocus.dispose();
    _closePlaceOverlay();
    super.dispose();
  }

  Future<void> _loadUsersIfNeeded() async {
    if (_usersLoading || _usersLoadedOnce) return;
    setState(() => _usersLoading = true);
    try {
      final data = await (widget.fetchUsers?.call() ?? apiFetchUsers());
      if (mounted) {
        setState(() {
          _users = data;
          _usersLoadedOnce = true;
          _passengerUsers.removeWhere((n) => !_users.any((u) => u.fullName == n));
        });
        _backfillNamesFromUsers();
      }
    } catch (e) {
      _toast('Failed to load users.');
    } finally {
      if (mounted) setState(() => _usersLoading = false);
    }
  }

  String _initialDriverName() {
    return _nz(widget.initial?.driverName);
  }

  bool _isFlightFilled(FlightInfo? f) {
    if (f == null) return false;
    final src = (f.sourceAirport ?? '').trim();
    final dst = (f.destinationAirport ?? '').trim();
    final num = (f.flightNumber ?? '').trim();
    final tm = f.time;

    return src.isNotEmpty && dst.isNotEmpty && num.isNotEmpty && tm != null;
  }
  bool _validateFlightsForRouteStep() {
    final depAddr = _departureCtrl.text.trim();
    if (_looksLikeAirport(depAddr) && !_isFlightFilled(_depFlight)) {
      AppNotifications.warning(
        context,
        'You must complete the flight information for the Departure section before continuing.',
      );
      return false;
    }

    for (var i = 0; i < _destinations.length; i++) {
      final addr = _destinations[i].trim();
      if (_looksLikeAirport(addr)) {
        final FlightInfo? f = (i < _destFlights.length) ? _destFlights[i] : null;
        if (!_isFlightFilled(f)) {
          AppNotifications.warning(
            context,
            'You must complete the flight information for Destination ${i + 1} before continuing.',
          );
          return false;
        }
      }
    }

    return true;
  }
  Future<void> _next() async {
    if (!await _validateStep(_step)) return;

    if (_step == 3 && !_validateFlightsForRouteStep()) {
      AppNotifications.warning(
        context,
        'Please fill in all required fields before proceeding to the next step.',
      );
      return;
    }

    final isLast = _step >= _totalSteps - 1;
    if (isLast) {
      _finish();
    } else {
      setState(() => _step++);
      await _page.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _prefillLoggedUserIfCreate() async {
    if (widget.mode != CarRequestFormMode.create) return;
    if (_selectedUserId != null && _userCtrl.text.trim().isNotEmpty) return;

    final uid = widget.currentUserId ?? _loggedUserId;
    if (uid == null) {
      return;
    }
    _selectedUserId = uid;
    String? name;
    for (final u in _users) {
      if (u.id == uid) {
        name = u.fullName;
        break;
      }
    }
    name ??= widget.currentUserName;
    if (name != null && name.trim().isNotEmpty) {
      _userCtrl.text = name;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadDriversIfNeeded() async {
    if (_driversLoading || _driversLoadedOnce) return;
    setState(() => _driversLoading = true);
    try {
      final safeTo = _to ?? _from.add(const Duration(hours: 1));
      final data = await (widget.fetchDrivers?.call() ?? apiFetchDrivers(from: _from, to: safeTo));

      final savedName = _initialDriverName();
      if (_selectedDriverId != null &&
          !data.any((d) => d.id == _selectedDriverId) &&
          savedName.isNotEmpty) {
        data.insert(0, DriverLite(
          id: _selectedDriverId!,
          fullName: savedName,
        ));
      }

      if (mounted) {
        setState(() {
          _drivers = data;
          _driversLoadedOnce = true;
        });
      }
    } catch (_) {
      _toast('Failed to load drivers.');
    } finally {
      if (mounted) setState(() => _driversLoading = false);
    }
  }

  Future<void> _loadCarsIfNeeded() async {
    if (_carsLoading || _carsLoadedOnce) return;
    setState(() => _carsLoading = true);
    try {
      final safeTo = _to ?? _from.add(const Duration(hours: 1));
      final data = await (widget.fetchCars?.call() ?? apiFetchCars(from: _from, to: safeTo));

      if (_selectedCarId != null && !data.any((c) => c.id == _selectedCarId)) {
        final model = widget.initial?.model;
        final plate = widget.initial?.licensePlate;
        final name = (model?.isNotEmpty ?? false) ? model! : 'Car #${_selectedCarId}';
        data.insert(0, CarLite(
          id: _selectedCarId!,
          name: name,
          plate: (plate?.isEmpty ?? true) ? null : plate,
        ));
      }

      if (mounted) {
        setState(() {
          _cars = data;
          _carsLoadedOnce = true;
        });
      }
    } catch (_) {
      _toast('Failed to load cars.');
    } finally {
      if (mounted) setState(() => _carsLoading = false);
    }
  }

  Future<List<CostAllocLite>> _getCostAllocationsForUser(int ownerId) async {
    if (_userCostAllocCache.containsKey(ownerId)) {
      return _userCostAllocCache[ownerId]!;
    }
    try {
      final list = await (widget.fetchUserCostAllocs?.call(ownerId) ?? apiFetchUserCostAllocs(ownerId));
      _userCostAllocCache[ownerId] = list;
      return list;
    } catch (_) {
      _toast('Failed to load cost allocations.');
      return [];
    }
  }

  static const List<String> _carTypes = ['Outlander', 'Eclipse Cross', 'L200', 'ASX', 'Other'];

  String _matchCarType(String? raw) {
    if (raw == null || raw.trim().isEmpty) return _carTypes.first;
    final v = raw.trim().toLowerCase();
    return _carTypes.firstWhere((t) => t.toLowerCase() == v, orElse: () => _carTypes.first);
  }

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '—';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm ${hh}h$mi';
  }

  bool _looksLikeAirport(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return false;

    const keywordContains = <String>[
      'aeroporto',
      'airport',
      'congonhas',
      'guarulhos',
      'コンゴーニャス空港', // congonhas
      'グアルーリョス国際空港', // aeroporto de guarulhos
      'ヴィラコッポス国際空港', // Viracopos
    ];
    if (keywordContains.any((k) => t.contains(k))) return true;

    final codeRe = RegExp(
      r'\b(GRU|CGH|VCP|SDU|GIG|BSB|CNF|POA|SSA|REC|CWB|SJK|RAO)\b',
      caseSensitive: false,
    );
    return codeRe.hasMatch(s);
  }

  void _backfillNamesFromUsers() {
    if (!_usersLoadedOnce || _users.isEmpty) return;

    bool changed = false;

    if (_selectedUserId != null && _userCtrl.text.trim().isEmpty) {
      final u = _users.where((x) => x.id == _selectedUserId).toList();
      if (u.isNotEmpty) { _userCtrl.text = u.first.fullName; changed = true; }
    }

    for (var i = 0; i < _allocs.length; i++) {
      final a = _allocs[i];
      if (_nz(a.ownerName).isEmpty && a.ownerId != null) {
        final u = _users.where((x) => x.id == a.ownerId).toList();
        if (u.isNotEmpty) {
          _allocs[i] = a.copyWith(ownerName: u.first.fullName);
          changed = true;
        }
      }
    }

    if (_passengerUsersIds.isNotEmpty) {
      final current = Set<String>.from(_passengerUsers);
      for (final id in _passengerUsersIds) {
        final u = _users.where((x) => x.id == id).toList();
        if (u.isNotEmpty && !current.contains(u.first.fullName)) {
          _passengerUsers.add(u.first.fullName);
          current.add(u.first.fullName);
          changed = true;
        }
      }
      _passengerUsers.removeWhere((n) => !_users.any((u) => u.fullName == n));
    }

    if (changed && mounted) setState(() {});
  }

  String _flightSummary(FlightInfo f) {
    final t = f.time;
    final hh = t == null ? '--' : t.hour.toString().padLeft(2, '0');
    final mm = t == null ? '--' : t.minute.toString().padLeft(2, '0');
    final src = f.sourceAirport;
    final dst = f.destinationAirport;
    final num = f.flightNumber;
    return 'Time: $hh:$mm\nSource airport: ${src.isEmpty ? '—' : src}\nDestination airport: ${dst.isEmpty ? '—' : dst}\nFlight number: ${num.isEmpty ? '—' : num}';
  }

  TextStyle get _h1 => GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18);
  TextStyle get _h2 => GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black54);

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _page.previousPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic);
    } else {
      Navigator.pop(context);
    }
  }

  Future<bool> _validateStep(int s) async {
    switch (s) {
      case 0:
        if (_selectedUserId == null && _userCtrl.text.trim().isNotEmpty) {
          if (!_usersLoadedOnce) {
            await _loadUsersIfNeeded();
          }
          final name = _userCtrl.text.trim();
          final match = _users.where((u) => u.fullName == name).toList();
          if (match.isNotEmpty) {
            setState(() => _selectedUserId = match.first.id);
          }
        }

        final ok = _selectedUserId != null && _to != null;
        if (!ok) _toast('Please select the user and the period.');
        if (_to != null && _from.isAfter(_to!)) {
          _toast('Start date cannot be after end date.');
          return false;
        }
        return ok;

      case 1:
        return true;

      case 2:
        if (_allocs.isEmpty) {
          _toast('Add at least one cost allocation.');
          return false;
        }
        if ((_allocTotal - 100).abs() > 0.001) {
          _toast('The sum of allocations must be 100%.');
          return false;
        }
        return true;

      case 3:
        if (_departureCtrl.text.trim().isEmpty) {
          _toast('Please enter the departure address.');
          return false;
        }
        final dests = _destinations.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (dests.isEmpty) {
          _toast('Please add at least one destination.');
          return false;
        }
        return true;

      case 4:
        if (_canAssignInEdit) {
          if (_selectedDriverId == null) { _toast('Please select a driver.'); return false; }
          if (_selectedCarId == null)    { _toast('Please select a car.');    return false; }
        } else if (_canAssignCarInAdjust) {
          if (_selectedCarId == null)    { _toast('Please select a car.');    return false; }
        }

        if (_needsSpecialCarInfo && _specialCarInfoCtrl.text.trim().isEmpty) {
          _toast('Additional Information is required to confirm this request.');
          return false;
        }
        return true;


      default:
        return true;
    }
  }


  void  _finish() async {
    if (!_validateFlightsForRouteStep()) {
      AppNotifications.warning(
        context,
        'Please complete all required flight fields before finishing the request.',
      );
      return;
    }

    _showFinishLoadingOverlay();

    try {
      final flights = <Map<String, dynamic>>[];
      if (_depFlight != null) {
        flights.add(_flightToBackendDto(
          _depFlight!, isDeparture: true, destination: _departureCtrl.text.trim(),
        ));
      }
      for (var i = 0; i < _destinations.length; i++) {
        final f = (i < _destFlights.length) ? _destFlights[i] : null;
        if (f != null) {
          flights.add(_flightToBackendDto(
            f, isDeparture: false, destination: _destinations[i].trim(),
          ));
        }
      }

      final destsClean = _destinations.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final carRequestDests = <Map<String, dynamic>>[
        for (int i = 0; i < destsClean.length; i++)
          {'DestAddress': destsClean[i], 'Sequence': i + 1}
      ];

      final carRequestsCostAllocs = _allocs
          .where((a) => a.costAllocId != null)
          .map((a) => {
        if (a.ownerId != null) 'UserId': a.ownerId,
        'CostAllocId': a.costAllocId,
        'Percent': ((a.percent ?? 0) as num).toDouble(),
      })
          .toList();

      final Map<String, dynamic> body = {
        'UserId': _selectedUserId!,
        'StartDateTime': _from.toIso8601String(),
        'EndDateTime': (_to ?? _from.add(const Duration(hours: 1))).toIso8601String(),
        'SourceAddress': _departureCtrl.text.trim(),
        'BookNow': _bookNow,
        'ChildSeat': _childSeat,
        'CarType': _carTypeIdx,
        'PassengersId': List<int>.from(_passengerUsersIds),
        'CarRequestsCostAllocs': carRequestsCostAllocs,
        'CarRequestDests': carRequestDests,
        'FlightsInformations': flights,
      };

      final uid = widget.currentUserId ?? _loggedUserId;
      if (uid != null) {
        body['RequirerId'] = uid;
        body['requirerId'] = uid;
      }

      final note = _notesCtrl.text.trim();
      if (note.isNotEmpty) body['Note'] = note;

      final sci = _specialCarInfoCtrl.text.trim();
      if (sci.isNotEmpty) body['SpecialCarInfo'] = sci;

      if (_canAssignDriverCar) {
        if (_selectedDriverId != null) body['DriverId'] = _selectedDriverId;
        if (_selectedCarId != null) body['CarId'] = _selectedCarId;
      }

      final p1 = _otherPassengers[0].trim();
      final p2 = _otherPassengers[1].trim();
      final p3 = _otherPassengers[2].trim();
      if (p1.isNotEmpty) body['Passanger1'] = p1;
      if (p2.isNotEmpty) body['Passanger2'] = p2;
      if (p3.isNotEmpty) body['Passanger3'] = p3;

      final int? idForUpdate =
      (widget.mode == CarRequestFormMode.edit || widget.mode == CarRequestFormMode.adjust)
          ? int.tryParse(widget.initial!.id)
          : null;
      if (idForUpdate != null) body['Id'] = idForUpdate;

      final ok = await (widget.submitCarRequest?.call(
        body,
        id: idForUpdate,
        useAdminUpdate: widget.mode == CarRequestFormMode.adjust,
      ) ??
          apiSubmitCarRequest(
            body,
            id: idForUpdate,
            useAdminUpdate: widget.mode == CarRequestFormMode.adjust,
          ));

      if (!mounted) return;

      _hideFinishLoadingOverlay();

      if (ok) {
        Navigator.pop<bool>(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      _hideFinishLoadingOverlay();
      _toast('Failed to submit. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(
          widget.mode == CarRequestFormMode.create
              ? 'Register Car Request'
              : widget.mode == CarRequestFormMode.adjust
              ? 'Adjust Car Request'
              : 'Edit Car Request',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(step: _step, totalSteps: _totalSteps),
            const SizedBox(height: 4),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _stepFor(),
                  _stepPassengers(),
                  _stepPurpose(),
                  _stepRoute(),
                  _stepCar(),
                  _stepReview(),
                ],
              ),
            ),
            _BottomNav(step: _step, total: _totalSteps, onBack: _back, onNext: _next),
          ],
        ),
      ),
    );
  }

  Widget _stepFor() {
    final readOnly = _isAdjust;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('For', style: _h1),
        const SizedBox(height: 10),
        Text('User*', style: _h2),
        const SizedBox(height: 6),

        if (readOnly) ...[
          _box(
            child: Row(
              children: [
                const Icon(Icons.person_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _userCtrl.text.isNotEmpty ? _userCtrl.text : '—',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.lock_outline, size: 18),
              ],
            ),
          ),
        ] else ...[
          CompositedTransformTarget(
            link: _userLink,
            child: _box(
              key: _userFieldBoxKey,
              child: InkWell(
                onTap: () async {
                  await _loadUsersIfNeeded();
                  _openUserOverlay();
                },
                child: Row(
                  children: [
                    const Icon(Icons.person_outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FormField<String>(
                        key: _userFieldKey,
                        builder: (_) {
                          final hasValue = _userCtrl.text.isNotEmpty;
                          return Text(
                            hasValue
                                ? _userCtrl.text
                                : (_usersLoading ? 'Loading users...' : 'Select a user'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: hasValue ? null : Colors.black45,
                              fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        Text('Scheduled period', style: _h2),
        const SizedBox(height: 8),

        Row(children: [
          Expanded(
            child: readOnly
                ? _box(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('From', style: _h2),
                    const SizedBox(height: 4),
                    Text(_fmtDateTime(_from), style: GoogleFonts.inter(fontSize: 16)),
                  ]),
                  const Icon(Icons.lock_outline, size: 18),
                ],
              ),
            )
                : _dateBox('From', _from, (d) => setState(() => _from = d)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: readOnly
                ? _box(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('To', style: _h2),
                    const SizedBox(height: 4),
                    Text(_fmtDateTime(_to), style: GoogleFonts.inter(fontSize: 16)),
                  ]),
                  const Icon(Icons.lock_outline, size: 18),
                ],
              ),
            )
                : _dateBox('To', _to, (d) => setState(() => _to = d)),
          ),
        ]),
      ]),
    );
  }


  void _closeCarTypeOverlay(){ _carTypeEntry?.remove(); _carTypeEntry = null; }
  void _closeDriverOverlay(){ _driverEntry?.remove(); _driverEntry = null; }
  void _closeCarOverlay(){ _carEntry?.remove(); _carEntry = null; }

  void _openCarTypeOverlay() {
    _closeCarTypeOverlay();
    final rb = _carTypeBoxKey.currentContext!.findRenderObject() as RenderBox;
    final size = rb.size;

    _carTypeEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeCarTypeOverlay,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _carTypeLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 6),
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 320, minWidth: size.width, maxWidth: size.width,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _carTypeLabels.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (_, i) {
                      final selected = i == _carTypeIdx;
                      return InkWell(
                        onTap: () {
                          setState(() => _carTypeIdx = i);
                          _closeCarTypeOverlay();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(child: Text(_carTypeLabels[i], style: const TextStyle(fontSize: 16))),
                              if (selected) const Icon(Icons.check, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_carTypeEntry!);
  }

  void _openDriverOverlay() {
    _closeDriverOverlay();
    final rb = _driverBoxKey.currentContext!.findRenderObject() as RenderBox;
    final size = rb.size;

    _driverEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeDriverOverlay,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _driverLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 6),
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 320, minWidth: size.width, maxWidth: size.width,
                  ),
                  child: (_drivers.isEmpty)
                      ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_driversLoading ? 'Loading drivers...' : 'No drivers'),
                  )
                      : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _drivers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (_, i) {
                      final d = _drivers[i];
                      final selected = d.id == _selectedDriverId;
                      return InkWell(
                        onTap: () {
                          setState(() => _selectedDriverId = d.id);
                          _closeDriverOverlay();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(child: Text(d.fullName, style: const TextStyle(fontSize: 16))),
                              if (selected) const Icon(Icons.check, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_driverEntry!);
  }

  void _openCarOverlay() {
    _closeCarOverlay();
    final rb = _carBoxKey.currentContext!.findRenderObject() as RenderBox;
    final size = rb.size;

    _carEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeCarOverlay,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _carLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 6),
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 320, minWidth: size.width, maxWidth: size.width,
                  ),
                  child: (_cars.isEmpty)
                      ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_carsLoading ? 'Loading cars...' : 'No cars'),
                  )
                      : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _cars.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (_, i) {
                      final c = _cars[i];
                      final label = (c.plate == null || c.plate!.isEmpty)
                          ? c.name
                          : '${c.name} • ${c.plate}';
                      final selected = c.id == _selectedCarId;
                      return InkWell(
                        onTap: () {
                          setState(() => _selectedCarId = c.id);
                          _closeCarOverlay();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
                              if (selected) const Icon(Icons.check, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_carEntry!);
  }

  void _openUserOverlay() {
    _closeUserOverlay();
    final rb = _userFieldBoxKey.currentContext!.findRenderObject() as RenderBox;
    final size = rb.size;

    _userEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeUserOverlay,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _userLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 6),
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 320,
                    minWidth: size.width,
                    maxWidth: size.width,
                  ),
                  child: _users.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No users found'),
                  )
                      : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (_, i) {
                      final value = _users[i];
                      final selected = value.fullName == _userCtrl.text;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedUserId = value.id;
                            _userCtrl.text = value.fullName;
                          });
                          _userFieldKey.currentState?.didChange(value.fullName);
                          _closeUserOverlay();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(child: Text(value.fullName, style: const TextStyle(fontSize: 16))),
                              if (selected) const Icon(Icons.check, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_userEntry!);
  }

  void _closeUserOverlay() {
    _userEntry?.remove();
    _userEntry = null;
  }

  String _userNameById(int id) {
    final u = _users.firstWhere(
          (x) => x.id == id,
      orElse: () => const UserLite(id: -1, fullName: ''),
    );
    if (u.id != -1 && u.fullName.isNotEmpty) return u.fullName;
    return 'Loading…';
  }

  String _ownerLabel(_CostAllocationEntry a) {
    final base = _nz(a.ownerName);
    if (base.isNotEmpty) return base;
    if (a.ownerId != null) return _userNameById(a.ownerId!);
    return 'Select a user';
  }

  Widget _stepPassengers() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Passengers', style: _h1),
          const SizedBox(height: 8),

          Text('Users', style: _h2),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [

              for (final id in _passengerUsersIds)
                Chip(
                  label: Text(_userNameById(id)),
                  onDeleted: () => setState(() => _passengerUsersIds.remove(id)),
                ),

              ActionChip(
                label: const Text('Add user'),
                avatar: const Icon(Icons.person_add_alt_1),
                onPressed: _addPassengerUser,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Others', style: _h2),
          const SizedBox(height: 8),

          ..._otherPassengers.asMap().entries.map((e) {
            final idx = e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _box(
                child: Row(
                  children: [
                    const Icon(Icons.person_outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: e.value,
                        onChanged: (v) => _otherPassengers[idx] = v,
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
        ],
      ),
    );
  }


  Widget _stepPurpose() {
    final isOk = (_allocTotal - 100).abs() < 0.0001;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Purpose', style: _h1),
          const SizedBox(height: 8),
          Text('Cost allocation*', style: _h2),
          const SizedBox(height: 8),

          if (_allocs.isEmpty) _emptyHint('No allocation added yet.'),

          ..._allocs.asMap().entries.map(
                (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _allocationTile(e.key, e.value),
            ),
          ),

          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Total:', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      color: isOk ? const Color(0xFF22C55E) : const Color(0xFFE11D48),
                    ),
                    children: [
                      TextSpan(text: '${_allocTotal.toStringAsFixed(1)}%'),
                      if (!isOk) const TextSpan(text: '  -  The total must be 100%'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _usersLoading && !_usersLoadedOnce ? null : _openAddAllocationSheet,
                icon: const Icon(Icons.playlist_add_outlined),
                label: const Text('Add allocation'),
              ),
              const Spacer(),
              Text(
                'Total: ${_allocTotal.toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: isOk ? Colors.green : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _allocationTile(int idx, _CostAllocationEntry a) {
    final hasNameOrId = a.ownerName.isNotEmpty || a.ownerId != null;

    return _box(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFEFF4FF),
            child: Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () async {
                final edited = await _showAllocationEditor(initial: a);
                if (edited != null) {
                  final remaining = _remainingPercent(excludingIndex: idx);
                  if ((edited.percent ?? 0) > remaining + 1e-6) {
                    _toast('Total above 100%. Allowed remaining: ${remaining.toStringAsFixed(1)}%');
                    return;
                  }
                  setState(() => _allocs[idx] = edited);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ownerLabel(a),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: hasNameOrId ? FontWeight.w700 : FontWeight.w400,
                      color: hasNameOrId ? Colors.black : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.costAllocName.isEmpty ? 'Select a cost allocation' : a.costAllocName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${(a.percent ?? 0).toStringAsFixed(1)}%',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _allocs.removeAt(idx)),
          ),
        ],
      ),
    );
  }

  Future<List<_FavPlace>> apiGetFavoritePlacesByUser(int userId, {String? bearerToken}) async {
    try {
      final res = await Api.FavoritePlacesByUserCall.call(userId: userId, bearerToken: bearerToken);
      final raw = Api.FavoritePlacesByUserCall.items(res);
      return raw
          .map((m) => _FavPlace(m['placeName'] ?? '', m['address'] ?? ''))
          .where((p) => p.address.isNotEmpty)
          .toList();
    } catch (_) {
      return const <_FavPlace>[];
    }
  }

  Future<List<_FavPlace>> apiAutocompleteFavoritePlaces({
    required String term,
    required int userId,
    String? bearerToken,
  }) async {
    if (term.trim().isEmpty) return const <_FavPlace>[];
    try {
      final res = await Api.AutocompleteFavoritePlacesCall.call(
        term: term.trim(),
        userId: userId,
        bearerToken: bearerToken,
      );
      final raw = Api.AutocompleteFavoritePlacesCall.items(res);
      return raw
          .map((m) => _FavPlace(m['placeName'] ?? '', m['address'] ?? ''))
          .where((p) => p.address.isNotEmpty)
          .toList();
    } catch (_) {
      return const <_FavPlace>[];
    }
  }


  Future<List<UserLite>> apiFetchUsers({String? bearerToken}) async {
    final res = await Api.UsersIndexCall.call(bearerToken: bearerToken);
    if (res.succeeded != true) return <UserLite>[];
    final raw = Api.UsersIndexCall.items(res);
    final out = <UserLite>[];
    for (final u in raw) {
      final id = Api.UsersIndexCall.id(u);
      final name = Api.UsersIndexCall.fullName(u)?.trim();
      if (id != null && (name?.isNotEmpty ?? false)) {
        out.add(UserLite(id: id, fullName: name!));
      }
    }
    out.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return out;
  }

  Future<List<CostAllocLite>> apiFetchUserCostAllocs(int ownerId, {String? bearerToken}) async {
    final res = await Api.CostAllocationsByUserCall.call(userId: ownerId, bearerToken: bearerToken);
    if (res.succeeded != true) return <CostAllocLite>[];
    final raw = Api.CostAllocationsByUserCall.items(res);
    final out = <CostAllocLite>[];
    for (final c in raw) {
      final id = Api.CostAllocationsByUserCall.id(c);
      final name = Api.CostAllocationsByUserCall.name(c)?.trim();
      if (id != null && (name?.isNotEmpty ?? false)) {
        out.add(CostAllocLite(id: id, name: name!));
      }
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  Future<List<DriverLite>> apiFetchDrivers({required DateTime from, required DateTime to, String? bearerToken}) async {
    final res = await Api.DriversAvailableCall.call(from: from, to: to, bearerToken: bearerToken);
    if (res.succeeded != true) return <DriverLite>[];
    final raw = Api.DriversAvailableCall.items(res);
    final out = <DriverLite>[];
    for (final d in raw) {
      final id = Api.DriversAvailableCall.id(d);
      final name = Api.DriversAvailableCall.name(d)?.trim();
      if (id != null && (name?.isNotEmpty ?? false)) {
        out.add(DriverLite(id: id, fullName: name!));
      }
    }
    out.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return out;
  }

  Future<List<CarLite>> apiFetchCars({required DateTime from, required DateTime to, String? bearerToken}) async {
    final res = await Api.CarsAvailableCall.call(from: from, to: to, bearerToken: bearerToken);
    if (res.succeeded != true) return <CarLite>[];
    final raw = Api.CarsAvailableCall.items(res);
    final out = <CarLite>[];
    for (final c in raw) {
      final id = Api.CarsAvailableCall.id(c);
      final desc = (Api.CarsAvailableCall.description(c) ?? '').trim();
      final plate = Api.CarsAvailableCall.plate(c)?.trim();
      if (id != null && desc.isNotEmpty) {
        out.add(CarLite(id: id, name: desc, plate: (plate?.isEmpty ?? true) ? null : plate));
      }
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  Future<bool> apiSubmitCarRequest(
      Map<String, dynamic> body, {
        int? id,
        bool useAdminUpdate = false,
        String? bearerToken,
      }) async {
    try {
      final payload = Map<String, dynamic>.from(body);

      if (id != null) {
        payload['Id'] = id;
        payload['id'] = id;
      } else {
        payload.remove('Id');
        payload.remove('id');
      }

      if (payload['StartDateTime'] is DateTime) {
        payload['StartDateTime'] =
            (payload['StartDateTime'] as DateTime).toIso8601String();
      }
      if (payload['EndDateTime'] is DateTime) {
        payload['EndDateTime'] =
            (payload['EndDateTime'] as DateTime).toIso8601String();
      }
      payload['startDateTime'] ??= payload['StartDateTime'];
      payload['endDateTime'] ??= payload['EndDateTime'];

      final passengersId = (payload['PassengersId'] is List)
          ? List<int>.from(payload['PassengersId'] as List)
          : <int>[];
      payload['PassengersId'] = passengersId;
      payload['passengersId'] = passengersId;

      final allocRaw = payload['CarRequestsCostAllocs'];
      final allocs = (allocRaw is List ? allocRaw : const [])
          .whereType<Map>()
          .map<Map<String, dynamic>>((raw) {
        final m = Map<String, dynamic>.from(raw);
        final userId = m['UserId'] ?? m['userId'];
        final caId = m['CostAllocId'] ?? m['costAllocId'];
        final pct =
            ((m['Percent'] ?? m['percent']) as num?)?.toDouble() ?? 0.0;

        return {
          if (userId != null) 'UserId': userId,
          'CostAllocId': caId,
          'Percent': pct,
        };
      })
          .where((m) => m['CostAllocId'] != null)
          .toList();
      payload['CarRequestsCostAllocs'] = allocs;
      payload['carRequestsCostAllocs'] = allocs;

      final destRaw = payload['CarRequestDests'];
      final dests = (destRaw is List ? destRaw : const [])
          .whereType<Map>()
          .map<Map<String, dynamic>>((raw) {
        final m = Map<String, dynamic>.from(raw);
        final addr =
        (m['DestAddress'] ?? m['destAddress'] ?? '').toString().trim();
        return {'DestAddress': addr};
      })
          .where((m) => (m['DestAddress'] as String).isNotEmpty)
          .toList();
      var seq = 1;
      for (final m in dests) m['Sequence'] = seq++;
      payload['CarRequestDests'] = dests;
      payload['carRequestDests'] = dests;

      final flightsRaw = payload['FlightsInformations'];
      final flights = (flightsRaw is List ? flightsRaw : const [])
          .whereType<Map>()
          .map<Map<String, dynamic>>((raw) {
        final m = Map<String, dynamic>.from(raw);
        return {
          'IsDeparture':
          m['IsDeparture'] ?? m['isDeparture'] ?? false,
          'Destination':
          (m['Destination'] ?? m['destination'] ?? '').toString(),
          'Time': (m['Time'] ?? m['time']),
          'SourceAirport':
          (m['SourceAirport'] ?? m['sourceAirport'] ?? '').toString(),
          'DestinationAirport': (m['DestinationAirport'] ??
              m['destinationAirport'] ??
              '')
              .toString(),
          'FlightNumber':
          (m['FlightNumber'] ?? m['flightNumber'] ?? '').toString(),
        };
      }).toList();
      payload['FlightsInformations'] = flights;
      payload['flightsInformations'] = flights;

      void copyIfMissing(String pascal, String camel) {
        if (payload[pascal] == null && payload[camel] != null) {
          payload[pascal] = payload[camel];
        }
        if (payload[camel] == null && payload[pascal] != null) {
          payload[camel] = payload[pascal];
        }
      }

      for (final pair in const [
        ['SourceAddress', 'sourceAddress'],
        ['Note', 'note'],
        ['SpecialCarInfo', 'specialCarInfo'],
        ['Passanger1', 'passanger1'],
        ['Passanger2', 'passanger2'],
        ['Passanger3', 'passanger3'],
        ['ChildSeat', 'childSeat'],
        ['BookNow', 'bookNow'],
        ['CarType', 'carType'],
        ['UserId', 'userId'],
        ['DriverId', 'driverId'],
        ['CarId', 'carId'],
      ]) {
        copyIfMissing(pair[0], pair[1]);
      }

      assert(() {
        try {
        } catch (_) {}
        return true;
      }());

      Api.ApiCallResponse res;

      if (id == null) {
        res = await Api.CarRequestsCreateCall.call(
          body: payload,
          bearerToken: bearerToken ?? '',
        );
      } else if (useAdminUpdate) {
        res = await Api.CarRequestsUpdateAdminCall.call(
          bearerToken: bearerToken ?? '',
          id: id,
          carId: payload['CarId'] as int?,
          passengersId: passengersId,
          carRequestsCostAllocs: allocs,
          carRequestDests: dests,
          sourceAddress: payload['SourceAddress'] as String?,
          note: payload['Note'] as String?,
          specialCarInfo: payload['SpecialCarInfo'] as String?,
          passanger1: payload['Passanger1'] as String?,
          passanger2: payload['Passanger2'] as String?,
          passanger3: payload['Passanger3'] as String?,
          childSeat: payload['ChildSeat'] as bool?,
        );
      } else {
        res = await Api.CarRequestsUpdateCall.call(
          id: id!,
          body: payload,
          bearerToken: bearerToken,
        );
      }

      if (res.succeeded == true) return true;

      AppNotifications.warning(
        appNavigatorKey.currentContext ?? context,
        'Failed to ${id == null ? 'create' : (useAdminUpdate ? 'update (admin)' : 'update')} the request (${res.statusCode}).',
      );
      return false;
    } catch (e) {
      AppNotifications.warning(
        appNavigatorKey.currentContext ?? context,
        'Network/format error while ${id == null ? 'creating' : (useAdminUpdate ? 'updating (admin)' : 'updating')} the request.',
      );
      return false;
    }
  }

  Future<_CostAllocationEntry?> _showAllocationEditor({_CostAllocationEntry? initial}) async {
    await _loadUsersIfNeeded();

    int? ownerId = initial?.ownerId;
    String ownerName = initial?.ownerName ?? '';
    int? allocId = initial?.costAllocId;
    String allocName = initial?.costAllocName ?? '';
    double percent = (initial?.percent ?? 100.0).clamp(0.0, 100.0).toDouble();

    const double _kMenuMaxHeight = 160.0;

    if ((ownerId != null) && _nz(ownerName).isEmpty) {
      ownerName = _userNameById(ownerId!);
    }

    final usedExceptCurrent =
        _allocs.fold<double>(0.0, (s, a) => s + (a.percent ?? 0.0)) - (initial?.percent ?? 0.0);

    final remaining = (100.0 - usedExceptCurrent).clamp(0.0, 100.0).toDouble();
    final maxPercent = ((initial?.percent ?? 0.0) + remaining).clamp(0.0, 100.0).toDouble();
    percent = percent.clamp(0.0, maxPercent);

    final ownerLink = LayerLink();
    final ownerBoxKey = GlobalKey();
    OverlayEntry? ownerEntry;

    final allocLink = LayerLink();
    final allocBoxKey = GlobalKey();
    OverlayEntry? allocEntry;

    void closeOwner() { ownerEntry?.remove(); ownerEntry = null; }
    void closeAlloc() { allocEntry?.remove(); allocEntry = null; }

    Future<void> openOwner(BuildContext ctx) async {
      closeOwner();
      final rb = ownerBoxKey.currentContext!.findRenderObject() as RenderBox;
      final size = rb.size;

      ownerEntry = OverlayEntry(
        builder: (_) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: closeOwner,
          child: Stack(
            children: [
              CompositedTransformFollower(
                link: ownerLink,
                offset: Offset(0, size.height + 6),
                showWhenUnlinked: false,
                child: Material(
                  elevation: 10,
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: _kMenuMaxHeight,
                      minWidth: size.width,
                      maxWidth: size.width,
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (_, i) {
                        final value = _users[i];
                        final selected = value.id == ownerId;
                        return InkWell(
                          onTap: () async {
                            ownerId = value.id;
                            ownerName = value.fullName;
                            allocId = null;
                            allocName = '';
                            await _getCostAllocationsForUser(ownerId!);
                            (ctx as Element).markNeedsBuild();
                            closeOwner();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(child: Text(value.fullName, style: const TextStyle(fontSize: 16))),
                                if (selected) const Icon(Icons.check, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      Overlay.of(ctx).insert(ownerEntry!);
    }

    Future<void> openAlloc(BuildContext ctx) async {
      if (ownerId == null) {
        _toast('Select the Owner first.');
        return;
      }
      closeAlloc();
      final rb = allocBoxKey.currentContext!.findRenderObject() as RenderBox;
      final size = rb.size;

      final allocs = await _getCostAllocationsForUser(ownerId!);

      allocEntry = OverlayEntry(
        builder: (_) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: closeAlloc,
          child: Stack(
            children: [
              CompositedTransformFollower(
                link: allocLink,
                offset: Offset(0, size.height + 6),
                showWhenUnlinked: false,
                child: Material(
                  elevation: 10,
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: _kMenuMaxHeight,
                      minWidth: size.width,
                      maxWidth: size.width,
                    ),
                    child: (allocs.isEmpty)
                        ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No cost allocations for this user'),
                    )
                        : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemCount: allocs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (_, i) {
                        final value = allocs[i];
                        final selected = value.id == allocId;
                        return InkWell(
                          onTap: () {
                            allocId = value.id;
                            allocName = value.name;
                            (ctx as Element).markNeedsBuild();
                            closeAlloc();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(child: Text(value.name, style: const TextStyle(fontSize: 16))),
                                if (selected) const Icon(Icons.check, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      Overlay.of(ctx).insert(allocEntry!);
    }

    if (ownerId != null) {
      await _getCostAllocationsForUser(ownerId!);
    }

    return showModalBottomSheet<_CostAllocationEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final Color primary = Theme.of(context).colorScheme.primary;
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 8,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setM) {
              final ownerDisplay = _nz(ownerName).isNotEmpty
                  ? ownerName
                  : (ownerId != null ? _userNameById(ownerId!) : '');
              final hasOwner = (ownerId != null) || ownerDisplay.isNotEmpty;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Text('Cost allocation', style: _h1)),
                  const SizedBox(height: 12),

                  Text('Owner*', style: _h2),
                  const SizedBox(height: 6),
                  CompositedTransformTarget(
                    link: ownerLink,
                    child: _box(
                      key: ownerBoxKey,
                      child: InkWell(
                        onTap: () => openOwner(sheetCtx),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ownerDisplay.isEmpty ? 'Select a user' : ownerDisplay,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: hasOwner ? Colors.black : Colors.black45,
                                  fontWeight: hasOwner ? FontWeight.w700 : FontWeight.w400,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.keyboard_arrow_down),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text('Cost allocation*', style: _h2),
                  const SizedBox(height: 6),
                  CompositedTransformTarget(
                    link: allocLink,
                    child: _box(
                      key: allocBoxKey,
                      child: InkWell(
                        onTap: () => openAlloc(sheetCtx),
                        child: Row(
                          children: [
                            const Icon(Icons.badge_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _nz(allocName).isEmpty ? 'Select a cost allocation' : allocName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: _nz(allocName).isEmpty ? Colors.black45 : Colors.black,
                                  fontWeight: _nz(allocName).isEmpty ? FontWeight.w400 : FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.keyboard_arrow_down),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text('Percent', style: _h2),
                  const SizedBox(height: 6),
                  _box(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Slider(
                          value: percent,
                          min: 0,
                          max: maxPercent,
                          divisions: maxPercent >= 1 ? maxPercent.floor() : null,
                          label: '${percent.toStringAsFixed(0)}%',
                          onChanged: maxPercent == 0 ? null : (v) => setM(() => percent = v),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Remaining: ${remaining.toStringAsFixed(1)}%',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
                              ),
                            ),
                            Text(
                              '${percent.toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () {
                              closeOwner();
                              closeAlloc();
                              Navigator.pop(sheetCtx);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              backgroundColor: Colors.white,
                              side: BorderSide(color: primary, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: (ownerId == null || allocId == null)
                                ? null
                                : () {
                              final limit = maxPercent;
                              if (percent > limit + 1e-6) {
                                _toast('Total acima de 100%. Restante permitido: ${remaining.toStringAsFixed(1)}%');
                                return;
                              }
                              closeOwner();
                              closeAlloc();
                              Navigator.pop(
                                sheetCtx,
                                _CostAllocationEntry(
                                  ownerId: ownerId,
                                  ownerName: ownerDisplay.isEmpty ? '' : ownerDisplay,
                                  costAllocId: allocId,
                                  costAllocName: allocName,
                                  percent: percent,
                                ),
                              );
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openAddAllocationSheet() async {
    await _loadUsersIfNeeded();
    final remaining = _remainingPercent();
    if (remaining <= 1e-6) {
      _toast('Total already reached 100%.');
      return;
    }

    _CostAllocationEntry? initial;
    if (_selectedUserId != null) {
      final ownerName = _users.firstWhere(
            (u) => u.id == _selectedUserId,
        orElse: () => UserLite(id: _selectedUserId!, fullName: _userCtrl.text),
      ).fullName;

      initial = _CostAllocationEntry(
        ownerId: _selectedUserId,
        ownerName: ownerName,
        costAllocId: null,
        costAllocName: '',
        percent: remaining.clamp(0.0, 100.0),
      );
    }

    final created = await _showAllocationEditor(initial: initial);

    if (created != null) {
      final rem2 = _remainingPercent();
      if ((created.percent ?? 0) > rem2 + 1e-6) {
        _toast('Total acima de 100%. Restante permitido: ${rem2.toStringAsFixed(1)}%');
        return;
      }
      setState(() => _allocs.add(created));
    }
  }

  double _remainingPercent({int? excludingIndex}) {
    final total = _allocs.asMap().entries.fold<double>(
      0,
          (sum, e) => sum + (excludingIndex == e.key ? 0 : (e.value.percent ?? 0)),
    );
    return 100.0 - total;
  }


  void _addOrFillDestination(String text) {
    setState(() {
      _destinations.removeWhere((e) => e.trim().isEmpty);
      _destinations.add(text);
      _destKeys.add(UniqueKey());

      while (_destFlights.length < _destinations.length) {
        _destFlights.add(null);
      }
    });
  }

  Future<void> _openDepartureAirportForm() async {
    final place = _departureCtrl.text.trim();
    if (place.isEmpty || !_looksLikeAirport(place)) {
      AppNotifications.info(context, 'The departure address does not look like an airport.');
      return;
    }

    final res = await AppNotifications.showFlightInfoModal(
      context,
      isDeparture: true,
      selectedPlace: place,
      initial: _depFlight,
    );

    if (!mounted) return;
    if (res != null) setState(() => _depFlight = res);
  }

  Future<void> _openDestinationAirportForm(int idx) async {
    if (idx < 0 || idx >= _destinations.length) return;
    final place = _destinations[idx].trim();
    if (place.isEmpty || !_looksLikeAirport(place)) {
      AppNotifications.info(context, 'This destination does not look like an airport.');
      return;
    }

    final res = await AppNotifications.showFlightInfoModal(
      context,
      isDeparture: false,
      selectedPlace: place,
      initial: _destFlights[idx],
    );

    if (!mounted) return;
    if (res != null) setState(() => _destFlights[idx] = res);
  }

  Map<String, dynamic> _flightToBackendDto(FlightInfo f, {required bool isDeparture, required String destination}) {
    final t = f.time;
    final hh = t == null ? null : t.hour.toString().padLeft(2, '0');
    final mm = t == null ? null : t.minute.toString().padLeft(2, '0');
    return {
      'IsDeparture'       : isDeparture,
      'Destination'       : destination,
      'Time'              : (hh != null && mm != null) ? '$hh:$mm' : null,
      'SourceAirport'     : f.sourceAirport,
      'DestinationAirport': f.destinationAirport,
      'FlightNumber'      : f.flightNumber,
    };
  }

  Widget _stepRoute() {
    final depReadOnly = _isAdjust;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Route', style: _h1),
        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: !_onlyFavorites && _placeMode == 0,
              onSelected: _onlyFavorites ? null : (_) { setState(() => _placeMode = 0); _updatePredictions(); },
            ),
            ChoiceChip(
              label: const Text('Establishments'),
              selected: !_onlyFavorites && _placeMode == 1,
              onSelected: _onlyFavorites ? null : (_) { setState(() => _placeMode = 1); _updatePredictions(); },
            ),
            ChoiceChip(
              label: const Text('Addresses'),
              selected: !_onlyFavorites && _placeMode == 2,
              onSelected: _onlyFavorites ? null : (_) { setState(() => _placeMode = 2); _updatePredictions(); },
            ),
            ChoiceChip(
              label: const Text('Geocodes'),
              selected: !_onlyFavorites && _placeMode == 3,
              onSelected: _onlyFavorites ? null : (_) { setState(() => _placeMode = 3); _updatePredictions(); },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Strict bounds'),
              selected: !_onlyFavorites && _strictBounds,
              onSelected: _onlyFavorites ? null : (v) { setState(() => _strictBounds = v); _updatePredictions(); },
            ),
            FilterChip(
              label: const Text('Favorite places'),
              selected: _onlyFavorites,
              onSelected: (v) async {
                setState(() {
                  _onlyFavorites = v;
                  if (v) _strictBounds = false;
                });
                if (v) await _ensureFavoritePlacesLoaded();
                _updatePredictions();
              },
            ),
          ],
        ),

        const SizedBox(height: 8),

        CompositedTransformTarget(
          link: _placeLink,
          child: _box(
            key: _placeFieldBoxKey,
            child: Row(
              children: [
                const Icon(Icons.search),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _placeCtrl,
                    focusNode: _placeFocus,
                    onChanged: (_) => _updatePredictions(),
                    decoration: const InputDecoration(
                      hintText: 'Enter a location',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.pin_drop_outlined),
                  onPressed: _isAdjust ? null : _applyDepartureFromSearch,
                  label: const Text('Set as Departure'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_location_alt_outlined),
                  onPressed: _applyDestinationFromSearch,
                  label: const Text('Add as Destination'),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Text('Departure*', style: _h2),
        const SizedBox(height: 6),
        _box(
          child: Row(
            children: [
              const Icon(Icons.place_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _departureCtrl,
                  readOnly: depReadOnly,
                  enabled: !depReadOnly,
                  decoration: const InputDecoration(
                    hintText: 'Street, number, city...',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_looksLikeAirport(_departureCtrl.text)) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: _depFlight == null ? 'Add flight' : 'Edit flight',
                  child: IconButton(
                    icon: const Icon(Icons.flight_takeoff_outlined),
                    onPressed: depReadOnly ? null : _openDepartureAirportForm,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Tooltip(
                message: 'Open in Maps',
                child: IconButton(
                  icon: const Icon(Icons.map_outlined),
                  onPressed: depReadOnly ? null : () => _openInMapsFromField(_departureCtrl.text),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Favorite places',
                child: IconButton(
                  icon: const Icon(Icons.star_border),
                  onPressed: depReadOnly
                      ? null
                      : () async {
                    final chosen = await _showFavoritePlacesModal();
                    if (chosen != null) {
                      setState(() => _departureCtrl.text = chosen);
                      if (_looksLikeAirport(chosen)) await _openDepartureAirportForm();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        if (_depFlight != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 6, right: 6),
            child: _box(
              padding: const EdgeInsets.all(12),
              child: Text(
                _flightSummary(_depFlight!),
                style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
              ),
            ),
          ),

        const SizedBox(height: 14),
        Text('Destination address*', style: _h2),
        const SizedBox(height: 6),

        ReorderableListView.builder(
          key: const PageStorageKey('destinations-list'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _destinations.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _destinations.removeAt(oldIndex);
              final k = _destKeys.removeAt(oldIndex);
              _destinations.insert(newIndex, item);
              _destKeys.insert(newIndex, k);

              if (_destFlights.length >= oldIndex + 1) {
                final f = _destFlights.removeAt(oldIndex);
                if (_destFlights.length < newIndex) {
                  while (_destFlights.length < newIndex) {
                    _destFlights.add(null);
                  }
                }
                _destFlights.insert(newIndex, f);
              }
            });
          },
          itemBuilder: (context, idx) {
            return Padding(
              key: _destKeys[idx],
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _box(
                    child: Row(children: [
                      const Icon(Icons.flag_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(_destKeys[idx]),
                          initialValue: _destinations[idx],
                          onChanged: (v) {
                            _destinations[idx] = v;
                            while (_destFlights.length < _destinations.length) {
                              _destFlights.add(null);
                            }
                            setState(() {});
                          },
                          decoration: const InputDecoration(
                            hintText: 'Street, number, city, state',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_looksLikeAirport(_destinations[idx])) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: _destFlights.length > idx && _destFlights[idx] != null
                              ? 'Edit flight'
                              : 'Add flight',
                          child: IconButton(
                            icon: const Icon(Icons.flight_outlined),
                            onPressed: () => _openDestinationAirportForm(idx),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Open in Maps',
                        child: IconButton(
                          icon: const Icon(Icons.map_outlined),
                          onPressed: () => _openInMapsFromField(_destinations[idx]),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Favorite places',
                        child: IconButton(
                          icon: const Icon(Icons.star_border),
                          onPressed: () async {
                            final chosen = await _showFavoritePlacesModal();
                            if (chosen != null) {
                              setState(() => _destinations[idx] = chosen);
                              if (_looksLikeAirport(chosen)) await _openDestinationAirportForm(idx);
                            }
                          },
                        ),
                      ),
                      if (_destinations.length > 1)
                        Tooltip(
                          message: 'Remove destination',
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeDestination(idx),
                          ),
                        ),
                      const SizedBox(width: 4),
                      ReorderableDragStartListener(
                        index: idx,
                        child: const Icon(Icons.drag_handle_rounded),
                      ),
                    ]),
                  ),
                  if (_destFlights.length > idx && _destFlights[idx] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _box(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _flightSummary(_destFlights[idx]!),
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ]),
    );
  }

  Future<void> _updatePredictions() async {
    final q = _placeCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _predictions = []);
      _showOrUpdatePlaceOverlay();
      return;
    }

    if (_onlyFavorites) {
      final uid = _selectedUserId;
      if (uid == null) {
        setState(() => _predictions = []);
        _showOrUpdatePlaceOverlay();
        return;
      }

      final fav = await apiAutocompleteFavoritePlaces(term: q, userId: uid);
      setState(() {
        _predictions = fav.map((p) => p.display(true)).toList();
      });
      _showOrUpdatePlaceOverlay();
      return;
    }

    final results = await _placesApi.autocomplete(
      q,
      mode: _placeMode,
      strictBounds: _strictBounds,
      lat: _strictBounds ? _spLat : null,
      lng: _strictBounds ? _spLng : null,
      radiusMeters: _strictBounds ? _strictBoundsRadiusMeters : null,
    );

    setState(() {
      _predictions = results
          .map((p) => p.description ?? p.structuredFormatting?.mainText ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    });
    _showOrUpdatePlaceOverlay();
  }


  void _removeDestination(int idx) {
    setState(() {
      _destinations.removeAt(idx);
      _destKeys.removeAt(idx);
      if (_destFlights.length > idx) _destFlights.removeAt(idx);

      _ensureAtLeastOneDestination();
    });
  }

    void _ensureAtLeastOneDestination() {
    if (_destinations.isEmpty) {
      _destinations.add('');
      _destKeys.add(UniqueKey());
      while (_destFlights.length < _destinations.length) {
        _destFlights.add(null);
      }
    }
  }


  Future<void> _ensureFavoritePlacesLoaded() async {
    if (_favoritePlacesLoaded || _favoritePlacesLoading) return;

    final uid = _selectedUserId;
    if (uid == null) {
      setState(() {
        _favoritePlacesLoaded = true;
        _favoritePlaces = const [];
      });
      return;
    }

    setState(() => _favoritePlacesLoading = true);
    try {
      final list = await apiGetFavoritePlacesByUser(uid);
      if (mounted) {
        setState(() {
          _favoritePlaces = list;
          _favoritePlacesLoaded = true;
        });
      }
    } finally {
      if (mounted) setState(() => _favoritePlacesLoading = false);
    }
  }

  Future<void> _openInMapsFromField(String address) async {
    final a = address.trim();
    if (a.isEmpty) { _toast('Please fill in the address first.'); return; }
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(a)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _toast('Unable to open Maps.');
  }

  Future<String?> _showFavoritePlacesModal() async {
    await _ensureFavoritePlacesLoaded();
    String q = '';
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setM) {
          final list = _favoritePlaces.where((p) {
            final t = (p.name + ' ' + p.address).toLowerCase();
            return t.contains(q.toLowerCase());
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Favorite Places', style: _h1),
                const SizedBox(height: 8),
                _box(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search favorites',
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => setM(() => q = v),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: list.isEmpty
                      ? const ListTile(title: Text('No favorites found'))
                      : ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final fp = list[i];
                      return ListTile(
                        title: Text(fp.name.isEmpty ? fp.address : fp.name),
                        subtitle: fp.name.isEmpty
                            ? null
                            : Text(fp.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: FilledButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Select'),
                          onPressed: () => Navigator.pop(ctx, fp.address),
                        ),
                        onTap: () => Navigator.pop(ctx, fp.address),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ],
            ),
          );
        });
      },
    );
  }

  void _showOrUpdatePlaceOverlay() {
    if (!_placeFocus.hasFocus || _predictions.isEmpty) {
      _closePlaceOverlay();
      return;
    }
    final rb = _placeFieldBoxKey.currentContext!.findRenderObject() as RenderBox;
    final size = rb.size;

    final entry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closePlaceOverlay,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _placeLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 6),
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 280,
                    minWidth: size.width,
                    maxWidth: size.width,
                  ),
                  child: _buildPlaceList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (_placeEntry == null) {
      _placeEntry = entry;
      Overlay.of(context).insert(_placeEntry!);
    } else {
      _placeEntry!.remove();
      _placeEntry = entry;
      Overlay.of(context).insert(_placeEntry!);
    }
  }

  Widget _buildPlaceList() {
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
          itemCount: _predictions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = _predictions[i];
            return ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(p, style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => _onPredictionTap(p),
            );
          },
        ),
      ),
    );
  }

  void _closePlaceOverlay() {
    _placeEntry?.remove();
    _placeEntry = null;
  }

  String _normalizePlace(String placeRaw) {
    String place = placeRaw.trim();
    if (!_onlyFavorites) {
      const sep = '—';
      if (place.contains(sep)) {
        final parts = place.split(sep);
        if (parts.length >= 2) {
          place = parts.sublist(parts.length - 1).join(sep).trim();
        }
      }
    }
    return place;
  }

  void _onPredictionTap(String placeRaw) {
    final place = _normalizePlace(placeRaw);
    setState(() => _placeCtrl.text = place);
    _placeFocus.unfocus();
    _closePlaceOverlay();
  }

  Future<void> _applyDepartureFromSearch() async {
    final allowSetDeparture = !_isAdjust;
    if (!allowSetDeparture) return;

    final place = _normalizePlace(_placeCtrl.text);
    if (place.isEmpty) {
      _toast('Enter a location first.');
      return;
    }

    setState(() => _departureCtrl.text = place);
    if (_looksLikeAirport(place)) {
      await _openDepartureAirportForm();
    }
    _placeCtrl.clear();
    _placeFocus.unfocus();
    _closePlaceOverlay();
  }

  Future<void> _applyDestinationFromSearch() async {
    final place = _normalizePlace(_placeCtrl.text);
    if (place.isEmpty) {
      _toast('Enter a location first.');
      return;
    }

    _addOrFillDestination(place);
    final newIndex = _destinations.length - 1;
    if (_looksLikeAirport(place)) {
      await _openDestinationAirportForm(newIndex);
    }
    _placeCtrl.clear();
    _placeFocus.unfocus();
    _closePlaceOverlay();
  }


    Widget _stepCar() {
      final carTypeReadOnly = _isAdjust;

      if (_canAssignInEdit && !_driversLoadedOnce && !_driversLoading) {
        _loadDriversIfNeeded();
      }
      if ((_canAssignInEdit || _canAssignCarInAdjust) && !_carsLoadedOnce && !_carsLoading) {
        _loadCarsIfNeeded();
      }
      if (_isAdjust && !_driversLoadedOnce && !_driversLoading) {
        _loadDriversIfNeeded();
      }

      String _driverLabel() {
        if (_selectedDriverId == null) {
          return _driversLoading ? 'Loading drivers...' : 'Select a driver';
        }
        final id = _selectedDriverId!;
        final inList = _drivers.any((d) => d.id == id);
        if (inList) return _drivers.firstWhere((d) => d.id == id).fullName;
        final saved = _initialDriverName();
        return (saved.isNotEmpty) ? saved : 'Driver #$id';
      }

      String _carLabel() {
        if (_selectedCarId == null) {
          return _carsLoading ? 'Loading cars...' : 'Select a car';
        }
        final id = _selectedCarId!;
        final inList = _cars.any((c) => c.id == id);
        if (inList) {
          final c = _cars.firstWhere((x) => x.id == id);
          return (c.plate == null || c.plate!.isEmpty) ? c.name : '${c.name} • ${c.plate}';
        }
        final model = widget.initial?.model;
        final plate = widget.initial?.licensePlate;
        if ((model?.isNotEmpty ?? false) && (plate?.isNotEmpty ?? false)) return '$model • $plate';
        if ((model?.isNotEmpty ?? false)) return model!;
        return 'Car #$id';
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type of car', style: _h1),
            const SizedBox(height: 8),

            CompositedTransformTarget(
              link: _carTypeLink,
              child: _box(
                key: _carTypeBoxKey,
                child: InkWell(
                  onTap: carTypeReadOnly ? null : _openCarTypeOverlay,
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (_carTypeIdx >= 0 && _carTypeIdx < _carTypeLabels.length)
                              ? _carTypeLabels[_carTypeIdx]
                              : 'Select car type',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: carTypeReadOnly ? Colors.black54 : Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (carTypeReadOnly) const Icon(Icons.lock_outline, size: 18),
                      if (!carTypeReadOnly) const Icon(Icons.keyboard_arrow_down),
                    ],
                  ),
                ),
              ),
            ),

            if (_showSpecialCarInfo) ...[
              const SizedBox(height: 12),
              Text('Special car info*', style: _h2),
              const SizedBox(height: 6),
              _box(
                child: TextField(
                  controller: _specialCarInfoCtrl,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Required to confirm this request',
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  '*Required for confirm this request',
                  style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _switchTile(
              'Child seat',
              _childSeat,
              _isAdjust ? null : (v) => setState(() => _childSeat = v),
            ),
            const SizedBox(height: 8),

            _switchTile(
              'Book now',
              _bookNow,
              _isAdjust ? null : (v) => setState(() => _bookNow = v),
              subtitle: _canAssignInEdit
                  ? 'You can assign Driver and Car in this edit.'
                  : 'Admins in edit mode can assign Driver/Car.',
            ),
            const SizedBox(height: 16),

            if (_canAssignInEdit) ...[
              CompositedTransformTarget(
                link: _driverLink,
                child: _box(
                  key: _driverBoxKey,
                  child: InkWell(
                    onTap: _openDriverOverlay,
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _driverLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: _drivers.any((d) => d.id == _selectedDriverId)
                                  ? Colors.black
                                  : Colors.black45,
                              fontWeight: _drivers.any((d) => d.id == _selectedDriverId)
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else if (_isAdjust) ...[
              CompositedTransformTarget(
                link: _driverLink,
                child: _box(
                  key: _driverBoxKey,
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _driverLabel(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.lock_outline, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_canAssignInEdit || _canAssignCarInAdjust) ...[
              CompositedTransformTarget(
                link: _carLink,
                child: _box(
                  key: _carBoxKey,
                  child: InkWell(
                    onTap: _openCarOverlay,
                    child: Row(
                      children: [
                        const Icon(Icons.local_taxi_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _carLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: _cars.any((c) => c.id == _selectedCarId)
                                  ? Colors.black
                                  : Colors.black45,
                              fontWeight: _cars.any((c) => c.id == _selectedCarId)
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

  String _reviewAllocationsText() {
    if (_allocs.isEmpty) return '—';
    return _allocs.map((a) {
      final owner = _ownerLabel(a);
      final alloc = a.costAllocName.isEmpty ? '—' : a.costAllocName;
      final pct = (a.percent ?? 0).toStringAsFixed(1);
      return '• $owner — $alloc — $pct%';
    }).join('\n');
  }

  Widget _stepReview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notes', style: _h1),
          const SizedBox(height: 8),
          _box(
            child: TextFormField(
              controller: _notesCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Optional',
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 18),

          Text('Review', style: _h1),
          const SizedBox(height: 8),
          _reviewTile('User', _userCtrl.text),
          _reviewTile('Period', '${_fmtDateTime(_from)} → ${_fmtDateTime(_to)}'),

          _reviewTile(
            'Passengers (users)',
            _passengerUsers.isEmpty ? '—' : _passengerUsers.join(', '),
          ),

          _reviewTile(
            'Passengers (others)',
            _otherPassengers.where((e) => e.trim().isNotEmpty).join(', ').isEmpty
                ? '—'
                : _otherPassengers.where((e) => e.trim().isNotEmpty).join(', '),
          ),

          _reviewTile('Cost allocation', _reviewAllocationsText()),
          _reviewTile('Cost allocation total', '${_allocTotal.toStringAsFixed(1)}%'),

          _reviewTile(
            'Route',
            '${_departureCtrl.text} → ${_destinations.where((e) => e.trim().isNotEmpty).join(' • ')}',
          ),

          if (_depFlight != null)
            _reviewTile('Flight (Departure)', _flightSummary(_depFlight!)),
          ..._destFlights.asMap().entries.where((e) => e.value != null).map(
                (e) => _reviewTile(
              'Flight (Destination ${e.key + 1})',
              _flightSummary(e.value!),
            ),
          ),

          _reviewTile(
            'Car',
            (_carTypeIdx >= 0 && _carTypeIdx < _carTypeLabels.length)
                ? _carTypeLabels[_carTypeIdx]
                : '—',
          ),
          _reviewTile('Child seat', _childSeat ? 'Yes' : 'No'),
          _reviewTile('Book now', _bookNow ? 'Yes' : 'No'),

          if (_showSpecialCarInfo)
            _reviewTile(
              'Special car info',
              _specialCarInfoCtrl.text.trim().isEmpty
                  ? '—'
                  : _specialCarInfoCtrl.text.trim(),
            ),

          if (_canAssignDriverCar) ...[
            _reviewTile(
              'Driver',
              (() {
                if (_selectedDriverId == null) return '—';
                final id = _selectedDriverId!;
                final inList = _drivers.any((d) => d.id == id);
                if (inList) return _drivers.firstWhere((d) => d.id == id).fullName;
                return widget.initial?.driverName ?? 'Driver #$id';
              })(),
            ),
            _reviewTile(
              'Car (selected)',
              (() {
                if (_selectedCarId == null) return '—';
                final id = _selectedCarId!;
                final inList = _cars.any((c) => c.id == id);
                if (inList) {
                  final c = _cars.firstWhere((x) => x.id == id);
                  return (c.plate == null || c.plate!.isEmpty)
                      ? c.name
                      : '${c.name} • ${c.plate}';
                }
                final model = widget.initial?.model;
                final plate = widget.initial?.licensePlate;
                if ((model?.isNotEmpty ?? false) && (plate?.isNotEmpty ?? false)) return '$model • $plate';
                if ((model?.isNotEmpty ?? false)) return model!;
                return 'Car #$id';
              })(),
            ),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _box({
    Key? key,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  }) {
    return Container(
      key: key,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Color(0x11000000), offset: Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _dateBox(String label, DateTime? value, ValueChanged<DateTime> onChanged) {
    return _box(
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: value ?? now,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 2),
          );
          if (d == null) return;
          final t = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(value ?? now),
          );
          if (t == null) return;
          onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: _h2),
              const SizedBox(height: 4),
              Text(_fmtDateTime(value), style: GoogleFonts.inter(fontSize: 16)),
            ]),
            const Icon(Icons.schedule),
          ],
        ),
      ),
    );
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool>? onChanged, {String? subtitle}) {
    return _box(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return _box(
      child: Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _reviewTile(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _box(
        child: Row(
          children: [
            Expanded(child: Text(k, style: _h2)),
            const SizedBox(width: 8),
            Flexible(child: Text(v, textAlign: TextAlign.right)),
          ],
        ),
      ),
    );
  }

  Future<void> _addPassengerUser() async {
    await _loadUsersIfNeeded();
    final res = await showModalBottomSheet<UserLite>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          children: [
            const SizedBox(height: 8),
            Center(child: Text('Add passenger (user)', style: _h1)),
            const SizedBox(height: 8),
            ..._users.map((u) => ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: Text(u.fullName),
              onTap: () => Navigator.pop(ctx, u),
            )),
            const SizedBox(height: 12),
          ],
        );
      },
    );

    if (res != null) {
      setState(() {
        if (!_passengerUsers.contains(res.fullName)) {
          _passengerUsers.add(res.fullName);
        }
        if (!_passengerUsersIds.contains(res.id)) {
          _passengerUsersIds.add(res.id);
        }
      });
    }
  }

  void _toast(String msg) {
    AppNotifications.warning(context, msg);
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step, required this.totalSteps});

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final value = (step + 1) / totalSteps;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('Step ${step + 1} of $totalSteps', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(child: LinearProgressIndicator(value: value)),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.step,
    required this.total,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final int total;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    const btnHeight = 52.0;
    final isLast = step == total - 1;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [
            BoxShadow(blurRadius: 12, color: Color(0x11000000), offset: Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: btnHeight,
                child: OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(step == 0 ? 'Cancel' : 'Back'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: btnHeight,
                child: FilledButton.icon(
                  onPressed: onNext,
                  icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
                  label: Text(isLast ? 'Finish' : 'Next'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CostAllocationEntry {
  final int? ownerId;
  final String ownerName;
  final int? costAllocId;
  final String costAllocName;
  final double? percent;

  _CostAllocationEntry({
    required this.ownerId,
    required this.ownerName,
    required this.costAllocId,
    required this.costAllocName,
    required this.percent,
  });

  _CostAllocationEntry copyWith({
    int? ownerId,
    String? ownerName,
    int? costAllocId,
    String? costAllocName,
    double? percent,
  }) {
    return _CostAllocationEntry(
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      costAllocId: costAllocId ?? this.costAllocId,
      costAllocName: costAllocName ?? this.costAllocName,
      percent: percent ?? this.percent,
    );
  }

  Map<String, dynamic> toJson() => {
    'ownerId': ownerId,
    'ownerName': ownerName,
    'costAllocId': costAllocId,
    'costAllocName': costAllocName,
    'percent': percent,
  };
}
