import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kds/src/client.dart';

/// Loopback WebSocket server standing in for the register's kitchen socket,
/// asserting the exact wire shape of the verbs the client emits.
void main() {
  test('sendItemAction / sendAction emit the kds-role wire shapes', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = <Map<String, dynamic>>[];
    final gotAll = Completer<void>();
    const expected = 5; // hello + 3 item verbs + bump
    server.listen((req) async {
      final ws = await WebSocketTransformer.upgrade(req);
      ws.listen((msg) {
        received.add(jsonDecode(msg as String) as Map<String, dynamic>);
        if (received.length == expected && !gotAll.isCompleted) {
          gotAll.complete();
        }
      });
    });

    final client = KdsClient(deviceName: 'test-kds');
    await client.start(manualHost: '127.0.0.1:${server.port}');
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!client.isConnected && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(client.isConnected, isTrue);

    client.sendItemAction('item_start', 41);
    client.sendItemAction('item_done', 41);
    client.sendItemAction('item_reset', 41);
    client.sendAction('bump', 7);
    await gotAll.future.timeout(const Duration(seconds: 5));

    expect(received[0]['type'], 'hello');
    expect(received[0]['role'], 'kds');
    expect(received[1], {'type': 'item_start', 'itemId': 41});
    expect(received[2], {'type': 'item_done', 'itemId': 41});
    expect(received[3], {'type': 'item_reset', 'itemId': 41});
    expect(received[4], {'type': 'bump', 'ticketId': 7});

    await client.stop();
    client.dispose();
    await server.close(force: true);
  });
}
