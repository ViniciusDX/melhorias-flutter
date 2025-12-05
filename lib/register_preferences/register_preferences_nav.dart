import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import '/menu/app_drawer.dart';
import 'register_screen.dart';
import 'drivers_screen.dart';
import 'favorite_places_screen.dart';

class RegisterPreferencesNav extends StatelessWidget {
  const RegisterPreferencesNav({
    super.key,
    required this.userId,
    this.userEmail,
    this.userPhone,
  });

  static const String routeName = 'RegisterPreferences';
  static const String routePath  = '/register-preferences';

  final int userId;
  final String? userEmail;
  final String? userPhone;

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.inter(fontWeight: FontWeight.w700);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        drawer: AppDrawer(
          onGoCarRequest: () => context.goNamed('CarRequest'),
          onGoDrivers: () => context.goNamed('Drivers'),
          onGoCars: () => context.goNamed('Cars'),
        ),
        appBar: AppBar(
          title: Text(
            'Register & Preferences',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          iconTheme: const IconThemeData(color: Colors.black87),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Register'),
              Tab(text: 'Drivers'),
              Tab(text: 'Places'),
            ],
            labelStyle: labelStyle,
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.black87,
          ),
        ),
        body: const TabBarView(
          children: [
            RegisterScreen(
            ),
            DriversScreen(),
            FavoritePlacesScreen(),
          ],
        ),
      ),
    );
  }
}
