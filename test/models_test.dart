import 'package:flutter_test/flutter_test.dart';
import 'package:kds/src/models.dart';

void main() {
  test('KdsTicket parses the POS wire format', () {
    final t = KdsTicket.fromJson({
      'id': 7,
      'tableLabel': '12',
      'room': 'Dining Room',
      'guests': 4,
      'course': 2,
      'status': 'open',
      'createdAt': DateTime.now().subtract(const Duration(minutes: 9)).toIso8601String(),
      'items': [
        {
          'qty': 2,
          'name': 'Crispy Wings',
          'modifiers': ['Buffalo'],
          'seat': 1,
          'notes': 'Allergy: nuts',
          'station': 'Saute',
        },
        'garbage-entry',
      ],
    });
    expect(t.id, 7);
    expect(t.items.length, 1);
    expect(t.items.first.qty, 2);
    expect(t.items.first.modifiers, ['Buffalo']);
    expect(t.items.first.seat, 1);
    expect(t.age.inMinutes, inInclusiveRange(8, 10));
  });

  test('missing fields fall back safely', () {
    final t = KdsTicket.fromJson(const {});
    expect(t.id, 0);
    expect(t.items, isEmpty);
    expect(t.status, 'open');
  });

  test('age colors: green -> amber -> red', () {
    expect(KColors.ticketAge(const Duration(minutes: 3)), KColors.success);
    expect(KColors.ticketAge(const Duration(minutes: 9)), KColors.warning);
    expect(KColors.ticketAge(const Duration(minutes: 20)), KColors.danger);
  });

  test('station colors are distinct for the five kitchen stations', () {
    final colors = {
      for (final s in ['Grill', 'Saute', 'Pizza', 'Cold', 'Pastry']) KColors.station(s)
    };
    expect(colors.length, 5);
  });
}
