import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:mitsubishi/backend/api_requests/api_calls.dart' as API;

String _str(dynamic v) => v?.toString() ?? '';
int? _int(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(_str(v));
}
double? _double(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(_str(v).replaceAll(',', '.'));
}
bool _bool(dynamic v) {
  if (v is bool) return v;
  final s = _str(v).trim().toLowerCase();
  return s == '1' || s == 'true' || s == 'yes' || s == 'sim';
}
DateTime? _dt(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toLocal();
  if (v is num) {
    final iv = v.toInt();
    if (iv > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(iv, isUtc: true).toLocal();
    if (iv > 1000000000) return DateTime.fromMillisecondsSinceEpoch(iv * 1000, isUtc: true).toLocal();
  }
  final s = _str(v).trim();
  if (s.isEmpty) return null;
  final ms = RegExp(r'\/Date\((\d+)\)\/').firstMatch(s);
  if (ms != null) {
    final n = int.tryParse(ms.group(1)!);
    if (n != null) return DateTime.fromMillisecondsSinceEpoch(n, isUtc: true).toLocal();
  }
  return DateTime.tryParse(s)?.toLocal();
}

DateTime? _gdt(dynamic j, List<String> paths) {
  for (final p in paths) {
    final v = getJsonField(j, p);
    final dt = _dt(v);
    if (dt != null) return dt;
  }
  return null;
}

TimeOfDay? _parseTimeOfDay(dynamic any) {
  final s = _str(any).trim();
  if (s.isEmpty) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(s);
  if (m == null) return null;
  final h = int.tryParse(m.group(1) ?? '') ?? 0;
  final mi = int.tryParse(m.group(2) ?? '') ?? 0;
  return TimeOfDay(hour: h.clamp(0, 23), minute: mi.clamp(0, 59));
}

API.DetailedCarRequestStatus _collapseStatus(dynamic rawAny) {
  return API.parseDetailedCarRequestStatus(rawAny);
}

class CostAllocVM {
  final int? ownerId;
  final String ownerName;
  final int? costAllocId;
  final String costAllocName;
  final double percent;

  const CostAllocVM({
    required this.ownerId,
    required this.ownerName,
    required this.costAllocId,
    required this.costAllocName,
    required this.percent,
  });

  factory CostAllocVM.fromApiJson(dynamic j, {Map<int, String>? names}) {
    final caId = _int(getJsonField(j, r'$.id'));

    final ownerId =
        _int(getJsonField(j, r'$.userId')) ??
            _int(getJsonField(j, r'$.UserId'));

    final costAllocId =
        _int(getJsonField(j, r'$.costAllocId')) ??
            _int(getJsonField(j, r'$.CostAllocId')) ??
            _int(getJsonField(j, r'$.costAllocation.id'));

    final costAllocName = () {
      final a = _str(getJsonField(j, r'$.costAllocation.name'));
      if (a.isNotEmpty) return a;
      final b = _str(getJsonField(j, r'$.CostAllocation.Name'));
      if (b.isNotEmpty) return b;
      return _str(getJsonField(j, r'$.costAllocationName'));
    }();

    final percent =
        _double(getJsonField(j, r'$.percent')) ??
            _double(getJsonField(j, r'$.Percent')) ??
            0.0;

    String ownerName = '';
    if (ownerId != null && names != null && (names[ownerId]?.isNotEmpty ?? false)) {
      ownerName = names[ownerId]!;
    } else if (caId != null && names != null && (names[caId]?.isNotEmpty ?? false)) {
      ownerName = names[caId]!;
    }

    return CostAllocVM(
      ownerId: ownerId,
      ownerName: ownerName,
      costAllocId: costAllocId,
      costAllocName: costAllocName,
      percent: percent,
    );
  }
}

class FlightInformationVM {
  final int id;
  final int carRequestId;
  final String flightNumber;
  final TimeOfDay? time;
  final String sourceAirport;
  final String destinationAirport;
  final String destination;
  final bool isDeparture;

  const FlightInformationVM({
    required this.id,
    required this.carRequestId,
    required this.flightNumber,
    required this.time,
    required this.sourceAirport,
    required this.destinationAirport,
    required this.destination,
    required this.isDeparture,
  });

  factory FlightInformationVM.fromApiJson(dynamic j) {
    return FlightInformationVM(
      id: _int(getJsonField(j, r'$.id')) ?? 0,
      carRequestId: _int(getJsonField(j, r'$.carRequestId')) ?? 0,
      flightNumber: _str(getJsonField(j, r'$.flightNumber')),
      time: _parseTimeOfDay(getJsonField(j, r'$.time')),
      sourceAirport: _str(getJsonField(j, r'$.sourceAirport')),
      destinationAirport: _str(getJsonField(j, r'$.destinationAirport')),
      destination: _str(getJsonField(j, r'$.destination')),
      isDeparture: _bool(getJsonField(j, r'$.isDeparture')),
    );
  }
}

class CarRequestDestVM {
  final int id;
  final String address;
  final int sequence;
  const CarRequestDestVM({required this.id, required this.address, required this.sequence});

  factory CarRequestDestVM.fromApiJson(dynamic j) {
    final addr = () {
      final a = _str(getJsonField(j, r'$.destAddress'));
      if (a.isNotEmpty) return a;
      final b = _str(getJsonField(j, r'$.address'));
      if (b.isNotEmpty) return b;
      return _str(getJsonField(j, r'$.formattedAddress'));
    }();
    return CarRequestDestVM(
      id: _int(getJsonField(j, r'$.id')) ?? 0,
      address: addr,
      sequence: _int(getJsonField(j, r'$.sequence')) ?? 0,
    );
  }
}

class CarRequestViewModel {
  CarRequestViewModel({
    required this.id,
    required this.userId,
    required this.carId,
    required this.driverId,

    required this.userName,
    required this.driverName,
    required this.model,
    required this.licensePlate,

    required this.periodFrom,
    this.periodTo,
    required this.routeDeparture,
    this.destinations = const [],

    this.notes,
    this.childSeat = false,
    this.bookNow = false,
    this.driverIsAtThePlaceDeparture = false,

    this.status = API.DetailedCarRequestStatus.draft,
    this.statusName,

    this.passengersIds,
    this.passengersCsv,

    this.costAllocs = const [],
    this.flightsInformations = const [],

    this.realStartDateTime,
    this.realEndDateTime,
    this.startKm,
    this.endKm,
    this.cancelReason,
    this.specialCarInfo,
    this.confirmationId,
    this.disacordReason,

    this.carType,
    this.passanger1,
    this.passanger2,
    this.passanger3,
  });

  final String id;
  final int? userId;
  final int? carId;
  final int? driverId;

  final String userName;
  final String driverName;
  final String model;
  final String licensePlate;

  final DateTime periodFrom;
  final DateTime? periodTo;
  final String routeDeparture;
  final List<String> destinations;

  final String? notes;
  final bool childSeat;
  final bool bookNow;
  final bool driverIsAtThePlaceDeparture;

  API.DetailedCarRequestStatus status;
  final String? statusName;

  final List<int>? passengersIds;
  final String? passengersCsv;

  final List<CostAllocVM> costAllocs;
  final List<FlightInformationVM> flightsInformations;

  final DateTime? realStartDateTime;
  final DateTime? realEndDateTime;
  final int? startKm;
  final int? endKm;
  final String? cancelReason;
  final String? specialCarInfo;
  final String? confirmationId;
  final String? disacordReason;

  final int? carType;
  final String? passanger1;
  final String? passanger2;
  final String? passanger3;

  int get idAsInt => int.tryParse(id) ?? 0;
  String get destinationsJoined =>
      destinations.where((s) => s.trim().isNotEmpty).join(' • ');

  static const List<String> _carTypeLabels = [
    'Outlander', 'Mini Van', 'Van', 'Sedan', 'SUV'
  ];
  String get carTypeLabel =>
      (carType != null && carType! >= 0 && carType! < _carTypeLabels.length)
          ? _carTypeLabels[carType!]
          : '—';

  String get specification {
    final s = (specialCarInfo ?? '').trim();
    return s.isNotEmpty ? s : licensePlate;
  }

  CarRequestViewModel copyWith({
    String? id,
    int? userId,
    int? carId,
    int? driverId,
    String? userName,
    String? driverName,
    String? model,
    String? licensePlate,
    DateTime? periodFrom,
    DateTime? periodTo,
    String? routeDeparture,
    List<String>? destinations,
    String? notes,
    bool? childSeat,
    bool? bookNow,
    bool? driverIsAtThePlaceDeparture,
    API.DetailedCarRequestStatus? status,
    String? statusName,
    List<int>? passengersIds,
    String? passengersCsv,
    List<CostAllocVM>? costAllocs,
    List<FlightInformationVM>? flightsInformations,
    DateTime? realStartDateTime,
    DateTime? realEndDateTime,
    int? startKm,
    int? endKm,
    String? cancelReason,
    String? specialCarInfo,
    String? confirmationId,
    String? disacordReason,

    int? carType,
    String? passanger1,
    String? passanger2,
    String? passanger3,
  }) {
    return CarRequestViewModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      carId: carId ?? this.carId,
      driverId: driverId ?? this.driverId,
      userName: userName ?? this.userName,
      driverName: driverName ?? this.driverName,
      model: model ?? this.model,
      licensePlate: licensePlate ?? this.licensePlate,
      periodFrom: periodFrom ?? this.periodFrom,
      periodTo: periodTo ?? this.periodTo,
      routeDeparture: routeDeparture ?? this.routeDeparture,
      destinations: destinations ?? this.destinations,
      notes: notes ?? this.notes,
      childSeat: childSeat ?? this.childSeat,
      bookNow: bookNow ?? this.bookNow,
      driverIsAtThePlaceDeparture:
      driverIsAtThePlaceDeparture ?? this.driverIsAtThePlaceDeparture,
      status: status ?? this.status,
      statusName: statusName ?? this.statusName,
      passengersIds: passengersIds ?? this.passengersIds,
      passengersCsv: passengersCsv ?? this.passengersCsv,
      costAllocs: costAllocs ?? this.costAllocs,
      flightsInformations: flightsInformations ?? this.flightsInformations,
      realStartDateTime: realStartDateTime ?? this.realStartDateTime,
      realEndDateTime: realEndDateTime ?? this.realEndDateTime,
      startKm: startKm ?? this.startKm,
      endKm: endKm ?? this.endKm,
      cancelReason: cancelReason ?? this.cancelReason,
      specialCarInfo: specialCarInfo ?? this.specialCarInfo,
      confirmationId: confirmationId ?? this.confirmationId,
      disacordReason: disacordReason ?? this.disacordReason,

      carType: carType ?? this.carType,
      passanger1: passanger1 ?? this.passanger1,
      passanger2: passanger2 ?? this.passanger2,
      passanger3: passanger3 ?? this.passanger3,
    );
  }

  factory CarRequestViewModel.fromApiJson(dynamic j) {
    final idInt = _int(getJsonField(j, r'$.id')) ?? 0;
    final userId =
        _int(getJsonField(j, r'$.userId')) ??
            _int(getJsonField(j, r'$.requirerId'));

    final carId = _int(getJsonField(j, r'$.carId'));
    final driverId = _int(getJsonField(j, r'$.driverId'));

    final start = _gdt(j, [
      r'$.startDateTime', r'$.start', r'$.periodFrom', r'$.startAt',
      r'$.carRequest.startDateTime', r'$.carRequest.start', r'$.carRequest.periodFrom'
    ]) ?? DateTime.now();

    final end = _gdt(j, [
      r'$.endDateTime', r'$.end', r'$.periodTo', r'$.endAt',
      r'$.carRequest.endDateTime', r'$.carRequest.end', r'$.carRequest.periodTo'
    ]);

    final sourceAddress = _str(getJsonField(j, r'$.sourceAddress'));

    final dests = () {
      final raw = getJsonField(j, r'$.carRequestDests');
      if (raw is List) {
        final list = raw.map((e) => CarRequestDestVM.fromApiJson(e)).toList();
        list.sort((a, b) => a.sequence.compareTo(b.sequence));
        return list.map((e) => e.address).where((s) => s.isNotEmpty).toList();
      }
      return const <String>[];
    }();

    final notes = () {
      final n1 = _str(getJsonField(j, r'$.note'));
      if (n1.isNotEmpty) return n1;
      final n2 = _str(getJsonField(j, r'$.notes'));
      if (n2.isNotEmpty) return n2;
      final n3 = _str(getJsonField(j, r'$.description'));
      if (n3.isNotEmpty) return n3;
      return null;
    }();

    final childSeat = _bool(getJsonField(j, r'$.childSeat'));
    final bookNow = _bool(getJsonField(j, r'$.bookNow'));
    final driverIsAtThePlaceDeparture =
    _bool(getJsonField(j, r'$.driverIsAtThePlaceDeparture'));

    final rawStatus = _str(getJsonField(j, r'$.requestStatus'));
    final statusEnum = _collapseStatus(rawStatus);

    final userName =
    _str(getJsonField(j, r'$.userDto.fullName')).isNotEmpty
        ? _str(getJsonField(j, r'$.userDto.fullName'))
        : _str(getJsonField(j, r'$.user.fullName'));

    final driverName =
    _str(getJsonField(j, r'$.driverDto.fullName')).isNotEmpty
        ? _str(getJsonField(j, r'$.driverDto.fullName'))
        : _str(getJsonField(j, r'$.driver.fullName'));

    final carType = () {
      final raw = getJsonField(j, r'$.carType');
      if (raw is num) return raw.toInt();
      final s = _str(raw);
      final n = int.tryParse(s);
      return n;
    }();

    final model = () {
      final d = _str(getJsonField(j, r'$.carDto.description'));
      if (d.isNotEmpty) return d;
      final dd = _str(getJsonField(j, r'$.car.description'));
      if (dd.isNotEmpty) return dd;
      final label =
      (carType != null && carType! >= 0 && carType! < _carTypeLabels.length)
          ? _carTypeLabels[carType!]
          : '';
      return label;
    }();

    final plate = () {
      final a = _str(getJsonField(j, r'$.carDto.licensePlate'));
      if (a.isNotEmpty) return a;
      final b = _str(getJsonField(j, r'$.car.licensePlate'));
      if (b.isNotEmpty) return b;
      return '';
    }();

    final passengersIds = () {
      final l = getJsonField(j, r'$.passengersId') ??
          getJsonField(j, r'$.PassengersId');
      if (l is List) {
        return l.map((e) => _int(e) ?? 0).where((n) => n != 0).toList();
      }
      return <int>[];
    }();
    final passengersCsv = _str(getJsonField(j, r'$.passengersCsv')).isNotEmpty
        ? _str(getJsonField(j, r'$.passengersCsv'))
        : null;

    final p1 = _str(getJsonField(j, r'$.passanger1'));
    final p2 = _str(getJsonField(j, r'$.passanger2'));
    final p3 = _str(getJsonField(j, r'$.passanger3'));

    final Map<int, String> costAllocsUserNames = () {
      final raw =
          getJsonField(j, r'$.costAllocsUserNames') ??
              getJsonField(j, r'$.CostAllocsUserNames') ??
              getJsonField(j, r'$.costAllocsUsersNames') ??
              getJsonField(j, r'$.CostAllocsUsersNames');

      final map = <int, String>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          final key = (k is num) ? k.toInt() : int.tryParse(_str(k));
          final name = _str(v);
          if (key != null && name.isNotEmpty) map[key] = name;
        });
      }
      return map;
    }();

    final costAllocs = () {
      final raw = getJsonField(j, r'$.carRequestsCostAllocs');
      if (raw is List) {
        return raw
            .map((e) => CostAllocVM.fromApiJson(e, names: costAllocsUserNames))
            .toList();
      }
      return const <CostAllocVM>[];
    }();

    final flights = () {
      final raw = getJsonField(j, r'$.flightsInformations') ??
          getJsonField(j, r'$.flightInformations') ??
          getJsonField(j, r'$.FlightsInformations') ??
          getJsonField(j, r'$.FlightInformations');
      if (raw is List) {
        return raw.map((e) => FlightInformationVM.fromApiJson(e)).toList();
      }
      return const <FlightInformationVM>[];
    }();

    final realStart = _gdt(j, [
      r'$.realStartDateTime', r'$.realStart', r'$.realStartAt',
      r'$.realPeriod.start', r'$.reportStart', r'$.startedAt',
      r'$.carRequest.realStart', r'$.carRequest.realStartAt'
    ]);

    final realEnd = _gdt(j, [
      r'$.realEndDateTime', r'$.realEnd', r'$.realEndAt',
      r'$.realPeriod.end', r'$.reportEnd', r'$.endedAt',
      r'$.carRequest.realEnd', r'$.carRequest.realEndAt'
    ]);
    final startKm = _int(getJsonField(j, r'$.startKm'));
    final endKm = _int(getJsonField(j, r'$.endKm'));
    final cancelReason = _str(getJsonField(j, r'$.cancelReason'));

    final specialCarInfo = () {
      final a = _str(getJsonField(j, r'$.specialCarInfo'));
      if (a.isNotEmpty) return a;
      final b = _str(getJsonField(j, r'$.carDto.specialCarInfo'));
      if (b.isNotEmpty) return b;
      final c = _str(getJsonField(j, r'$.car.specialCarInfo'));
      if (c.isNotEmpty) return c;
      final d = _str(getJsonField(j, r'$.carRequest.specialCarInfo'));
      if (d.isNotEmpty) return d;
      return '';
    }();

    final confirmationId = _str(getJsonField(j, r'$.confirmationId'));
    final disacordReason = _str(getJsonField(j, r'$.disacordReason'));

    return CarRequestViewModel(
      id: idInt.toString(),
      userId: userId,
      carId: carId,
      driverId: driverId,
      userName: userName.isEmpty ? '—' : userName,
      driverName: driverName.isEmpty ? '—' : driverName,
      model: model.isEmpty ? '—' : model,
      licensePlate: plate,
      periodFrom: start,
      periodTo: end,
      routeDeparture: sourceAddress,
      destinations: dests,
      notes: notes,
      childSeat: childSeat,
      bookNow: bookNow,
      driverIsAtThePlaceDeparture: driverIsAtThePlaceDeparture,
      status: statusEnum,
      statusName: rawStatus.isEmpty ? null : rawStatus,
      passengersIds: passengersIds.isEmpty ? null : passengersIds,
      passengersCsv: passengersCsv,
      costAllocs: costAllocs,
      flightsInformations: flights,
      realStartDateTime: realStart,
      realEndDateTime: realEnd,
      startKm: startKm,
      endKm: endKm,
      cancelReason: cancelReason.isEmpty ? null : cancelReason,
      specialCarInfo: specialCarInfo.isEmpty ? null : specialCarInfo,
      confirmationId: confirmationId.isEmpty ? null : confirmationId,
      disacordReason: disacordReason.isEmpty ? null : disacordReason,

      carType: carType,
      passanger1: p1.isEmpty ? null : p1,
      passanger2: p2.isEmpty ? null : p2,
      passanger3: p3.isEmpty ? null : p3,
    );
  }
}

class CarRequestModel extends FlutterFlowModel<Widget> {
  CarRequestViewModel? initial;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}

  void setFromApiBody(dynamic body) {
    final json = (body is API.ApiCallResponse) ? body.jsonBody : body;
    initial = CarRequestViewModel.fromApiJson(json);
  }

  void clearInitial() {
    initial = null;
  }
}
