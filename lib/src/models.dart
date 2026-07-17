import 'package:flutter/material.dart';

/// Design tokens — mirrors the restaurant module in xpos_lite_version.
class KColors {
  KColors._();
  static const Color bg = Color(0xFF14171E);
  static const Color surface = Color(0xFF1B1F27);
  static const Color surfaceAlt = Color(0xFF232936);
  static const Color border = Color(0xFF2A313D);
  static const Color primary = Color(0xFFFF6A1A);
  static const Color text = Color(0xFFF3F5F8);
  static const Color textMuted = Color(0xFF9AA4B4);
  static const Color textFaint = Color(0xFF69707E);
  static const Color success = Color(0xFF34C77B);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  static Color station(String name) {
    switch (name.toLowerCase()) {
      case 'grill':
        return const Color(0xFFEC4899);
      case 'saute':
      case 'sauté':
        return const Color(0xFF34C77B);
      case 'pizza':
        return const Color(0xFFF08A3C);
      case 'cold':
        return const Color(0xFF29B6D8);
      case 'pastry':
        return const Color(0xFFB56CE0);
      default:
        return const Color(0xFF8B93A7);
    }
  }

  /// Ticket age color: green under 8m, amber under 15m, red after.
  static Color ticketAge(Duration age) {
    final m = age.inMinutes;
    if (m >= 15) return danger;
    if (m >= 8) return warning;
    return success;
  }
}

/// One line item on a kitchen ticket (wire format from the POS).
class KdsItem {
  final int qty;
  final String name;
  final List<String> modifiers;
  final int? seat;
  final String notes;
  final String station;
  const KdsItem({
    required this.qty,
    required this.name,
    this.modifiers = const [],
    this.seat,
    this.notes = '',
    this.station = '',
  });

  factory KdsItem.fromJson(Map<String, dynamic> j) => KdsItem(
        qty: (j['qty'] as num?)?.toInt() ?? 1,
        name: (j['name'] ?? '').toString(),
        modifiers: [for (final m in (j['modifiers'] as List? ?? [])) m.toString()],
        seat: (j['seat'] as num?)?.toInt(),
        notes: (j['notes'] ?? '').toString(),
        station: (j['station'] ?? '').toString(),
      );
}

/// A kitchen ticket (wire format from the POS).
class KdsTicket {
  final int id;
  final String tableLabel;
  final String room;
  final int guests;
  final int course;
  final String status; // open | held
  final DateTime createdAt;
  final List<KdsItem> items;
  const KdsTicket({
    required this.id,
    required this.tableLabel,
    required this.room,
    required this.guests,
    required this.course,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  Duration get age => DateTime.now().difference(createdAt);

  factory KdsTicket.fromJson(Map<String, dynamic> j) => KdsTicket(
        id: (j['id'] as num?)?.toInt() ?? 0,
        tableLabel: (j['tableLabel'] ?? '').toString(),
        room: (j['room'] ?? '').toString(),
        guests: (j['guests'] as num?)?.toInt() ?? 1,
        course: (j['course'] as num?)?.toInt() ?? 1,
        status: (j['status'] ?? 'open').toString(),
        createdAt:
            DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
        items: [
          for (final i in (j['items'] as List? ?? []))
            if (i is Map) KdsItem.fromJson(Map<String, dynamic>.from(i))
        ],
      );
}
