import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'api_manager.dart';

export 'api_manager.dart' show ApiCallResponse;

//HOMOLOG SEM VPN
// const _kPrivateApiFunctionName = 'http://177.92.123.2:5000/api/';
//HOMOLOG COM VPN
const _kPrivateApiFunctionName = 'http://10.11.1.30:5000/api/';
//QA COM VPN
// const _kPrivateApiFunctionName = 'http://10.11.1.32:5000/api/';

enum CarRequestStatus { draft, confirmed, canceled }

extension CarRequestStatusX on CarRequestStatus {
  bool get isDraft => this == CarRequestStatus.draft;
  bool get isConfirmed => this == CarRequestStatus.confirmed;
  bool get isCanceled => this == CarRequestStatus.canceled;
}

enum DetailedCarRequestStatus {
  draft,
  waiting,
  pending,
  scheduled,
  assigned,
  approved,
  confirmed,
  inProgress,
  finished,
  canceled,
  unknown,
}

extension DetailedCarRequestStatusX on DetailedCarRequestStatus {
  CarRequestStatus collapse() {
    switch (this) {
      case DetailedCarRequestStatus.canceled:
        return CarRequestStatus.canceled;
      case DetailedCarRequestStatus.draft:
      case DetailedCarRequestStatus.waiting:
        return CarRequestStatus.draft;
      default:
        return CarRequestStatus.confirmed;
    }
  }

  bool get isCanceled => this == DetailedCarRequestStatus.canceled;

  bool get isDraft => this == DetailedCarRequestStatus.draft || this == DetailedCarRequestStatus.waiting;

  bool get isConfirmed => !isCanceled && !isDraft;
}


DetailedCarRequestStatus parseDetailedCarRequestStatus(dynamic rawAny) {
  if (rawAny is num) {
    switch (rawAny.toInt()) {
      case 0: return DetailedCarRequestStatus.confirmed;
      case 1: return DetailedCarRequestStatus.draft;
      case 2: return DetailedCarRequestStatus.finished;
      case 3: return DetailedCarRequestStatus.waiting;
      case 4: return DetailedCarRequestStatus.canceled;
      case 5: return DetailedCarRequestStatus.pending;
      case 6: return DetailedCarRequestStatus.inProgress;
      default: return DetailedCarRequestStatus.unknown;
    }
  }

  final s = (rawAny?.toString() ?? '').toLowerCase().trim();
  if (s.isEmpty) return DetailedCarRequestStatus.unknown;

  if (s.contains('cancel')) return DetailedCarRequestStatus.canceled;
  if (s.contains('finish') || s.contains('final') || s.contains('done') || s.contains('close')) {
    return DetailedCarRequestStatus.finished;
  }
  if (s.contains('progress') || s.contains('ongoing') || s.contains('start')) {
    return DetailedCarRequestStatus.inProgress;
  }
  if (s.contains('schedul') || s.contains('agend')) return DetailedCarRequestStatus.scheduled;
  if (s.contains('assign')) return DetailedCarRequestStatus.assigned;
  if (s.contains('approve')) return DetailedCarRequestStatus.approved;
  if (s.contains('confirm')) return DetailedCarRequestStatus.confirmed;

  if (s.contains('wait') || s.contains('aguard') || s.contains('analis')) return DetailedCarRequestStatus.waiting;
  if (s.contains('pend')) return DetailedCarRequestStatus.pending;

  if (s.contains('draft') || s.contains('rascun')) return DetailedCarRequestStatus.draft;

  return DetailedCarRequestStatus.unknown;
}


/// =================== AUTH ===================
class UsersLoginCall {
  static Future<ApiCallResponse> call({
    required String email,
    required String password,
  }) async {
    final ffApiRequestBody = '''
{
  "email": "${escapeStringForJson(email)}",
  "password": "${escapeStringForJson(password)}"
}''';

    return ApiManager.instance.makeApiCall(
      callName: 'UsersLogin',
      apiUrl: _kPrivateApiFunctionName + 'users/login',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static String? token(ApiCallResponse res) =>
      getJsonField(res.jsonBody, r'$.token')?.toString();
  static dynamic user(ApiCallResponse res) =>
      getJsonField(res.jsonBody, r'$.user');
}

class ForgotPasswordCall {
  static Future<ApiCallResponse> call({required String email}) {
    final bodyJson = jsonEncode({'email': email});

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    return ApiManager.instance.makeApiCall(
      callName: 'ForgotPassword',
      apiUrl: '${_kPrivateApiFunctionName}Users/ForgotPassword',
      callType: ApiCallType.POST,
      headers: headers,
      body: bodyJson,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: true,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: true,
    );
  }
}
// ------------------- Modelos leves -------------------
class UserLite {
  final int id;
  final String fullName;

  const UserLite({required this.id, required this.fullName});

  factory UserLite.fromParts(int id, String name) =>
      UserLite(id: id, fullName: name);
}

class CostAllocLite {
  final int id;
  final String name;

  const CostAllocLite({required this.id, required this.name});
}

//  /users/index
class CarRequestsApi {
  const CarRequestsApi();

  Future<List<UserLite>> getUsers({String? bearerToken}) async {
    final res = await UsersIndexCall.call(bearerToken: bearerToken);
    if (!res.succeeded) {
      throw Exception(
        'Erro ao buscar usuários (status ${res.statusCode ?? 'desconhecido'})',
      );
    }

    final rawItems = UsersIndexCall.items(res);
    final users = <UserLite>[];
    for (final u in rawItems) {
      final id = UsersIndexCall.id(u);
      final name = (UsersIndexCall.fullName(u) ?? '').trim();
      if (id != null && name.isNotEmpty) {
        users.add(UserLite.fromParts(id, name));
      }
    }

    users.sort(
          (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return users;
  }
}

class RescheduleCarRequestListCall {
  static Future<ApiCallResponse> call({String? bearerToken}) {
    return ApiManager.instance.makeApiCall(
      callName: 'RescheduleCarRequestList',
      apiUrl:
      _kPrivateApiFunctionName + 'RescheduleCarResquest/GetRescheduleCarRequest',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }

  static List<dynamic> items(ApiCallResponse res) {
    final body = res.jsonBody;
    if (body is List) return body;
    if (body is Map) {
      final items = getJsonField(body, r'$.items');
      if (items is List) return items;
      final data = getJsonField(body, r'$.data');
      if (data is List) return data;
    }
    return const [];
  }
}

class RescheduleCarRequestUpdateStatusCall {
  static Future<ApiCallResponse> call({
    String? bearerToken,
    required int rescheduleId,
    required String status,
  }) {
    final payload = jsonEncode({
      'RescheduleId': rescheduleId,
      'Status': status,
    });

    return ApiManager.instance.makeApiCall(
      callName: 'RescheduleCarRequestUpdateStatus',
      apiUrl:
      _kPrivateApiFunctionName + 'RescheduleCarResquest/UpdateStatus',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      body: payload,
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }

  static bool success(ApiCallResponse res) =>
      (getJsonField(res.jsonBody, r'$.success') ?? false) == true;

  static String? message(ApiCallResponse res) {
    final msg = getJsonField(res.jsonBody, r'$.message');
    if (msg == null) return null;
    final text = msg.toString().trim();
    return text.isEmpty ? null : text;
  }
}

class DriversAvailableToChangeCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required int carRequestId,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'DriversAvailableToChange',
      apiUrl: _kPrivateApiFunctionName +
          'Drivers/GetAvailableToChange/$carRequestId',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Accept': 'application/json',
      },
      params: const {},
      returnBody: true,
      bodyType: BodyType.JSON,
      cache: false,
    );
  }

  static List<dynamic> items(ApiCallResponse res) {
    final body = res.jsonBody;
    if (body is List) return body;
    final items = getJsonField(body, r'$.items');
    if (items is List) return items;
    return const [];
  }

  static int? id(dynamic item) {
    final value = getJsonField(item, r'$.id');
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? name(dynamic item) {
    final name = getJsonField(item, r'$.fullName') ??
        getJsonField(item, r'$.name') ??
        getJsonField(item, r'$.description');
    return name?.toString();
  }
}

// =================== LISTA GERAL ===================
class CarRequestsListCall {
  static Future<ApiCallResponse> call({
    String? bearerToken,
    required DateTime from,
    required DateTime to,
    int page = 1,
    int pageSize = 10,
  }) async {
    final bodyMap = {
      'fromDateTime': from.toIso8601String(),
      'toDateTime': to.toIso8601String(),
    };

    final resp = await ApiManager.instance.makeApiCall(
      callName: 'CarRequestsList',
      apiUrl: _kPrivateApiFunctionName +
          'carrequests/index/app?pageSize=$pageSize&page=$page',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(bodyMap),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );

    return resp;
  }

  // static void _logJsonPretty(String label, dynamic body) {
  //   try {
  //     final pretty = const JsonEncoder.withIndent('  ').convert(body);
  //     debugPrint('$label:\n$pretty', wrapWidth: 1024);
  //   } catch (_) {
  //     debugPrint('$label (raw): ${body.toString()}', wrapWidth: 1024);
  //   }
  // }

  // -------- parsing ----------
  static List<dynamic> items(ApiCallResponse res) {
    final body = res.jsonBody;
    if (body is Map) {
      final list = getJsonField(body, r'$.items');
      if (list is List) return list;
    }
    if (body is List) return body;
    return const [];
  }

  static bool hasNext(ApiCallResponse res) =>
      (getJsonField(res.jsonBody, r'$.hasNext') as bool?) ?? false;

  static String _str(dynamic v) => v?.toString() ?? '';

  static DateTime? _parseDate(dynamic v) {
    final s = _str(v);
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return null;
    }
  }

  static String? id(d) {
    final v = getJsonField(d, r'$.id');
    final s = _str(v);
    return s.isEmpty ? null : s;
  }

  static String? userName(d) =>
      _str(getJsonField(d, r'$.user.fullName')).isNotEmpty
          ? _str(getJsonField(d, r'$.user.fullName'))
          : (_str(getJsonField(d, r'$.userDto.fullName')).isNotEmpty
          ? _str(getJsonField(d, r'$.userDto.fullName'))
          : _str(getJsonField(d, r'$.requirerDto.fullName')));

  static DateTime? startAt(d) =>
      _parseDate(getJsonField(d, r'$.startDateTime')) ??
          _parseDate(getJsonField(d, r'$.start')) ??
          _parseDate(getJsonField(d, r'$.periodFrom'));

  static DateTime? endAt(d) =>
      _parseDate(getJsonField(d, r'$.endDateTime')) ??
          _parseDate(getJsonField(d, r'$.end')) ??
          _parseDate(getJsonField(d, r'$.periodTo'));

  static String? departure(d) {
    final a = _str(getJsonField(d, r'$.routeDeparture'));
    if (a.isNotEmpty) return a;
    final b = _str(getJsonField(d, r'$.startAddress'));
    if (b.isNotEmpty) return b;
    final c = _str(getJsonField(d, r'$.fromAddress'));
    if (c.isNotEmpty) return c;
    final d0 = _str(getJsonField(d, r'$.sourceAddress'));
    if (d0.isNotEmpty) return d0;
    return null;
  }

  static List<String> destinations(d) {
    final list = getJsonField(d, r'$.carRequestDests');
    if (list is List) {
      return list
          .map((e) {
        final a = _str(getJsonField(e, r'$.address'));
        if (a.isNotEmpty) return a;
        final f = _str(getJsonField(e, r'$.formattedAddress'));
        if (f.isNotEmpty) return f;
        return _str(getJsonField(e, r'$.routeDestination'));
      })
          .where((s) => s.isNotEmpty)
          .cast<String>()
          .toList();
    }
    return const [];
  }

  static String? notes(d) {
    final n1 = _str(getJsonField(d, r'$.notes'));
    if (n1.isNotEmpty) return n1;
    final n2 = _str(getJsonField(d, r'$.description'));
    if (n2.isNotEmpty) return n2;
    final n3 = _str(getJsonField(d, r'$.note'));
    if (n3.isNotEmpty) return n3;
    return null;
  }

  static String? driverName(d) =>
      _str(getJsonField(d, r'$.driverDto.fullName')).isNotEmpty
          ? _str(getJsonField(d, r'$.driverDto.fullName'))
          : _str(getJsonField(d, r'$.driver.fullName'));

  static String? model(d) =>
      _str(getJsonField(d, r'$.car.description')).isNotEmpty
          ? _str(getJsonField(d, r'$.car.description'))
          : (_str(getJsonField(d, r'$.car.model')).isNotEmpty
          ? _str(getJsonField(d, r'$.car.model'))
          : _str(getJsonField(d, r'$.carDto.description')));

  static String? licensePlate(d) {
    final a = _str(getJsonField(d, r'$.car.licensePlate'));
    if (a.isNotEmpty) return a;
    final b = _str(getJsonField(d, r'$.carDto.licensePlate'));
    if (b.isNotEmpty) return b;
    return _str(getJsonField(d, r'$.licensePlate'));
  }

  static bool childSeat(d) =>
      (getJsonField(d, r'$.childSeat') as bool?) ?? false;

  static bool hadIncident(d) {
    num? _toNum(dynamic v) {
      if (v is num) return v;
      if (v is String) return num.tryParse(v.trim());
      return null;
    }

    final n =
        _toNum(getJsonField(d, r'$.trafficIncidentId')) ??
            _toNum(getJsonField(d, r'$.TrafficIncidentId'));

    if (n != null) return n != 0;

    final b1 = getJsonField(d, r'$.hadIncident');
    if (b1 is bool) return b1;
    final b2 = getJsonField(d, r'$.HadIncident');
    if (b2 is bool) return b2;

    return false;
  }

  static CarRequestStatus status(d) {
    final raw = getJsonField(d, r'$.requestStatus') ??
        getJsonField(d, r'$.status') ??
        getJsonField(d, r'$.statusName');
    return parseDetailedCarRequestStatus(raw).collapse();
  }

  static DetailedCarRequestStatus detailedStatus(d) {
    final raw = getJsonField(d, r'$.requestStatus') ??
        getJsonField(d, r'$.status') ??
        getJsonField(d, r'$.statusName');
    return parseDetailedCarRequestStatus(raw);
  }
}

// =================== LISTA (ADMIN Index - sem paginação) ===================
class CarRequestsListAdminCall {
  static Future<ApiCallResponse> call({
    String? bearerToken,
    required DateTime from,
    required DateTime to,
  }) {
    final bodyMap = {
      'fromDateTime': from.toIso8601String(),
      'toDateTime': to.toIso8601String(),
    };

    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsListAdminIndex',
      apiUrl: _kPrivateApiFunctionName + 'carrequests/index',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(bodyMap),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static List<dynamic> items(ApiCallResponse res) {
    final body = res.jsonBody;
    if (body is List) return body;
    if (body is Map) {
      final list = getJsonField(body, r'$.items');
      if (list is List) return list;
    }
    return const [];
  }
}
// ========================= Traffic Incident Calls =========================

class TrafficIncidentVerifyExistsByCarRequestCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required dynamic carRequestId,
  }) {
    final idStr = carRequestId?.toString() ?? '';

    return ApiManager.instance.makeApiCall(
      callName: 'TrafficIncidentVerifyExistsByCarRequest',
      apiUrl:
      _kPrivateApiFunctionName + 'TrafficIncident/VerifyExistsByCarRequest',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      },
      params: {
        'carRequestId': idStr,
      },
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }

  static bool exists(ApiCallResponse r) {
    final b = r.jsonBody;

    final e1 = getJsonField(b, r'$.existsIncident');
    if (e1 is bool) return e1;
    if (e1 != null) {
      final s = e1.toString().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }

    // 2) exists
    final e2 = getJsonField(b, r'$.exists');
    if (e2 is bool) return e2;
    if (e2 != null) {
      final s = e2.toString().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }

    // 3) boolean puro no corpo
    if (b is bool) return b;

    // 4) string booleana pura
    if (b is String) {
      final s = b.trim().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }

    // fallback seguro
    return false;
  }
}

class TrafficIncidentGetByCarRequestCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required String carRequestId,
  }) {
    final url = '$_kPrivateApiFunctionName'
        'TrafficIncident/GetByCarRequest';

    return ApiManager.instance.makeApiCall(
      callName: 'TrafficIncidentGetByCarRequest',
      apiUrl: url,
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      },
      params: {
        'carRequestId': carRequestId,
      },
      returnBody: true,
      cache: false,
    );
  }

  // Accessors (ajuste os paths conforme o DTO real)
  static dynamic id(ApiCallResponse r) => getJsonField(r.jsonBody, r'$.id');
  static String? driverName(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.driverDto.fullName') as String?) ??
          (getJsonField(r.jsonBody, r'$.driverName') as String?);

  static DateTime? creationAt(ApiCallResponse r) {
    final s = (getJsonField(r.jsonBody, r'$.creationDateTime') ?? '').toString();
    return DateTime.tryParse(s);
  }

  static DateTime? incidentAt(ApiCallResponse r) {
    final s = (getJsonField(r.jsonBody, r'$.incidentDateTime') ?? '').toString();
    return DateTime.tryParse(s);
  }

  static bool hadInjuries(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.isInjuries') as bool?) ?? false;

  static String? injuriesDetails(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.injuriesDetails') as String?);

  static String? incidentLocation(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.incidentLocation') as String?);

  static String? incidentSummary(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.incidentBriefSummary') as String?);

  static String? damagePlate(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.carDamagePlate') as String?);

  static String? damageSummary(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.carDamageBriefSummary') as String?);

  static List<dynamic> passengers(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.passengers') as List?) ?? const [];

  static List<dynamic> photos(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.trafficIncidentPhotosDto') as List?) ?? const [];
}

class TrafficIncidentGetUsersCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
  }) {
    final url = '$_kPrivateApiFunctionName'
        'TrafficIncident/GetUsers';

    return ApiManager.instance.makeApiCall(
      callName: 'TrafficIncidentGetUsers',
      apiUrl: url,
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      },
      params: const {},
      returnBody: true,
      cache: true,
    );
  }

  static List<dynamic> items(ApiCallResponse r) {
    final body = r.jsonBody;
    if (body is List) return body;
    return const [];
  }

  static String idOf(dynamic u) => '${getJsonField(u, r'$.id')}';
  static String nameOf(dynamic u) =>
      (getJsonField(u, r'$.fullName') as String?) ?? '';
  static String emailOf(dynamic u) =>
      (getJsonField(u, r'$.email') as String?) ?? '';
}

class RescheduleCarRequestCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required int carRequestId,
    required DateTime newStart,
    required DateTime newEnd,
  }) async {
    String _fmt(DateTime d) {
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final mi = d.minute.toString().padLeft(2, '0');
      final ss = d.second.toString().padLeft(2, '0');
      return '$y-$m-$dd' 'T' '$hh:$mi:$ss';
    }

    final payload = jsonEncode({
      "carRequestId": carRequestId,
      "newScheduledStartDate": _fmt(newStart),
      "newScheduledEndDate": _fmt(newEnd),
    });

    return ApiManager.instance.makeApiCall(
      callName: 'RescheduleCarRequest',
      apiUrl: _kPrivateApiFunctionName + 'RescheduleCarResquest/Reschedule',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: payload,
      bodyType: BodyType.JSON,          // <- importante
      returnBody: true,
      encodeBodyUtf8: true,
    );
  }

  static bool success(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.success') ?? false) == true;

  static String? message(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.message') ?? '').toString();
}

class TrafficIncidentCreateMultipartCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required int carRequestId,
    int? driverId,
    required DateTime creationAt,
    required DateTime incidentAt,
    required bool hasInjuries,
    String? injuriesDetails,
    required String incidentLocation,
    required String incidentBriefSummary,
    String? carDamagePlate,
    required String carDamageBriefSummary,
    List<int> passengersIds = const <int>[],
    String? passanger1,
    String? passanger2,
    String? passanger3,
    required List<({String filename, List<int> bytes, String contentType})> photos,
  }) async {
    // endpoint correto: Create
    final uri = Uri.parse(_kPrivateApiFunctionName + 'TrafficIncident/Index');

    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $bearerToken'
      ..headers['Accept'] = 'application/json';

    req.fields['Id'] = '0';
    req.fields['CarRequestId'] = '$carRequestId';
    if (driverId != null) req.fields['DriverId'] = '$driverId';
    req.fields['CreationDateTime'] = creationAt.toUtc().toIso8601String();
    req.fields['IncidentDateTime'] = incidentAt.toUtc().toIso8601String();
    req.fields['IsInjuries'] = hasInjuries.toString();
    req.fields['InjuriesDetails'] = (injuriesDetails ?? '');
    req.fields['IncidentLocation'] = incidentLocation;
    req.fields['IncidentBriefSummary'] = incidentBriefSummary;
    req.fields['CarDamagePlate'] = (carDamagePlate ?? '');
    req.fields['CarDamageBriefSummary'] = carDamageBriefSummary;

    // Lista de passageiros (mesma chave repetida)
    for (final id in passengersIds) {
      req.files.add(
        http.MultipartFile.fromString(
          'PassengersId',
          id.toString(),
          contentType: MediaType('text', 'plain'),
        ),
      );
    }

    // Outros passageiros (texto)
    if ((passanger1 ?? '').trim().isNotEmpty) {
      req.fields['Passanger1'] = passanger1!.trim();
    }
    if ((passanger2 ?? '').trim().isNotEmpty) {
      req.fields['Passanger2'] = passanger2!.trim();
    }
    if ((passanger3 ?? '').trim().isNotEmpty) {
      req.fields['Passanger3'] = passanger3!.trim();
    }

    // Fotos
    for (final p in photos) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'TrafficIncidentPhotos',
          p.bytes,
          filename: p.filename,
          contentType: MediaType.parse(p.contentType),
        ),
      );
    }

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    dynamic jsonBody;
    try {
      jsonBody = jsonDecode(resp.body);
    } catch (_) {
      jsonBody = resp.body;
    }

    return ApiCallResponse(
      jsonBody,
      resp.headers,
      resp.statusCode,
    );
  }
}

class TrafficIncidentPassengersSelectCall {
  static Future<ApiCallResponse> call({String? bearerToken}) {
    return ApiManager.instance.makeApiCall(
      callName: 'TrafficIncidentPassengersSelect',
      apiUrl: '${_kPrivateApiFunctionName}TrafficIncident/GetUsers',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }

  static List<dynamic> items(ApiCallResponse resp) {
    final body = resp.jsonBody;
    if (body is List) return body;
    return const [];
  }

  static int? value(dynamic item) => item?['id'] as int?;
  static String? text(dynamic item) => item?['fullName'] as String?;
  static String? email(dynamic item) => item?['email'] as String?;
}

// =================== MY REQUESTS (abas) ===================
class CarRequestsBookedCarsCall {
  static Future<ApiCallResponse> call({
    String? bearerToken,
    int page = 1,
    int pageSize = 10,
  }) {
    final path =
        'carrequests/bookedcars/app?pageBookedCars=$page&pageSizeBookedCars=$pageSize';

    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsBookedCars',
      apiUrl: _kPrivateApiFunctionName + path,
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      body: null,
      returnBody: true,
      cache: false,
    );
  }

  static List<dynamic> items(ApiCallResponse res) {
    final j = getJsonField(res.jsonBody, r'$.bookedCars.items');
    return (j is List) ? j : const [];
  }

  static bool hasNext(ApiCallResponse res) =>
      (getJsonField(res.jsonBody, r'$.bookedCars.hasNext') as bool?) ?? false;

  static int? pageNumber(ApiCallResponse res) =>
      getJsonField(res.jsonBody, r'$.bookedCars.page') as int?;

  static int? totalPages(ApiCallResponse res) =>
      getJsonField(res.jsonBody, r'$.bookedCars.totalPages') as int?;
}

class CarRequestsBookedByOthersCall {
  static Future<ApiCallResponse> call({
    String? bearerToken,
    int page = 1,
    int pageSize = 10,
  }) {
    final path =
        'carrequests/bookedbyothers/app?pageBookedByOthers=$page&pageSizeBookedByOthers=$pageSize';

    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsBookedByOthers',
      apiUrl: _kPrivateApiFunctionName + path,
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      body: null,
      returnBody: true,
      cache: false,
    );
  }

  static List<dynamic> items(ApiCallResponse res) {
    final j = getJsonField(res.jsonBody, r'$.bookedByOthers.items');
    return (j is List) ? j : const [];
  }

  static bool hasNext(ApiCallResponse res) =>
      (getJsonField(res.jsonBody, r'$.bookedByOthers.hasNext') as bool?) ??
          false;

  static int? pageNumber(ApiCallResponse res) =>
      getJsonField(res.jsonBody, r'$.bookedByOthers.page') as int?;

  static int? totalPages(ApiCallResponse res) =>
      getJsonField(res.jsonBody, r'$.bookedByOthers.totalPages') as int?;
}

class CarRequestsBookedAsPassengerCall {
  static Future<ApiCallResponse> call({
    String? bearerToken,
    int page = 1,
    int pageSize = 10,
  }) {
    final path =
        'carrequests/bookedaspassenger/app?pageBookedAsPassenger=$page&pageSizeBookedAsPassenger=$pageSize';

    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsBookedAsPassenger',
      apiUrl: _kPrivateApiFunctionName + path,
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      body: null,
      returnBody: true,
      cache: false,
    );
  }

  static List<dynamic> items(ApiCallResponse res) {
    final j = getJsonField(res.jsonBody, r'$.bookedAsPassenger.items');
    return (j is List) ? j : const [];
  }

  static bool hasNext(ApiCallResponse res) =>
      (getJsonField(res.jsonBody, r'$.bookedAsPassenger.hasNext') as bool?) ??
          false;

  static int? pageNumber(ApiCallResponse res) =>
      getJsonField(res.jsonBody, r'$.bookedAsPassenger.page') as int?;

  static int? totalPages(ApiCallResponse res) =>
      getJsonField(res.jsonBody, r'$.bookedAsPassenger.totalPages') as int?;
}

// =================== REQUEST ACTIONS ===================
class CarRequestsCancelCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required String id,
    required String reason,
  }) {
    final payload = jsonEncode(<String, dynamic>{
      'id': int.tryParse(id) ?? id,
      'cancelReason': reason,
    });

    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsCancel',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests/Cancel',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
      bodyType: BodyType.JSON,
      body: payload,
      returnBody: true,
    );
  }
}

class CarRequestsRepeatCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required String originalId,
    required DateTime newStart,
    required DateTime newEnd,
  }) {
    final payload = jsonEncode(<String, dynamic>{
      'originalId': int.tryParse(originalId) ?? originalId,
      'newStart': newStart.toIso8601String(),
      'newEnd': newEnd.toIso8601String(),
    });

    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsRepeat',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests/RepeatRequest',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
      bodyType: BodyType.JSON,
      body: payload,
      returnBody: true,
    );
  }
}

// =================== DRIVERS ===================
class DriversListCall {
  static Future<ApiCallResponse> call({
    String? bearerToken,
    int page = 1,
    int pageSize = 5,
    String? search,
  }) {
    final searchTerm = search?.trim();
    final searchParam =
        (searchTerm?.isNotEmpty == true) ? '&search=${Uri.encodeQueryComponent(searchTerm!)}' : '';
    return ApiManager.instance.makeApiCall(
      callName: 'DriversList',
      apiUrl: _kPrivateApiFunctionName +
          'drivers/index/app?pageSize=$pageSize&page=$page$searchParam',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static List<dynamic> items(ApiCallResponse res) {
    final body = res.jsonBody;
    if (body is List) return body;
    final fromItems = getJsonField(body, r'$.items');
    if (fromItems is List) return fromItems;
    return const [];
  }

  static int? id(dynamic item) => getJsonField(item, r'$.id');
  static String? name(dynamic item) =>
      getJsonField(item, r'$.fullName')?.toString();
  static String? company(dynamic item) =>
      getJsonField(item, r'$.company.fullName')?.toString();
  static String? email(dynamic item) =>
      getJsonField(item, r'$.email')?.toString();
  static bool active(dynamic item) =>
      (getJsonField(item, r'$.active') as bool?) ?? true;
  static String? phone(dynamic item) =>
      getJsonField(item, r'$.phoneNumber')?.toString();
  static String? license(dynamic item) =>
      getJsonField(item, r'$.license')?.toString();
  static int? available(dynamic item) => getJsonField(item, r'$.curStatus');
  static bool presidence(dynamic item) =>
      (getJsonField(item, r'$.presidenceDriver') as bool?) ?? false;
  static bool backup(dynamic item) =>
      (getJsonField(item, r'$.backupDriver') as bool?) ?? false;
  static bool japanese(dynamic item) =>
      (getJsonField(item, r'$.japanese') as bool?) ?? false;
  static bool english(dynamic item) =>
      (getJsonField(item, r'$.english') as bool?) ?? false;
  static String? rg(dynamic item) => getJsonField(item, r'$.rg')?.toString();
  static String? phone2(dynamic item) =>
      getJsonField(item, r'$.phoneNumber2')?.toString();
  static String? photoBase64(dynamic item) =>
      getJsonField(item, r'$.base64DriverProfilePicture')?.toString();
  static int? companyId(dynamic item) {
    final cid = getJsonField(item, r'$.companyId');
    if (cid is num) return cid.toInt();
    final nested = getJsonField(item, r'$.company.id');
    if (nested is num) return nested.toInt();
    return null;
  }

  static int? pageNumber(ApiCallResponse res) =>
      getJsonField(res.jsonBody, r'$.page') as int? ??
          getJsonField(res.jsonBody, r'$.pageNumber') as int?;

  static int? totalPages(ApiCallResponse res) =>
      getJsonField(res.jsonBody, r'$.totalPages') as int?;
}

class DriversDeleteCall {
  static Future<ApiCallResponse> call({
    required int id,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'DriversDelete',
      apiUrl: _kPrivateApiFunctionName + 'drivers/$id',
      callType: ApiCallType.DELETE,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class DriverCreateCall {
  static Future<ApiCallResponse> call({required Map<String, dynamic> body}) {
    return ApiManager.instance.makeApiCall(
      callName: 'DriverCreate',
      apiUrl: _kPrivateApiFunctionName + 'drivers',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        if ((ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class DriverUpdateCall {
  static Future<ApiCallResponse> call({
    required int id,
    required Map<String, dynamic> body,
  }) {
    final b = Map<String, dynamic>.from(body)..['id'] = id;
    return ApiManager.instance.makeApiCall(
      callName: 'DriverUpdate',
      apiUrl: _kPrivateApiFunctionName + 'drivers/$id',
      callType: ApiCallType.PUT,
      headers: {
        'Accept': 'application/json',
        if ((ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(b),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class DriverGetCall {
  static Future<ApiCallResponse> call({
    required int id,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'DriverGet',
      apiUrl: _kPrivateApiFunctionName + 'drivers/$id',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static int? id(ApiCallResponse r) => getJsonField(r.jsonBody, r'$.id');
  static String? fullName(ApiCallResponse r) =>
      getJsonField(r.jsonBody, r'$.fullName')?.toString();
  static String? email(ApiCallResponse r) =>
      getJsonField(r.jsonBody, r'$.email')?.toString();
  static String? phone(ApiCallResponse r) =>
      getJsonField(r.jsonBody, r'$.phoneNumber')?.toString();
  static String? phone2(ApiCallResponse r) =>
      getJsonField(r.jsonBody, r'$.phoneNumber2')?.toString();
  static String? rg(ApiCallResponse r) =>
      getJsonField(r.jsonBody, r'$.rG')?.toString() ??
          getJsonField(r.jsonBody, r'$.rg')?.toString();
  static bool active(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.active') as bool?) ?? true;
  static bool english(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.english') as bool?) ?? false;
  static bool japanese(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.japanese') as bool?) ?? false;
  static bool presidence(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.presidenceDriver') as bool?) ?? false;
  static bool backup(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.backupDriver') as bool?) ?? false;
  static int? companyId(ApiCallResponse r) =>
      getJsonField(r.jsonBody, r'$.companyId');
  static String? companyName(ApiCallResponse r) =>
      getJsonField(r.jsonBody, r'$.company.fullName')?.toString();
  static String? companyEmail(ApiCallResponse r) =>
      getJsonField(r.jsonBody, r'$.company.email')?.toString();
  static String? base64Photo(ApiCallResponse r) =>
      getJsonField(r.jsonBody, r'$.base64DriverProfilePicture')?.toString();
}

// =================== RENTAL STORES ===================
class RentalStoresListCall {
  static Future<ApiCallResponse> call([String? bearerToken]) {
    return ApiManager.instance.makeApiCall(
      callName: 'RentalStoresList',
      apiUrl: _kPrivateApiFunctionName + 'rentalstores/index',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static List<dynamic> items(ApiCallResponse res) {
    final body = res.jsonBody;
    if (body is List) return body;
    final fromItems = getJsonField(body, r'$.items');
    if (fromItems is List) return fromItems;
    return const [];
  }

  static int? id(dynamic item) {
    final raw =
        getJsonField(item, r'$.id') ?? getJsonField(item, r'$.companyId');
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  static String? name(dynamic item) {
    return getJsonField(item, r'$.fullName')?.toString() ??
        getJsonField(item, r'$.name')?.toString() ??
        getJsonField(item, r'$.company.fullName')?.toString();
  }

  static String? email(dynamic item) {
    return getJsonField(item, r'$.email')?.toString() ??
        getJsonField(item, r'$.company.email')?.toString();
  }

  static List<Map<String, dynamic>> companies(ApiCallResponse res) {
    final list = items(res);
    final seen = <int>{};
    final out = <Map<String, dynamic>>[];
    for (final it in list) {
      final i = id(it);
      final n = (name(it) ?? '').trim();
      if (i == null || n.isEmpty) continue;
      if (seen.add(i)) {
        out.add({'id': i, 'name': n, 'email': email(it)});
      }
    }
    return out;
  }
}

class DriversFavorCarCall {
  static Future<ApiCallResponse> call({
    required int driverId,
    required int carId,
    required bool isFavorite,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'DriversFavorCar',
      apiUrl: _kPrivateApiFunctionName + 'drivers/favorcar',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
        'Content-Type': 'application/json',
      },
      params: const {},
      body: jsonEncode({
        'driverId': driverId,
        'carId': carId,
        'isFavorite': isFavorite,
      }),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

// === FAVORITE CARS (MVC) ===
class DriversGetFavoriteCarsCall {
  static Future<ApiCallResponse> call({
    required int driverId,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'DriversGetFavoriteCars',
      apiUrl: _kPrivateApiFunctionName + 'Drivers/GetFavoriteCars/$driverId',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static List<dynamic> items(ApiCallResponse res) {
    final body = res.jsonBody;
    if (body is List) return body;
    final fromItems = getJsonField(body, r'$.items');
    if (fromItems is List) return fromItems;
    return const [];
  }

  static int? id(dynamic it) => getJsonField(it, r'$.id');
  static String? description(dynamic it) =>
      getJsonField(it, r'$.description')?.toString();
  static int? km(dynamic it) => getJsonField(it, r'$.km');
  static String? plate(dynamic it) =>
      getJsonField(it, r'$.licensePlate')?.toString();
  static String? color(dynamic it) =>
      getJsonField(it, r'$.carColorDto.color')?.toString();
  static bool isFavorite(dynamic it) =>
      (getJsonField(it, r'$.isFavoriteCar') as bool?) ?? false;

  static int? curStatus(dynamic it) => getJsonField(it, r'$.curStatus');
  static bool available(dynamic it) {
    final cs = curStatus(it);
    return cs == 1 || cs?.toString().toLowerCase() == 'available';
  }

  static bool presidence(dynamic it) =>
      (getJsonField(it, r'$.presidenceCar') as bool?) ?? false;
}

// =================== DRIVER CALENDAR (Presidence) ===================
class DriversGetEventsPresidenceCall {
  static Future<ApiCallResponse> call({
    required int driverId,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'DriversGetEventsPresidence',
      apiUrl:
      _kPrivateApiFunctionName + 'drivers/geteventspresidence/$driverId',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }

  static List items(ApiCallResponse r) {
    final b = r.jsonBody;
    final data = getJsonField(b, r'$.data');
    if (data is List) return data;
    if (b is List) return b;
    return const [];
  }

  static int? id(dynamic e) => getJsonField(e, r'$.id');
  static String? title(dynamic e) => getJsonField(e, r'$.title')?.toString();
  static String? start(dynamic e) => getJsonField(e, r'$.start')?.toString();
  static String? end(dynamic e) => getJsonField(e, r'$.end')?.toString();
  static String? color(dynamic e) =>
      getJsonField(e, r'$.eventColor')?.toString();
  static bool allDay(dynamic e) =>
      (getJsonField(e, r'$.isFullDay') as bool?) ?? true;
}

class DriversSaveEventPresidenceCall {
  static Future<ApiCallResponse> call({
    required int driverId,
    required DateTime start,
    required DateTime end,
    String title = 'Presidence',
    String eventColor = 'green',
    String? bearerToken,
  }) {
    final body = {
      'id': 0,
      'title': title,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'driverId': driverId,
      'isFullDay': true,
      'eventColor': eventColor,
    };
    return ApiManager.instance.makeApiCall(
      callName: 'DriversSaveEventPresidence',
      apiUrl: _kPrivateApiFunctionName + 'drivers/saveeventpresidence',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }

  static bool status(ApiCallResponse r) =>
      (getJsonField(r.jsonBody, r'$.status') as bool?) ?? false;
  static String? returnEvent(ApiCallResponse r) =>
      getJsonField(r.jsonBody, r'$.returnEvent')?.toString();
}

class DriversDeleteEventPresidenceCall {
  static Future<ApiCallResponse> call({
    required int id,
    String? bearerToken,
  }) async {
    final headers = {
      'Accept': 'application/json',
      if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
        'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
    };

    final urlPath =
        '${_kPrivateApiFunctionName}drivers/deleteeventpresidence/$id';
    var res = await ApiManager.instance.makeApiCall(
      callName: 'DriversDeleteEventPresidence(DELETE path)',
      apiUrl: urlPath,
      callType: ApiCallType.DELETE,
      headers: headers,
      params: const {},
      body: null,
      returnBody: true,
      cache: false,
    );
    if (res.succeeded) return res;

    final urlQuery =
        '${_kPrivateApiFunctionName}drivers/deleteeventpresidence';
    res = await ApiManager.instance.makeApiCall(
      callName: 'DriversDeleteEventPresidence(DELETE query)',
      apiUrl: urlQuery,
      callType: ApiCallType.DELETE,
      headers: headers,
      params: {'id': id},
      body: null,
      returnBody: true,
      cache: false,
    );

    return res;
  }
}

// =================== CARS ===================
class CarsListCall {
  static Future<ApiCallResponse> call({
    String? bearerToken,
    int page = 1,
    int pageSize = 5,
  }) {
    final path = 'cars/index/app?pageSize=$pageSize&page=$page';
    return ApiManager.instance.makeApiCall(
      callName: 'CarsList',
      apiUrl: _kPrivateApiFunctionName + path,
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static List<dynamic> items(ApiCallResponse res) {
    final body = res.jsonBody;
    if (body is List) return body;
    final fromItems = getJsonField(body, r'$.items');
    if (fromItems is List) return fromItems;
    return const [];
  }

  static int? id(dynamic item) => getJsonField(item, r'$.id');
  static String? description(dynamic item) =>
      getJsonField(item, r'$.description')?.toString();
  static String? model(dynamic item) => description(item);
  static int? km(dynamic item) => getJsonField(item, r'$.km');
  static String? licensePlate(dynamic item) =>
      getJsonField(item, r'$.licensePlate')?.toString();

  static String? colorName(dynamic item) =>
      getJsonField(item, r'$.carColorDto.color')?.toString();

  static String? colorId(dynamic item) =>
      getJsonField(item, r'$.carColorDto.id')?.toString();

  static int? curStatus(dynamic item) => getJsonField(item, r'$.curStatus');

  static bool available(dynamic item) {
    final cs = curStatus(item);
    return cs == 1 || cs?.toString().toLowerCase() == 'available';
  }

  static bool presidence(dynamic item) =>
      (getJsonField(item, r'$.presidenceCar') as bool?) ??
          (getJsonField(item, r'$.isPresidence') as bool?) ??
          false;
}

class CarsDeleteCall {
  static Future<ApiCallResponse> call({
    required int id,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'CarsDelete',
      apiUrl: _kPrivateApiFunctionName + 'cars/$id',
      callType: ApiCallType.DELETE,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// PUT /api/cars/{id}
class CarsUpdateCall {
  static Future<ApiCallResponse> call({
    required int id,
    required String description,
    required int km,
    required String licensePlate,
    required bool active,
    required bool presidenceCar,
    String? carColorId,
    String? carColor,
  }) {
    final bodyMap = <String, dynamic>{
      'id': id,
      'description': description,
      'km': km,
      'licensePlate': licensePlate,
      'active': active,
      'presidenceCar': presidenceCar,
      if (carColorId != null) 'carColorId': carColorId,
      if (carColorId != null || carColor != null)
        'carColorDto': {
          if (carColorId != null) 'id': carColorId,
          if (carColor != null) 'color': carColor,
        },
    };

    return ApiManager.instance.makeApiCall(
      callName: 'CarsUpdate',
      apiUrl: _kPrivateApiFunctionName + 'cars/$id',
      callType: ApiCallType.PUT,
      headers: {
        'Accept': 'application/json',
        if ((ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(bodyMap),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

// GET /api/cars/getcarcolors
class CarsColorsCall {
  static Future<ApiCallResponse> call() {
    return ApiManager.instance.makeApiCall(
      callName: 'CarsColors',
      apiUrl: _kPrivateApiFunctionName + 'cars/getcarcolors',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static List<dynamic> items(ApiCallResponse res) {
    final body = res.jsonBody;
    if (body is List) return body;
    return const [];
  }

  static String? id(dynamic item) => getJsonField(item, r'$.id')?.toString();
  static String? color(dynamic item) =>
      getJsonField(item, r'$.color')?.toString();
  static String? textColor(dynamic item) =>
      getJsonField(item, r'$.textColor')?.toString();
}

// POST /api/cars
class CarCreateCall {
  static Future<ApiCallResponse> call({required Map<String, dynamic> body}) {
    final fullBody = Map<String, dynamic>.from(body);
    final colorId = body['carColorId']?.toString();
    if (colorId != null && (body['carColorDto'] == null)) {
      fullBody['carColorDto'] = {'id': colorId};
    }

    return ApiManager.instance.makeApiCall(
      callName: 'CarCreate',
      apiUrl: _kPrivateApiFunctionName + 'cars',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        if ((ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(fullBody),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

// PUT /api/cars/{id}
class CarUpdateCall {
  static Future<ApiCallResponse> call({
    required int id,
    required Map<String, dynamic> body,
  }) {
    final fullBody = Map<String, dynamic>.from(body);
    fullBody['id'] = id;
    final colorId = body['carColorId']?.toString();
    if (colorId != null && (body['carColorDto'] == null)) {
      fullBody['carColorDto'] = {'id': colorId};
    }

    return ApiManager.instance.makeApiCall(
      callName: 'CarUpdate',
      apiUrl: _kPrivateApiFunctionName + 'cars/$id',
      callType: ApiCallType.PUT,
      headers: {
        'Accept': 'application/json',
        if ((ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(fullBody),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

// =================== (NOVO) WIZARD: CREATE / UPDATE e BUSCAS ===================
// CREATE
class CarRequestsCreateCall {
  static Future<ApiCallResponse> call({
    required Map<String, dynamic> body,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsCreate',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }
}

// UPDATE
class CarRequestsUpdateCall {
  static Future<ApiCallResponse> call({
    required int id,
    required Map<String, dynamic> body,
    String? bearerToken,
  }) {
    final b = Map<String, dynamic>.from(body)..['id'] = id;
    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsUpdate',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests/$id',
      callType: ApiCallType.PUT,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(b),
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }
}

// =================== REQUEST: GET ONE ===================
class CarRequestsGetCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required String id,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsGet',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests/$id',
      callType: ApiCallType.GET,
      headers: {'Authorization': 'Bearer $bearerToken'},
      returnBody: true,
    );
  }

  static dynamic _b(dynamic r) => (r is ApiCallResponse) ? r.jsonBody : r;
  static String _s(dynamic v) => v?.toString() ?? '';

  static String _firstNonEmpty(List<String> opts) =>
      opts.firstWhere((s) => s.trim().isNotEmpty, orElse: () => '');

  static String? _firstNonEmptyNullable(List<String> opts) {
    final s = _firstNonEmpty(opts);
    return s.isEmpty ? null : s;
  }

  static String? id(dynamic r) => _s(getJsonField(_b(r), r'$.id')).isEmpty
      ? null
      : _s(getJsonField(_b(r), r'$.id'));

  static String? userName(dynamic r) => _firstNonEmptyNullable([
    _s(getJsonField(_b(r), r'$.userDto.fullName')),
    _s(getJsonField(_b(r), r'$.user.fullName')),
    _s(getJsonField(_b(r), r'$.requirerDto.fullName')),
  ]);

  static DateTime? startAt(dynamic r) {
    final s = _firstNonEmpty([
      _s(getJsonField(_b(r), r'$.startDateTime')),
      _s(getJsonField(_b(r), r'$.start')),
      _s(getJsonField(_b(r), r'$.periodFrom')),
    ]);
    return s.isEmpty ? null : DateTime.tryParse(s)?.toLocal();
  }

  static DateTime? endAt(dynamic r) {
    final s = _firstNonEmpty([
      _s(getJsonField(_b(r), r'$.endDateTime')),
      _s(getJsonField(_b(r), r'$.end')),
      _s(getJsonField(_b(r), r'$.periodTo')),
    ]);
    return s.isEmpty ? null : DateTime.tryParse(s)?.toLocal();
  }

  static String? driver(dynamic r) => _firstNonEmptyNullable([
    _s(getJsonField(_b(r), r'$.driverDto.fullName')),
    _s(getJsonField(_b(r), r'$.driver.fullName')),
  ]);

  static String? model(dynamic r) => _firstNonEmptyNullable([
    _s(getJsonField(_b(r), r'$.carDto.description')),
    _s(getJsonField(_b(r), r'$.car.description')),
    _s(getJsonField(_b(r), r'$.car.model')),
  ]);

  static String? license(dynamic r) => _firstNonEmptyNullable([
    _s(getJsonField(_b(r), r'$.carDto.licensePlate')),
    _s(getJsonField(_b(r), r'$.car.licensePlate')),
    _s(getJsonField(_b(r), r'$.licensePlate')),
  ]);

  static bool childSeat(dynamic r) =>
      (getJsonField(_b(r), r'$.childSeat') as bool?) ?? false;

  static bool hadIncident(dynamic r) {
    final v = getJsonField(_b(r), r'$.trafficIncidentId');
    if (v is num) return v != 0;
    if (v is String) return (int.tryParse(v) ?? 0) != 0;
    return (getJsonField(_b(r), r'$.hadIncident') as bool?) ?? false;
  }

  static String? departure(dynamic r) => _firstNonEmptyNullable([
    _s(getJsonField(_b(r), r'$.departure')),
    _s(getJsonField(_b(r), r'$.sourceAddress')),
    _s(getJsonField(_b(r), r'$.startAddress')),
    _s(getJsonField(_b(r), r'$.fromAddress')),
  ]);

  static List<String> destinations(dynamic r) {
    final list = getJsonField(_b(r), r'$.carRequestDests');
    if (list is List) {
      return list
          .map((e) => _firstNonEmpty([
        _s(getJsonField(e, r'$.address')),
        _s(getJsonField(e, r'$.destAddress')),
        _s(getJsonField(e, r'$.formattedAddress')),
        _s(getJsonField(e, r'$.routeDestination')),
      ]))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final simple = getJsonField(_b(r), r'$.destinations');
    if (simple is List) return simple.map((e) => _s(e)).toList();
    return const [];
  }

  static String? notes(dynamic r) => _firstNonEmptyNullable([
    _s(getJsonField(_b(r), r'$.notes')),
    _s(getJsonField(_b(r), r'$.note')),
    _s(getJsonField(_b(r), r'$.description')),
  ]);

  static bool bookNow(dynamic r) =>
      (getJsonField(_b(r), r'$.bookNow') as bool?) ?? false;

  static int? driverId(dynamic r) =>
      (getJsonField(_b(r), r'$.driverId') as num?)?.toInt();

  static int? carId(dynamic r) =>
      (getJsonField(_b(r), r'$.carId') as num?)?.toInt();

  static String? confirmationId(dynamic r) =>
      _s(getJsonField(_b(r), r'$.confirmationId')).isEmpty
          ? null
          : _s(getJsonField(_b(r), r'$.confirmationId'));

  static List<int> passengersIds(dynamic r) {
    final list = getJsonField(_b(r), r'$.passengersId');
    if (list is List) {
      return list
          .map((e) {
        if (e is num) return e.toInt();
        return int.tryParse(_s(e)) ?? 0;
      })
          .where((n) => n != 0)
          .toList();
    }
    return const [];
  }

  static String? passengersCsv(dynamic r) {
    final s = _s(getJsonField(_b(r), r'$.passengersCsv'));
    return s.isEmpty ? null : s;
  }

  static String? specialCarInfo(dynamic r) => _firstNonEmptyNullable([
    _s(getJsonField(_b(r), r'$.specialCarInfo')),
    _s(getJsonField(_b(r), r'$.carDto.specialCarInfo')),
    _s(getJsonField(_b(r), r'$.car.specialCarInfo')),
    _s(getJsonField(_b(r), r'$.carRequest.specialCarInfo')),
  ]);

}


class CarRequestsFinishCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required String id,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsFinish',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests/Finish/$id',
      callType: ApiCallType.POST,
      headers: {'Authorization': 'Bearer $bearerToken'},
      returnBody: true,
    );
  }
}

class CarRequestsDeleteCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required String id,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsDelete',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests/$id',
      callType: ApiCallType.DELETE,
      headers: {'Authorization': 'Bearer $bearerToken'},
      returnBody: true,
    );
  }
}

// ============== DRIVER LIST (paged) ==============
class DriverRequestsPagedCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required int page,
    required int pageSize,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'DriverRequestsPaged',
      apiUrl: _kPrivateApiFunctionName + 'requests',
      callType: ApiCallType.GET,
      headers: {'Authorization': 'Bearer $bearerToken'},
      params: {'page': page, 'pageSize': pageSize},
      returnBody: true,
    );
  }

  static List<dynamic> items(ApiCallResponse res) =>
      (getJsonField(res.jsonBody, r'$.items') as List?) ??
          (getJsonField(res.jsonBody, r'$') as List?) ??
          const [];

  static bool hasNext(ApiCallResponse res) =>
      (getJsonField(res.jsonBody, r'$.hasNext') as bool?) ??
          (getJsonField(res.jsonBody, r'$.hasMore') as bool?) ??
          false;

  static String? id(dynamic d) => CarRequestsListCall.id(d);
  static DateTime? startAt(dynamic d) => CarRequestsListCall.startAt(d);
  static DateTime? endAt(dynamic d) => CarRequestsListCall.endAt(d);
  static String? userName(dynamic d) => CarRequestsListCall.userName(d);
  static String? driverName(dynamic d) => CarRequestsListCall.driverName(d);
  static String? model(dynamic d) => CarRequestsListCall.model(d);
  static String? licensePlate(dynamic d) => CarRequestsListCall.licensePlate(d);
  static bool childSeat(dynamic d) => CarRequestsListCall.childSeat(d);
  static String? notes(dynamic d) => CarRequestsListCall.notes(d);
  static String? departure(dynamic d) => CarRequestsListCall.departure(d);
  static List<String> destinations(dynamic d) =>
      CarRequestsListCall.destinations(d);
  static DetailedCarRequestStatus detailedStatus(dynamic d) =>
      CarRequestsListCall.detailedStatus(d);

}

class DriverImHereCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required int id,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'DriverImHere',
      apiUrl: '${_kPrivateApiFunctionName}CarRequests/DriverHasArrived/$id',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Accept': 'application/json',
      },
      returnBody: true,
    );
  }
}

class DriverStartCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required int id,
    required int startKm,
  }) {
    final body = jsonEncode({
      'Id': id,
      'id': id,
      'StartKm': startKm,
      'startKm': startKm,
    });

    return ApiManager.instance.makeApiCall(
      callName: 'DriverStart',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests/Start',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
    );
  }
}

// Finish trip (start, end, hadIncident)
class DriverFinishCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required String id,
    required DateTime start,
    required DateTime end,
    required bool hadIncident,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'DriverFinish',
      apiUrl: _kPrivateApiFunctionName + 'driver/requests/$id/finish',
      callType: ApiCallType.PUT,
      headers: {'Authorization': 'Bearer $bearerToken'},
      body: jsonEncode({
        'startDateTime': start.toUtc().toIso8601String(),
        'endDateTime': end.toUtc().toIso8601String(),
        'hadIncident': hadIncident,
      }),
      bodyType: BodyType.JSON,
      returnBody: true,
    );
  }

}

// Final KM
  class DriverFinalKmCall {
    static Future<ApiCallResponse> call({
      required String bearerToken,
      required String id,
      required int finalKm,
    }) {
      return ApiManager.instance.makeApiCall(
        callName: 'DriverFinalKm',
        apiUrl: _kPrivateApiFunctionName + 'driver/requests/$id/final-km',
        callType: ApiCallType.PUT,
        headers: {'Authorization': 'Bearer $bearerToken'},
        body: jsonEncode({'finalKm': finalKm}),
        bodyType: BodyType.JSON,
        returnBody: true,
      );
    }
  }

// === FAVORITE PLACES (por usuário) =====================

// GET /api/CarRequests/GetFavoritePlaces/{userId}
class FavoritePlacesByUserCall {
  static Future<ApiCallResponse> call({
    required int userId,
    String? bearerToken,
  }) {
    final path = 'Users/GetFavoritePlaces/$userId';
    return ApiManager.instance.makeApiCall(
      callName: 'FavoritePlacesByUser',
      apiUrl: _kPrivateApiFunctionName + path,
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }

  static List<Map<String, String>> items(ApiCallResponse r) {
    final b = r.jsonBody;
    final list = (b is List)
        ? b
        : (getJsonField(b, r'$.items') as List? ?? const []);
    final out = <Map<String, String>>[];
    for (final it in list) {
      if (it is Map) {
        final name = (getJsonField(it, r'$.placeName') ?? '').toString();
        final addr = (getJsonField(it, r'$.address') ?? '').toString();
        if (addr.trim().isNotEmpty) {
          out.add({'placeName': name, 'address': addr});
        }
      } else if (it != null) {
        final s = it.toString();
        if (s.trim().isNotEmpty) out.add({'placeName': '', 'address': s});
      }
    }
    return out;
  }
}

// POST /api/CarRequests/AutocompleteFavoritePlaces
class AutocompleteFavoritePlacesCall {
  static Future<ApiCallResponse> call({
    required String term,
    required int userId,
    String? bearerToken,
  }) {
      final path = 'Users/AutocompleteFavoritePlaces';
    final body = jsonEncode({'term': term, 'userId': userId});
    return ApiManager.instance.makeApiCall(
      callName: 'AutocompleteFavoritePlaces',
      apiUrl: _kPrivateApiFunctionName + path,
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }

  static List<Map<String, String>> items(ApiCallResponse r) {
    final b = r.jsonBody;
    final list = (b is List)
        ? b
        : (getJsonField(b, r'$') as List? ?? const []);
    final out = <Map<String, String>>[];
    for (final it in list) {
      final name = (getJsonField(it, r'$.placeName') ?? '').toString();
      final addr = (getJsonField(it, r'$.address') ?? '').toString();
      if (addr.trim().isNotEmpty) {
        out.add({'placeName': name, 'address': addr});
      }
    }
    return out;
  }
}

class TrafficIncidentByCarRequestCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required int carRequestId,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'TrafficIncidentByCarRequest',
      apiUrl: _kPrivateApiFunctionName + 'TrafficIncident/GetByCarRequest',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Accept': 'application/json',
      },
      params: {'carRequestId': carRequestId},
      returnBody: true,
    );
  }

  // ---------------- helpers ----------------
  static dynamic _j(ApiCallResponse r) => r.jsonBody;
  static String _s(dynamic v) => v?.toString() ?? '';

  static DateTime? _tryParseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toLocal();
    if (v is num) {
      final iv = v.toInt();
      if (iv > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(iv, isUtc: true).toLocal();
      }
      if (iv > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(iv * 1000, isUtc: true).toLocal();
      }
    }
    final s = _s(v).trim();
    if (s.isEmpty) return null;
    final ms = RegExp(r'\/Date\((\d+)\)\/').firstMatch(s);
    if (ms != null) {
      final n = int.tryParse(ms.group(1)!);
      if (n != null) {
        return DateTime.fromMillisecondsSinceEpoch(n, isUtc: true).toLocal();
      }
    }
    return DateTime.tryParse(s)?.toLocal();
  }

  static int? id(ApiCallResponse r)                 => getJsonField(_j(r), r'$.id');
  static int? carRequestId(ApiCallResponse r)       => getJsonField(_j(r), r'$.carRequestId');

  static String? driverName(ApiCallResponse r)      =>
      getJsonField(_j(r), r'$.driverDto.fullName');

  static String? incidentLocation(ApiCallResponse r)=>
      getJsonField(_j(r), r'$.incidentLocation');

  static String? incidentSummary(ApiCallResponse r) =>
      getJsonField(_j(r), r'$.incidentBriefSummary');

  static bool hadInjuries(ApiCallResponse r)        =>
      (getJsonField(_j(r), r'$.isInjuries') ?? false) as bool;

  static String? injuriesDetails(ApiCallResponse r) =>
      getJsonField(_j(r), r'$.injuriesDetails');

  static String? damagePlate(ApiCallResponse r)     =>
      getJsonField(_j(r), r'$.carDamagePlate');

  static String? damageSummary(ApiCallResponse r)   =>
      getJsonField(_j(r), r'$.carDamageBriefSummary');

  static DateTime? creationAt(ApiCallResponse r)    =>
      _tryParseDate(getJsonField(_j(r), r'$.creationDateTime'));

  static DateTime? incidentAt(ApiCallResponse r)    =>
      _tryParseDate(getJsonField(_j(r), r'$.incidentDateTime'));

  static String? requestPlate(ApiCallResponse r) {
    final root = _j(r);
    final v = getJsonField(root, r'$.carRequestDto.carDto.licensePlate') ??
        getJsonField(root, r'$.carRequest.licensePlate') ??
        getJsonField(root, r'$.carRequest.carDto.licensePlate');
    final s = _s(v).trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? requestRealStart(ApiCallResponse r) {
    final root = _j(r);
    final v = getJsonField(root, r'$.carRequestDto.realStartDateTime') ??
        getJsonField(root, r'$.carRequest.realStartDateTime');
    return _tryParseDate(v);
  }

  static List<String> passengers(ApiCallResponse r) {
    final root = _j(r);
    final acc = <String>{};

    final paxMap = getJsonField(root, r'$.passengers');
    if (paxMap is Map) {
      for (final v in paxMap.values) {
        final name = _s(v).trim();
        if (name.isNotEmpty) acc.add(name);
      }
    }

    final paxMapAlt = getJsonField(root, r'$.passengerNames') ??
        getJsonField(root, r'$.passengersNames') ??
        getJsonField(root, r'$.PassengerNames');
    if (paxMapAlt is Map) {
      for (final v in paxMapAlt.values) {
        final name = _s(v).trim();
        if (name.isNotEmpty) acc.add(name);
      }
    }

    final paxList = getJsonField(root, r'$.passengers');
    if (paxList is List) {
      for (final e in paxList) {
        String name = '';
        if (e is String) {
          name = e;
        } else {
          name = [
            _s(getJsonField(e, r'$.fullName')),
            _s(getJsonField(e, r'$.name')),
            _s(getJsonField(e, r'$.value')),
            _s(getJsonField(e, r'$.text')),
          ].firstWhere((s) => s.trim().isNotEmpty, orElse: () => '');
        }
        if (name.trim().isNotEmpty) acc.add(name.trim());
      }
    }

    final tip = getJsonField(root, r'$.trafficIncidentPassengersDto') ??
        getJsonField(root, r'$.trafficIncidentPassengers');
    if (tip is List) {
      for (final e in tip) {
        final name = [
          _s(getJsonField(e, r'$.userDto.fullName')),
          _s(getJsonField(e, r'$.passenger.fullName')),
          _s(getJsonField(e, r'$.fullName')),
          _s(getJsonField(e, r'$.name')),
        ].firstWhere((s) => s.trim().isNotEmpty, orElse: () => '');
        if (name.trim().isNotEmpty) acc.add(name.trim());
      }
    }

    return acc.toList();
  }

  static List<String> otherPassengers(ApiCallResponse r) {
    final root = _j(r);
    final p1 = _s(getJsonField(root, r'$.passanger1')).trim();
    final p2 = _s(getJsonField(root, r'$.passanger2')).trim();
    final p3 = _s(getJsonField(root, r'$.passanger3')).trim();
    return [p1, p2, p3].where((s) => s.isNotEmpty).toList();
  }

  static List<Map<String, dynamic>> photos(ApiCallResponse r) {
    final root = _j(r);

    dynamic src = getJsonField(root, r'$.trafficIncidentPhotosDto');
    src ??= getJsonField(root, r'$.imagesFromDataBase');
    src ??= getJsonField(root, r'$.trafficIncidentPhotos');
    src ??= getJsonField(root, r'$.trafficIncidentPhotosBase64');

    if (src is! List) return const [];

    return src.map<Map<String, dynamic>>((e) {
      // filename
      final fileName = (_s(getJsonField(e, r'$.fileName')).trim().isNotEmpty)
          ? _s(getJsonField(e, r'$.fileName'))
          : _s(getJsonField(e, r'$.name'));

      // extension
      final extension = (_s(getJsonField(e, r'$.extension')).trim().isNotEmpty)
          ? _s(getJsonField(e, r'$.extension'))
          : _s(getJsonField(e, r'$.Extension'));

      // base64
      String base64 =
      _s(getJsonField(e, r'$.base64Content')).trim();
      if (base64.isEmpty) base64 = _s(getJsonField(e, r'$.base64content')).trim();
      if (base64.isEmpty) base64 = _s(getJsonField(e, r'$.base64')).trim();
      if (base64.isEmpty) base64 = _s(getJsonField(e, r'$.Base64')).trim();
      if (base64.isEmpty) base64 = _s(getJsonField(e, r'$.content')).trim();

      return {
        'fileName': fileName,
        'extension': extension,
        'base64': base64,
      };
    }).where((m) => (m['base64'] as String).trim().isNotEmpty).toList();
  }
}

// POST /api/CarRequests/FinishPeriod
class CarRequestsFinishPeriodCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required String id,
    required DateTime realStart,
    required DateTime realEnd,
  }) {
    final payload = jsonEncode({
      'id': int.tryParse(id) ?? id,
      'realStartDateTime': realStart.toUtc().toIso8601String(),
      'realEndDateTime': realEnd.toUtc().toIso8601String(),
    });

    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsFinishPeriod',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests/FinishPeriod',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
      bodyType: BodyType.JSON,
      body: payload,
      returnBody: true,
    );
  }
}

class CarRequestsDetailsCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required String id,
  }) {
    final url = '$_kPrivateApiFunctionName'
        'CarRequests/$id';

    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsDetails',
      apiUrl: url,
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      },
      params: const {},
      returnBody: true,
      cache: false,
    );
  }

  // ----------------- helpers -----------------
  static dynamic _b(dynamic r) => (r is ApiCallResponse) ? r.jsonBody : r;
  static String _s(dynamic v) => v?.toString() ?? '';

  static DateTime? _dt(dynamic v) {
    final s = _s(v).trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s)?.toLocal();
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  // ----------------- campos principais -----------------
  static String? id(dynamic r) {
    final s = _s(getJsonField(_b(r), r'$.id'));
    return s.isEmpty ? null : s;
  }

  static String? userName(dynamic r) {
    final v = getJsonField(_b(r), r'$.userDto.fullName') ??
        getJsonField(_b(r), r'$.user.fullName') ??
        getJsonField(_b(r), r'$.requirerDto.fullName');
    final s = _s(v).trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? startAt(dynamic r) => _dt(
    getJsonField(_b(r), r'$.startDateTime') ??
        getJsonField(_b(r), r'$.start') ??
        getJsonField(_b(r), r'$.periodFrom'),
  );

  static DateTime? endAt(dynamic r) => _dt(
    getJsonField(_b(r), r'$.endDateTime') ??
        getJsonField(_b(r), r'$.end') ??
        getJsonField(_b(r), r'$.periodTo'),
  );

  // Período REAL (Finished)
  static DateTime? realStart(dynamic r) => _dt(
    getJsonField(_b(r), r'$.realStartDateTime') ??
        getJsonField(_b(r), r'$.realStart') ??
        getJsonField(_b(r), r'$.reportStart') ??
        getJsonField(_b(r), r'$.startedAt'),
  );

  static DateTime? realEnd(dynamic r) => _dt(
    getJsonField(_b(r), r'$.realEndDateTime') ??
        getJsonField(_b(r), r'$.realEnd') ??
        getJsonField(_b(r), r'$.reportEnd') ??
        getJsonField(_b(r), r'$.endedAt'),
  );

  static int? startKm(dynamic r) =>
      (getJsonField(_b(r), r'$.startKm') as num?)?.toInt();

  static int? endKm(dynamic r) =>
      (getJsonField(_b(r), r'$.endKm') as num?)?.toInt();

  static int? requestStatusCode(dynamic r) {
    final v = getJsonField(_b(r), r'$.curStatus') ??
        getJsonField(_b(r), r'$.requestStatus') ??
        getJsonField(_b(r), r'$.status') ??
        getJsonField(_b(r), r'$.carRequest.curStatus');
    return _toInt(v);
  }

  static int? curStatus(dynamic r) => requestStatusCode(r);

  static int? curStatusCar(dynamic r) {
    final v = getJsonField(_b(r), r'$.carDto.curStatus') ??
        getJsonField(_b(r), r'$.car.curStatus');
    return _toInt(v);
  }

  static String? cancelReason(dynamic r) {
    final s = _s(getJsonField(_b(r), r'$.cancelReason')).trim();
    return s.isEmpty ? null : s;
  }

  static String? disacordReason(dynamic r) {
    final s = _s(getJsonField(_b(r), r'$.disacordReason')).trim();
    return s.isEmpty ? null : s;
  }

  static String? confirmationId(dynamic r) {
    final s = _s(getJsonField(_b(r), r'$.confirmationId')).trim();
    return s.isEmpty ? null : s;
  }

  static String? driver(dynamic r) {
    final v = getJsonField(_b(r), r'$.driverDto.fullName') ??
        getJsonField(_b(r), r'$.driver.fullName');
    final s = _s(v).trim();
    return s.isEmpty ? null : s;
  }

  static String? company(dynamic r) {
    final b = _b(r);
    final v =
    getJsonField(b, r'$.driverDto.company.fullName') ??
        getJsonField(b, r'$.driverDto.Company.FullName') ??
        getJsonField(b, r'$.driver.company.fullName') ??
        getJsonField(b, r'$.userDto.company.fullName') ??
        getJsonField(b, r'$.companyDto.fullName') ??
        getJsonField(b, r'$.company.fullName') ??
        getJsonField(b, r'$.companyName');

    final s = _s(v).trim();
    return s.isEmpty ? null : s;
  }

  static String? model(dynamic r) {
    final v = getJsonField(_b(r), r'$.carDto.description') ??
        getJsonField(_b(r), r'$.car.description') ??
        getJsonField(_b(r), r'$.car.model');
    final s = _s(v).trim();
    return s.isEmpty ? null : s;
  }

  static String? license(dynamic r) {
    final v = getJsonField(_b(r), r'$.carDto.licensePlate') ??
        getJsonField(_b(r), r'$.car.licensePlate') ??
        getJsonField(_b(r), r'$.licensePlate');
    final s = _s(v).trim();
    return s.isEmpty ? null : s;
  }

  static bool childSeat(dynamic r) =>
      (getJsonField(_b(r), r'$.childSeat') as bool?) ?? false;

  static bool hadIncident(dynamic r) {
    final v = getJsonField(_b(r), r'$.trafficIncidentId');
    if (v is num) return v != 0;
    if (v is String) return (int.tryParse(v) ?? 0) != 0;
    return (getJsonField(_b(r), r'$.hadIncident') as bool?) ?? false;
  }

  static String? departure(dynamic r) {
    final s = _s(
      getJsonField(_b(r), r'$.sourceAddress') ??
          getJsonField(_b(r), r'$.departure') ??
          getJsonField(_b(r), r'$.routeDeparture') ??
          getJsonField(_b(r), r'$.startAddress') ??
          getJsonField(_b(r), r'$.fromAddress'),
    ).trim();
    return s.isEmpty ? null : s;
  }

  static List<String> destinations(dynamic r) {
    final list = getJsonField(_b(r), r'$.carRequestDests');
    if (list is List) {
      return list
          .map((e) => [
        _s(getJsonField(e, r'$.destAddress')),
        _s(getJsonField(e, r'$.address')),
        _s(getJsonField(e, r'$.formattedAddress')),
        _s(getJsonField(e, r'$.routeDestination')),
      ].join().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final simple = getJsonField(_b(r), r'$.destinations');
    if (simple is List) {
      return simple
          .map((e) => _s(e).trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  static String? notes(dynamic r) {
    final s = _s(
      getJsonField(_b(r), r'$.note') ??
          getJsonField(_b(r), r'$.notes') ??
          getJsonField(_b(r), r'$.description'),
    ).trim();
    return s.isEmpty ? null : s;
  }

  static String? passengersCsv(dynamic r) {
    final s = _s(getJsonField(_b(r), r'$.passengersCsv')).trim();
    return s.isEmpty ? null : s;
  }

  static List<Map<String, dynamic>> costAllocs(dynamic r) {
    final list = getJsonField(_b(r), r'$.carRequestsCostAllocs');
    if (list is! List) return const [];
    final namesObj = getJsonField(_b(r), r'$.costAllocsUserNames');

    String _nameFor(dynamic id) {
      if (namesObj is Map) {
        final v = namesObj[id] ?? namesObj[id?.toString()];
        return _s(v);
      }
      return '';
    }

    return list.map((it) {
      final id = getJsonField(it, r'$.id');
      return {
        'id': id,
        'userName': _nameFor(id),
        'costAllocName': _s(getJsonField(it, r'$.costAllocation.name')),
        'percent': (getJsonField(it, r'$.percent') as num?)?.toDouble(),
      };
    }).toList();
  }

  static List<Map<String, dynamic>> flights(dynamic r) {
    final list = getJsonField(_b(r), r'$.flightsInformations');
    if (list is! List) return const [];
    return list
        .map((f) => {
      'destination': _s(getJsonField(f, r'$.destination')),
      'time': _s(getJsonField(f, r'$.time')),
      'sourceAirport': _s(getJsonField(f, r'$.sourceAirport')),
      'destinationAirport':
      _s(getJsonField(f, r'$.destinationAirport')),
      'flightNumber': _s(getJsonField(f, r'$.flightNumber')),
    })
        .toList();
  }
}

class CarRequestsUpdateAdminCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required int id,
    int? carId,
    List<int>? passengersId,
    List<Map<String, dynamic>> carRequestsCostAllocs = const [],
    List<String>? destAddresses,
    List<Map<String, dynamic>>? carRequestDests,
    String? note,
    String? specialCarInfo,
    String? passanger1,
    String? passanger2,
    String? passanger3,
    bool? childSeat,
    String? sourceAddress,
  }) {
    List<Map<String, dynamic>> _dests;
    if (carRequestDests != null) {
      _dests = carRequestDests;
    } else if (destAddresses != null) {
      var seq = 1;
      _dests = destAddresses
          .where((s) => s.trim().isNotEmpty)
          .map((addr) => {'DestAddress': addr.trim(), 'Sequence': seq++})
          .toList();
    } else {
      _dests = <Map<String, dynamic>>[];
    }

    final _allocs = (carRequestsCostAllocs ?? const [])
        .map((c) => {
      'UserId': c['UserId'] ?? c['userId'],
      'CostAllocId': c['CostAllocId'] ?? c['costAllocId'],
      'Percent': c['Percent'] ?? c['percent'] ?? 0,
    })
        .toList();

    final _pass = passengersId ?? <int>[];

    final body = <String, dynamic>{
      'Id': id,
      if (carId != null) 'CarId': carId,

      'PassengersId': _pass,
      'CarRequestsCostAllocs': _allocs,
      'CarRequestDests': _dests,

      if ((note ?? '').trim().isNotEmpty) 'Note': note,
      if ((specialCarInfo ?? '').trim().isNotEmpty) 'SpecialCarInfo': specialCarInfo,
      if (passanger1 != null) 'Passanger1': passanger1,
      if (passanger2 != null) 'Passanger2': passanger2,
      if (passanger3 != null) 'Passanger3': passanger3,
      if (childSeat != null) 'ChildSeat': childSeat,
      if ((sourceAddress ?? '').trim().isNotEmpty) 'SourceAddress': sourceAddress,
    };

    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsUpdateAdmin',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests/UpdateAdmin/$id',
      callType: ApiCallType.PUT,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      },
      params: const {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }
}
// =================== USER PREFERENCES (Information) ===================
class UsersGetByIdCall {
  static Future<ApiCallResponse> call({
    required int userId,
    required String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'UsersGetById',
      apiUrl: _kPrivateApiFunctionName + 'Users/$userId',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if (bearerToken != null && bearerToken.isNotEmpty)
          'Authorization': 'Bearer $bearerToken',
      },
      returnBody: true,
      cache: false,
    );
  }

  static Map<String, dynamic> map(ApiCallResponse res) =>
      (res.jsonBody ?? {}) as Map<String, dynamic>;

  static String? email(Map<String, dynamic> m) =>
      (m['email'] ?? m['Email'])?.toString();

  static String? phone(Map<String, dynamic> m) =>
      (m['phoneNumber'] ?? m['phone'] ?? m['PhoneNumber'])?.toString();
}

class UsersPreferencesCall {
  static Future<ApiCallResponse> call({
    required int id,
    required String email,
    required String phoneNumber,
    required String? bearerToken,
  }) {
    final body = jsonEncode({
      'Id': id,
      'Email': email,
      'PhoneNumber': phoneNumber,
    });

    return ApiManager.instance.makeApiCall(
      callName: 'UsersPreferences',
      apiUrl: _kPrivateApiFunctionName + 'Users/Preferences',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (bearerToken != null && bearerToken.isNotEmpty)
          'Authorization': 'Bearer $bearerToken',
      },
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }
}

// =================== COST ALLOCATIONS (update) ===================
class CostAllocationsUpdateCall {
  /// POST/PUT /api/costallocations/update
  static Future<ApiCallResponse> call({
    required String name,
    required List<Map<String, dynamic>> details,
    String? bearerToken,
    bool usePut = false,
  }) {
    final body = jsonEncode({
      'name': name,
      'costAllocDetails': details
          .map((d) => {
        'name': d['name'] ?? d['code'],
        'percent': (d['percent'] as num?)?.toDouble() ?? 0.0,
      })
          .toList(),
    });

    return ApiManager.instance.makeApiCall(
      callName: 'CostAllocationsUpdate',
      apiUrl: _kPrivateApiFunctionName + 'costallocations/update',
      callType: usePut ? ApiCallType.PUT : ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      bodyType: BodyType.JSON,
      body: body,
      returnBody: true,
      cache: false,
    );
  }
}

class CostAllocationsUpdateDetailsCall {
  /// POST/PUT /api/costallocations/update-details
  static Future<ApiCallResponse> call({
    required String name,
    required List<Map<String, dynamic>> details,
    String? bearerToken,
    bool usePut = false,
  }) {
    final body = jsonEncode({
      'name': name,
      'details': details
          .map((d) => {
        'name': d['name'] ?? d['code'],
        'percent': (d['percent'] as num?)?.toDouble() ?? 0.0,
      })
          .toList(),
    });

    return ApiManager.instance.makeApiCall(
      callName: 'CostAllocationsUpdateDetails',
      apiUrl: _kPrivateApiFunctionName + 'costallocations/update-details',
      callType: usePut ? ApiCallType.PUT : ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      bodyType: BodyType.JSON,
      body: body,
      returnBody: true,
      cache: false,
    );
  }
}

// =================== FAVORITE PLACES (share/unshare/delete) ===================
class UsersShareFavoritePlaceCall {
  /// POST /api/Users/ShareFavoritePlace
  static Future<ApiCallResponse> call({
    required int userId,
    required String address,
    String? placeName,
    String? bearerToken,
  }) {
    final body = jsonEncode({
      'userId': userId,
      'address': address,
      if ((placeName ?? '').trim().isNotEmpty) 'placeName': placeName,
    });

    return ApiManager.instance.makeApiCall(
      callName: 'UsersShareFavoritePlace',
      apiUrl: _kPrivateApiFunctionName + 'Users/ShareFavoritePlace',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      bodyType: BodyType.JSON,
      body: body,
      returnBody: true,
      cache: false,
    );
  }
}

class UsersUnshareFavoritePlaceCall {
  /// POST /api/Users/UnshareFavoritePlace
  static Future<ApiCallResponse> call({
    required int userId,
    required String address,
    String? bearerToken,
  }) {
    final body = jsonEncode({'userId': userId, 'address': address});

    return ApiManager.instance.makeApiCall(
      callName: 'UsersUnshareFavoritePlace',
      apiUrl: _kPrivateApiFunctionName + 'Users/UnshareFavoritePlace',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      bodyType: BodyType.JSON,
      body: body,
      returnBody: true,
      cache: false,
    );
  }
}

class UsersDeleteFavoritePlaceCall {
  /// DELETE /api/Users/FavoritePlace/{id}
  static Future<ApiCallResponse> call({
    required int id,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'UsersDeleteFavoritePlace',
      apiUrl: _kPrivateApiFunctionName + 'Users/FavoritePlace/$id',
      callType: ApiCallType.DELETE,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }
}
class UsersIndexCall {
  static Future<ApiCallResponse> call({String? bearerToken}) {
    return ApiManager.instance.makeApiCall(
      callName: 'UsersIndex',
      apiUrl: _kPrivateApiFunctionName + 'users/index',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }

  static List<dynamic> items(ApiCallResponse r) {
    final b = r.jsonBody;
    final i = getJsonField(b, r'$.items');
    if (i is List) return i;
    if (b is List) return b;
    return const [];
  }

  static int? id(dynamic u) => getJsonField(u, r'$.id');
  static String? fullName(dynamic u) =>
      getJsonField(u, r'$.fullNameDetail')?.toString() ??
          getJsonField(u, r'$.fullName')?.toString();
}
// api/CostAllocations
class CostAllocationsByUserCall {
  static Future<ApiCallResponse> call({
    required int userId,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'CostAllocationsByUser',
      apiUrl: _kPrivateApiFunctionName + 'costallocations/getbyuser/$userId',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }

  static List<dynamic> items(ApiCallResponse r) {
    final b = r.jsonBody;
    if (b is List) return b;
    final i = getJsonField(b, r'$.items');
    return (i is List) ? i : const [];
  }

  static int? id(dynamic c) => getJsonField(c, r'$.id');
  static String? name(dynamic c) => getJsonField(c, r'$.name')?.toString();
}

class GetCostAllocations {
  static Future<ApiCallResponse> call({
    required int userId,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'GetCostAllocations',
      apiUrl: _kPrivateApiFunctionName + 'CostAllocations/GetCostAllocations/$userId',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }
}

class CostAllocationsAddOrEditCall {
  static Future<ApiCallResponse> call({
    required Map<String, dynamic> costAllocation,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'CostAllocationsAddOrEdit',
      apiUrl: _kPrivateApiFunctionName + 'CostAllocations/AddOrEdit',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(costAllocation),
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }
}

class CostAllocationsGetCall {
  static Future<ApiCallResponse> call({
    required int costAllocId,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'CostAllocationsGet',
      apiUrl:
      _kPrivateApiFunctionName + 'CostAllocations/Get/$costAllocId',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }
}

class CostAllocationsDeleteCall {
  static Future<ApiCallResponse> call({
    required int id,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'CostAllocationsDelete',
      apiUrl: _kPrivateApiFunctionName + 'CostAllocations/Delete/$id',
      callType: ApiCallType.DELETE,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }
}
class CostAllocDetailsGetByCostAllocCall {
  static Future<ApiCallResponse> call({
    required int costAllocId,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'CostAllocDetailsGetByCostAlloc',
      apiUrl: _kPrivateApiFunctionName + 'CostAllocDetails/GetDetails/$costAllocId',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }

  static List<dynamic> items(ApiCallResponse r) {
    final b = r.jsonBody;
    if (b is List) return b;
    final i = getJsonField(b, r'$.items');
    return (i is List) ? i : const [];
  }

  static int? id(dynamic d) => getJsonField(d, r'$.id');
  static String name(dynamic d) => (getJsonField(d, r'$.name') ?? '').toString();
  static double percent(dynamic d) {
    final v = getJsonField(d, r'$.percent');
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0.0;
  }
  static int? costAllocationId(dynamic d) => getJsonField(d, r'$.costAllocationId');
}

class CostAllocDetailsAddOrEditCall {
  static Future<ApiCallResponse> call({
    required Map<String, dynamic> body,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'CostAllocDetailsAddOrEdit',
      apiUrl: _kPrivateApiFunctionName + 'CostAllocDetails/AddOrEdit',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }
}

class CostAllocDetailsDeleteCall {
  static Future<ApiCallResponse> call({
    required int id,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'CostAllocDetailsDelete',
      apiUrl: _kPrivateApiFunctionName + 'CostAllocDetails/Delete/$id',
      callType: ApiCallType.DELETE,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }
}

// ========= Users -> Favorite Drivers (API wrappers) =========

class UsersGetFavoriteDriversCall {
  static Future<ApiCallResponse> call({
    required int userId,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'UsersGetFavoriteDrivers',
      apiUrl: _kPrivateApiFunctionName + 'Users/GetFavoriteDrivers/$userId',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }

  static List<dynamic> items(ApiCallResponse r) {
    final b = r.jsonBody;
    if (b is List) return b;
    final i = getJsonField(b, r'$.data');
    if (i is List) return i;
    return const [];
  }

  static int? id(dynamic d) => getJsonField(d, r'$.id');
  static bool isFavorite(dynamic d) => (getJsonField(d, r'$.isFavoriteDriver') ?? false) == true;
  static int? favOrder(dynamic d) {
    final v = getJsonField(d, r'$.driverFavOrder');
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString());
  }
}

class UsersFavorDriverCall {
  static Future<ApiCallResponse> call({
    required int userId,
    required int driverId,
    required bool isFavorite,
    String? bearerToken,
  }) {
    final body = jsonEncode({
      'UserId': userId,
      'DriverId': driverId,
      'IsFavorite': isFavorite,
    });

    return ApiManager.instance.makeApiCall(
      callName: 'UsersFavorDriver',
      apiUrl: _kPrivateApiFunctionName + 'Users/FavorDriver',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }
}

class UsersMoveFavDriverToTopCall {
  static Future<ApiCallResponse> call({
    required int userId,
    required int driverId,
    String? bearerToken,
  }) {
    final body = jsonEncode({
      'UserId': userId,
      'DriverId': driverId,
    });

    return ApiManager.instance.makeApiCall(
      callName: 'UsersMoveFavDriverToTop',
      apiUrl: _kPrivateApiFunctionName + 'Users/MoveFavDriverToTop',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }
}

// === Favorite Places =========================================================

class UsersGetFavoritePlacesCall {
  static Future<ApiCallResponse> call({
    required int userId,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'UsersGetFavoritePlaces',
      apiUrl: _kPrivateApiFunctionName + 'Users/GetFavoritePlaces/$userId',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }

  static List<dynamic> items(ApiCallResponse r) {
    final b = r.jsonBody;
    if (b is List) return b;
    final data = getJsonField(b, r'$.data');
    if (data is List) return data;
    return const [];
  }

  static int? id(dynamic m) {
    final v = getJsonField(m, r'$.id');
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString());
  }

  static String name(dynamic m) {
    final a = (getJsonField(m, r'$.placeName') ?? getJsonField(m, r'$.name') ?? '')
        .toString()
        .trim();
    return a;
  }

  static String address(dynamic m) {
    return (getJsonField(m, r'$.address') ?? '').toString().trim();
  }

  static bool shared(dynamic m) {
    final raw = getJsonField(m, r'$.sharingIsActive');
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final s = (raw ?? '').toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static String? sharedOnIso(dynamic m) {
    final v = getJsonField(m, r'$.sharingDate');
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}

class UsersDeletePlaceCall {
  static Future<ApiCallResponse> call({
    required int placeId,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'UsersDeletePlace',
      apiUrl: _kPrivateApiFunctionName + 'Users/DeletePlace/$placeId',
      callType: ApiCallType.DELETE,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }
}

class UsersSharePlaceCall {
  static Future<ApiCallResponse> call({
    required int placeId,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'UsersSharePlace',
      apiUrl: _kPrivateApiFunctionName + 'Users/SharePlace',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode({'placeId': placeId}),
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }
}

class UsersStopSharePlaceCall {
  static Future<ApiCallResponse> call({
    required int placeId,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'UsersStopSharePlace',
      apiUrl: _kPrivateApiFunctionName + 'Users/StopSharePlace',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode({'placeId': placeId}),
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }
}

class UsersGetFavoritePlaceCall {
  static Future<ApiCallResponse> call({
    required int placeId,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'UsersGetFavoritePlace',
      apiUrl: _kPrivateApiFunctionName + 'Users/GetFavoritePlace/$placeId',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      bodyType: BodyType.NONE,
      returnBody: true,
      cache: false,
    );
  }

  static Map<String, dynamic> map(ApiCallResponse r) {
    final b = r.jsonBody;
    return (b is Map) ? b.cast<String, dynamic>() : <String, dynamic>{};
  }
}

class UsersAddOrEditPlaceCall {
  static Future<ApiCallResponse> call({
    required Map<String, dynamic> placeBody,
    String? bearerToken,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'UsersAddOrEditPlace',
      apiUrl: _kPrivateApiFunctionName + 'Users/AddOrEditPlace',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(placeBody),
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }
}

class CarRequestsHistoryCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required DateTime from,
    required DateTime to,
    int? userId,
    bool finishedOnly = false,
  }) {
    final body = {
      'userId': userId ?? 0,
      'fromDateTime': from.toIso8601String(),
      'toDateTime': to.toIso8601String(),
      'finishedOnly': finishedOnly,
    };
    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsHistory',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests/History',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
    );
  }
}

class CarRequestsChangeDriverCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required int id,
    required int driverId,
  }) {
    final body = jsonEncode({'id': id, 'driverId': driverId});
    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsChangeDriver',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests/ChangeDriver',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
    );
  }
}

// =================== REQUEST ACTIONS (NOVOS) ===================
// POST /api/CarRequests/ExtendPeriod
class CarRequestsExtendPeriodCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required String id,
    required DateTime newEnd,
  }) {
    final payload = jsonEncode({
      'id': int.tryParse(id) ?? id,
      'endDateTime': newEnd.toUtc().toIso8601String(),
    });

    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsExtendPeriod',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests/ExtendPeriod',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
      bodyType: BodyType.JSON,
      body: payload,
      returnBody: true,
    );
  }
}

// POST /api/CarRequests/FinishKm
class CarRequestsFinishKmCall {
  static Future<ApiCallResponse> call({
    required String bearerToken,
    required String id,
    required int endKm,
  }) {
    final payload = jsonEncode({
      'id': int.tryParse(id) ?? id,
      'endKm': endKm,
    });

    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsFinishKm',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests/FinishKm',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
      bodyType: BodyType.JSON,
      body: payload,
      returnBody: true,
    );
  }
}

// GET /api/CarRequests/GetConfirmation/{ConfirmId}
class CarRequestsGetConfirmationCall {
  static Future<ApiCallResponse> call({
    required String confirmId,
  }) {
    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsGetConfirmation',
      apiUrl:
      _kPrivateApiFunctionName + 'CarRequests/GetConfirmation/$confirmId',
      callType: ApiCallType.GET,
      headers: {'Accept': 'application/json'},
      returnBody: true,
      cache: false,
    );
  }

  static dynamic _b(dynamic r) => (r is ApiCallResponse) ? r.jsonBody : r;
  static String _s(dynamic v) => v?.toString() ?? '';

  static String? id(dynamic r) {
    final s = _s(getJsonField(_b(r), r'$.id'));
    return s.isEmpty ? null : s;
  }

  static String? userName(dynamic r) => _firstNonEmptyNullable([
    _s(getJsonField(_b(r), r'$.userDto.fullName')),
    _s(getJsonField(_b(r), r'$.user.fullName')),
    _s(getJsonField(_b(r), r'$.requirerDto.fullName')),
  ]);

  static String? driver(dynamic r) => _firstNonEmptyNullable([
    _s(getJsonField(_b(r), r'$.driverDto.fullName')),
    _s(getJsonField(_b(r), r'$.driver.fullName')),
  ]);

  static DateTime? startAt(dynamic r) {
    final s = _firstNonEmpty([
      _s(getJsonField(_b(r), r'$.startDateTime')),
      _s(getJsonField(_b(r), r'$.start')),
      _s(getJsonField(_b(r), r'$.periodFrom')),
    ]);
    return s.isEmpty ? null : DateTime.tryParse(s)?.toLocal();
  }

  static DateTime? endAt(dynamic r) {
    final s = _firstNonEmpty([
      _s(getJsonField(_b(r), r'$.endDateTime')),
      _s(getJsonField(_b(r), r'$.end')),
      _s(getJsonField(_b(r), r'$.periodTo')),
    ]);
    return s.isEmpty ? null : DateTime.tryParse(s)?.toLocal();
  }

  static String? departure(dynamic r) => _firstNonEmptyNullable([
    _s(getJsonField(_b(r), r'$.routeDeparture')),
    _s(getJsonField(_b(r), r'$.sourceAddress')),
    _s(getJsonField(_b(r), r'$.startAddress')),
    _s(getJsonField(_b(r), r'$.fromAddress')),
  ]);

  static List<String> destinations(dynamic r) {
    final list = getJsonField(_b(r), r'$.carRequestDests');
    if (list is List) {
      return list
          .map((e) => _firstNonEmpty([
        _s(getJsonField(e, r'$.address')),
        _s(getJsonField(e, r'$.formattedAddress')),
        _s(getJsonField(e, r'$.destAddress')),
        _s(getJsonField(e, r'$.routeDestination')),
      ]))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static String _firstNonEmpty(List<String> opts) =>
      opts.firstWhere((s) => s.trim().isNotEmpty, orElse: () => '');
  static String? _firstNonEmptyNullable(List<String> opts) {
    final s = _firstNonEmpty(opts);
    return s.isEmpty ? null : s;
  }
}

// POST /api/CarRequests/Confirm
class CarRequestsConfirmByTokenCall {
  static Future<ApiCallResponse> call({
    required String confirmId,
    String? txtReason,
  }) {
    final body = jsonEncode({
      'ConfirmId': confirmId,
      'txtReason': txtReason,
    });

    return ApiManager.instance.makeApiCall(
      callName: 'CarRequestsConfirmByToken',
      apiUrl: _kPrivateApiFunctionName + 'CarRequests/Confirm',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }
}

class CarsAvailableCall {
  static Future<ApiCallResponse> call({
    required DateTime from,
    required DateTime to,
    String? bearerToken,
  }) {
    final body = {
      'fromDate': from.toIso8601String(),
      'toDate': to.toIso8601String(),
    };
    return ApiManager.instance.makeApiCall(
      callName: 'CarsAvailable',
      apiUrl: _kPrivateApiFunctionName + 'cars/available',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }

  static List<dynamic> items(ApiCallResponse r) {
    final b = r.jsonBody;
    if (b is List) return b;
    final i = getJsonField(b, r'$.items');
    return (i is List) ? i : const [];
  }

  static int? id(dynamic it) => getJsonField(it, r'$.id');
  static String? description(dynamic it) =>
      getJsonField(it, r'$.description')?.toString();
  static String? plate(dynamic it) =>
      getJsonField(it, r'$.licensePlate')?.toString();
}

// BUSCA: Motoristas disponíveis no período
class DriversAvailableCall {
  static Future<ApiCallResponse> call({
    required DateTime from,
    required DateTime to,
    String? bearerToken,
  }) {
    final body = {
      'fromDate': from.toIso8601String(),
      'toDate': to.toIso8601String(),
    };
    return ApiManager.instance.makeApiCall(
      callName: 'DriversAvailable',
      apiUrl: _kPrivateApiFunctionName + 'drivers/available',
      callType: ApiCallType.POST,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if ((bearerToken ?? ApiManager.accessToken)?.isNotEmpty == true)
          'Authorization': 'Bearer ${bearerToken ?? ApiManager.accessToken}',
      },
      params: const {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      cache: false,
    );
  }

  static List<dynamic> items(ApiCallResponse r) {
    final b = r.jsonBody;
    if (b is List) return b;
    final i = getJsonField(b, r'$.items');
    return (i is List) ? i : const [];
  }

  static int? id(dynamic d) => getJsonField(d, r'$.id');
  static String? name(dynamic d) =>
      getJsonField(d, r'$.fullName')?.toString();
}

class CarRequestBody {
  static Map<String, dynamic> fromWizard({
    required DateTime start,
    required DateTime end,
    required String sourceAddress,
    required List<String> destAddresses,
    required List<int> passengersIds,
    required List<Map<String, dynamic>> costAllocs,
    bool childSeat = false,
    String? note,

    required int carType,
    String? specialCarInfo,
    List<Map<String, dynamic>> flightsInformations = const [],
    String? passanger1,
    String? passanger2,
    String? passanger3,

    required int userId,
    bool bookNow = true,
    int? carId,
    int? driverId,
  }) {
    final dests = <Map<String, dynamic>>[];
    var seq = 1;
    for (final a in destAddresses) {
      dests.add({'destAddress': a, 'sequence': seq++});
    }

    return <String, dynamic>{
      'startDateTime': start.toIso8601String(),
      'endDateTime': end.toIso8601String(),
      'sourceAddress': sourceAddress,
      'carRequestDests': dests,
      'passengersId': passengersIds,
      'carRequestsCostAllocs': costAllocs.map((c) => {
        'userId': c['userId'],
        'costAllocId': c['costAllocId'],
        'percent': c['percent'],
      }).toList(),
      'childSeat': childSeat,
      'bookNow': bookNow,
      'userId': userId,
      if (note != null && note.trim().isNotEmpty) 'note': note,
      'carType': carType,
      if (specialCarInfo != null && specialCarInfo.trim().isNotEmpty) 'specialCarInfo': specialCarInfo,
      'flightsInformations': flightsInformations,
      'passanger1': passanger1 ?? '',
      'passanger2': passanger2 ?? '',
      'passanger3': passanger3 ?? '',

      if (carId != null) 'carId': carId,
      if (driverId != null) 'driverId': driverId,
    };
  }
}
// =================== HELPERS ===================
class ApiPagingParams {
  int nextPageNumber = 0;
  int numItems = 0;
  dynamic lastResponse;

  ApiPagingParams({
    required this.nextPageNumber,
    required this.numItems,
    required this.lastResponse,
  });

  @override
  String toString() =>
      'PagingParams(nextPageNumber: $nextPageNumber, numItems: $numItems, lastResponse: $lastResponse,)';
}

String? escapeStringForJson(String? input) {
  if (input == null) return null;
  return input
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\t', '\\t');
}
