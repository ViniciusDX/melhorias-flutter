import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/api_requests/api_manager.dart';
import '/backend/api_requests/api_calls.dart' as API;
import '/widgets/notifications/app_notifications.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final _searchCtrl = TextEditingController();

  bool _showAll = true;
  bool _filterJpn = false;
  bool _filterEng = false;

  String? _error;
  final List<_Driver> _drivers = [];

  OverlayEntry? _pageLoadingOverlay;
  bool _bootstrapped = false;

  int? _userId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _resolveUserIdFromJwt();
        await _reload();
      });
    }
  }

  @override
  void dispose() {
    _hideLoadingOverlay();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolveUserIdFromJwt() async {
    try {
      final token = ApiManager.accessToken;
      if (token == null || token
          .split('.')
          .length != 3) return;
      final payloadB64 = token.split('.')[1];
      final normalized = base64Url.normalize(payloadB64);
      final payload = json.decode(
          utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      final nameId1 = payload['nameid'];
      final nameId2 = payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'];
      final sub = payload['sub'];
      final idStr = (nameId1 ?? nameId2 ?? sub)?.toString();
      _userId = int.tryParse(idStr ?? '');
    } catch (_) {}
  }

  void _showLoadingOverlay() {
    if (!mounted || _pageLoadingOverlay != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (_) =>
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black.withOpacity(0.25),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
    );

    final phase = SchedulerBinding.instance.schedulerPhase;
    final building = phase != SchedulerPhase.idle;
    if (building) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pageLoadingOverlay != null) return;
        overlay.insert(entry);
        _pageLoadingOverlay = entry;
      });
    } else {
      overlay.insert(entry);
      _pageLoadingOverlay = entry;
    }
  }

  void _hideLoadingOverlay() {
    _pageLoadingOverlay?.remove();
    _pageLoadingOverlay = null;
  }

  String _readString(dynamic m, List<String> keys, {String fallback = ''}) {
    if (m is Map) {
      final map = m.cast<String, dynamic>();
      for (final k in keys) {
        final v = map[k];
        if (v is String && v
            .trim()
            .isNotEmpty) return v.trim();
      }
    }
    return fallback;
  }

  bool _readBool(dynamic m, List<String> keys, {bool fallback = false}) {
    if (m is Map) {
      final map = m.cast<String, dynamic>();
      for (final k in keys) {
        final v = map[k];
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) {
          final s = v.toLowerCase();
          if (s == 'true' || s == '1') return true;
          if (s == 'false' || s == '0') return false;
        }
      }
    }
    return fallback;
  }

  String? _readPhotoBase64(dynamic m) {
    if (m is Map) {
      final map = m.cast<String, dynamic>();
      final keys = [
        'base64DriverProfilePicture',
        'photoBase64',
        'photo',
        'pictureBase64',
        'avatarBase64',
        'imageBase64'
      ];
      for (final k in keys) {
        final v = map[k];
        if (v is String && v
            .trim()
            .isNotEmpty) return v.trim();
      }
    }
    return null;
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _reload() async {
    if (_userId == null) {
      setState(() => _error = 'Could not resolve user id.');
      return;
    }
    _showLoadingOverlay();
    _error = null;
    _drivers.clear();
    setState(() {});

    try {
      final res = await API.UsersGetFavoriteDriversCall.call(
        userId: _userId!,
        bearerToken: ApiManager.accessToken,
      );

      if (!res.succeeded) {
        setState(() {
          _error = res.statusCode == 401
              ? 'Your session expired (401). Please sign in again.'
              : 'Failed to load drivers (${res.statusCode}).';
        });
        return;
      }

      final items = API.UsersGetFavoriteDriversCall.items(res);
      for (final it in items) {
        final id = API.UsersGetFavoriteDriversCall.id(it);
        if (id == null) continue;

        final isFav = API.UsersGetFavoriteDriversCall.isFavorite(it);
        final order = _readInt(API.UsersGetFavoriteDriversCall.favOrder(it));

        final name = _readString(it, ['name', 'fullName', 'displayName']);
        final email = _readString(it, ['email', 'mail']);
        final phone = _readString(
            it, ['phone', 'phoneNumber', 'mobile', 'cell']);
        final jpn = _readBool(it, ['japanese', 'isJpn', 'jpn']);
        final eng = _readBool(it, ['english', 'isEng', 'eng']);

        ImageProvider? photo;
        final b64 = _readPhotoBase64(it);
        if (b64 != null) {
          try {
            final bytes = base64Decode(b64);
            photo = MemoryImage(bytes);
          } catch (_) {}
        }

        _drivers.add(_Driver(
          id: id,
          name: name.isEmpty ? 'Driver #$id' : name,
          email: email,
          phone: phone.isEmpty ? null : phone,
          jpn: jpn,
          eng: eng,
          favorite: isFav,
          order: order,
          photo: photo,
        ));
      }

      setState(() {});
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      _hideLoadingOverlay();
    }
  }

  int _sortOrderKey(_Driver d) {
    if (d.order != null) return d.order!;
    return d.favorite ? 0 : 1 << 30;
  }

  int _nextFavoriteOrder() {
    final current = _drivers
        .where((d) => d.favorite && d.order != null)
        .map((d) => d.order!)
        .fold<int>(0, (m, e) => max(m, e));
    return current + 1;
  }

  int _nextNonFavoriteOrder() {
    final existing = _drivers
        .where((d) => !d.favorite && d.order != null)
        .map((d) => d.order!)
        .fold<int>(999, (m, e) => max(m, e));
    final next = existing + 1;
    return next < 1000 ? 1000 : next;
  }

  int? _minFavoriteOrder() {
    final orders = _drivers
        .where((d) => d.favorite && d.order != null)
        .map((d) => d.order!)
        .toList();
    if (orders.isEmpty) return null;
    return orders.reduce(min);
  }

  List<_Driver> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();

    Iterable<_Driver> base =
    _showAll ? _drivers : _drivers.where((d) => d.favorite);

    if (q.isNotEmpty) {
      base = base.where((d) =>
      d.name.toLowerCase().contains(q) ||
          d.email.toLowerCase().contains(q) ||
          (d.phone ?? '').toLowerCase().contains(q));
    }

    base = base.where((d) {
      if (_filterJpn && !d.jpn) return false;
      if (_filterEng && !d.eng) return false;
      return true;
    });

    final out = base.toList()
      ..sort((a, b) {
        final orderCmp = _sortOrderKey(a).compareTo(_sortOrderKey(b));
        if (orderCmp != 0) return orderCmp;
        return a.id.compareTo(b.id);
      });
    return out;
  }

  Future<void> _moveToTop(_Driver d) async {
    if (_userId == null) return;
    if (!d.favorite) return;
    _showLoadingOverlay();

    final prevOrders =
    Map<int, int?>.fromEntries(_drivers.map((x) => MapEntry(x.id, x.order)));
    setState(() {
      final minOrder = _minFavoriteOrder() ?? 1;
      d.order = minOrder - 1;
    });

    try {
      final res = await API.UsersMoveFavDriverToTopCall.call(
        userId: _userId!,
        driverId: d.id,
        bearerToken: ApiManager.accessToken,
      );

      if (!res.succeeded) {
        for (final x in _drivers) {
          x.order = prevOrders[x.id];
        }

        if (res.statusCode == 401) {
          AppNotifications.error(context, 'Your session expired (401). Please sign in again.');
        } else {
          AppNotifications.error(context, 'Failed to move driver to top.');
        }
      } else {
        await _reload();
        AppNotifications.success(context, 'Driver moved to the top.');
      }
    } catch (e) {
      for (final x in _drivers) {
        x.order = prevOrders[x.id];
      }
      AppNotifications.error(context, 'Error moving driver to top: $e');
    } finally {
      _hideLoadingOverlay();
    }
  }

  Future<void> _toggleFavorite(_Driver d, bool v) async {
    if (_userId == null) return;
    _showLoadingOverlay();

    final prevFavorite = d.favorite;
    final prevOrder = d.order;

    setState(() {
      d.favorite = v;
      if (v) {
        if (d.order == null || d.order! >= 1000) {
          d.order = _nextFavoriteOrder();
        }
      } else {
        d.order = _nextNonFavoriteOrder();
      }
    });

    try {
      final res = await API.UsersFavorDriverCall.call(
        userId: _userId!,
        driverId: d.id,
        isFavorite: v,
        bearerToken: ApiManager.accessToken,
      );

      if (!res.succeeded) {
        d.favorite = prevFavorite;
        d.order = prevOrder;

        if (res.statusCode == 401) {
          AppNotifications.error(context, 'Your session expired (401). Please sign in again.');
        } else {
          AppNotifications.error(context, 'Failed to update favorite.');
        }
      } else {
        AppNotifications.success(context, v ? 'Added to favorites.' : 'Removed from favorites.');
        await _reload();
      }
    } catch (e) {
      d.favorite = prevFavorite;
      d.order = prevOrder;
      AppNotifications.error(context, 'Error updating favorite: $e');
    } finally {
      _hideLoadingOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0x22000000)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterToggle(
                      icon: Icons.group,
                      label: 'All',
                      value: _showAll,
                      onChanged: (v) => setState(() => _showAll = v),
                    ),
                    _FilterToggle(
                      icon: Icons.translate,
                      label: 'Jpn',
                      value: _filterJpn,
                      onChanged: (v) => setState(() => _filterJpn = v),
                    ),
                    _FilterToggle(
                      icon: Icons.translate,
                      label: 'Eng',
                      value: _filterEng,
                      onChanged: (v) => setState(() => _filterEng = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _error != null
                    ? ListView(
                  children: const [
                    SizedBox(height: 120),
                  ],
                )
                    : _filtered.isEmpty
                    ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('No drivers found.')),
                    SizedBox(height: 12),
                    _EndFooter(),
                  ],
                )
                    : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _filtered.length + 1,
                  separatorBuilder: (_, i) => i >= _filtered.length
                      ? const SizedBox.shrink()
                      : const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    if (i == _filtered.length) {
                      return const _EndFooter();
                    }
                    final d = _filtered[i];
                    final displayOrder = d.favorite ? i + 1 : null;
                    return _DriverCard(
                      data: d,
                      displayOrder: displayOrder,
                      onToggleFav: (v) => _toggleFavorite(d, v),
                      onMoveTop: () => _moveToTop(d),
                    );
                  },
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterToggle extends StatelessWidget {
  const _FilterToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 3, offset: Offset(0, 1))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Transform.scale(
            scale: 1.0,
            child: Switch(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndFooter extends StatelessWidget {
  const _EndFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Center(child: Text('End of list')),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.data,
    required this.displayOrder,
    required this.onToggleFav,
    required this.onMoveTop,
  });

  final _Driver data;
  final int? displayOrder;
  final ValueChanged<bool> onToggleFav;
  final VoidCallback onMoveTop;

  @override
  Widget build(BuildContext context) {
    Widget langChip(String label, bool on) => Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      avatar: Icon(on ? Icons.check_circle : Icons.cancel,
          size: 16, color: on ? Colors.green : Colors.redAccent),
      side: BorderSide(color: on ? Colors.green : Colors.redAccent),
    );

    Widget photoBadge() {
      final label = displayOrder != null ? '#$displayOrder' : '-';
      final bg = displayOrder != null ? const Color(0xFF1E88E5) : Colors.black87;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1))
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
    }

    ImageProvider? avatarProvider() {
      if (data.photo != null) return data.photo!;
      return null;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: avatarProvider(),
                child: avatarProvider() == null
                    ? Text(data.initials, style: const TextStyle(fontWeight: FontWeight.w700))
                    : null,
              ),
              Positioned(right: -4, bottom: -4, child: photoBadge()),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF222222),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  data.email,
                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF5B5B5B)),
                ),
                const SizedBox(height: 4),
                if (data.phone != null)
                  Text(
                    '• ${data.phone}',
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF5B5B5B)),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: -6,
                  children: [
                    langChip('Jpn', data.jpn),
                    langChip('Eng', data.eng),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Transform.scale(
                scale: 0.95,
                child: Switch(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: data.favorite,
                  onChanged: onToggleFav,
                ),
              ),
              const SizedBox(height: 8),
              if (data.favorite)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onMoveTop,
                  child: const Text('Move to Top'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Driver {
  _Driver({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.jpn = false,
    this.eng = false,
    this.favorite = false,
    this.order,
    this.photo,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  bool jpn;
  bool eng;
  bool favorite;
  int? order;
  final ImageProvider? photo;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    String first(String s) => s.isNotEmpty ? s[0] : '';
    if (parts.length == 1) return first(parts[0]).toUpperCase();
    return (first(parts.first) + first(parts.last)).toUpperCase();
  }
}
