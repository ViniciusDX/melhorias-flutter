import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/api_requests/api_manager.dart';
import 'drivers_widget.dart' show DriverViewModel;
import 'package:mitsubishi/widgets/notifications/app_notifications.dart';

class ScalaPresidenceWidget extends StatefulWidget {
  const ScalaPresidenceWidget({super.key, required this.driver});
  final DriverViewModel driver;

  static String routeName = 'ScalaPresidence';
  static String routePath = '/scala-presidence';

  @override
  State<ScalaPresidenceWidget> createState() => _ScalaPresidenceWidgetState();
}

class _ScalaPresidenceWidgetState extends State<ScalaPresidenceWidget> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _loading = false;
  String? _error;

  final Set<DateTime> _reserved = <DateTime>{};

  final Map<DateTime, (_Evt evt, Color color)> _marks = {};

  @override
  void initState() {
    super.initState();
    _fetchMonth();
  }

  Future<void> _fetchMonth() async {
    setState(() {
      _loading = true;
      _error = null;
      _reserved.clear();
      _marks.clear();
    });

    try {
      final driverId = int.tryParse(widget.driver.id) ?? 0;
      final res = await DriversGetEventsPresidenceCall.call(
        driverId: driverId,
        bearerToken: ApiManager.accessToken,
      );
      if (!res.succeeded) {
        setState(() => _error = 'Failed to load (${res.statusCode}).');
        return;
      }

      final visible = _visibleDays(_month).toSet();

      for (final e in DriversGetEventsPresidenceCall.items(res)) {
        final id = DriversGetEventsPresidenceCall.id(e) ?? -1;
        final startStr = DriversGetEventsPresidenceCall.start(e);
        final endStr = DriversGetEventsPresidenceCall.end(e);
        final title = DriversGetEventsPresidenceCall.title(e) ?? 'Presidence';

        final String? colorRaw = () {
          final c1 = getJsonField(e, r'$.eventColor');
          if (c1 is String && c1.isNotEmpty) return c1;
          final c2 = getJsonField(e, r'$.backgroundColor');
          if (c2 is String && c2.isNotEmpty) return c2;
          final c3 = getJsonField(e, r'$.color');
          if (c3 is String && c3.isNotEmpty) return c3;
          return null;
        }();
        final colorStr = colorRaw ?? 'green';

        if (id <= 0 || startStr == null) continue;

        final start = DateTime.tryParse(startStr);
        final end = endStr == null ? null : DateTime.tryParse(endStr);
        if (start == null) continue;

        final last = (end ?? start.add(const Duration(days: 1)))
            .subtract(const Duration(days: 1));
        final color = _parseColor(colorStr);

        for (var d = _norm(start);
        !d.isAfter(_norm(last));
        d = d.add(const Duration(days: 1))) {
          if (visible.contains(d)) {
            _reserved.add(d);
            _marks[d] = (_Evt(id, title), color);
          }
        }
      }
    } catch (_) {
      setState(() => _error = 'Failed to load events.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleDay(DateTime day) async {
    final key = _norm(day);
    final mark = _marks[key];

    setState(() => _loading = true);
    try {
      if (mark != null) {
        final ok = await AppNotifications.confirmDanger(
          context,
          title: 'Confirm delete?',
          message:
          'Remove the President schedule on ${_fmtDay(key)} for ${widget.driver.name}?',
          cancelLabel: 'Cancel',
          confirmLabel: 'Delete',
        );
        if (!ok) return;

        final res = await DriversDeleteEventPresidenceCall.call(
          id: mark.$1.id,
          bearerToken: ApiManager.accessToken,
        );
        if (res.succeeded) {
          await _fetchMonth();
          if (mounted) AppNotifications.success(context, 'Day removed.');
        } else {
          if (mounted) {
            AppNotifications.error(
              context,
              'Failed to delete (${res.statusCode}).',
            );
          }
        }
        return;
      }

      final start = DateTime(key.year, key.month, key.day);
      final end = start.add(const Duration(days: 1));

      final res = await DriversSaveEventPresidenceCall.call(
        driverId: int.parse(widget.driver.id),
        start: start,
        end: end,
        title: 'Presidence',
        eventColor: 'green',
        bearerToken: ApiManager.accessToken,
      );

      final conflictName = _conflictNameFromResponse(res.jsonBody);

      if (!res.succeeded) {
        if (mounted) {
          AppNotifications.error(
            context,
            'Failed to save (${res.statusCode}).',
          );
        }
      } else if (conflictName != null && conflictName.isNotEmpty) {
        if (mounted) {
          await AppNotifications.showPresidenceConflictModal(
            context,
            driverName: conflictName,
          );
          await _fetchMonth();
        }
      } else {
        await _fetchMonth();
        if (mounted) AppNotifications.success(context, 'Day assigned.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteByEventId(int id) async {
    setState(() => _loading = true);
    try {
      final res = await DriversDeleteEventPresidenceCall.call(
        id: id,
        bearerToken: ApiManager.accessToken,
      );
      if (res.succeeded) {
        await _fetchMonth();
        if (mounted) AppNotifications.success(context, 'Day removed.');
      } else {
        if (mounted) {
          AppNotifications.error(
            context,
            'Failed to delete (${res.statusCode}).',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    final chipsEntries = _marks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF2F2F2),
          appBar: AppBar(
            title: Text(
              'Scala Presidence',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: theme.secondaryBackground,
            foregroundColor: theme.primaryText,
            elevation: 0.5,
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Material(
                    elevation: 1,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: Column(
                        children: [
                          SfDateRangePicker(
                            view: DateRangePickerView.month,
                            selectionMode: DateRangePickerSelectionMode.single,
                            onSelectionChanged: (args) {
                              if (args.value is DateTime) {
                                _toggleDay(args.value as DateTime);
                              }
                            },
                            onViewChanged: (args) {
                              final visibleStart = args.visibleDateRange.startDate;
                              if (visibleStart == null) return;
                              final newMonth = DateTime(
                                visibleStart.year,
                                visibleStart.month,
                                1,
                              );
                              if (newMonth.year != _month.year ||
                                  newMonth.month != _month.month) {
                                setState(() => _month = newMonth);
                                _fetchMonth();
                              }
                            },
                            monthViewSettings: DateRangePickerMonthViewSettings(
                              specialDates: _reserved.toList(),
                            ),
                            monthCellStyle: DateRangePickerMonthCellStyle(
                              specialDatesDecoration: BoxDecoration(
                                border: Border.all(
                                    color: const Color(0xFF2ECC71), width: 2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              specialDatesTextStyle: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            selectionColor: const Color(0xFF90CAF9),
                            todayHighlightColor: const Color(0xFF1976D2),
                            showNavigationArrow: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],

                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chipsEntries.map((e) {
                        final d = e.key;
                        final evt = e.value.$1;
                        final color = e.value.$2;
                        final label =
                            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} • ${evt.title}';
                        return Chip(
                          label: Text(
                            label,
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: color,
                          deleteIcon:
                          const Icon(Icons.close, color: Colors.white),
                          onDeleted: () => _deleteByEventId(evt.id),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_loading)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }

  List<DateTime> _visibleDays(DateTime month) =>
      _buildMonthDays(month).map(_norm).toList();

  List<DateTime> _buildMonthDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final start = first.subtract(Duration(days: first.weekday % 7));
    final last = DateTime(month.year, month.month + 1, 0);
    final end = last.add(Duration(days: 6 - (last.weekday % 7)));
    final days = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }
    return days;
  }

  DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);
  String _fmtDay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _parseColor(String s) {
    final named = {
      'red': const Color(0xFFE74C3C),
      'green': const Color(0xFF2ECC71),
      'blue': const Color(0xFF3498DB),
      'orange': const Color(0xFFF39C12),
      'yellow': const Color(0xFFF1C40F),
      'purple': const Color(0xFF9B59B6),
      'gray': const Color(0xFF95A5A6),
      'grey': const Color(0xFF95A5A6),
    };
    final lower = s.trim().toLowerCase();
    if (named.containsKey(lower)) return named[lower]!;
    final hex = lower.replaceAll('#', '');
    if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
    if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    return const Color(0xFF2ECC71);
  }

  String? _conflictNameFromResponse(dynamic body) {
    try {
      if (body == null) return null;

      if (body is String) {
        final s = body.replaceAll('"', '').trim();
        return s.isEmpty ? null : s;
      }

      if (body is Map) {
        final status = body['status'];
        if (status is bool && status == false) {
          final msg = body['returnEvent']?.toString().trim();
          if (msg != null && msg.isNotEmpty) return msg;
        }
        final direct = body['returnEvent']?.toString().trim();
        if (direct != null && direct.isNotEmpty) return direct;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class _Evt {
  final int id;
  final String title;
  _Evt(this.id, this.title);
}
