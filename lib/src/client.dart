import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Connects to the XPOS register's kitchen socket (WebSocket :7171) either by
/// listening for its UDP discovery beacon on :7172 or via a manually entered
/// host. Reconnects automatically and keeps discovery running so a restarted
/// register is picked up again.
class KdsClient {
  static const int wsPort = 7171;
  static const int udpPort = 7172;
  static const String beaconPrefix = 'XPOS_KDS_HOST:';

  final String deviceName;
  KdsClient({this.deviceName = 'kds-screen'});

  WebSocket? _ws;
  RawDatagramSocket? _udp;
  Timer? _retry;
  bool _disposed = false;
  String? _manualHost;
  String? _lastHost;
  int _lastPort = wsPort;

  final _tickets = StreamController<List<KdsTicket>>.broadcast();
  final _status = StreamController<String>.broadcast();

  /// SLA thresholds (minutes) pushed by the register with each ticket update.
  int slaWarnMinutes = 8;
  int slaLateMinutes = 15;

  Stream<List<KdsTicket>> get tickets => _tickets.stream;
  Stream<String> get status => _status.stream;
  bool get isConnected => _ws != null;
  String? get connectedHost => _ws != null ? _lastHost : null;

  Future<void> start({String? manualHost}) async {
    _disposed = false;
    _manualHost = (manualHost != null && manualHost.trim().isNotEmpty)
        ? manualHost.trim()
        : null;
    if (_manualHost != null) {
      final parts = _manualHost!.split(':');
      final port = parts.length > 1 ? int.tryParse(parts[1]) ?? wsPort : wsPort;
      unawaited(_connect(parts[0], port));
      return;
    }
    _status.add('Searching for the XPOS register on this network…');
    await _listenForBeacon();
  }

  Future<void> _listenForBeacon() async {
    try {
      _udp?.close();
      _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort);
      _udp!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = _udp!.receive();
        if (dg == null) return;
        final msg = utf8.decode(dg.data, allowMalformed: true);
        if (!msg.startsWith(beaconPrefix)) return;
        final hostPort = msg.substring(beaconPrefix.length).split(':');
        if (hostPort.isNotEmpty && !isConnected) {
          final port =
              hostPort.length > 1 ? int.tryParse(hostPort[1]) ?? wsPort : wsPort;
          _connect(hostPort[0], port);
        }
      });
    } catch (e) {
      _status.add('Discovery failed ($e) — enter the register IP manually.');
    }
  }

  Future<void> _connect(String host, int port) async {
    if (_disposed || isConnected) return;
    _lastHost = host;
    _lastPort = port;
    _status.add('Connecting to $host…');
    try {
      final ws =
          await WebSocket.connect('ws://$host:$port').timeout(const Duration(seconds: 6));
      _ws = ws;
      ws.add(jsonEncode({'v': 1, 'type': 'hello', 'role': 'kds', 'device': deviceName}));
      _status.add('Connected to $host');
      ws.listen((message) {
        try {
          final data = jsonDecode(message as String);
          if (data is Map && data['type'] == 'tickets' && data['tickets'] is List) {
            final sla = data['sla'];
            if (sla is Map) {
              slaWarnMinutes = (sla['warn'] as num?)?.toInt() ?? slaWarnMinutes;
              slaLateMinutes = (sla['late'] as num?)?.toInt() ?? slaLateMinutes;
            }
            _tickets.add([
              for (final t in data['tickets'] as List)
                if (t is Map) KdsTicket.fromJson(Map<String, dynamic>.from(t))
            ]);
          }
        } catch (_) {}
      }, onDone: _onDisconnected, onError: (_) => _onDisconnected());
    } catch (e) {
      _status.add('Could not reach $host ($e)');
      _scheduleRetry();
    }
  }

  void _onDisconnected() {
    _ws = null;
    if (_disposed) return;
    _status.add('Disconnected — retrying…');
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 5), () {
      if (_disposed || isConnected) return;
      if (_lastHost != null) {
        _connect(_lastHost!, _lastPort);
      } else if (_manualHost == null) {
        _listenForBeacon();
      }
    });
  }

  void sendAction(String action, int ticketId) {
    try {
      _ws?.add(jsonEncode({'type': action, 'ticketId': ticketId}));
    } catch (_) {}
  }

  /// Per-item expo verbs: 'item_start' | 'item_done' | 'item_reset'.
  /// The register updates the row and re-broadcasts a full snapshot.
  void sendItemAction(String action, int itemId) {
    try {
      _ws?.add(jsonEncode({'type': action, 'itemId': itemId}));
    } catch (_) {}
  }

  Future<void> stop() async {
    _disposed = true;
    _retry?.cancel();
    _udp?.close();
    _udp = null;
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;
  }

  void dispose() {
    stop();
    _tickets.close();
    _status.close();
  }
}
