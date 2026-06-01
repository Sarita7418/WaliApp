import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioguiaPlayer extends StatefulWidget {
  final Map<String, dynamic> audioguia;

  const AudioguiaPlayer({super.key, required this.audioguia});

  @override
  State<AudioguiaPlayer> createState() => _AudioguiaPlayerState();
}

class _AudioguiaPlayerState extends State<AudioguiaPlayer>
    with SingleTickerProviderStateMixin {

  static const Color brandTeal    = Color(0xFF0F988A);
  static const Color brandEmerald = Color(0xFF197D61);
  static const Color brandAmber   = Color(0xFFD27817);
  static const Color brandDark    = Color(0xFF23373E);

  late final AudioPlayer _player;
  late final AnimationController _pulseCtrl;

  bool _isLoading = true;
  bool _hasError  = false;
  Duration _position = Duration.zero;
  Duration _duration  = Duration.zero;
  bool _isPlaying = false;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _player   = AudioPlayer();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      final url = widget.audioguia['audio_url'] as String? ?? '';
      if (url.isEmpty) throw Exception('Sin URL');

      await _player.setUrl(url);

      _durSub = _player.durationStream.listen((d) {
        if (d != null && mounted) setState(() => _duration = d);
      });
      _posSub = _player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _stateSub = _player.playerStateStream.listen((s) {
        if (mounted) setState(() => _isPlaying = s.playing);
        if (s.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
        }
      });

      if (mounted) setState(() => _isLoading = false);
      // Auto-play al abrir
      await _player.play();

    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _seek(double val) =>
      _player.seek(Duration(milliseconds: val.toInt()));

  void _skip(int seconds) {
    final target = _position + Duration(seconds: seconds);
    _player.seek(target.isNegative ? Duration.zero : target);
  }

  @override
  Widget build(BuildContext context) {
    final nombre    = widget.audioguia['nombre_punto'] as String? ?? 'Audioguía';
    final subtitulo = widget.audioguia['descripcion']  as String? ?? 'La Paz, Bolivia';
    final progreso  = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: brandDark.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),

          // Header con ícono animado
          Row(children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [brandEmerald, brandTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: brandTeal.withValues(
                      alpha: _isPlaying ? 0.25 + _pulseCtrl.value * 0.25 : 0.15),
                    blurRadius: _isPlaying ? 12 + _pulseCtrl.value * 8 : 8,
                    offset: const Offset(0, 4),
                  )],
                ),
                child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 26),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre,
                style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: brandDark)),
              const SizedBox(height: 3),
              Text(subtitulo,
                style: TextStyle(
                  fontSize: 12, color: brandDark.withValues(alpha: 0.50))),
            ])),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: brandDark.withValues(alpha: 0.07),
                  shape: BoxShape.circle),
                child: Icon(Icons.close_rounded,
                  size: 18, color: brandDark.withValues(alpha: 0.50)),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Barra de progreso
          if (!_hasError) ...[
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: brandTeal,
                inactiveTrackColor: brandDark.withValues(alpha: 0.10),
                thumbColor: brandTeal,
                overlayColor: brandTeal.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: _duration.inMilliseconds > 0
                    ? _position.inMilliseconds.toDouble().clamp(
                        0, _duration.inMilliseconds.toDouble())
                    : 0,
                min: 0,
                max: _duration.inMilliseconds > 0
                    ? _duration.inMilliseconds.toDouble()
                    : 1,
                onChanged: _isLoading ? null : _seek,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(_position),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: brandDark.withValues(alpha: 0.50))),
                  Text(_fmt(_duration),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: brandDark.withValues(alpha: 0.35))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Controles
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(color: brandTeal, strokeWidth: 2.5),
            )
          else if (_hasError)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No se pudo cargar el audio',
                style: TextStyle(color: brandDark.withValues(alpha: 0.45), fontSize: 13)),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // -15s
                _controlBtn(
                  icon: Icons.replay_10_rounded,
                  size: 28,
                  onTap: () => _skip(-15),
                ),
                const SizedBox(width: 20),
                // Play / Pause principal
                GestureDetector(
                  onTap: () => _isPlaying ? _player.pause() : _player.play(),
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [brandEmerald, brandTeal],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: brandTeal.withValues(alpha: 0.40),
                        blurRadius: 18, offset: const Offset(0, 5),
                      )],
                    ),
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white, size: 34,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // +15s
                _controlBtn(
                  icon: Icons.forward_10_rounded,
                  size: 28,
                  onTap: () => _skip(15),
                ),
              ],
            ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: brandDark.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: brandDark.withValues(alpha: 0.65), size: size),
      ),
    );
  }
}