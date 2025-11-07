import 'package:rxdart/rxdart.dart';

class MitsubishiAuthUser {
  MitsubishiAuthUser({required this.loggedIn, this.uid});
  bool loggedIn;
  String? uid;
}

MitsubishiAuthUser? currentUser;
bool get loggedIn => currentUser?.loggedIn ?? false;

final BehaviorSubject<MitsubishiAuthUser> mitsubishiAuthUserSubject =
BehaviorSubject.seeded(MitsubishiAuthUser(loggedIn: false));

Stream<MitsubishiAuthUser> mitsubishiAuthUserStream() =>
    mitsubishiAuthUserSubject.asBroadcastStream().map((user) {
      currentUser = user;
      return user;
    });
