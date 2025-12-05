import 'package:flutter/material.dart';
import 'package:mitsubishi/backend/api_requests/api_calls.dart' as API;


class _UiStatus {
  final String label;
  final Color color;
  const _UiStatus(this.label, this.color);
}

extension DetailedCarRequestStatusUiX on API.DetailedCarRequestStatus {
  String get uiLabel => switch (this) {
    API.DetailedCarRequestStatus.draft       => 'Draft',
    API.DetailedCarRequestStatus.waiting     => 'Waiting',
    API.DetailedCarRequestStatus.pending     => 'Pending',
    API.DetailedCarRequestStatus.scheduled   => 'Scheduled',
    API.DetailedCarRequestStatus.assigned    => 'Assigned',
    API.DetailedCarRequestStatus.approved    => 'Approved',
    API.DetailedCarRequestStatus.confirmed   => 'Confirmed',
    API.DetailedCarRequestStatus.inProgress  => 'In Progress',
    API.DetailedCarRequestStatus.finished    => 'Finished',
    API.DetailedCarRequestStatus.canceled    => 'Cancelled',
    API.DetailedCarRequestStatus.unknown     => 'Unknown',
  };

  Color get uiColor => switch (this) {
    API.DetailedCarRequestStatus.draft       => const Color(0xFF9CA3AF), // gray
    API.DetailedCarRequestStatus.waiting     => const Color(0xFFF59E0B), // amber
    API.DetailedCarRequestStatus.pending     => const Color(0xFFF59E0B), // amber
    API.DetailedCarRequestStatus.scheduled   => const Color(0xFF38BDF8), // sky-400
    API.DetailedCarRequestStatus.assigned    => const Color(0xFF22D3EE), // cyan-400
    API.DetailedCarRequestStatus.approved    => const Color(0xFF34D399), // emerald-400
    API.DetailedCarRequestStatus.confirmed   => const Color(0xFF10B981), // emerald-500
    API.DetailedCarRequestStatus.inProgress  => const Color(0xFF2563EB), // blue-600
    API.DetailedCarRequestStatus.finished    => const Color(0xFF3B82F6), // blue-500
    API.DetailedCarRequestStatus.canceled    => const Color(0xFFE34A48), // red
    API.DetailedCarRequestStatus.unknown     => const Color(0xFF9CA3AF), // gray
  };


  String uiLabelFromRaw(String? raw) => _decorate(raw).label;
  Color  uiColorFromRaw(String? raw)  => _decorate(raw).color;

  _UiStatus _decorate(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s.isNotEmpty) {
      if (s.contains('cancel')) {
        return const _UiStatus('Cancelled', Color(0xFFE34A48));
      }
      if (s.contains('finish') || s.contains('final') || s.contains('done') || s.contains('close')) {
        return const _UiStatus('Finished', Color(0xFF3B82F6));
      }
      if (s.contains('in progress') || s.contains('progress') || s.contains('ongoing') || s.contains('start')) {
        return const _UiStatus('In Progress', Color(0xFF2563EB));
      }
      if (s.contains('schedul') || s.contains('agend')) {
        return const _UiStatus('Scheduled', Color(0xFF38BDF8));
      }
      if (s.contains('assign')) {
        return const _UiStatus('Assigned', Color(0xFF22D3EE));
      }
      if (s.contains('approve')) {
        return const _UiStatus('Approved', Color(0xFF34D399));
      }
      if (s.contains('confirm')) {
        return const _UiStatus('Confirmed', Color(0xFF10B981));
      }
      if (s.contains('wait') || s.contains('aguard') || s.contains('analis') || s.contains('análise')) {
        return const _UiStatus('Waiting', Color(0xFFF59E0B));
      }
      if (s.contains('pend')) {
        return const _UiStatus('Pending', Color(0xFFF59E0B));
      }
      if (s.contains('draft') || s.contains('rascun')) {
        return const _UiStatus('Draft', Color(0xFF9CA3AF));
      }
    }

    return _UiStatus(uiLabel, uiColor);
  }
}
