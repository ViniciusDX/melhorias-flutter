import 'package:flutter/material.dart';

class CostAllocationDetail {
  String code;
  double percent;

  CostAllocationDetail({
    required this.code,
    required this.percent,
  });
}

class CostAllocationGroup {
  String name;
  List<CostAllocationDetail> details;

  CostAllocationGroup({
    required this.name,
    required this.details,
  });
}

class DriverPreference {
  int? order;
  String name;
  String email;
  String? phone;
  bool jpn;
  bool eng;
  bool favorite;

  DriverPreference({
    required this.order,
    required this.name,
    required this.email,
    this.phone,
    this.jpn = false,
    this.eng = false,
    this.favorite = false,
  });
}

class FavoritePlace {
  String name;
  String address;
  DateTime? sharedOn;
  bool shared;

  FavoritePlace({
    required this.name,
    required this.address,
    this.sharedOn,
    this.shared = false,
  });
}

String fmtPercent(double v) => '${v.toStringAsFixed(1)}%';

String fmtDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

InputDecoration inputDecoration(String label, {Widget? prefixIcon}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: prefixIcon,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    isDense: true,
  );
}

String? validate100(List<CostAllocationDetail> items) {
  final total = items.fold<double>(0, (s, e) => s + e.percent);
  if ((total - 100).abs() > 0.001) {
    return 'A soma das porcentagens deve ser 100% (atual: ${total.toStringAsFixed(1)}%)';
  }
  return null;
}
