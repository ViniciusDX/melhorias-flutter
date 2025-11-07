import 'package:flutter/material.dart';
import 'package:mitsubishi/widgets/notifications/app_notifications.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_widgets.dart';

DateTime _clampDate(DateTime v, DateTime min, DateTime max) {
  if (v.isBefore(min)) return min;
  if (v.isAfter(max)) return max;
  return v;
}

DateTime? _safeOrNull(DateTime? d) => (d != null && d.year >= 2000) ? d : null;

DateTime _coerceEndAfterStart(DateTime start, DateTime? end) {
  final e = _safeOrNull(end);
  if (e == null || !e.isAfter(start)) return start.add(const Duration(hours: 1));
  return e;
}

String _fmtDateTime(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yyyy = d.year.toString();
  final hh = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy  $hh:$mi';
}

Widget _greyHeader(BuildContext context, String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: const BoxDecoration(
      color: Color(0xFF6B7280),
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
    ),
    child: Text(
      text,
      style: FlutterFlowTheme.of(context).titleSmall.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget _pillButton({
  required BuildContext context,
  required String label,
  required Color color,
  required VoidCallback onPressed,
}) {
  final theme = FlutterFlowTheme.of(context);
  return SizedBox(
    width: double.infinity,
    child: FFButtonWidget(
      onPressed: onPressed,
      text: label,
      options: FFButtonOptions(
        width: double.infinity,
        height: 50,
        padding: const EdgeInsets.all(8),
        color: color,
        textStyle: theme.titleSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        borderSide: const BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.circular(28),
        elevation: 6,
      ),
      showLoadingIndicator: false,
    ),
  );
}


class PeriodModals {
  static Future<DateTimeRange?> showRepeatRequestModal(
      BuildContext context, {
        required String originalId,
        required DateTime originalStart,
        required DateTime originalEnd,
      }) {
    final start = _safeOrNull(originalStart) ?? DateTime.now();
    final end = _coerceEndAfterStart(start, originalEnd);

    const labels = _PeriodLabels(
      title: 'Repeat Request',
      idLabel: 'Original Request:',
      originalPeriodLabel: 'Original Period:',
      sectionTitle: 'New Request Period',
      primaryCtaLabel: 'Create Request',
      showOriginalId: true,
      useRange: true,
      showQuickShifts: true,
      primaryColor: Color(0xFF22C55E),
      secondaryCtaLabel: 'Close',
      showOriginalPeriod: true,
    );

    return showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _PeriodDialog(
        labels: labels,
        originalId: originalId,
        originalStart: start,
        originalEnd: end,
      ),
    );
  }

  static Future<DateTimeRange?> showChangeRequestModal(
      BuildContext context, {
        required String requestId,
        required DateTime currentStart,
        required DateTime currentEnd,
      }) {
    final start = _safeOrNull(currentStart) ?? DateTime.now();
    final end = _coerceEndAfterStart(start, currentEnd);

    const labels = _PeriodLabels(
      title: 'Reschedule',
      idLabel: 'Request:',
      originalPeriodLabel: 'Current Period:',
      sectionTitle: 'Date and Time Range',
      primaryCtaLabel: 'Save',
      showOriginalId: false,
      useRange: true,
      showQuickShifts: false,
      primaryColor: Color(0xFF22C55E),
      secondaryCtaLabel: 'Close',
      showOriginalPeriod: false,
    );

    return showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _PeriodDialog(
        labels: labels,
        originalId: requestId,
        originalStart: start,
        originalEnd: end,
      ),
    );
  }

  static Future<DateTimeRange?> showFinishPeriodModal(
      BuildContext context, {
        required String requestId,
        required DateTime currentStart,
        required DateTime currentEnd,
      }) {
    final start = _safeOrNull(currentStart) ?? DateTime.now();
    final end = _coerceEndAfterStart(start, currentEnd);

    const labels = _PeriodLabels(
      title: 'Finish',
      idLabel: 'Request:',
      originalPeriodLabel: 'Current Period:',
      sectionTitle: 'Date and Time Range',
      primaryCtaLabel: 'Save',
      showOriginalId: false,
      useRange: true,
      showQuickShifts: false,
      primaryColor: Color(0xFF22C55E),
      secondaryCtaLabel: 'Close',
      showOriginalPeriod: false,
    );

    return showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _PeriodDialog(
        labels: labels,
        originalId: requestId,
        originalStart: start,
        originalEnd: end,
      ),
    );
  }

  static Future<DateTimeRange?> showExtendPeriodModal(
      BuildContext context, {
        required String requestId,
        required DateTime currentStart,
        required DateTime currentEnd,
      }) {
    final start = _safeOrNull(currentStart) ?? DateTime.now();
    final end = _coerceEndAfterStart(start, currentEnd);

    const labels = _PeriodLabels(
      title: 'Extend Period',
      idLabel: 'Request:',
      originalPeriodLabel: 'Current Period:',
      sectionTitle: 'End Time',
      primaryCtaLabel: 'Extend',
      showOriginalId: true,
      useRange: false,
      showQuickShifts: false,
      primaryColor: Color(0xFFF59E0B),
      secondaryCtaLabel: 'Cancel',
      showOriginalPeriod: true,
    );

    return showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _PeriodDialog(
        labels: labels,
        originalId: requestId,
        originalStart: start,
        originalEnd: end,
      ),
    );
  }

  static Future<DateTimeRange?> showRevisePeriodModal(
      BuildContext context, {
        required String requestId,
        required DateTime recordedStart,
        required DateTime recordedEnd,
      }) {
    final start = _safeOrNull(recordedStart) ?? DateTime.now();
    final end = _coerceEndAfterStart(start, recordedEnd);

    const labels = _PeriodLabels(
      title: 'Revise Period',
      idLabel: 'Request:',
      originalPeriodLabel: 'Recorded Period:',
      sectionTitle: 'Adjust Real Period',
      primaryCtaLabel: 'Save',
      showOriginalId: true,
      useRange: true,
      showQuickShifts: false,
      primaryColor: Color(0xFF22C55E),
      secondaryCtaLabel: 'Close',
      showOriginalPeriod: true,
    );

    return showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _PeriodDialog(
        labels: labels,
        originalId: requestId,
        originalStart: start,
        originalEnd: end,
      ),
    );
  }

  static Future<DateTimeRange?> showRevTimeFinishedModal(
      BuildContext context, {
        required String requestId,
        required DateTime recordedStart,
        required DateTime recordedEnd,
      }) {
    return showFinishPeriodModal(
      context,
      requestId: requestId,
      currentStart: recordedStart,
      currentEnd: recordedEnd,
    );
  }
}


class _PeriodLabels {
  final String title;
  final String idLabel;
  final String originalPeriodLabel;
  final String sectionTitle;
  final String primaryCtaLabel;
  final bool showOriginalId;
  final bool useRange;
  final bool showQuickShifts;
  final Color primaryColor;
  final String secondaryCtaLabel;
  final bool showOriginalPeriod;

  const _PeriodLabels({
    required this.title,
    required this.idLabel,
    required this.originalPeriodLabel,
    required this.sectionTitle,
    required this.primaryCtaLabel,
    this.showOriginalId = false,
    this.useRange = true,
    this.showQuickShifts = true,
    this.primaryColor = const Color(0xFF22C55E),
    this.secondaryCtaLabel = 'Close',
    this.showOriginalPeriod = true,
  });
}

class _PeriodDialog extends StatefulWidget {
  const _PeriodDialog({
    required this.labels,
    required this.originalId,
    required this.originalStart,
    required this.originalEnd,
  });

  final _PeriodLabels labels;
  final String originalId;
  final DateTime originalStart;
  final DateTime originalEnd;

  @override
  State<_PeriodDialog> createState() => _PeriodDialogState();
}

class _PeriodDialogState extends State<_PeriodDialog> {
  late DateTime _start;
  late DateTime _end;
  late final TextEditingController _rangeCtrl;
  late final TextEditingController _endCtrl;

  @override
  void initState() {
    super.initState();
    _start = widget.originalStart;
    _end = _coerceEndAfterStart(_start, widget.originalEnd);
    _rangeCtrl = TextEditingController();
    _endCtrl = TextEditingController();
    _syncText(updateState: false);
  }

  @override
  void dispose() {
    _rangeCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => _fmtDateTime(d);

  void _syncText({bool updateState = true}) {
    _rangeCtrl.text = '${_fmt(_start)} - ${_fmt(_end)}';
    _endCtrl.text = _fmt(_end);
    if (updateState && mounted) setState(() {});
  }

  void _shiftDays(int days) {
    setState(() {
      _start = _start.add(Duration(days: days));
      _end = _end.add(Duration(days: days));
      _syncText(updateState: false);
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final firstDateStart = now.subtract(const Duration(days: 365 * 5));
    final lastDateStart = now.add(const Duration(days: 365 * 5));

    final initialStart = _clampDate(_start, firstDateStart, lastDateStart);

    final d1 = await showDatePicker(
      context: context,
      initialDate: initialStart,
      firstDate: firstDateStart,
      lastDate: lastDateStart,
    );
    if (d1 == null) return;
    final t1 = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _start.hour, minute: _start.minute),
    );
    if (t1 == null) return;
    final newStart = DateTime(d1.year, d1.month, d1.day, t1.hour, t1.minute);

    final firstDateEnd = newStart;
    final lastDateEnd = now.add(const Duration(days: 365 * 5));
    final initialEndSeed = _end.isAfter(newStart) ? _end : newStart;
    final initialEnd = _clampDate(initialEndSeed, firstDateEnd, lastDateEnd);

    final d2 = await showDatePicker(
      context: context,
      initialDate: initialEnd,
      firstDate: firstDateEnd,
      lastDate: lastDateEnd,
    );
    if (d2 == null) return;
    final t2 = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _end.hour, minute: _end.minute),
    );
    if (t2 == null) return;
    final newEnd = DateTime(d2.year, d2.month, d2.day, t2.hour, t2.minute);

    if (!newEnd.isAfter(newStart)) {
      AppNotifications.error(context, 'End must be after start.');
      return;
    }

    setState(() {
      _start = newStart;
      _end = newEnd;
      _syncText(updateState: false);
    });
  }

  Future<void> _pickEndOnly() async {
    final DateTime firstDate = DateTime(_end.year, _end.month, _end.day);
    final DateTime lastDate  = DateTime(_end.year + 5, 12, 31);
    final DateTime initial   = _clampDate(_end, firstDate, lastDate);

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_end),
    );
    if (pickedTime == null) return;

    final newEnd = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day,
      pickedTime.hour, pickedTime.minute,
    );

    if (newEnd.isBefore(_end)) {
      AppNotifications.error(context, 'New end must be after the current end.');
      return;
    }

    setState(() {
      _end = newEnd;
      _endCtrl.text = _fmt(_end);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            elevation: 16,
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.labels.title,
                      style: theme.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (widget.labels.showOriginalId) ...[
                      RichText(
                        text: TextSpan(
                          style: theme.bodyMedium
                              .copyWith(color: const Color(0xFF111827)),
                          children: [
                            TextSpan(
                              text: '${widget.labels.idLabel} ',
                              style:
                              const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: '#${widget.originalId}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],

                    if (widget.labels.showOriginalPeriod)
                      RichText(
                        text: TextSpan(
                          style: theme.bodyMedium
                              .copyWith(color: const Color(0xFF111827)),
                          children: [
                            TextSpan(
                              text: '${widget.labels.originalPeriodLabel} ',
                              style:
                              const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                              text:
                              '${_fmt(widget.originalStart)}  -  ${_fmt(widget.originalEnd)}',
                            ),
                          ],
                        ),
                      ),

                    if (widget.labels.showOriginalPeriod)
                      const SizedBox(height: 14),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
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
                        children: [
                          _greyHeader(context, widget.labels.sectionTitle),
                          Padding(
                            padding:
                            const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            child: Column(
                              children: [
                                if (widget.labels.useRange &&
                                    widget.labels.showQuickShifts) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _shiftDays(1),
                                          child: const Text('+1 day'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _shiftDays(7),
                                          child: const Text('+1 week'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _shiftDays(30),
                                          child: const Text('+1 month'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                ],

                                if (widget.labels.useRange)
                                  TextField(
                                    controller: _rangeCtrl,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText:
                                      'DD/MM/YYYY HH:mm - DD/MM/YYYY HH:mm',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 14),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Colors.black12),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: theme.alternate
                                              .withOpacity(0.25),
                                        ),
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: 'Pick period',
                                        icon: const Icon(
                                            Icons.access_time_rounded),
                                        onPressed: _pickRange,
                                      ),
                                    ),
                                    onTap: _pickRange,
                                  ),

                                if (!widget.labels.useRange)
                                  TextField(
                                    controller: _endCtrl,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'DD/MM/YYYY HH:mm',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 14),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Colors.black12),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: theme.alternate
                                              .withOpacity(0.25),
                                        ),
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: 'Pick end time',
                                        icon: const Icon(
                                            Icons.access_time_rounded),
                                        onPressed: _pickEndOnly,
                                      ),
                                    ),
                                    onTap: _pickEndOnly,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _pillButton(
                      context: context,
                      label: widget.labels.primaryCtaLabel,
                      color: widget.labels.primaryColor,
                      onPressed: () {
                        if (!_end.isAfter(_start)) {
                          AppNotifications.error(
                              context, 'End must be after start.');
                          return;
                        }
                        Navigator.of(context).pop<DateTimeRange>(
                          DateTimeRange(start: _start, end: _end),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _pillButton(
                      context: context,
                      label: widget.labels.secondaryCtaLabel,
                      color: theme.primary,
                      onPressed: () => Navigator.of(context)
                          .pop<DateTimeRange?>(null),
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
}

class RepeatRequestDialog extends StatefulWidget {
  const RepeatRequestDialog({
    super.key,
    required this.originalId,
    required this.originalStart,
    required this.originalEnd,
  });

  final String originalId;
  final DateTime originalStart;
  final DateTime originalEnd;

  static Future<DateTimeRange?> show(
      BuildContext context, {
        required String originalId,
        required DateTime originalStart,
        required DateTime originalEnd,
      }) {
    final start = _safeOrNull(originalStart) ?? DateTime.now();
    final end = _coerceEndAfterStart(start, originalEnd);
    return showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (_) => RepeatRequestDialog(
        originalId: originalId,
        originalStart: start,
        originalEnd: end,
      ),
    );
  }

  @override
  State<RepeatRequestDialog> createState() => _RepeatRequestDialogState();
}

class _RepeatRequestDialogState extends State<RepeatRequestDialog> {
  late DateTime _start = widget.originalStart;
  late DateTime _end = _coerceEndAfterStart(widget.originalStart, widget.originalEnd);
  late final TextEditingController _rangeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void dispose() {
    _rangeCtrl.dispose();
    super.dispose();
  }

  void _sync() {
    _rangeCtrl.text = '${_fmtDateTime(_start)} - ${_fmtDateTime(_end)}';
    setState(() {});
  }

  void _shiftDays(int days) {
    _start = _start.add(Duration(days: days));
    _end = _end.add(Duration(days: days));
    _sync();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final firstDateStart = now.subtract(const Duration(days: 365 * 5));
    final lastDateStart = now.add(const Duration(days: 365 * 5));
    final initialStart = _clampDate(_start, firstDateStart, lastDateStart);

    final d1 = await showDatePicker(
      context: context,
      initialDate: initialStart,
      firstDate: firstDateStart,
      lastDate: lastDateStart,
    );
    if (d1 == null) return;
    final t1 = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _start.hour, minute: _start.minute),
    );
    if (t1 == null) return;
    final newStart = DateTime(d1.year, d1.month, d1.day, t1.hour, t1.minute);

    final firstDateEnd = newStart;
    final lastDateEnd = now.add(const Duration(days: 365 * 5));
    final initialEndSeed = _end.isAfter(newStart) ? _end : newStart;
    final initialEnd = _clampDate(initialEndSeed, firstDateEnd, lastDateEnd);

    final d2 = await showDatePicker(
      context: context,
      initialDate: initialEnd,
      firstDate: firstDateEnd,
      lastDate: lastDateEnd,
    );
    if (d2 == null) return;
    final t2 = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _end.hour, minute: _end.minute),
    );
    if (t2 == null) return;
    final newEnd = DateTime(d2.year, d2.month, d2.day, t2.hour, t2.minute);

    if (!newEnd.isAfter(newStart)) {
      AppNotifications.error(context, 'End must be after start.');
      return;
    }

    _start = newStart;
    _end = newEnd;
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            elevation: 16,
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Repeat Request',
                      style: theme.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),

                    RichText(
                      text: TextSpan(
                        style: theme.bodyMedium
                            .copyWith(color: const Color(0xFF111827)),
                        children: const [
                          TextSpan(
                            text: 'Original Request: ',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Text('#${widget.originalId}', style: theme.bodyMedium),
                    const SizedBox(height: 4),

                    RichText(
                      text: TextSpan(
                        style: theme.bodyMedium
                            .copyWith(color: const Color(0xFF111827)),
                        children: [
                          const TextSpan(
                              text: 'Original Period: ',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(
                              text:
                              '${_fmtDateTime(widget.originalStart)}  -  ${_fmtDateTime(widget.originalEnd)}'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 8,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        children: [
                          _greyHeader(context, 'New Request Period'),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                        child: OutlinedButton(
                                            onPressed: () => _shiftDays(1),
                                            child: const Text('+1 day'))),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: OutlinedButton(
                                            onPressed: () => _shiftDays(7),
                                            child: const Text('+1 week'))),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: OutlinedButton(
                                            onPressed: () => _shiftDays(30),
                                            child: const Text('+1 month'))),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _rangeCtrl,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText:
                                    'DD/MM/YYYY HH:mm - DD/MM/YYYY HH:mm',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.black12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: theme.alternate
                                            .withOpacity(0.25),
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: 'Pick period',
                                      icon: const Icon(
                                          Icons.access_time_rounded),
                                      onPressed: _pickRange,
                                    ),
                                  ),
                                  onTap: _pickRange,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _pillButton(
                      context: context,
                      label: 'Create Request',
                      color: const Color(0xFF22C55E),
                      onPressed: () {
                        if (!_end.isAfter(_start)) {
                          AppNotifications.error(
                              context, 'End must be after start.');
                          return;
                        }
                        Navigator.of(context).pop(
                            DateTimeRange(start: _start, end: _end));
                      },
                    ),
                    const SizedBox(height: 10),
                    _pillButton(
                      context: context,
                      label: 'Close',
                      color: theme.primary,
                      onPressed: () =>
                          Navigator.of(context).pop<DateTimeRange?>(null),
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
}


class ExtendPeriodDialog extends StatefulWidget {
  const ExtendPeriodDialog({
    super.key,
    required this.requestId,
    required this.currentStart,
    required this.currentEnd,
  });

  final String requestId;
  final DateTime currentStart;
  final DateTime currentEnd;

  static Future<DateTimeRange?> show(
      BuildContext context, {
        required String requestId,
        required DateTime currentStart,
        required DateTime currentEnd,
      }) {
    final start = _safeOrNull(currentStart) ?? DateTime.now();
    final end = _coerceEndAfterStart(start, currentEnd);
    return showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ExtendPeriodDialog(
        requestId: requestId,
        currentStart: start,
        currentEnd: end,
      ),
    );
  }

  @override
  State<ExtendPeriodDialog> createState() => _ExtendPeriodDialogState();
}

class _ExtendPeriodDialogState extends State<ExtendPeriodDialog> {
  late DateTime _start;
  late DateTime _end;
  late final TextEditingController _endCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _start = widget.currentStart;
    _end = _coerceEndAfterStart(_start, widget.currentEnd);
    _endCtrl.text = _fmtCompact(_end);
  }

  @override
  void dispose() {
    _endCtrl.dispose();
    super.dispose();
  }

  String _fmtCompact(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm ${hh}h$mi';
  }

  Future<void> _pickEndOnly() async {
    final firstDate = DateTime(_start.year, _start.month, _start.day);
    final lastDate = DateTime(_start.year + 5, 12, 31);
    final initial = _clampDate(_end, firstDate, lastDate);

    final d2 = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (d2 == null) return;
    final t2 = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _end.hour, minute: _end.minute),
    );
    if (t2 == null) return;

    final newEnd =
    DateTime(d2.year, d2.month, d2.day, t2.hour, t2.minute);

    if (!newEnd.isAfter(_start)) {
      AppNotifications.error(context, 'End must be after start.');
      return;
    }

    setState(() {
      _end = newEnd;
      _endCtrl.text = _fmtCompact(_end);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            elevation: 16,
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Extend Period',
                      style: theme.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),

                    RichText(
                      text: TextSpan(
                        style: theme.bodyMedium
                            .copyWith(color: const Color(0xFF111827)),
                        children: [
                          const TextSpan(
                              text: 'Request: ',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: '#${widget.requestId}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    RichText(
                      text: TextSpan(
                        style: theme.bodyMedium
                            .copyWith(color: const Color(0xFF111827)),
                        children: [
                          const TextSpan(
                              text: 'Current Period: ',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(
                              text:
                              '${_fmtCompact(widget.currentStart)}  -  ${_fmtCompact(widget.currentEnd)}'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 8,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        children: [
                          _greyHeader(context, 'End Time'),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              controller: _endCtrl,
                              readOnly: true,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'DD/MM/YYYY HH:mm',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Colors.black12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: theme.alternate
                                          .withOpacity(0.25)),
                                ),
                                suffixIcon: IconButton(
                                  tooltip: 'Pick end time',
                                  icon: const Icon(
                                      Icons.access_time_rounded),
                                  onPressed: _pickEndOnly,
                                ),
                              ),
                              onTap: _pickEndOnly,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _pillButton(
                      context: context,
                      label: 'Extend',
                      color: const Color(0xFFF59E0B),
                      onPressed: () {
                        if (!_end.isAfter(_start)) {
                          AppNotifications.error(
                              context, 'End must be after start.');
                          return;
                        }
                        Navigator.of(context).pop(
                            DateTimeRange(start: _start, end: _end));
                      },
                    ),
                    const SizedBox(height: 10),
                    _pillButton(
                      context: context,
                      label: 'Cancel',
                      color: theme.primary,
                      onPressed: () => Navigator.of(context)
                          .pop<DateTimeRange?>(null),
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
}

class RevisePeriodDialog extends StatefulWidget {
  const RevisePeriodDialog({
    super.key,
    required this.requestId,
    required this.recordedStart,
    required this.recordedEnd,
  });

  final String requestId;
  final DateTime recordedStart;
  final DateTime recordedEnd;

  static Future<DateTimeRange?> show(
      BuildContext context, {
        required String requestId,
        required DateTime recordedStart,
        required DateTime recordedEnd,
      }) {
    final start = _safeOrNull(recordedStart) ?? DateTime.now();
    final end = _coerceEndAfterStart(start, recordedEnd);
    return showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (_) => RevisePeriodDialog(
        requestId: requestId,
        recordedStart: start,
        recordedEnd: end,
      ),
    );
  }

  @override
  State<RevisePeriodDialog> createState() => _RevisePeriodDialogState();
}

class _RevisePeriodDialogState extends State<RevisePeriodDialog> {
  late DateTime _start = widget.recordedStart;
  late DateTime _end = _coerceEndAfterStart(widget.recordedStart, widget.recordedEnd);
  late final TextEditingController _rangeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void dispose() {
    _rangeCtrl.dispose();
    super.dispose();
  }

  void _sync() {
    _rangeCtrl.text = '${_fmtDateTime(_start)} - ${_fmtDateTime(_end)}';
    setState(() {});
  }

  void _shiftDays(int days) {
    _start = _start.add(Duration(days: days));
    _end = _end.add(Duration(days: days));
    _sync();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final firstDateStart = now.subtract(const Duration(days: 365 * 5));
    final lastDateStart = now.add(const Duration(days: 365 * 5));
    final initialStart = _clampDate(_start, firstDateStart, lastDateStart);

    final d1 = await showDatePicker(
      context: context,
      initialDate: initialStart,
      firstDate: firstDateStart,
      lastDate: lastDateStart,
    );
    if (d1 == null) return;
    final t1 = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _start.hour, minute: _start.minute),
    );
    if (t1 == null) return;
    final newStart = DateTime(d1.year, d1.month, d1.day, t1.hour, t1.minute);

    final firstDateEnd = newStart;
    final lastDateEnd = now.add(const Duration(days: 365 * 5));
    final initialEndSeed = _end.isAfter(newStart) ? _end : newStart;
    final initialEnd = _clampDate(initialEndSeed, firstDateEnd, lastDateEnd);

    final d2 = await showDatePicker(
      context: context,
      initialDate: initialEnd,
      firstDate: firstDateEnd,
      lastDate: lastDateEnd,
    );
    if (d2 == null) return;
    final t2 = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _end.hour, minute: _end.minute),
    );
    if (t2 == null) return;
    final newEnd = DateTime(d2.year, d2.month, d2.day, t2.hour, t2.minute);

    if (!newEnd.isAfter(newStart)) {
      AppNotifications.error(context, 'End must be after start.');
      return;
    }

    _start = newStart;
    _end = newEnd;
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            elevation: 16,
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Revise Period',
                      style: theme.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),

                    RichText(
                      text: TextSpan(
                        style: theme.bodyMedium
                            .copyWith(color: const Color(0xFF111827)),
                        children: [
                          const TextSpan(
                              text: 'Request: ',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: '#${widget.requestId}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    RichText(
                      text: TextSpan(
                        style: theme.bodyMedium
                            .copyWith(color: const Color(0xFF111827)),
                        children: [
                          const TextSpan(
                              text: 'Recorded Period: ',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(
                              text:
                              '${_fmtDateTime(widget.recordedStart)}  -  ${_fmtDateTime(widget.recordedEnd)}'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 8,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        children: [
                          _greyHeader(context, 'Adjust Real Period'),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                        child: OutlinedButton(
                                            onPressed: () => _shiftDays(1),
                                            child: const Text('+1 day'))),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: OutlinedButton(
                                            onPressed: () => _shiftDays(7),
                                            child: const Text('+1 week'))),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: OutlinedButton(
                                            onPressed: () => _shiftDays(30),
                                            child: const Text('+1 month'))),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _rangeCtrl,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText:
                                    'DD/MM/YYYY HH:mm - DD/MM/YYYY HH:mm',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.black12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: theme.alternate
                                            .withOpacity(0.25),
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: 'Pick period',
                                      icon: const Icon(
                                          Icons.access_time_rounded),
                                      onPressed: _pickRange,
                                    ),
                                  ),
                                  onTap: _pickRange,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _pillButton(
                      context: context,
                      label: 'Save',
                      color: const Color(0xFF22C55E),
                      onPressed: () {
                        if (!_end.isAfter(_start)) {
                          AppNotifications.error(
                              context, 'End must be after start.');
                          return;
                        }
                        Navigator.of(context).pop(
                            DateTimeRange(start: _start, end: _end));
                      },
                    ),
                    const SizedBox(height: 10),
                    _pillButton(
                      context: context,
                      label: 'Close',
                      color: theme.primary,
                      onPressed: () =>
                          Navigator.of(context).pop<DateTimeRange?>(null),
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
}

class FinishPeriodDialog extends StatefulWidget {
  const FinishPeriodDialog({
    super.key,
    required this.title,
    required this.sectionTitle,
    required this.primaryLabel,
    required this.currentStart,
    required this.currentEnd,
  });

  final String title;
  final String sectionTitle;
  final String primaryLabel;
  final DateTime currentStart;
  final DateTime currentEnd;

  static Future<DateTimeRange?> showFinish(
      BuildContext context, {
        required DateTime currentStart,
        required DateTime currentEnd,
      }) {
    final start = _safeOrNull(currentStart) ?? DateTime.now();
    final end = _coerceEndAfterStart(start, currentEnd);
    return showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (_) => FinishPeriodDialog(
        title: 'Finish',
        sectionTitle: 'Date and Time Range',
        primaryLabel: 'Save',
        currentStart: start,
        currentEnd: end,
      ),
    );
  }

  static Future<DateTimeRange?> showRevTime(
      BuildContext context, {
        required DateTime currentStart,
        required DateTime currentEnd,
      }) {
    final start = _safeOrNull(currentStart) ?? DateTime.now();
    final end = _coerceEndAfterStart(start, currentEnd);
    return showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (_) => FinishPeriodDialog(
        title: 'Review Time',
        sectionTitle: 'Real Period',
        primaryLabel: 'Save Period',
        currentStart: start,
        currentEnd: end,
      ),
    );
  }

  @override
  State<FinishPeriodDialog> createState() => _FinishPeriodDialogState();
}

class _FinishPeriodDialogState extends State<FinishPeriodDialog> {
  late DateTime _start = widget.currentStart;
  late DateTime _end = _coerceEndAfterStart(widget.currentStart, widget.currentEnd);
  late final TextEditingController _rangeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void dispose() {
    _rangeCtrl.dispose();
    super.dispose();
  }

  void _sync() {
    _rangeCtrl.text = '${_fmtDateTime(_start)} - ${_fmtDateTime(_end)}';
    setState(() {});
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final firstDateStart = now.subtract(const Duration(days: 365 * 5));
    final lastDateStart = now.add(const Duration(days: 365 * 5));
    final initialStart = _clampDate(_start, firstDateStart, lastDateStart);

    final d1 = await showDatePicker(
      context: context,
      initialDate: initialStart,
      firstDate: firstDateStart,
      lastDate: lastDateStart,
    );
    if (d1 == null) return;
    final t1 = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _start.hour, minute: _start.minute),
    );
    if (t1 == null) return;
    final newStart = DateTime(d1.year, d1.month, d1.day, t1.hour, t1.minute);

    final firstDateEnd = newStart;
    final lastDateEnd = now.add(const Duration(days: 365 * 5));
    final initialEndSeed = _end.isAfter(newStart) ? _end : newStart;
    final initialEnd = _clampDate(initialEndSeed, firstDateEnd, lastDateEnd);

    final d2 = await showDatePicker(
      context: context,
      initialDate: initialEnd,
      firstDate: firstDateEnd,
      lastDate: lastDateEnd,
    );
    if (d2 == null) return;
    final t2 = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _end.hour, minute: _end.minute),
    );
    if (t2 == null) return;
    final newEnd = DateTime(d2.year, d2.month, d2.day, t2.hour, t2.minute);

    if (!newEnd.isAfter(newStart)) {
      AppNotifications.error(context, 'End must be after start.');
      return;
    }

    _start = newStart;
    _end = newEnd;
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            elevation: 16,
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: theme.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 8,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        children: [
                          _greyHeader(context, widget.sectionTitle),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              controller: _rangeCtrl,
                              readOnly: true,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText:
                                'DD/MM/YYYY HH:mm - DD/MM/YYYY HH:mm',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Colors.black12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: theme.alternate
                                          .withOpacity(0.25)),
                                ),
                                suffixIcon: IconButton(
                                  tooltip: 'Pick period',
                                  icon: const Icon(
                                      Icons.access_time_rounded),
                                  onPressed: _pickRange,
                                ),
                              ),
                              onTap: _pickRange,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _pillButton(
                      context: context,
                      label: widget.primaryLabel,
                      color: const Color(0xFF22C55E),
                      onPressed: () {
                        if (!_end.isAfter(_start)) {
                          AppNotifications.error(
                              context, 'End must be after start.');
                          return;
                        }
                        Navigator.of(context).pop(
                            DateTimeRange(start: _start, end: _end));
                      },
                    ),
                    const SizedBox(height: 10),
                    _pillButton(
                      context: context,
                      label: 'Close',
                      color: theme.primary,
                      onPressed: () =>
                          Navigator.of(context).pop<DateTimeRange?>(null),
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
}
