import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:mitsubishi/backend/api_requests/api_calls.dart';
import 'package:mitsubishi/backend/api_requests/api_manager.dart';

import 'cost_allocation_details_screen.dart';
import '/widgets/add_fab_button.dart';
import '/widgets/notifications/app_notifications.dart';

import 'rp_models.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _GroupVM {
  final int id;
  String name;
  List<CostAllocationDetail> details;

  _GroupVM({required this.id, required this.name, required this.details});

  CostAllocationGroup toDomain() => CostAllocationGroup(name: name, details: details);

  static _GroupVM fromServer(Map<String, dynamic> map) {
    final id = (map['id'] ?? 0) as int;
    final name = (map['name'] ?? '').toString();
    final detailsRaw = (map['costAllocDetails'] as List?) ?? const [];
    final details = detailsRaw.map<CostAllocationDetail>((d) {
      final dm = (d as Map).cast<String, dynamic>();
      return CostAllocationDetail(
        code: (dm['name'] ?? '').toString(),
        percent: ((dm['percent'] ?? 0) as num).toDouble(),
      );
    }).toList();
    return _GroupVM(id: id, name: name, details: details);
  }
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _savingInfo = false;
  final List<_GroupVM> _groups = [];
  OverlayEntry? _pageLoadingOverlay;

  int? _userId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _hideLoadingOverlay();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _emailCtrl.text = '';
    _phoneCtrl.text = '';
    await _resolveUserIdFromJwt();
    await _fetchAndFillUser();
    await _reloadGroups();
  }

  Future<void> _resolveUserIdFromJwt() async {
    try {
      final token = ApiManager.accessToken;
      if (token == null || token.split('.').length != 3) return;
      final payloadB64 = token.split('.')[1];
      final normalized = base64Url.normalize(payloadB64);
      final payload = json.decode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      final nameId1 = payload['nameid'];
      final nameId2 = payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'];
      final sub = payload['sub'];
      final idStr = (nameId1 ?? nameId2 ?? sub)?.toString();
      final parsedId = int.tryParse(idStr ?? '');
      _userId = parsedId;
    } catch (_) {}
  }

  Future<void> _fetchAndFillUser() async {
    if (_userId == null) return;
    if (!_ensureAuthOrRedirect()) return;
    final res = await UsersGetByIdCall.call(
      userId: _userId!,
      bearerToken: ApiManager.accessToken,
    );
    if (res.succeeded) {
      final map = UsersGetByIdCall.map(res);
      final email = UsersGetByIdCall.email(map) ?? '';
      final phone = UsersGetByIdCall.phone(map) ?? '';
      if (mounted) {
        if (email.isNotEmpty) _emailCtrl.text = email;
        if (phone.isNotEmpty) _phoneCtrl.text = phone;
      }
    }
  }

  void _showLoadingOverlay() {
    if (!mounted || _pageLoadingOverlay != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;
    _pageLoadingOverlay = OverlayEntry(
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
    overlay.insert(_pageLoadingOverlay!);
  }

  void _hideLoadingOverlay() {
    _pageLoadingOverlay?.remove();
    _pageLoadingOverlay = null;
  }

  bool _ensureAuthOrRedirect() {
    final token = ApiManager.accessToken;
    final ok = token != null && token.trim().isNotEmpty;
    if (!ok) {
      AppNotifications.error(context, 'Session expired. Please sign in again.');
      if (mounted) context.goNamed('Login');
    }
    return ok;
  }

  void _handleUnauthorized() {
    AppNotifications.error(context, 'Your session expired (401). Please sign in again.');
    if (mounted) context.goNamed('Login');
  }

  bool _ensureUserId() {
    if (_userId == null) {
      AppNotifications.error(context, 'Could not resolve your user id.');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 12, bottom: 12),
        child: AddFabButton(
          heroTag: 'registerAddFab',
          onTap: _onAddGroup,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reloadAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              _sectionCard(
                title: 'Information',
                child: Column(
                  children: [
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: inputDecoration(
                        'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        const SimplePhoneFormatter(),
                      ],
                      decoration: inputDecoration(
                        'Phone',
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _savingInfo ? null : _onSaveInfo,
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Cost Allocation',
                child: (_groups.isEmpty)
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('No Cost Allocations yet.')),
                )
                    : Column(
                  children: _groups.map((g) => _groupTile(g)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    List<Widget>? actions,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (actions != null) ...actions,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _groupTile(_GroupVM g) {
    final subtitle = g.details.map((d) => '${d.code}: ${fmtPercent(d.percent)}').join('   •   ');
    return InkWell(
      onTap: () => _openGroupSheet(g),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle.isEmpty ? 'No details yet.' : subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openGroupSheet(_GroupVM g) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(g.name, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Details', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (g.details.isEmpty) const Text('No details yet. Tap "CHANGE DETAILS" to add.'),
                ...g.details.map(
                      (d) => Row(
                    children: [
                      const Text('• '),
                      Expanded(child: Text(d.code)),
                      Text(fmtPercent(d.percent)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _pillButton(
                  'RENAME',
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    final renamed = await AppNotifications.showRenameGroupModal(
                      context,
                      initial: g.name,
                    );
                    if ((renamed ?? '').trim().isEmpty) return;
                    final newName = renamed!.trim();
                    final ok = await _renameGroup(g, newName);
                    if (ok) {
                      setState(() => g.name = newName);
                      AppNotifications.success(context, 'Group renamed.');
                    }
                  },
                  bg: const Color(0xFF8BB9FF),
                ),
                const SizedBox(height: 10),
                _pillButton(
                  'CHANGE DETAILS',
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    await _onChangeDetails(g);
                  },
                  bg: const Color(0xFF3B82F6),
                ),
                const SizedBox(height: 10),
                _pillButton(
                  'DELETE',
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    await _onDeleteGroup(g);
                  },
                  bg: const Color(0xFFE34A48),
                ),
                const SizedBox(height: 10),
                _pillButton(
                  'CLOSE',
                  onPressed: () => Navigator.pop(sheetCtx),
                  bg: const Color(0xFFD4D4D4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pillButton(
      String label, {
        required VoidCallback onPressed,
        Color bg = const Color(0xFF8BB9FF),
      }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: Colors.black12,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _reloadAll() async {
    await _fetchAndFillUser();
    await _reloadGroups();
  }

  Future<void> _reloadGroups() async {
    if (!_ensureAuthOrRedirect()) return;
    if (!_ensureUserId()) return;

    _showLoadingOverlay();
    try {
      final resp = await GetCostAllocations.call(
        userId: _userId!,
        bearerToken: ApiManager.accessToken,
      );

      if (!mounted) return;

      if (resp.succeeded == true && resp.jsonBody != null) {
        final parsed = _parseGroupsFromServer(resp.jsonBody);
        setState(() {
          _groups
            ..clear()
            ..addAll(parsed);
        });
      } else {
        if (resp.statusCode == 401) {
          _handleUnauthorized();
        } else {
          AppNotifications.error(context, 'Failed to load Cost Allocations.');
        }
      }
    } catch (_) {
      if (mounted) {
        AppNotifications.error(context, 'Error loading Cost Allocations.');
      }
    } finally {
      _hideLoadingOverlay();
    }
  }

  List<_GroupVM> _parseGroupsFromServer(dynamic body) {
    if (body == null) return [];
    final list = (body as List).cast<dynamic>();
    return list.map<_GroupVM>((item) {
      final map = (item as Map).cast<String, dynamic>();
      return _GroupVM.fromServer(map);
    }).toList();
  }

  Future<void> _onAddGroup() async {
    if (!_ensureAuthOrRedirect()) return;
    if (!_ensureUserId()) return;

    final name = await AppNotifications.showRenameGroupModal(
      context,
      initial: '',
    );

    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return;

    final payload = {'Id': 0, 'UserId': _userId, 'Name': trimmed};

    _showLoadingOverlay();
    try {
      final res = await CostAllocationsAddOrEditCall.call(
        costAllocation: payload,
        bearerToken: ApiManager.accessToken,
      );

      if (!mounted) return;

      if (res.succeeded == true) {
        await _reloadGroups();
        AppNotifications.success(context, 'Group created.');
      } else {
        if (res.statusCode == 401) {
          _handleUnauthorized();
        } else {
          AppNotifications.error(context, 'Failed to create group.');
        }
      }
    } catch (_) {
      if (mounted) {
        AppNotifications.error(context, 'Error creating group.');
      }
    } finally {
      _hideLoadingOverlay();
    }
  }

  Future<bool> _renameGroup(_GroupVM g, String newName) async {
    if (!_ensureAuthOrRedirect()) return false;
    if (!_ensureUserId()) return false;

    final payload = {'Id': g.id, 'UserId': _userId, 'Name': newName};

    _showLoadingOverlay();
    try {
      final res = await CostAllocationsAddOrEditCall.call(
        costAllocation: payload,
        bearerToken: ApiManager.accessToken,
      );

      if (!mounted) return false;

      if (res.succeeded == true) {
        return true;
      } else {
        if (res.statusCode == 401) {
          _handleUnauthorized();
        } else {
          AppNotifications.error(context, 'Failed to rename group.');
        }
        return false;
      }
    } catch (_) {
      if (mounted) {
        AppNotifications.error(context, 'Error renaming group.');
      }
      return false;
    } finally {
      _hideLoadingOverlay();
    }
  }

  Future<void> _onChangeDetails(_GroupVM g) async {
    final updated = await Navigator.of(context).push<CostAllocationGroup>(
      MaterialPageRoute(
        builder: (_) => CostAllocationDetailsScreen(
          costAllocId: g.id,
          initial: g.toDomain(),
          userLabel: 'USER • ${g.name}',
        ),
      ),
    );

    if (updated != null) {
      setState(() {
        g.name = updated.name;
        g.details = updated.details;
      });
      AppNotifications.success(context, 'Cost Allocation updated.');
    }
  }

  Future<bool> _saveUserPreferences({
    required String email,
    required String phoneNumber,
  }) async {
    if (!_ensureAuthOrRedirect()) return false;
    if (!_ensureUserId()) return false;

    _showLoadingOverlay();
    try {
      final res = await UsersPreferencesCall.call(
        id: _userId!,
        email: email,
        phoneNumber: phoneNumber,
        bearerToken: ApiManager.accessToken,
      );

      if (!mounted) return false;

      if (res.succeeded == true) {
        return true;
      } else {
        if (res.statusCode == 401) {
          _handleUnauthorized();
        } else {
          AppNotifications.error(
            context,
            'Failed to save information (${res.statusCode}).',
          );
        }
        return false;
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.error(context, 'Unexpected error: $e');
      }
      return false;
    } finally {
      _hideLoadingOverlay();
    }
  }

  Future<void> _onDeleteGroup(_GroupVM g) async {
    if (!_ensureAuthOrRedirect()) return;

    final ok = await AppNotifications.confirmDanger(
      context,
      title: 'Delete group',
      message: 'This will remove "${g.name}" and its allocation details.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
    );

    if (!ok) return;

    _showLoadingOverlay();
    try {
      final res = await CostAllocationsDeleteCall.call(
        id: g.id,
        bearerToken: ApiManager.accessToken,
      );

      if (!mounted) return;

      if (res.succeeded == true) {
        setState(() => _groups.remove(g));
        AppNotifications.success(context, 'Group deleted.');
      } else {
        if (res.statusCode == 401) {
          _handleUnauthorized();
        } else {
          AppNotifications.error(context, 'Failed to delete group.');
        }
      }
    } catch (_) {
      if (mounted) {
        AppNotifications.error(context, 'Error deleting group.');
      }
    } finally {
      _hideLoadingOverlay();
    }
  }

  Future<void> _onSaveInfo() async {
    if (_savingInfo) return;
    setState(() => _savingInfo = true);
    try {
      final email = _emailCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();

      if (email.isEmpty || !email.contains('@')) {
        AppNotifications.error(context, 'Please enter a valid email.');
        return;
      }
      if (phone.isEmpty) {
        AppNotifications.error(context, 'Please enter a phone number.');
        return;
      }

      final ok = await _saveUserPreferences(
        email: email,
        phoneNumber: phone,
      );

      if (ok) {
        await _fetchAndFillUser();
        AppNotifications.success(context, 'Information saved!');
      }
    } finally {
      if (mounted) setState(() => _savingInfo = false);
    }
  }
}

class SimplePhoneFormatter extends TextInputFormatter {
  const SimplePhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 11; i++) {
      final c = digits[i];
      if (i == 0) buf.write('(');
      if (i == 2) buf.write(') ');
      if (i == 7) buf.write('-');
      buf.write(c);
    }
    return TextEditingValue(
      text: buf.toString(),
      selection: TextSelection.collapsed(offset: buf.length),
    );
  }
}

InputDecoration inputDecoration(
    String label, {
      Widget? prefixIcon,
    }) {
  return InputDecoration(
    labelText: label,
    prefixIcon: prefixIcon,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
  );
}
