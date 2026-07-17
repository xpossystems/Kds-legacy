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

  test('expo/allergy wire additions parse', () {
    final t = KdsTicket.fromJson({
      'id': 3,
      'tableLabel': '5',
      'allergyAckBy': 'Dana M',
      'items': [
        {
          'id': 41,
          'qty': 1,
          'name': 'Pad Thai',
          'prepStatus': 'started',
          'allergy': true,
          'allergyNote': 'peanut - severe',
        },
        {'id': 42, 'qty': 2, 'name': 'Spring Rolls', 'prepStatus': 'done'},
      ],
    });
    expect(t.allergyAckBy, 'Dana M');
    expect(t.hasAllergy, isTrue);
    expect(t.items[0].id, 41);
    expect(t.items[0].prepStatus, 'started');
    expect(t.items[0].allergy, isTrue);
    expect(t.items[0].allergyNote, 'peanut - severe');
    expect(t.items[1].allergy, isFalse);
    expect(t.items[1].allergyNote, '');
  });

  test('old-register payloads without expo fields fall back to defaults', () {
    final t = KdsTicket.fromJson({
      'id': 1,
      'tableLabel': '9',
      'items': [
        {'qty': 1, 'name': 'Burger', 'station': 'Grill'},
      ],
    });
    expect(t.allergyAckBy, '');
    expect(t.hasAllergy, isFalse);
    final it = t.items.single;
    expect(it.id, 0);
    expect(it.prepStatus, '');
    expect(it.allergy, isFalse);
    expect(it.allergyNote, '');
  });

  test('all-items-done drives the expo ready highlight', () {
    KdsTicket ticket(List<String> states) => KdsTicket.fromJson({
          'id': 1,
          'items': [
            for (var i = 0; i < states.length; i++)
              {'id': i + 1, 'qty': 1, 'name': 'Item $i', 'prepStatus': states[i]},
          ],
        });
    expect(ticket(['done', 'done']).allItemsDone, isTrue);
    expect(ticket(['done', 'started']).allItemsDone, isFalse);
    expect(ticket(['done', '']).allItemsDone, isFalse);
    expect(ticket([]).allItemsDone, isFalse,
        reason: 'an itemless ticket must not light the ready highlight');
  });

  test('copyWith supports the optimistic prep update', () {
    final t = KdsTicket.fromJson({
      'id': 8,
      'allergyAckBy': 'Sam',
      'items': [
        {'id': 1, 'qty': 1, 'name': 'Soup', 'prepStatus': '', 'allergy': true},
        {'id': 2, 'qty': 1, 'name': 'Steak', 'prepStatus': 'done'},
      ],
    });
    final updated = t.copyWith(items: [
      for (final i in t.items)
        if (i.id == 1) i.copyWith(prepStatus: 'started') else i
    ]);
    expect(updated.id, 8);
    expect(updated.allergyAckBy, 'Sam');
    expect(updated.items[0].prepStatus, 'started');
    expect(updated.items[0].allergy, isTrue, reason: 'other fields survive');
    expect(updated.items[1].prepStatus, 'done');
    expect(t.items[0].prepStatus, '', reason: 'original stays immutable');
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
