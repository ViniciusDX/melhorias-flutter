import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/api_requests/api_calls.dart';
import 'cars_widget.dart' show CarViewModel;
import 'package:mitsubishi/widgets/notifications/app_notifications.dart';

enum CarFormMode { create, edit }

class CarFormWidget extends StatefulWidget {
  const CarFormWidget({
    super.key,
    this.mode = CarFormMode.create,
    this.initial,
  });

  final CarFormMode mode;
  final CarViewModel? initial;

  @override
  State<CarFormWidget> createState() => _CarFormWidgetState();
}

class _CarFormWidgetState extends State<CarFormWidget> {
  final _formKey = GlobalKey<FormState>();

  final _modelCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  bool _isActive = true;
  bool _isPresidence = false;

  final GlobalKey _colorFieldKey = GlobalKey();
  OverlayEntry? _colorOverlay;
  bool _colorOpen = false;

  List<_CarColor> _colors = [];
  bool _loadingColors = true;
  String? _selectedColorId;

  static const kBlueOn = Color(0xFF84B6FF);
  static const kGreenOn = Color(0xFF8EE57F);
  static const kGreyOff = Color(0xFFE5E7EB);
  static const kRedOff = Color(0xFFFF7A78);

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    if (c != null) {
      _modelCtrl.text = c.model;
      _kmCtrl.text = '${c.km}';
      _plateCtrl.text = c.licensePlate;

      _isActive = c.isActive;
      _isPresidence = c.isPresidence;
    }
    _fetchColors();
  }

  Future<void> _fetchColors() async {
    setState(() => _loadingColors = true);
    try {
      final res = await CarsColorsCall.call();
      if (!mounted) return;
      if (res.succeeded) {
        final items = CarsColorsCall.items(res)
            .map((e) => _CarColor.fromJson(e))
            .whereType<_CarColor>()
            .toList();

        String? preselectId;
        final initialId = widget.initial?.colorId;
        if (initialId != null && initialId.trim().isNotEmpty) {
          final has = items.any((x) => (x.id ?? '') == initialId);
          if (has) preselectId = initialId;
        }
        if (preselectId == null) {
          final initialName = widget.initial?.colorName;
          if (initialName != null && initialName.trim().isNotEmpty) {
            final found = items.firstWhere(
                  (x) => (x.color ?? '').toLowerCase() == initialName.toLowerCase(),
              orElse: () => _CarColor.empty(),
            );
            preselectId = found.id;
          }
        }

        setState(() {
          _colors = items;
          _selectedColorId = preselectId;
          _loadingColors = false;
        });
      } else {
        setState(() => _loadingColors = false);
        AppNotifications.error(
          context,
          'Failed to load colors (${res.statusCode}).',
        );
      }
    } catch (e) {
      setState(() => _loadingColors = false);
      AppNotifications.error(context, 'Error loading colors.');
    }
  }

  @override
  void dispose() {
    _closeColorOverlay(quietly: true);
    _modelCtrl.dispose();
    _kmCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(BuildContext context, String hint, {Widget? suffixIcon}) {
    final theme = FlutterFlowTheme.of(context);
    return InputDecoration(
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
  }

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
              onChanged: onChanged,
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

  void _toggleColorOverlay(FormFieldState<String> state) {
    if (_colorOpen) {
      _closeColorOverlay();
    } else {
      _openColorOverlay(state);
    }
  }

  void _openColorOverlay(FormFieldState<String> state) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final box = _colorFieldKey.currentContext!.findRenderObject() as RenderBox;
    final size = box.size;
    final offset = box.localToGlobal(Offset.zero);

    final media = MediaQuery.of(context);
    final availableBelow = media.size.height - (offset.dy + size.height);
    final maxHeight = (availableBelow - 12).clamp(180.0, 320.0);

    _colorOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeColorOverlay,
                child: const SizedBox.shrink(),
              ),
            ),
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height,
              width: size.width,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _loadingColors
                      ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: _colors.length,
                    itemBuilder: (_, i) {
                      final c = _colors[i];
                      final isSelected = c.id == _selectedColorId;
                      return InkWell(
                        onTap: () {
                          setState(() => _selectedColorId = c.id);
                          state.didChange(c.id);
                          _closeColorOverlay();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              _colorDot(c.id),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  c.color ?? '(no name)',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check,
                                    size: 18, color: Color(0xFF2563EB)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_colorOverlay!);
    setState(() => _colorOpen = true);
  }

  void _closeColorOverlay({bool quietly = false}) {
    _colorOverlay?.remove();
    _colorOverlay = null;
    _colorOpen = false;
    if (!quietly && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final title =
    widget.mode == CarFormMode.create ? 'Register Car' : 'Edit Car';

    final selectedColorName =
        _colors.firstWhere(
              (e) => e.id == _selectedColorId,
          orElse: () => _CarColor.empty(),
        ).color ??
            'Select a color';

    return Scaffold(
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
                      controller: _modelCtrl,
                      decoration: _dec(
                        context,
                        'Model',
                        suffixIcon: const Icon(
                          Icons.directions_car_outlined,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Model is required'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _kmCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _dec(
                        context,
                        'Km',
                        suffixIcon:
                        const Icon(Icons.route, color: Color(0xFF9CA3AF)),
                      ),
                      validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Km is required'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _plateCtrl,
                      decoration: _dec(
                        context,
                        'License Plate',
                        suffixIcon: const Icon(
                          Icons.confirmation_number_outlined,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'License Plate is required'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    FormField<String>(
                      validator: (_) =>
                      (_selectedColorId == null || _selectedColorId!.isEmpty)
                          ? 'Color is required'
                          : null,
                      builder: (state) {
                        final hasSelection =
                            _selectedColorId != null && _selectedColorId!.isNotEmpty;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              key: _colorFieldKey,
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                _toggleColorOverlay(state);
                              },
                              child: InputDecorator(
                                isEmpty: !hasSelection,
                                decoration: _dec(
                                  context,
                                  'Select a color',
                                  suffixIcon: Icon(
                                    _colorOpen
                                        ? Icons.expand_less
                                        : Icons.expand_more_rounded,
                                    size: 22,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (hasSelection) _colorDot(_selectedColorId),
                                    if (hasSelection) const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        selectedColorName,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          color: hasSelection
                                              ? const Color(0xFF111827)
                                              : const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (state.hasError)
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 6),
                                child: Text(
                                  state.errorText!,
                                  style: TextStyle(
                                    color: theme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _toggle(
                      'Presidence Car',
                      _isPresidence,
                          (v) => setState(() => _isPresidence = v),
                      on: kBlueOn,
                      off: kGreyOff,
                    ),
                    _toggle(
                      'Active',
                      _isActive,
                          (v) => setState(() => _isActive = v),
                      on: kGreenOn,
                      off: kRedOff,
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          widget.mode == CarFormMode.create ? 'SAVE' : 'EDIT CAR',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _colorDot(String? hex) {
    final c = _tryParseHexColor(hex);
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: c ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
    );
  }

  Color? _tryParseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      var clean = hex.toUpperCase().replaceAll('#', '');
      if (clean.length == 6) clean = 'FF$clean';
      final value = int.parse(clean, radix: 16);
      return Color(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedColorId == null || _selectedColorId!.isEmpty) {
      AppNotifications.warning(context, 'Select a color');
      return;
    }

    final km = int.tryParse(_kmCtrl.text.trim()) ?? 0;

    final body = <String, dynamic>{
      'description': _modelCtrl.text.trim(),
      'km': km,
      'licensePlate': _plateCtrl.text.trim(),
      'carColorId': _selectedColorId,
      'presidenceCar': _isPresidence,
      'active': _isActive,
    };

    try {
      ApiCallResponse res;
      if (widget.mode == CarFormMode.edit) {
        final int? idInt = int.tryParse(widget.initial?.id ?? '');
        if (idInt == null) {
          AppNotifications.error(context, 'Invalid ID for editing.');
          return;
        }
        res = await CarUpdateCall.call(id: idInt, body: body);
      } else {
        res = await CarCreateCall.call(body: body);
      }

      if (!mounted) return;

      if (res.succeeded) {
        final carVm = CarViewModel(
          id: widget.initial?.id ?? 'c${DateTime.now().microsecondsSinceEpoch}',
          model: _modelCtrl.text.trim(),
          km: km,
          licensePlate: _plateCtrl.text.trim(),
          colorName: _colors
              .firstWhere((x) => x.id == _selectedColorId,
              orElse: () => _CarColor.empty())
              .color ??
              '',
          isActive: _isActive,
          isAvailable: widget.initial?.isAvailable ?? true,
          isPresidence: _isPresidence,
          colorId: _selectedColorId,
        );
        Navigator.pop(context, carVm);
      } else if (res.statusCode == 409) {
        final msg =
            _extractMessage(res.jsonBody) ?? 'Conflict when saving the car.';
        AppNotifications.error(context, msg);
      } else {
        AppNotifications.error(
            context, 'Failed to save (${res.statusCode}).');
      }
    } catch (e) {
      AppNotifications.error(context, 'Error trying to save.');
    }
  }

  String? _extractMessage(dynamic body) {
    try {
      if (body == null) return null;
      if (body is Map) {
        final m = body['message'] ??
            body['Message'] ??
            body['error'] ??
            body['Error'];
        return m?.toString();
      }
      if (body is String) return body;
      try {
        return getJsonField(body, r'$.message')?.toString();
      } catch (_) {}
      return null;
    } catch (_) {
      return null;
    }
  }
}

class _CarColor {
  final String? id;
  final String? color;
  final String? textColor;

  _CarColor({this.id, this.color, this.textColor});

  factory _CarColor.fromJson(dynamic json) {
    return _CarColor(
      id: CarsColorsCall.id(json),
      color: CarsColorsCall.color(json),
      textColor: CarsColorsCall.textColor(json),
    );
  }

  static _CarColor empty() => _CarColor(id: null, color: null, textColor: null);
}
