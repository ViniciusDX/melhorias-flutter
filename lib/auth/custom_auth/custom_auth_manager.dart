import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'custom_auth_user_provider.dart';

const _kAuthTokenKey = '_auth_authentication_token_';
const _kRefreshTokenKey = '_auth_refresh_token_';
const _kTokenExpirationKey = '_auth_token_expiration_';
const _kUidKey = '_auth_uid_';
const _kUserDataKey = '_auth_user_data_';

class CustomAuthManager {
  String? authenticationToken;
  String? refreshToken;
  DateTime? tokenExpiration;
  String? uid;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? get userData => _userData;
  String? get member => _userData?['member']?.toString();
  String? get email  => _userData?['email']?.toString();

  void setUserData(Map<String, dynamic>? data) {
    _userData = data;
    persistAuthData();
  }

  Future signOut() async {
    authenticationToken = null;
    refreshToken = null;
    tokenExpiration = null;
    uid = null;
    _userData = null;

    mitsubishiAuthUserSubject.add(MitsubishiAuthUser(loggedIn: false));
    persistAuthData();
  }

  Future<MitsubishiAuthUser?> signIn({
    String? authenticationToken,
    String? refreshToken,
    DateTime? tokenExpiration,
    String? authUid,
  }) async =>
      _updateCurrentUser(
        authenticationToken: authenticationToken,
        refreshToken: refreshToken,
        tokenExpiration: tokenExpiration,
        authUid: authUid,
      );

  void updateAuthUserData({
    String? authenticationToken,
    String? refreshToken,
    DateTime? tokenExpiration,
    String? authUid,
  }) {
    assert(loggedIn, 'User must be logged in to update auth user data.');
    _updateCurrentUser(
      authenticationToken: authenticationToken,
      refreshToken: refreshToken,
      tokenExpiration: tokenExpiration,
      authUid: authUid,
    );
  }

  MitsubishiAuthUser? _updateCurrentUser({
    String? authenticationToken,
    String? refreshToken,
    DateTime? tokenExpiration,
    String? authUid,
  }) {
    this.authenticationToken = authenticationToken ?? this.authenticationToken;
    this.refreshToken = refreshToken ?? this.refreshToken;
    this.tokenExpiration = tokenExpiration ?? this.tokenExpiration;
    this.uid = authUid ?? this.uid;

    final updatedUser = MitsubishiAuthUser(loggedIn: true, uid: this.uid);
    mitsubishiAuthUserSubject.add(updatedUser);
    persistAuthData();
    return updatedUser;
  }

  late SharedPreferences _prefs;
  Future initialize() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      authenticationToken = _prefs.getString(_kAuthTokenKey);
      refreshToken = _prefs.getString(_kRefreshTokenKey);
      tokenExpiration = _prefs.getInt(_kTokenExpirationKey) != null
          ? DateTime.fromMillisecondsSinceEpoch(
          _prefs.getInt(_kTokenExpirationKey)!)
          : null;
      uid = _prefs.getString(_kUidKey);

      final userDataStr = _prefs.getString(_kUserDataKey);
      if (userDataStr != null && userDataStr.isNotEmpty) {
        final decoded = jsonDecode(userDataStr);
        if (decoded is Map<String, dynamic>) _userData = decoded;
      }
    } catch (e) {
      if (kDebugMode) print('Error initializing auth: $e');
      return;
    }

    final authTokenExists = authenticationToken != null;
    final tokenExpired =
        tokenExpiration != null && tokenExpiration!.isBefore(DateTime.now());

    final updatedUser =
    MitsubishiAuthUser(loggedIn: authTokenExists && !tokenExpired, uid: uid);
    mitsubishiAuthUserSubject.add(updatedUser);
  }

  void persistAuthData() {
    authenticationToken != null
        ? _prefs.setString(_kAuthTokenKey, authenticationToken!)
        : _prefs.remove(_kAuthTokenKey);
    refreshToken != null
        ? _prefs.setString(_kRefreshTokenKey, refreshToken!)
        : _prefs.remove(_kRefreshTokenKey);
    tokenExpiration != null
        ? _prefs.setInt(
        _kTokenExpirationKey, tokenExpiration!.millisecondsSinceEpoch)
        : _prefs.remove(_kTokenExpirationKey);
    uid != null ? _prefs.setString(_kUidKey, uid!) : _prefs.remove(_kUidKey);

    if (_userData != null) {
      _prefs.setString(_kUserDataKey, jsonEncode(_userData));
    } else {
      _prefs.remove(_kUserDataKey);
    }
  }
}
