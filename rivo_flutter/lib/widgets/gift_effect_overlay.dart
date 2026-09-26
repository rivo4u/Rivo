import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class GiftEffectOverlay extends StatefulWidget {
  const GiftEffectOverlay({
    super.key,
    required this.child,
    required this.events,
    required this.initialEventsLoaded,
    required this.giftCatalog,
  });

  final Widget child;
  final List<Map<String, dynamic>> events;
  final bool initialEventsLoaded;
  final Future<List<Map<String, dynamic>>> giftCatalog;

  @override
  State<GiftEffectOverlay> createState() => _GiftEffectOverlayState();
}

class _GiftEffectOverlayState extends State<GiftEffectOverlay>
    with SingleTickerProviderStateMixin {
  static const _maxQueueLength = 24;

  late final AnimationController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Map<String, dynamic>> _queue = [];
  final Set<String> _seenEvents = {};
  Map<String, dynamic>? _active;
  bool _initialEventsLoaded = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _acceptEvents();
  }

  @override
  void didUpdateWidget(covariant GiftEffectOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _acceptEvents();
  }

  void _acceptEvents() {
    if (!widget.initialEventsLoaded) return;
    if (!_initialEventsLoaded) {
      _initialEventsLoaded = true;
      for (final event in widget.events) {
        _remember(_eventKey(event));
      }
      return;
    }

    var added = false;
    for (final event in widget.events) {
      final key = _eventKey(event);
      if (!_remember(key)) continue;
      if (_queue.length < _maxQueueLength) _queue.add(event);
      added = true;
    }
    if (added) scheduleMicrotask(() => unawaited(_playNext()));
  }

  bool _remember(String key) {
    if (!_seenEvents.add(key)) return false;
    if (_seenEvents.length > 500) _seenEvents.remove(_seenEvents.first);
    return true;
  }

  String _eventKey(Map<String, dynamic> event) =>
      event['id']?.toString() ??
      '${event['created_at']}:${event['sender_id']}:${event['gift_id']}';

  Future<void> _playNext() async {
    if (!mounted || _playing || _queue.isEmpty) return;
    _playing = true;
    final transaction = _queue.removeAt(0);
    Map<String, dynamic>? gift;
    try {
      gift = (await widget.giftCatalog)
          .where((item) => item['id']?.toString() == transaction['gift_id']?.toString())
          .firstOrNull;
    } catch (_) {
      gift = null;
    }
    if (!mounted) {
      _playing = false;
      return;
    }

    final durationMs = int.tryParse(gift?['effect_duration_ms']?.toString() ?? '') ?? 3000;
    final duration = durationMs.clamp(1600, 12000);
    _controller.duration = Duration(milliseconds: duration);
    setState(() => _active = {'transaction': transaction, 'gift': gift ?? {}});
    final soundUrl = _httpUrl(gift?['effect_sound_url']);
    if (soundUrl != null) unawaited(_playSound(soundUrl));
    try {
      await _controller.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    setState(() => _active = null);
    _playing = false;
    if (_queue.isNotEmpty) unawaited(_playNext());
  }

  Future<void> _playSound(String url) async {
    try {
      await _audioPlayer.stop();
      if (!mounted) return;
      await _audioPlayer.play(UrlSource(url));
    } catch (_) {
      // Gift visuals remain available when a remote sound cannot be loaded.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (active != null)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _controller.value;
              final fade = progress < 0.12
                  ? progress / 0.12
                  : progress > 0.88
                      ? (1 - progress) / 0.12
                      : 1.0;
              final scale = 0.72 + Curves.easeOutBack.transform(progress) * 0.28;
              return Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: fade.clamp(0.0, 1.0),
                    child: Center(
                      child: Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                    ),
                  ),
                ),
              );
            },
            child: _effectCard(active),
          ),
      ],
    );
  }

  Widget _effectCard(Map<String, dynamic> active) {
    final transaction = active['transaction'] as Map<String, dynamic>;
    final gift = active['gift'] as Map<String, dynamic>;
    final name = _value(gift, ['name', 'title', 'gift_name']) ?? 'Gift';
    final mode = gift['effect_mode']?.toString() ?? '';
    final quantity = _value(transaction, ['quantity', 'gift_quantity', 'count']) ?? '1';
    final sender = _shortId(transaction['sender_id'], 'Someone');
    final receiver = _shortId(transaction['receiver_id'], 'someone');
    final metadata = gift['effect_metadata'];
    final subtitle = metadata is Map
        ? (metadata['subtitle'] ?? metadata['tagline'])?.toString()
        : null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xF21C2B22),
          border: Border.all(color: _accent(mode).withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 28, spreadRadius: 2),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$sender sent $name to $receiver',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Quantity $quantity${subtitle == null ? '' : ' · $subtitle'}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD7E8DC), fontSize: 12)),
            const SizedBox(height: 10),
            if (mode == 'luxury_car_drive')
              _luxuryCarScene()
            else
              _effectVisual(gift, mode),
          ],
        ),
      ),
    );
  }

  Widget _effectVisual(Map<String, dynamic> gift, String mode) {
    final assetUrl = _httpUrl(gift['effect_asset_url']);
    final giftImage = _httpUrl(_value(
        gift, ['image_url', 'gift_image_url', 'image', 'icon_url']));
    final icon = _icon(mode, gift['name']?.toString() ?? '');
    return SizedBox(
      height: 132,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (giftImage != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  giftImage,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(icon, color: _accent(mode)),
                ),
              ),
            ),
          if (assetUrl == null)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Transform.rotate(
                angle: mode == 'diamond_shine'
                    ? (_controller.value - 0.5) * 0.24
                    : 0,
                child: Icon(icon,
                    size: 94, color: _accent(mode), shadows: const [
                  Shadow(color: Color(0x99FFFFFF), blurRadius: 22),
                ]),
              ),
            )
          else
            Image.network(
              assetUrl,
              width: 132,
              height: 132,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(icon, size: 94, color: _accent(mode)),
            ),
        ],
      ),
    );
  }

  Widget _luxuryCarScene() => SizedBox(
        width: 300,
        height: 132,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: 12,
                right: 12,
                bottom: 22,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2B85B),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(color: Color(0x99E2B85B), blurRadius: 12),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: -90 + _controller.value * 390,
                top: 22,
                child: Column(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Color(0xFFFFE4A3), size: 22),
                    Icon(Icons.directions_car_filled_rounded,
                        color: const Color(0xFFE2B85B),
                        size: 68,
                        shadows: const [
                          Shadow(color: Color(0xAAE2B85B), blurRadius: 20),
                        ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  static String? _value(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().isNotEmpty) return value.toString();
    }
    return null;
  }

  static String _shortId(dynamic value, String fallback) {
    final id = value?.toString();
    if (id == null || id.isEmpty) return fallback;
    return id.length > 14 ? '${id.substring(0, 6)}...${id.substring(id.length - 4)}' : id;
  }

  static String? _httpUrl(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return null;
    return raw;
  }

  static IconData _icon(String mode, String name) {
    switch (mode) {
      case 'rose_burst':
        return Icons.local_florist_rounded;
      case 'heart_burst':
        return Icons.favorite_rounded;
      case 'diamond_shine':
        return Icons.diamond_rounded;
      case 'crown_burst':
        return Icons.workspace_premium_rounded;
      case 'luxury_car_drive':
        return Icons.directions_car_filled_rounded;
      default:
        final normalized = name.toLowerCase();
        if (normalized.contains('rose')) return Icons.local_florist_rounded;
        if (normalized.contains('heart')) return Icons.favorite_rounded;
        if (normalized.contains('diamond')) return Icons.diamond_rounded;
        if (normalized.contains('crown')) return Icons.workspace_premium_rounded;
        if (normalized.contains('car')) return Icons.directions_car_filled_rounded;
        return Icons.auto_awesome_rounded;
    }
  }

  static Color _accent(String mode) {
    switch (mode) {
      case 'rose_burst':
        return const Color(0xFFFF7898);
      case 'heart_burst':
        return const Color(0xFFFF596D);
      case 'diamond_shine':
        return const Color(0xFF76D9FF);
      case 'crown_burst':
      case 'luxury_car_drive':
        return const Color(0xFFE2B85B);
      default:
        return const Color(0xFF9BE5B3);
    }
  }
}