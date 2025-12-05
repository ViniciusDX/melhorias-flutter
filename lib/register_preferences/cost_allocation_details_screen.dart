import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mitsubishi/flutter_flow/flutter_flow_util.dart';

import '/backend/api_requests/api_calls.dart';
import '/backend/api_requests/api_manager.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/widgets/notifications/app_notifications.dart';
import '/widgets/add_fab_button.dart';
import 'rp_models.dart';

class CostAllocationDetailsScreen extends StatefulWidget {
  const CostAllocationDetailsScreen({
    super.key,
    required this.costAllocId,
    required this.initial,
    this.userLabel,
  });

  final int costAllocId;
  final CostAllocationGroup initial;
  final String? userLabel;

  @override
  State<CostAllocationDetailsScreen> createState() =>
      _CostAllocationDetailsScreenState();
}

class _DetailVM {
  int? id;
  String code;
  double percent;
  _DetailVM({this.id, required this.code, required this.percent});

  _DetailVM copy() => _DetailVM(id: id, code: code, percent: percent);

  Map<String, dynamic> toApiPayload(int costAllocId) => {
    'Id': id ?? 0,
    'CostAllocationId': costAllocId,
    'Name': code,
    'Percent': percent,
  };
}

class _CostAllocationDetailsScreenState
    extends State<CostAllocationDetailsScreen> {
  late List<_DetailVM> _items = widget.initial.details
      .map((e) => _DetailVM(code: e.code, percent: e.percent))
      .toList();

  List<_DetailVM> _serverSnapshot = [];

  double get _total =>
      _items.fold<double>(0, (p, e) => p + (e.percent.isNaN ? 0 : e.percent));

  String _fmtP(double v) => fmtPercent(v);

  OverlayEntry? _loadingOverlay;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadFromServer);
  }

  @override
  void dispose() {
    _hideLoading();
    super.dispose();
  }

  void _showLoading() {
    if (!mounted || _loadingOverlay != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;
    _loadingOverlay = OverlayEntry(
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
    overlay.insert(_loadingOverlay!);
  }

  void _hideLoading() {
    _loadingOverlay?.remove();
    _loadingOverlay = null;
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

  Future<void> _loadFromServer() async {
    if (!_ensureAuthOrRedirect()) return;
    _showLoading();
    try {
      final res = await CostAllocDetailsGetByCostAllocCall.call(
        costAllocId: widget.costAllocId,
        bearerToken: ApiManager.accessToken,
      );

      if (!mounted) return;

      if (res.succeeded) {
        final items = CostAllocDetailsGetByCostAllocCall.items(res);
        _serverSnapshot = items.map<_DetailVM>((d) {
          return _DetailVM(
            id: CostAllocDetailsGetByCostAllocCall.id(d),
            code: CostAllocDetailsGetByCostAllocCall.name(d),
            percent: CostAllocDetailsGetByCostAllocCall.percent(d),
          );
        }).toList();

        if (_serverSnapshot.isNotEmpty) {
          setState(() {
            _items = _serverSnapshot.map((e) => e.copy()).toList();
          });
        }
      } else if (res.statusCode == 401) {
        _handleUnauthorized();
      } else {
        AppNotifications.error(context, 'Failed to load details (${res.statusCode}).');
      }
    } catch (_) {
      if (mounted) {
        AppNotifications.error(context, 'Error loading details.');
      }
    } finally {
      _hideLoading();
    }
  }

  Future<void> _add() async {
    final created = await AppNotifications.showCostAllocationDetailModal(
      context,
      title: 'Cost Allocation Detail',
    );
    if (created == null) return;

    final remaining = _remainingPercent();
    if (created.percent > remaining + 1e-6) {
      AppNotifications.error(
        context,
        'Total would exceed 100%. Remaining allowed: ${fmtPercent(remaining)}',
      );
      return;
    }
    final exists = _items.any(
          (d) => d.code.trim().toLowerCase() == created.code.trim().toLowerCase(),
    );
    if (exists) {
      AppNotifications.error(context, 'This BU/code is already in the list.');
      return;
    }

    if (!_ensureAuthOrRedirect()) return;

    _showLoading();
    try {
      final res = await CostAllocDetailsAddOrEditCall.call(
        bearerToken: ApiManager.accessToken,
        body: {
          'Id': 0,
          'CostAllocationId': widget.costAllocId,
          'Name': created.code,
          'Percent': created.percent,
        },
      );
      if (!mounted) return;

      if (!res.succeeded) {
        if (res.statusCode == 401) _handleUnauthorized();
        else AppNotifications.error(context, 'Failed to save detail (${res.statusCode}).');
        return;
      }

      int? newId;
      try {
        final j = res.jsonBody;
        newId = getJsonField(j, r'$.id');
      } catch (_) {}

      setState(() {
        _items.add(_DetailVM(id: newId, code: created.code, percent: created.percent));
      });
      AppNotifications.success(context, 'Detail added');
    } finally {
      _hideLoading();
    }
  }

  Future<void> _edit(int index) async {
    final original = _items[index];

    final editedRaw = await AppNotifications.showCostAllocationDetailModal(
      context,
      title: 'Cost Allocation Detail',
      initial: CostAllocationDetail(code: original.code, percent: original.percent),
    );
    if (editedRaw == null) return;

    final remaining = _remainingPercent(excludingIndex: index);
    if (editedRaw.percent > remaining + 1e-6) {
      AppNotifications.error(
        context,
        'Total would exceed 100%. Remaining allowed: ${fmtPercent(remaining)}',
      );
      return;
    }
    final existsSameCode = _items.asMap().entries.any(
          (e) =>
      e.key != index &&
          e.value.code.trim().toLowerCase() == editedRaw.code.trim().toLowerCase(),
    );
    if (existsSameCode) {
      AppNotifications.error(context, 'This BU/code is already in the list.');
      return;
    }

    if (!_ensureAuthOrRedirect()) return;

    _showLoading();
    try {
      final res = await CostAllocDetailsAddOrEditCall.call(
        bearerToken: ApiManager.accessToken,
        body: {
          'Id': original.id ?? 0,
          'CostAllocationId': widget.costAllocId,
          'Name': editedRaw.code,
          'Percent': editedRaw.percent,
        },
      );
      if (!mounted) return;

      if (!res.succeeded) {
        if (res.statusCode == 401) _handleUnauthorized();
        else AppNotifications.error(context, 'Failed to save detail (${res.statusCode}).');
        return;
      }

      setState(() {
        original.code = editedRaw.code;
        original.percent = editedRaw.percent;
      });
      AppNotifications.success(context, 'Detail updated');
    } finally {
      _hideLoading();
    }
  }

  Future<void> _delete(int index) async {
    final d = _items[index];
    final ok = await AppNotifications.confirmDanger(
      context,
      title: 'Delete',
      message: 'Remove "${d.code}"?',
      confirmLabel: 'Delete',
    );
    if (!ok) return;

    if (!_ensureAuthOrRedirect()) return;

    if (d.id == null) {
      setState(() => _items.removeAt(index));
      AppNotifications.success(context, 'Removed');
      return;
    }

    _showLoading();
    try {
      final res = await CostAllocDetailsDeleteCall.call(
        id: d.id!,
        bearerToken: ApiManager.accessToken,
      );
      if (!mounted) return;

      if (!res.succeeded) {
        if (res.statusCode == 401) _handleUnauthorized();
        else AppNotifications.error(context, 'Failed to delete detail (${res.statusCode}).');
        return;
      }

      setState(() => _items.removeAt(index));
      AppNotifications.success(context, 'Removed');
    } finally {
      _hideLoading();
    }
  }

  void _openRowSheet(int index) {
    final d = _items[index];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Text('${d.code} — ${_fmtP(d.percent)}',
                  style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _pill('EDIT DETAIL', const Color(0xFF3B82F6), () {
                Navigator.pop(sheetCtx);
                _edit(index);
              }),
              const SizedBox(height: 10),
              _pill('DELETE DETAIL', const Color(0xFFE34A48), () async {
                Navigator.pop(sheetCtx);
                await _delete(index);
              }),
              const SizedBox(height: 10),
              _pill('CLOSE', const Color(0xFFD4D4D4), () {
                Navigator.pop(sheetCtx);
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return WillPopScope(
      onWillPop: () async {
        final isOk = (_total - 100).abs() < 0.0001;
        if (!isOk) {
          AppNotifications.error(
            context,
            'The total must be 100% to continue.',
          );
          return false;
        }

        Navigator.of(context).pop<CostAllocationGroup>(
          CostAllocationGroup(
            name: widget.initial.name,
            details: _items
                .map((e) => CostAllocationDetail(code: e.code, percent: e.percent))
                .toList(),
          ),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: theme.secondaryBackground,
        appBar: AppBar(
          elevation: 0.5,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title: Text(
            'Cost Allocation Details',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800),
          ),
        ),

        floatingActionButton: Padding(
          padding: const EdgeInsets.only(right: 12, bottom: 12),
          child: AddFabButton(heroTag: 'cad_fab', onTap: _add),
        ),

        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F7F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.userLabel ?? 'USER • ${widget.initial.name}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111111),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('BU',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF111111))),
                        ),
                        Text('Percentage (%)',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111111))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),

                  ..._items.asMap().entries.map((e) {
                    final i = e.key;
                    final d = e.value;
                    return InkWell(
                      onTap: () => _openRowSheet(i),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    d.code,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF374151),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  _fmtP(d.percent),
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF374151),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Builder(
                builder: (context) {
                  final isOk = (_total - 100).abs() < 0.0001;

                  return Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total:',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            color: isOk ? const Color(0xFF22C55E) : const Color(0xFFE11D48),
                          ),
                          children: [
                            TextSpan(text: _fmtP(_total)),
                            if (!isOk)
                              const TextSpan(text: '  -  The total must be 100%'),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color bg, VoidCallback onPressed) {
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
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  double _remainingPercent({int? excludingIndex}) {
    final total = _items.asMap().entries.fold<double>(
      0,
          (sum, e) =>
      sum + (excludingIndex == e.key ? 0 : (e.value.percent.isNaN ? 0 : e.value.percent)),
    );
    return 100.0 - total;
  }
}
