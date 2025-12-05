import 'custom_auth_manager.dart';
import 'custom_auth_user_provider.dart';

export 'custom_auth_manager.dart';

final _authManager = CustomAuthManager();
CustomAuthManager get authManager => _authManager;

String get currentUserUid => currentUser?.uid ?? '';
String? get currentAuthenticationToken => authManager.authenticationToken;
String? get currentAuthRefreshToken => authManager.refreshToken;
DateTime? get currentAuthTokenExpiration => authManager.tokenExpiration;

String? get currentUserMember => authManager.member;
String? get currentUserEmail  => authManager.email;
