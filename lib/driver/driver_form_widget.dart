import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/backend/api_requests/api_calls.dart';
import 'drivers_widget.dart' show DriverViewModel;
import 'package:mitsubishi/widgets/notifications/app_notifications.dart';

enum DriverFormMode { create, edit }

class DriverFormWidget extends StatefulWidget {
  const DriverFormWidget({
    super.key,
    this.mode = DriverFormMode.create,
    this.initial,
  });

  final DriverFormMode mode;
  final DriverViewModel? initial;

  @override
  State<DriverFormWidget> createState() => _DriverFormWidgetState();
}

class _DriverFormWidgetState extends State<DriverFormWidget> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _rgCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phone1Ctrl = TextEditingController();
  final _phone2Ctrl = TextEditingController();

  final LayerLink _companyLink = LayerLink();
  final GlobalKey _companyFieldBoxKey = GlobalKey();
  final GlobalKey<FormFieldState<String>> _companyFieldKey =
  GlobalKey<FormFieldState<String>>();
  OverlayEntry? _companyEntry;

  List<_Company> _companies = [];
  bool _loadingCompanies = false;
  int? _selectedCompanyId;
  String? _selectedCompanyName;
  String? _selectedCompanyEmail;

  bool _active = true;
  bool _presidence = false;
  bool _backup = false;
  bool _jpn = false;
  bool _eng = false;

  final ImagePicker _picker = ImagePicker();
  Uint8List? _avatarBytes;
  String? _photoUrl;
  bool _saving = false;

  static const kBlueOn = Color(0xFF84B6FF);
  static const kGreenOn = Color(0xFF8EE57F);
  static const kGreyOff = Color(0xFFE5E7EB);
  static const kRedOff = Color(0xFFFF7A78);

  String _clip(String s, int max) => s.length <= max ? s : s.substring(0, max);

  String? _normPhone(String? raw, {int max = 15}) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    return _clip(digits, max);
  }

  String? get _photoBase64 => _avatarBytes == null ? null : base64Encode(_avatarBytes!);

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    if (d != null) {
      _nameCtrl.text = d.name;
      _rgCtrl.text = d.rg ?? '';
      _emailCtrl.text = d.email;
      _phone1Ctrl.text = d.phone ?? '';
      _phone2Ctrl.text = d.phone2 ?? '';
      _active = d.active;
      _presidence = d.presidenceDriver;
      _backup = d.backupDriver;
      _jpn = d.speaksJpn;
      _eng = d.speaksEng;
      _photoUrl = d.base64Photo;

      _selectedCompanyId = d.companyId;
      _selectedCompanyName = d.company;
    }

    if (widget.mode == DriverFormMode.edit) {
      final id = int.tryParse(widget.initial?.id ?? '');
      if (id != null) _loadDriverDetail(id);
    }
  }

  Future<void> _loadDriverDetail(int id) async {
    try {
      final res = await DriverGetCall.call(id: id);
      if (!mounted) return;

      if (res.succeeded) {
        setState(() {
          _nameCtrl.text = DriverGetCall.fullName(res) ?? _nameCtrl.text;
          _emailCtrl.text = DriverGetCall.email(res) ?? _emailCtrl.text;
          _rgCtrl.text = DriverGetCall.rg(res) ?? _rgCtrl.text;
          _phone1Ctrl.text = DriverGetCall.phone(res) ?? _phone1Ctrl.text;
          _phone2Ctrl.text = DriverGetCall.phone2(res) ?? _phone2Ctrl.text;

          _active = DriverGetCall.active(res);
          _presidence = DriverGetCall.presidence(res);
          _backup = DriverGetCall.backup(res);
          _jpn = DriverGetCall.japanese(res);
          _eng = DriverGetCall.english(res);

          _selectedCompanyId = DriverGetCall.companyId(res) ?? _selectedCompanyId;
          _selectedCompanyName = DriverGetCall.companyName(res) ?? _selectedCompanyName;

          final b64 = DriverGetCall.base64Photo(res);
          if (b64 != null && b64.trim().isNotEmpty) {
            try {
              _avatarBytes = base64Decode(b64);
              _photoUrl = null;
            } catch (_) {}
          }
        });
      } else {
        AppNotifications.warning(
          context,
          'Failed to load driver data (${res.statusCode}).',
        );
      }
    } catch (_) {
      if (mounted) {
        AppNotifications.error(context, 'Error loading driver data.');
      }
    }
  }

  Future<void> _fetchCompanies() async {
    setState(() => _loadingCompanies = true);
    _companyEntry?.markNeedsBuild();

    try {
      final res = await RentalStoresListCall.call();
      if (!mounted) return;

      if (res.succeeded) {
        final items = RentalStoresListCall.items(res)
            .map((e) => _Company(
          id: RentalStoresListCall.id(e) ?? -1,
          name: RentalStoresListCall.name(e) ?? '-',
          email: RentalStoresListCall.email(e),
        ))
            .where((c) => c.id != -1)
            .toList();

        int? matchId;
        String? matchEmail;
        if ((_selectedCompanyName ?? '').trim().isNotEmpty) {
          final m = items.firstWhere(
                (c) => c.name.toLowerCase().trim() == _selectedCompanyName!.toLowerCase().trim(),
            orElse: () => _Company.empty(),
          );
          if (m.id != -1) {
            matchId = m.id;
            matchEmail = m.email;
          }
        }

        setState(() {
          _companies = items;
          _selectedCompanyId = _selectedCompanyId ?? matchId;
          _selectedCompanyEmail = matchEmail;
          _loadingCompanies = false;
        });

        _companyEntry?.markNeedsBuild();
      } else {
        setState(() => _loadingCompanies = false);
        _companyEntry?.markNeedsBuild();
        AppNotifications.error(
          context,
          'Failed to load companies (${res.statusCode}).',
        );
      }
    } catch (e) {
      setState(() => _loadingCompanies = false);
      _companyEntry?.markNeedsBuild();
      AppNotifications.error(context, 'Error loading companies.');
    }
  }

  @override
  void dispose() {
    _closeCompanyOverlay();
    _nameCtrl.dispose();
    _rgCtrl.dispose();
    _emailCtrl.dispose();
    _phone1Ctrl.dispose();
    _phone2Ctrl.dispose();
    super.dispose();
  }

  ImageProvider<Object>? _currentAvatarProvider() {
    if (_avatarBytes != null) return MemoryImage(_avatarBytes!);
    if (_photoUrl != null) return NetworkImage(_photoUrl!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final title = widget.mode == DriverFormMode.create ? 'Register Driver' : 'Edit Driver';

    InputDecoration _dec(String hint, {Widget? suffixIcon}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: theme.alternate.withOpacity(0.25)),
      ),
    );

    Widget _toggle(String label, bool value, ValueChanged<bool> onChanged,
        {required Color on, required Color off}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              CupertinoSwitch(
                value: value,
                activeColor: on,
                trackColor: off,
                onChanged: _saving ? null : onChanged,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF444444),
                ),
              ),
            ],
          ),
        );

    return WillPopScope(
      onWillPop: () async {
        if (_companyEntry != null) {
          _closeCompanyOverlay();
          return false;
        }
        return true;
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: const Color(0xFFF6F7F9),
            appBar: AppBar(
              title: Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: theme.primaryText,
                ),
              ),
              backgroundColor: theme.secondaryBackground,
              foregroundColor: theme.primaryText,
              elevation: 0.5,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Text(
                            'Profile Picture',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF3B3B3B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 52,
                                      backgroundColor: const Color(0xFFE5E7EB),
                                      backgroundImage: _currentAvatarProvider(),
                                      child: (_avatarBytes == null && _photoUrl == null)
                                          ? const Icon(Icons.person, size: 52, color: Color(0xFF9CA3AF))
                                          : null,
                                    ),
                                    Material(
                                      color: Colors.white,
                                      shape: const CircleBorder(),
                                      elevation: 2,
                                      child: IconButton(
                                        tooltip: 'Change photo',
                                        iconSize: 18,
                                        onPressed: _saving ? null : _chooseAvatarSource,
                                        icon: const Icon(Icons.camera_alt_outlined),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Register',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF3B3B3B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _nameCtrl,
                            inputFormatters: [LengthLimitingTextInputFormatter(120)],
                            decoration: _dec(
                              'Name',
                              suffixIcon: const Icon(Icons.person_outline, color: Color(0xFF9CA3AF)),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                            enabled: !_saving,
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _rgCtrl,
                            inputFormatters: [LengthLimitingTextInputFormatter(20)],
                            decoration:
                            _dec('RG', suffixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF9CA3AF))),
                            enabled: !_saving,
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            inputFormatters: [LengthLimitingTextInputFormatter(100)],
                            decoration:
                            _dec('E-mail', suffixIcon: const Icon(Icons.mail_outline, color: Color(0xFF9CA3AF))),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'E-mail is required';
                              final ok = RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim());
                              return ok ? null : 'Invalid e-mail';
                            },
                            enabled: !_saving,
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _phone1Ctrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9()+\- ]')),
                              LengthLimitingTextInputFormatter(20),
                            ],
                            decoration:
                            _dec('Telephone', suffixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF9CA3AF))),
                            enabled: !_saving,
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _phone2Ctrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9()+\- ]')),
                              LengthLimitingTextInputFormatter(20),
                            ],
                            decoration: _dec('Telephone 2',
                                suffixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF9CA3AF))),
                            enabled: !_saving,
                          ),
                          const SizedBox(height: 12),

                          FormField<String>(
                            key: _companyFieldKey,
                            validator: (_) => (_selectedCompanyId == null &&
                                (_selectedCompanyName == null || _selectedCompanyName!.trim().isEmpty))
                                ? 'Company is required'
                                : null,
                            builder: (state) {
                              final isEmpty = _selectedCompanyId == null &&
                                  (_selectedCompanyName == null || _selectedCompanyName!.trim().isEmpty);

                              String? selectedText;
                              if (_selectedCompanyId != null && _companies.isNotEmpty) {
                                selectedText = _companies
                                    .firstWhere(
                                      (e) => e.id == _selectedCompanyId,
                                  orElse: () => _Company.empty(),
                                )
                                    .name;
                                if (selectedText == '-') selectedText = _selectedCompanyName;
                              } else {
                                selectedText = _selectedCompanyName;
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CompositedTransformTarget(
                                    link: _companyLink,
                                    child: GestureDetector(
                                      key: _companyFieldBoxKey,
                                      onTap: _saving
                                          ? null
                                          : () {
                                        if (_companies.isEmpty && !_loadingCompanies) {
                                          _fetchCompanies();
                                        }
                                        _openCompanyOverlay();
                                      },
                                      child: InputDecorator(
                                        isEmpty: isEmpty,
                                        decoration: _dec(
                                          'Outsourcing Company',
                                          suffixIcon: Icon(
                                            Icons.expand_more,
                                            color: _saving ? Colors.black26 : const Color(0xFF9CA3AF),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: isEmpty
                                                  ? const SizedBox.shrink()
                                                  : Text(
                                                selectedText ?? '',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Color(0xFF111827)),
                                              ),
                                            ),
                                            if (_loadingCompanies)
                                              const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (state.hasError) ...[
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Company is required',
                                      style: TextStyle(color: Colors.red, fontSize: 12),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 10),

                          _toggle('Active', _active, (v) => setState(() => _active = v),
                              on: kGreenOn, off: kRedOff),
                          _toggle('Presidence\'s Driver', _presidence, (v) => setState(() => _presidence = v),
                              on: kBlueOn, off: kGreyOff),
                          _toggle('Backup Driver', _backup, (v) => setState(() => _backup = v),
                              on: kBlueOn, off: kGreyOff),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 2),
                              child: Text(
                                'Languages',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          _toggle('Japanese', _jpn, (v) => setState(() => _jpn = v), on: kBlueOn, off: kGreyOff),
                          _toggle('English', _eng, (v) => setState(() => _eng = v), on: kBlueOn, off: kGreyOff),

                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _onSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2ECC71),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text(widget.mode == DriverFormMode.create ? 'SAVE' : 'EDIT DRIVER'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_saving)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openCompanyOverlay() {
    _closeCompanyOverlay();
    final rb = _companyFieldBoxKey.currentContext!.findRenderObject() as RenderBox;
    final size = rb.size;

    _companyEntry = OverlayEntry(
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _closeCompanyOverlay,
          child: Stack(
            children: [
              CompositedTransformFollower(
                link: _companyLink,
                showWhenUnlinked: false,
                offset: Offset(0, size.height + 6),
                child: Material(
                  elevation: 10,
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 320,
                      minWidth: size.width,
                      maxWidth: size.width,
                    ),
                    child: _loadingCompanies
                        ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                        : (_companies.isEmpty
                        ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No companies found'),
                    )
                        : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemCount: _companies.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (_, i) {
                        final value = _companies[i];
                        final selected = value.id == _selectedCompanyId;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCompanyId = value.id;
                              _selectedCompanyName = value.name;
                              _selectedCompanyEmail = value.email;
                            });
                            _companyFieldKey.currentState?.didChange(value.name);
                            _closeCompanyOverlay();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    value.name,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                if (selected) const Icon(Icons.check, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    )),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_companyEntry!);
  }

  void _closeCompanyOverlay() {
    _companyEntry?.remove();
    _companyEntry = null;
  }

  void _closeAndPop<T>([T? result]) {
    _closeCompanyOverlay();
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _chooseAvatarSource() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Use camera'),
              onTap: () async {
                Navigator.pop(context);
                await _pickAvatar(ImageSource.camera);
              },
            ),
            if (_avatarBytes != null || _photoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _avatarBytes = null;
                    _photoUrl = null;
                  });
                },
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar(ImageSource src) async {
    final XFile? file = await _picker.pickImage(source: src, maxWidth: 1024, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _avatarBytes = bytes;
    });
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCompanyId == null) {
      AppNotifications.warning(context, 'Select a company');
      return;
    }

    setState(() => _saving = true);

    final phone1 = _normPhone(_phone1Ctrl.text);
    final phone2 = _normPhone(_phone2Ctrl.text);

    final Map<String, dynamic> body = {
      'fullName': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phoneNumber': phone1,
      'phoneNumber2': phone2,
      'rg': _rgCtrl.text.trim().isEmpty ? null : _rgCtrl.text.trim(),
      'active': _active,
      'presidenceDriver': _presidence,
      'backupDriver': _backup,
      'japanese': _jpn,
      'english': _eng,
      'companyId': _selectedCompanyId,
    };

    if (_avatarBytes != null) {
      body['base64DriverProfilePicture'] = _photoBase64;
    }

    try {
      ApiCallResponse res;
      final int? driverId = int.tryParse(widget.initial?.id ?? '');

      if (widget.mode == DriverFormMode.edit && driverId != null) {
        body['id'] = driverId;
        res = await DriverUpdateCall.call(id: driverId, body: body);
      } else {
        res = await DriverCreateCall.call(body: body);
      }

      if (!mounted) return;

      if (res.succeeded) {
        _closeAndPop(true);
      } else {
        final msg = _extractMessage(res.jsonBody) ?? 'Failed to save (${res.statusCode}).';
        AppNotifications.error(context, msg);
      }
    } catch (_) {
      if (mounted) AppNotifications.error(context, 'Error trying to save.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _extractMessage(dynamic body) {
    try {
      if (body == null) return null;

      if (body is String) {
        final s = body.replaceAll('"', '').trim();
        if (s.isNotEmpty) return s;
        return null;
      }

      if (body is Map) {
        if (body['errors'] is Map) {
          final errs = body['errors'] as Map;
          final msgs = <String>[];
          errs.forEach((_, v) {
            if (v is List && v.isNotEmpty) {
              msgs.add(v.first.toString());
            } else if (v is String && v.isNotEmpty) {
              msgs.add(v);
            }
          });
          if (msgs.isNotEmpty) return msgs.join('\n');
        }
        final m = body['title'] ?? body['message'] ?? body['Message'] ?? body['error'] ?? body['Error'];
        if (m != null) return m.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class _Company {
  final int id;
  final String name;
  final String? email;
  _Company({required this.id, required this.name, this.email});
  static _Company empty() => _Company(id: -1, name: '-', email: null);
}
