import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:equatable/equatable.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime_type/mime_type.dart';

import '/flutter_flow/uploaded_file.dart';
import 'get_streamed_response.dart';


const bool kApiLog = kDebugMode;

const int kDefaultApiRequestTimeoutMs = 60000;

void _apiLog(Object msg) {
  if (kApiLog) debugPrint('[API] $msg');
}

String _maskToken(String? t) {
  if (t == null || t.isEmpty) return '<empty>';
  final head = t.length >= 10 ? t.substring(0, 10) : t;
  final tail = t.length >= 5 ? t.substring(t.length - 5) : '';
  return '$head…$tail';
}

enum ApiCallType { GET, POST, DELETE, PUT, PATCH }

enum BodyType { NONE, JSON, TEXT, X_WWW_FORM_URL_ENCODED, MULTIPART }

class ApiCallOptions extends Equatable {
  const ApiCallOptions({
    this.callName = '',
    required this.callType,
    required this.apiUrl,
    required this.headers,
    required this.params,
    this.bodyType,
    this.body,
    this.returnBody = true,
    this.encodeBodyUtf8 = false,
    this.decodeUtf8 = false,
    this.alwaysAllowBody = false,
    this.cache = false,
    this.isStreamingApi = false,
  });

  final String callName;
  final ApiCallType callType;
  final String apiUrl;
  final Map<String, dynamic> headers;
  final Map<String, dynamic> params;
  final BodyType? bodyType;
  final String? body;
  final bool returnBody;
  final bool encodeBodyUtf8;
  final bool decodeUtf8;
  final bool alwaysAllowBody;
  final bool cache;
  final bool isStreamingApi;

  ApiCallOptions copyWith({
    String? callName,
    ApiCallType? callType,
    String? apiUrl,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? params,
    BodyType? bodyType,
    String? body,
    bool? returnBody,
    bool? encodeBodyUtf8,
    bool? decodeUtf8,
    bool? alwaysAllowBody,
    bool? cache,
    bool? isStreamingApi,
  }) {
    return ApiCallOptions(
      callName: callName ?? this.callName,
      callType: callType ?? this.callType,
      apiUrl: apiUrl ?? this.apiUrl,
      headers: headers ?? _cloneMap(this.headers),
      params: params ?? _cloneMap(this.params),
      bodyType: bodyType ?? this.bodyType,
      body: body ?? this.body,
      returnBody: returnBody ?? this.returnBody,
      encodeBodyUtf8: encodeBodyUtf8 ?? this.encodeBodyUtf8,
      decodeUtf8: decodeUtf8 ?? this.decodeUtf8,
      alwaysAllowBody: alwaysAllowBody ?? this.alwaysAllowBody,
      cache: cache ?? this.cache,
      isStreamingApi: isStreamingApi ?? this.isStreamingApi,
    );
  }

  ApiCallOptions clone() => ApiCallOptions(
    callName: callName,
    callType: callType,
    apiUrl: apiUrl,
    headers: _cloneMap(headers),
    params: _cloneMap(params),
    bodyType: bodyType,
    body: body,
    returnBody: returnBody,
    encodeBodyUtf8: encodeBodyUtf8,
    decodeUtf8: decodeUtf8,
    alwaysAllowBody: alwaysAllowBody,
    cache: cache,
    isStreamingApi: isStreamingApi,
  );

  @override
  List<Object?> get props => [
    callName,
    callType.name,
    apiUrl,
    headers,
    params,
    bodyType,
    body,
    returnBody,
    encodeBodyUtf8,
    decodeUtf8,
    alwaysAllowBody,
    cache,
    isStreamingApi,
  ];

  static Map<String, dynamic> _cloneMap(Map<String, dynamic> map) =>
      Map<String, dynamic>.from(map);
}

class ApiCallResponse {
  const ApiCallResponse(
      this.jsonBody,
      this.headers,
      this.statusCode, {
        this.response,
        this.streamedResponse,
        this.exception,
      });

  final dynamic jsonBody;
  final Map<String, String> headers;
  final int statusCode;
  final http.Response? response;
  final http.StreamedResponse? streamedResponse;
  final Object? exception;

  bool get succeeded => statusCode >= 200 && statusCode < 300;
  String getHeader(String headerName) => headers[headerName] ?? '';

  String get bodyText {
    if (response != null) return response!.body;
    if (jsonBody is String) return jsonBody as String;
    try {
      return jsonEncode(jsonBody);
    } catch (_) {
      return '<no-body>';
    }
  }

  String get exceptionMessage => exception.toString();

  ApiCallResponse copyWith({
    dynamic jsonBody,
    Map<String, String>? headers,
    int? statusCode,
    http.Response? response,
    http.StreamedResponse? streamedResponse,
    Object? exception,
  }) {
    return ApiCallResponse(
      jsonBody ?? this.jsonBody,
      headers ?? this.headers,
      statusCode ?? this.statusCode,
      response: response ?? this.response,
      streamedResponse: streamedResponse ?? this.streamedResponse,
      exception: exception ?? this.exception,
    );
  }

  static ApiCallResponse fromHttpResponse(
      http.Response response,
      bool returnBody,
      bool decodeUtf8,
      ) {
    dynamic parsed;
    try {
      final ct = (response.headers['content-type'] ?? '').toLowerCase();
      final isJson =
          ct.contains('application/json') || ct.contains('text/json');
      final raw = decodeUtf8 && returnBody
          ? const Utf8Decoder().convert(response.bodyBytes)
          : response.body;

      if (!returnBody) {
        parsed = null;
      } else if (isJson) {
        parsed = raw.isEmpty ? {} : json.decode(raw);
      } else {
        final looksJson = raw.startsWith('{') || raw.startsWith('[');
        if (looksJson) {
          try {
            parsed = json.decode(raw);
          } catch (_) {
            parsed = raw;
          }
        } else {
          parsed = raw;
        }
      }
    } catch (_) {
      parsed = returnBody ? (decodeUtf8 ? const Utf8Decoder().convert(response.bodyBytes) : response.body) : null;
    }

    return ApiCallResponse(
      parsed,
      response.headers,
      response.statusCode,
      response: response,
    );
  }

  static ApiCallResponse fromCloudCallResponse(Map<String, dynamic> response) =>
      ApiCallResponse(
        response['body'],
        ApiManager.toStringMap(response['headers'] ?? {}),
        response['statusCode'] ?? 400,
      );
}

class ApiManager {
  ApiManager._();

  static Map<ApiCallOptions, ApiCallResponse> _apiCache = {};
  static ApiManager? _instance;
  static ApiManager get instance => _instance ??= ApiManager._();

  static http.Client? _sharedClient;
  static http.Client get _client => _sharedClient ??= http.Client();

  static void resetHttpClient() {
    try {
      _sharedClient?.close();
    } catch (_) {}
    _sharedClient = null;
  }

  static String? _accessToken;
  static void setAccessToken(String? token) {
    _accessToken = token;
    _apiLog('AccessToken set: ${_maskToken(_accessToken)}');
  }
  static String? get accessToken => _accessToken;

  static void clearCache(String callName) => _apiCache.keys
      .toSet()
      .forEach((k) => k.callName == callName ? _apiCache.remove(k) : null);

  static Map<String, String> toStringMap(Map map) =>
      map.map((key, value) => MapEntry(key.toString(), value.toString()));

  static String asQueryParams(Map<String, dynamic> map) => map.entries
      .map((e) =>
  "${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}")
      .join('&');

  static final Map<String, Future<ApiCallResponse>> _inflight = {};

  static String _fingerprint({
    required ApiCallType callType,
    required String apiUrl,
    required Map<String, dynamic> headers,
    required Map<String, dynamic> params,
    required String? body,
    required BodyType? bodyType,
  }) {
    String _canonMap(Map<String, dynamic> m) {
      final keys = m.keys.map((e) => e.toString()).toList()..sort();
      final b = StringBuffer();
      for (final k in keys) {
        b.write(k);
        b.write('=');
        b.write(m[k]);
        b.write('&');
      }
      return b.toString();
    }

    return [
      callType.name,
      apiUrl,
      _canonMap(headers),
      _canonMap(params),
      body ?? '',
      bodyType?.name ?? 'NONE',
    ].join('|');
  }

  // ---------- Requisições sem corpo ----------
  static Future<ApiCallResponse> urlRequest(
      ApiCallType callType,
      String apiUrl,
      Map<String, dynamic> headers,
      Map<String, dynamic> params,
      bool returnBody,
      bool decodeUtf8,
      bool isStreamingApi, {
        required http.Client client,
        required int timeoutMs,
      }) async {
    if (params.isNotEmpty) {
      final specifier =
      Uri.parse(apiUrl).queryParameters.isNotEmpty ? '&' : '?';
      apiUrl = '$apiUrl$specifier${asQueryParams(params)}';
    }

    if (isStreamingApi) {
      final request =
      http.Request(callType.toString().split('.').last, Uri.parse(apiUrl))
        ..headers.addAll(toStringMap(headers));
      final streamedResponse =
      await getStreamedResponse(request).timeout(Duration(milliseconds: timeoutMs));
      return ApiCallResponse(
        null,
        streamedResponse.headers,
        streamedResponse.statusCode,
        streamedResponse: streamedResponse,
      );
    }

    try {
      late http.Response response;
      if (callType == ApiCallType.GET) {
        response = await client
            .get(Uri.parse(apiUrl), headers: toStringMap(headers))
            .timeout(Duration(milliseconds: timeoutMs));
      } else {
        response = await client
            .delete(Uri.parse(apiUrl), headers: toStringMap(headers))
            .timeout(Duration(milliseconds: timeoutMs));
      }
      return ApiCallResponse.fromHttpResponse(response, returnBody, decodeUtf8);
    } on TimeoutException catch (e) {
      return ApiCallResponse(null, const {}, -1, exception: e);
    } on Object catch (e) {
      return ApiCallResponse(null, const {}, -1, exception: e);
    }
  }

  // ---------- Requisições com corpo ----------
  static Future<ApiCallResponse> requestWithBody(
      ApiCallType type,
      String apiUrl,
      Map<String, dynamic> headers,
      Map<String, dynamic> params,
      String? body,
      BodyType? bodyType,
      bool returnBody,
      bool encodeBodyUtf8,
      bool decodeUtf8,
      bool alwaysAllowBody,
      bool isStreamingApi, {
        required http.Client client,
        required int timeoutMs,
      }) async {
    assert(
    {ApiCallType.POST, ApiCallType.PUT, ApiCallType.PATCH}.contains(type) ||
        (alwaysAllowBody && type == ApiCallType.DELETE),
    'Invalid ApiCallType $type for request with body',
    );

    final postBody =
    createBody(headers, params, body, bodyType, encodeBodyUtf8);

    if (isStreamingApi) {
      final request =
      http.Request(type.toString().split('.').last, Uri.parse(apiUrl))
        ..headers.addAll(toStringMap(headers))
        ..body = postBody ?? '';
      final streamedResponse =
      await getStreamedResponse(request).timeout(Duration(milliseconds: timeoutMs));
      return ApiCallResponse(
        null,
        streamedResponse.headers,
        streamedResponse.statusCode,
        streamedResponse: streamedResponse,
      );
    }

    final requestFn = {
      ApiCallType.POST: client.post,
      ApiCallType.PUT: client.put,
      ApiCallType.PATCH: client.patch,
      ApiCallType.DELETE: client.delete,
    }[type]!;

    try {
      final response = await requestFn(
        Uri.parse(apiUrl),
        headers: toStringMap(headers),
        body: postBody,
      ).timeout(Duration(milliseconds: timeoutMs));

      return ApiCallResponse.fromHttpResponse(response, returnBody, decodeUtf8);
    } on TimeoutException catch (e) {
      return ApiCallResponse(null, const {}, -1, exception: e);
    } on Object catch (e) {
      return ApiCallResponse(null, const {}, -1, exception: e);
    }
  }

  static Future<ApiCallResponse> multipartRequest(
      ApiCallType? type,
      String apiUrl,
      Map<String, dynamic> headers,
      Map<String, dynamic> params,
      bool returnBody,
      bool decodeUtf8,
      bool alwaysAllowBody, {
        required int timeoutMs,
      }) async {
    assert(
    {ApiCallType.POST, ApiCallType.PUT, ApiCallType.PATCH}.contains(type) ||
        (alwaysAllowBody && type == ApiCallType.DELETE),
    'Invalid ApiCallType $type for request with body',
    );

    bool isFile(dynamic e) =>
        e is FFUploadedFile ||
            e is List<FFUploadedFile> ||
            (e is List && e.firstOrNull is FFUploadedFile);

    final nonFileParams = toStringMap(
        Map.fromEntries(params.entries.where((e) => !isFile(e.value))));

    final files = <http.MultipartFile>[];
    params.entries.where((e) => isFile(e.value)).forEach((e) {
      final param = e.value;
      final uploadedFiles = param is List
          ? param as List<FFUploadedFile>
          : [param as FFUploadedFile];
      for (var uploadedFile in uploadedFiles) {
        files.add(
          http.MultipartFile.fromBytes(
            e.key,
            uploadedFile.bytes ?? Uint8List.fromList([]),
            filename: uploadedFile.name,
            contentType: _getMediaType(uploadedFile.name),
          ),
        );
      }
    });

    final request =
    http.MultipartRequest(type.toString().split('.').last, Uri.parse(apiUrl))
      ..headers.addAll(toStringMap(headers))
      ..files.addAll(files);

    nonFileParams.forEach((key, value) => request.fields[key] = value);

    try {
      final streamed = await request.send().timeout(Duration(milliseconds: timeoutMs));
      final response = await http.Response.fromStream(streamed);
      return ApiCallResponse.fromHttpResponse(response, returnBody, decodeUtf8);
    } on TimeoutException catch (e) {
      return ApiCallResponse(null, const {}, -1, exception: e);
    } on Object catch (e) {
      return ApiCallResponse(null, const {}, -1, exception: e);
    }
  }

  static MediaType? _getMediaType(String? filename) {
    final contentType = mime(filename);
    if (contentType == null) return null;
    final parts = contentType.split('/');
    if (parts.length != 2) return null;
    return MediaType(parts.first, parts.last);
  }

  static dynamic createBody(
      Map<String, dynamic> headers,
      Map<String, dynamic>? params,
      String? body,
      BodyType? bodyType,
      bool encodeBodyUtf8,
      ) {
    String? contentType;
    dynamic postBody;

    switch (bodyType) {
      case BodyType.JSON:
        contentType = 'application/json';
        postBody = body ?? json.encode(params ?? {});
        break;
      case BodyType.TEXT:
        contentType = 'text/plain';
        postBody = body ?? '';
        break;
      case BodyType.X_WWW_FORM_URL_ENCODED:
        contentType = 'application/x-www-form-urlencoded';
        postBody = toStringMap(params ?? {});
        break;
      case BodyType.MULTIPART:
      // Content-Type é setado pelo MultipartRequest; não force aqui.
        break;
      case BodyType.NONE:
      case null:
        break;
    }

    if (contentType != null &&
        !headers.keys.any((h) => h.toLowerCase() == 'content-type')) {
      headers['Content-Type'] = contentType;
    }

    return encodeBodyUtf8 && postBody is String
        ? utf8.encode(postBody)
        : postBody;
  }

  Future<ApiCallResponse> call(
      ApiCallOptions options, {
        http.Client? client,
        int? timeoutMs,
        bool dedupeInFlight = true,
      }) =>
      makeApiCall(
        callName: options.callName,
        apiUrl: options.apiUrl,
        callType: options.callType,
        headers: options.headers,
        params: options.params,
        body: options.body,
        bodyType: options.bodyType,
        returnBody: options.returnBody,
        encodeBodyUtf8: options.encodeBodyUtf8,
        decodeUtf8: options.decodeUtf8,
        alwaysAllowBody: options.alwaysAllowBody,
        cache: options.cache,
        isStreamingApi: options.isStreamingApi,
        options: options,
        client: client,
        timeoutMs: timeoutMs,
        dedupeInFlight: dedupeInFlight,
      );

  Future<ApiCallResponse> makeApiCall({
    required String callName,
    required String apiUrl,
    required ApiCallType callType,
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> params = const {},
    String? body,
    BodyType? bodyType,
    bool returnBody = true,
    bool encodeBodyUtf8 = false,
    bool decodeUtf8 = false,
    bool alwaysAllowBody = false,
    bool cache = false,
    bool isStreamingApi = false,
    ApiCallOptions? options,
    http.Client? client,
    int? timeoutMs,
    bool dedupeInFlight = true,
  }) async {
    final callOptions = options ??
        ApiCallOptions(
          callName: callName,
          callType: callType,
          apiUrl: apiUrl,
          headers: headers,
          params: params,
          bodyType: bodyType,
          body: body,
          returnBody: returnBody,
          encodeBodyUtf8: encodeBodyUtf8,
          decodeUtf8: decodeUtf8,
          alwaysAllowBody: alwaysAllowBody,
          cache: cache,
          isStreamingApi: isStreamingApi,
        );
    client ??= _client;

    if (_accessToken != null &&
        !headers.keys
            .map((h) => h.toLowerCase())
            .contains(HttpHeaders.authorizationHeader)) {
      headers[HttpHeaders.authorizationHeader] = 'Bearer $_accessToken';
    }

    headers.putIfAbsent(HttpHeaders.acceptHeader, () => 'application/json');
    headers.putIfAbsent(HttpHeaders.acceptEncodingHeader, () => 'gzip');
    headers.putIfAbsent(HttpHeaders.connectionHeader, () => 'keep-alive');
    headers.putIfAbsent(HttpHeaders.userAgentHeader, () => 'Mitsubishi-App/1.0 (Flutter)');

    if (!apiUrl.startsWith('http')) {
      apiUrl = 'https://$apiUrl';
    }

    final _timeoutMs = timeoutMs ?? kDefaultApiRequestTimeoutMs;

    // ----- LOG REQUEST -----
    final maskedHeaders = Map<String, dynamic>.from(headers);
    final authKey = maskedHeaders.keys.firstWhere(
          (k) => k.toLowerCase() == 'authorization',
      orElse: () => '',
    );
    if (authKey.isNotEmpty) {
      final v = maskedHeaders[authKey].toString().replaceFirst('Bearer ', '');
      maskedHeaders[authKey] = 'Bearer ${_maskToken(v)}';
    }
    _apiLog('>> $callName ${callType.name} $apiUrl');
    if (params.isNotEmpty) _apiLog('   params: $params');
    if (body != null && body.isNotEmpty) _apiLog('   body: $body');
    _apiLog('   headers: $maskedHeaders');

    if (cache && _apiCache.containsKey(callOptions)) {
      final cached = _apiCache[callOptions]!;
      _apiLog('<< $callName [CACHE ${cached.statusCode}]');
      return cached;
    }

    final fp = _fingerprint(
      callType: callType,
      apiUrl: apiUrl,
      headers: headers,
      params: params,
      body: body,
      bodyType: bodyType,
    );

    if (dedupeInFlight && _inflight.containsKey(fp)) {
      _apiLog('.. awaiting in-flight: $callName');
      try {
        final r = await _inflight[fp]!;
        return r;
      } catch (_) {
      }
    }

    late Future<ApiCallResponse> futureCall;

    final sw = Stopwatch()..start();
    Future<ApiCallResponse> _doCall() async {
      ApiCallResponse result;
      try {
        switch (callType) {
          case ApiCallType.GET:
            result = await urlRequest(
              callType,
              apiUrl,
              headers,
              params,
              returnBody,
              decodeUtf8,
              isStreamingApi,
              client: client!,
              timeoutMs: _timeoutMs,
            );
            break;
          case ApiCallType.DELETE:
            result = alwaysAllowBody
                ? await requestWithBody(
              callType,
              apiUrl,
              headers,
              params,
              body,
              bodyType,
              returnBody,
              encodeBodyUtf8,
              decodeUtf8,
              alwaysAllowBody,
              isStreamingApi,
              client: client!,
              timeoutMs: _timeoutMs,
            )
                : await urlRequest(
              callType,
              apiUrl,
              headers,
              params,
              returnBody,
              decodeUtf8,
              isStreamingApi,
              client: client!,
              timeoutMs: _timeoutMs,
            );
            break;
          case ApiCallType.POST:
          case ApiCallType.PUT:
          case ApiCallType.PATCH:
            result = await requestWithBody(
              callType,
              apiUrl,
              headers,
              params,
              body,
              bodyType,
              returnBody,
              encodeBodyUtf8,
              decodeUtf8,
              alwaysAllowBody,
              isStreamingApi,
              client: client!,
              timeoutMs: _timeoutMs,
            );
            break;
        }

        if (cache) {
          _apiCache[callOptions] = result;
        }
      } catch (e) {
        result = ApiCallResponse(null, const {}, -1, exception: e);
      }

      // ----- LOG RESPONSE -----
      final status = result.statusCode;
      String bodyPreview;
      try {
        final txt = result.bodyText;
        bodyPreview = txt.length > 800 ? '${txt.substring(0, 800)}…' : txt;
      } catch (_) {
        bodyPreview = '<no-body>';
      }
      sw.stop();
      _apiLog('<< $callName [$status] in ${sw.elapsedMilliseconds}ms');
      _apiLog('   resp headers: ${result.headers}');
      _apiLog('   resp body: $bodyPreview');
      if (status == -1) {
        _apiLog('   EXC: ${result.exceptionMessage}');
      }

      return result;
    }

    futureCall = _doCall();
    if (dedupeInFlight) {
      _inflight[fp] = futureCall;
      try {
        final r = await futureCall;
        return r;
      } finally {
        _inflight.remove(fp);
      }
    } else {
      return await futureCall;
    }
  }
}
