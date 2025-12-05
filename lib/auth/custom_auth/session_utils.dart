import 'dart:convert';
import '/auth/custom_auth/auth_util.dart';
import '/backend/api_requests/api_manager.dart';

class CurrentUserInfo {
  final String? id;
  final String? member;
  final Map<String, dynamic>? rawUser;
  const CurrentUserInfo({this.id, this.member, this.rawUser});
}

class Session {
  static CurrentUserInfo currentUser() {
    final member = authManager.member;
    String? idFromUserData;
    Map<String, dynamic>? rawUser;

    try {
      final data = authManager.userData;
      if (data is Map) {
        rawUser = Map<String, dynamic>.from(
          data!.map((k, v) => MapEntry(k.toString(), v)),
        );
        final v = rawUser['id'];
        if (v != null) idFromUserData = v.toString();
      }
    } catch (_) {

    }


    String? idFromJwt;
    try {
      final token = ApiManager.accessToken;
      if (token != null && token.isNotEmpty) {
        final map = _jwtPayload(token);
        const keys = ['nameid', 'sub', 'uid', 'id', 'userId', 'user_id'];
        for (final k in keys) {
          final v = map[k];
          if (v != null && v.toString().isNotEmpty) {
            idFromJwt = v.toString();
            break;
          }
        }
      }
    } catch (_) {

    }

    return CurrentUserInfo(
      id: idFromUserData ?? idFromJwt,
      member: member,
      rawUser: rawUser,
    );
  }

  static String? userId() => currentUser().id;
  static String? memberRole() => currentUser().member;
  static bool hasMember(String role) =>
      (memberRole() ?? '').toUpperCase() == role.toUpperCase();
  static bool isAdmin() => hasMember('ADMIN');

  static Map<String, dynamic> _jwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return const {};
      final payload = utf8.decode(base64Url.decode(base64.normalize(parts[1])));
      final map = jsonDecode(payload);
      return (map is Map)
          ? Map<String, dynamic>.from(
        map.map((k, v) => MapEntry(k.toString(), v)),
      )
          : const {};
    } catch (_) {
      return const {};
    }
  }
}
