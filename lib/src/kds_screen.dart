import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'client.dart';
import 'models.dart';

/// Full-screen kitchen display: station filters, color-coded age timers,
/// Hold/Bump. Mirrors the register's tickets over the LAN — no local state.
class KdsScreen extends StatefulWidget {
  const KdsScreen({super.key});

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen> {
  static const _stations = ['All', 'Grill', 'Saute', 'Pizza', 'Cold', 'Pastry', 'Bar'];

  final _client = KdsClient(deviceName: 'kds-app');
  List<KdsTicket> _tickets = [];
  String _statusText = 'Starting…';
  String _station = 'All';
  bool _expo = false;
  Timer? _tick;
  StreamSubscription? _sub1;
  StreamSubscription? _sub2;

  @override
  void initState() {
    super.initState();
    _sub1 = _client.tickets.listen((t) => setState(() => _tickets = t));
    _sub2 = _client.status.listen((s) => setState(() => _statusText = s));
    _tick = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
    _startFromPrefs();
  }

  Future<void> _startFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await _client.start(manualHost: prefs.getString('manual_host'));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _sub1?.cancel();
    _sub2?.cancel();
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _station == 'All'
        ? _tickets
        : _tickets
            .where((t) =>
                t.items.any((i) => i.station.toLowerCase() == _station.toLowerCase()))
            .toList();
    final itemCount = _tickets.fold<int>(0, (s, t) => s + t.items.length);
    final oldest =
        _tickets.fold<int>(0, (m, t) => t.age.inMinutes > m ? t.age.inMinutes : m);
    final lateAt = _client.slaLateMinutes;

    return Scaffold(
      backgroundColor: KColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: KColors.primary, borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: const Text('ƒ',
                        style: TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kitchen Display',
                          style: TextStyle(
                              color: KColors.text, fontSize: 19, fontWeight: FontWeight.w700)),
                      Text(_statusText,
                          style: TextStyle(
                              color: _client.isConnected ? KColors.textMuted : KColors.warning,
                              fontSize: 11)),
                    ],
                  ),
                  const SizedBox(width: 18),
                  _stat('${_tickets.length}', 'Tickets', KColors.primary),
                  const SizedBox(width: 8),
                  _stat('$itemCount', 'Items', KColors.textMuted),
                  const SizedBox(width: 8),
                  _stat('${oldest}m', 'Oldest',
                      oldest >= lateAt ? KColors.danger : KColors.textMuted),
                  const Spacer(),
                  _viewToggle(),
                  const SizedBox(width: 8),
                  _stationChips(),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Connection settings',
                    onPressed: _showSettings,
                    icon: const Icon(Icons.settings_outlined, color: KColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: !_client.isConnected && _tickets.isEmpty
                    ? _disconnected()
                    : filtered.isEmpty
                        ? const Center(
                            child: Text('No open tickets',
                                style: TextStyle(color: KColors.textFaint, fontSize: 16)))
                        : SingleChildScrollView(
                            child: Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                for (final t in filtered)
                                  _expo ? _expoCard(t) : _ticketCard(t)
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _disconnected() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_tethering, size: 46, color: KColors.textFaint),
          const SizedBox(height: 12),
          Text(_statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KColors.textMuted, fontSize: 14)),
          const SizedBox(height: 6),
          const Text(
              'Make sure the XPOS register is running on this Wi-Fi\nand set as the kitchen server.',
              textAlign: TextAlign.center,
              style: TextStyle(color: KColors.textFaint, fontSize: 12)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _showSettings,
            style: OutlinedButton.styleFrom(
              foregroundColor: KColors.text,
              side: const BorderSide(color: KColors.border),
            ),
            icon: const Icon(Icons.settings_ethernet, size: 16),
            label: const Text('Enter register IP'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final ctrl = TextEditingController(text: prefs.getString('manual_host') ?? '');
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Register connection',
            style: TextStyle(color: KColors.text, fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Leave empty for automatic discovery, or enter the register IP (e.g. 192.168.1.20).',
                style: TextStyle(color: KColors.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: KColors.text),
              decoration: InputDecoration(
                hintText: 'Auto-discover',
                hintStyle: const TextStyle(color: KColors.textFaint),
                filled: true,
                fillColor: KColors.surfaceAlt,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: KColors.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: KColors.primary, foregroundColor: Colors.white),
            child: const Text('Save & reconnect'),
          ),
        ],
      ),
    );
    if (saved == true) {
      final host = ctrl.text.trim();
      if (host.isEmpty) {
        await prefs.remove('manual_host');
      } else {
        await prefs.setString('manual_host', host);
      }
      await _client.stop();
      await _client.start(manualHost: host.isEmpty ? null : host);
    }
  }

  Widget _stat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: KColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: KColors.border),
      ),
      child: Row(children: [
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: KColors.textMuted, fontSize: 11)),
      ]),
    );
  }

  Widget _stationChips() {
    int countFor(String s) => s == 'All'
        ? _tickets.length
        : _tickets
            .where((t) =>
                t.items.any((i) => i.station.toLowerCase() == s.toLowerCase()))
            .length;
    return Wrap(
      spacing: 6,
      children: [
        for (final s in _stations)
          GestureDetector(
            onTap: () => setState(() => _station = s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: _station == s ? Colors.white : KColors.surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _station == s ? Colors.white : KColors.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (s != 'All') ...[
                  Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: KColors.station(s), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                ],
                Text(s,
                    style: TextStyle(
                        color: _station == s ? const Color(0xFF14171E) : KColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 11)),
                if (countFor(s) > 0) ...[
                  const SizedBox(width: 4),
                  Text('${countFor(s)}',
                      style: TextStyle(
                          color: _station == s
                              ? const Color(0xFF6B7280)
                              : KColors.textFaint,
                          fontSize: 10)),
                ],
              ]),
            ),
          ),
      ],
    );
  }

  /// Compact segmented view switch: Tickets (station grid) | Expo (board).
  Widget _viewToggle() {
    Widget seg(String label, bool selected, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? const Color(0xFF14171E) : KColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 11)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: KColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: KColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('Tickets', !_expo, () => setState(() => _expo = false)),
        seg('Expo', _expo, () => setState(() => _expo = true)),
      ]),
    );
  }

  Widget _ticketCard(KdsTicket t) {
    final held = t.status == 'held';
    final ageColor = held
        ? KColors.textFaint
        : KColors.ticketAge(t.age,
            warn: _client.slaWarnMinutes, late: _client.slaLateMinutes);
    final mins = t.age.inMinutes;
    final secs = (t.age.inSeconds % 60).toString().padLeft(2, '0');
    final isNamedOrder =
        t.tableLabel.startsWith('TAKE') || t.tableLabel.startsWith('DELIV');
    return Opacity(
      opacity: held ? 0.65 : 1,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: KColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: KColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: ageColor,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(13), topRight: Radius.circular(13)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(
                                    isNamedOrder ? t.tableLabel : 'Table ${t.tableLabel}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: KColors.text,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700)),
                              ),
                              if (held)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Text('HELD',
                                      style: TextStyle(
                                          color: KColors.warning,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800)),
                                ),
                            ]),
                            const SizedBox(height: 2),
                            Text(
                                '${t.room.isNotEmpty ? '${t.room} · ' : ''}${t.guests} guests · Course ${t.course}',
                                style:
                                    const TextStyle(color: KColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: ageColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text('$mins:$secs',
                            style: TextStyle(
                                color: ageColor, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final it in t.items) _itemRow(it),
                  const SizedBox(height: 2),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _client.sendAction('hold', t.id),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: held ? KColors.warning : KColors.textMuted,
                          side: const BorderSide(color: KColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape:
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        ),
                        child: Text(held ? 'Resume' : 'Hold'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _client.sendAction('bump', t.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape:
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        ),
                        icon: const Icon(Icons.check, size: 17),
                        label: const Text('Bump'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(KdsItem it) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${it.qty}×',
              style: const TextStyle(
                  color: KColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(it.name,
                        style: const TextStyle(
                            color: KColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                  if (it.allergy) _allergyTag(),
                ]),
                for (final m in it.modifiers)
                  Text('› $m',
                      style: const TextStyle(color: KColors.textMuted, fontSize: 12)),
                if (it.notes.isNotEmpty)
                  Text('!! ${it.notes}',
                      style: const TextStyle(
                          color: Color(0xFFF08A8A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                if (it.allergy && it.allergyNote.isNotEmpty)
                  Text('!! ${it.allergyNote}',
                      style: const TextStyle(
                          color: KColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                if (it.seat != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: KColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(5)),
                      child: Text('SEAT ${it.seat}',
                          style: const TextStyle(
                              color: KColors.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
          // Read-only prep dot — expo is the interaction surface for prep.
          if (it.prepStatus == 'started' || it.prepStatus == 'done')
            Padding(
              padding: const EdgeInsets.only(right: 5, top: 2),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: it.prepStatus == 'done'
                        ? KColors.success
                        : KColors.warning,
                    shape: BoxShape.circle),
              ),
            ),
          Text(it.station.toUpperCase(),
              style: TextStyle(
                  color: KColors.station(it.station),
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _allergyTag() {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: KColors.danger.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(5)),
      child: const Text('ALLERGY',
          style: TextStyle(
              color: KColors.danger, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }

  // ── Expo board ────────────────────────────────────────────────────────────

  /// Consolidation card: every item of the ticket (all stations) with a
  /// tappable prep chip per line, allergy/ack state, and the Bump verb.
  Widget _expoCard(KdsTicket t) {
    final held = t.status == 'held';
    final ageColor = held
        ? KColors.textFaint
        : KColors.ticketAge(t.age,
            warn: _client.slaWarnMinutes, late: _client.slaLateMinutes);
    final mins = t.age.inMinutes;
    final secs = (t.age.inSeconds % 60).toString().padLeft(2, '0');
    final isNamedOrder =
        t.tableLabel.startsWith('TAKE') || t.tableLabel.startsWith('DELIV');
    final ready = t.allItemsDone;
    return Opacity(
      opacity: held ? 0.65 : 1,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: KColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: KColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: ageColor,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(13), topRight: Radius.circular(13)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(
                                    isNamedOrder
                                        ? t.tableLabel
                                        : 'Table ${t.tableLabel}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: KColors.text,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700)),
                              ),
                              if (held)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Text('HELD',
                                      style: TextStyle(
                                          color: KColors.warning,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800)),
                                ),
                              if (t.hasAllergy) _ackBadge(t),
                            ]),
                            const SizedBox(height: 2),
                            Text(
                                '${t.room.isNotEmpty ? '${t.room} · ' : ''}${t.guests} guests · Course ${t.course}',
                                style: const TextStyle(
                                    color: KColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: ageColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text('$mins:$secs',
                            style: TextStyle(
                                color: ageColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final it in t.items) _expoItemRow(t, it),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _client.sendAction('bump', t.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            ready ? KColors.primary : KColors.surfaceAlt,
                        foregroundColor: ready ? Colors.white : KColors.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                      ),
                      icon: const Icon(Icons.check, size: 17),
                      label: const Text('Bump'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Allergy ack state, shown only on tickets that carry allergy lines.
  Widget _ackBadge(KdsTicket t) {
    if (t.allergyAckBy.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: KColors.danger.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: KColors.danger.withValues(alpha: 0.55)),
        ),
        child: const Text('UNACKED',
            style: TextStyle(
                color: KColors.danger, fontSize: 9, fontWeight: FontWeight.w800)),
      );
    }
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: KColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
      child: Text('ACK ${t.allergyAckBy.toUpperCase()}',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: KColors.textMuted, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }

  Widget _expoItemRow(KdsTicket t, KdsItem it) {
    final detail = [
      if (it.seat != null) 'S${it.seat}',
      ...it.modifiers,
      if (it.notes.isNotEmpty) '!! ${it.notes}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.only(left: it.allergy ? 8 : 0),
      decoration: it.allergy
          ? const BoxDecoration(
              border:
                  Border(left: BorderSide(color: KColors.danger, width: 3)))
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text('${it.qty}× ${it.name}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: KColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                  if (it.allergy) _allergyTag(),
                ]),
                if (detail.isNotEmpty)
                  Text(detail,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: KColors.textMuted, fontSize: 11)),
                if (it.allergy && it.allergyNote.isNotEmpty)
                  Text('!! ${it.allergyNote}',
                      style: const TextStyle(
                          color: KColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _prepChip(t, it),
        ],
      ),
    );
  }

  /// Prep state chip: empty → COOKING (amber) → READY (green) → empty.
  Widget _prepChip(KdsTicket t, KdsItem it) {
    final Color? fill;
    final Color borderColor;
    final Widget child;
    if (it.prepStatus == 'started') {
      fill = KColors.warning.withValues(alpha: 0.16);
      borderColor = KColors.warning.withValues(alpha: 0.55);
      child = const Text('COOKING',
          style: TextStyle(
              color: KColors.warning, fontSize: 10, fontWeight: FontWeight.w800));
    } else if (it.prepStatus == 'done') {
      fill = KColors.success.withValues(alpha: 0.16);
      borderColor = KColors.success.withValues(alpha: 0.55);
      child = const Text('READY',
          style: TextStyle(
              color: KColors.success, fontSize: 10, fontWeight: FontWeight.w800));
    } else {
      fill = null;
      borderColor = KColors.border;
      child = const Icon(Icons.radio_button_unchecked,
          size: 14, color: KColors.textFaint);
    }
    return GestureDetector(
      onTap: () => _cycleItem(t, it),
      child: Container(
        constraints: const BoxConstraints(minWidth: 68),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: child,
      ),
    );
  }

  /// Sends the next item verb and applies it optimistically; the register's
  /// next full-snapshot broadcast replaces [_tickets] wholesale and reconciles.
  void _cycleItem(KdsTicket t, KdsItem it) {
    if (it.id == 0) return; // old-register payload: items are not addressable
    final String action;
    final String next;
    if (it.prepStatus == 'started') {
      action = 'item_done';
      next = 'done';
    } else if (it.prepStatus == 'done') {
      action = 'item_reset';
      next = '';
    } else {
      action = 'item_start';
      next = 'started';
    }
    _client.sendItemAction(action, it.id);
    setState(() {
      _tickets = [
        for (final tk in _tickets)
          if (tk.id != t.id)
            tk
          else
            tk.copyWith(items: [
              for (final i in tk.items)
                if (i.id == it.id) i.copyWith(prepStatus: next) else i
            ])
      ];
    });
  }
}
