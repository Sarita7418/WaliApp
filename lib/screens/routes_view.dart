import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────
//  ROUTES VIEW — Mapa / Rutas turísticas
// ─────────────────────────────────────────

class RoutesView extends StatefulWidget {
  const RoutesView({super.key});

  @override
  State<RoutesView> createState() => _RoutesViewState();
}

class _RoutesViewState extends State<RoutesView> {
  static const Color bgLight      = Color(0xFFF2FBFF);
  static const Color brandTeal    = Color(0xFF0F988A);
  static const Color brandEmerald = Color(0xFF197D61);
  static const Color brandAmber   = Color(0xFFD27817);
  static const Color brandDark    = Color(0xFF23373E);
  static const Color brandOrange  = Color(0xFFF25C05);

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _rutas = [];
  int _selectedTipo = 0;

  // Tipos de ruta según diccionario de datos WALI
  final List<_TipoFiltro> _tipos = const [
    _TipoFiltro(label: 'Todas',       icon: Icons.apps_rounded,           id: 0),
    _TipoFiltro(label: 'Histórica',   icon: Icons.history_edu_rounded,    id: 701),
    _TipoFiltro(label: 'Gastronómica',icon: Icons.restaurant_rounded,     id: 702),
    _TipoFiltro(label: 'Panorámica',  icon: Icons.landscape_rounded,      id: 703),
    _TipoFiltro(label: 'Mixta',       icon: Icons.route_rounded,          id: 704),
  ];

  @override
  void initState() {
    super.initState();
    _fetchRutas();
  }

  Future<void> _fetchRutas() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final sb = Supabase.instance.client;
      var query = sb
          .from('rutas')
          .select('id, nombre, descripcion, ia_generado, id_tipo_ruta, estado')
          .eq('estado', true)
          .order('nombre');

      final res = await query;
      if (!mounted) return;
      setState(() {
        _rutas = List<Map<String, dynamic>>.from(res as List);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  List<Map<String, dynamic>> get _rutasFiltradas {
    if (_selectedTipo == 0) return _rutas;
    return _rutas.where((r) => r['id_tipo_ruta'] == _selectedTipo).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildFiltros(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: bgLight,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: brandTeal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.map_rounded, color: brandTeal, size: 22),
        ),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rutas Turísticas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: brandDark, letterSpacing: -0.3)),
          Text('Explora La Paz a tu manera',
            style: TextStyle(fontSize: 12, color: Colors.black38)),
        ]),
      ]),
    );
  }

  Widget _buildFiltros() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tipos.length,
        itemBuilder: (_, i) {
          final tipo = _tipos[i];
          final isActive = _selectedTipo == tipo.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedTipo = tipo.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? brandEmerald : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? brandEmerald : brandDark.withValues(alpha: 0.10),
                ),
                boxShadow: isActive
                    ? [BoxShadow(color: brandEmerald.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                    : [BoxShadow(color: brandDark.withValues(alpha: 0.04), blurRadius: 4)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(tipo.icon, size: 14,
                  color: isActive ? Colors.white : brandDark.withValues(alpha: 0.55)),
                const SizedBox(width: 6),
                Text(tipo.label, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : brandDark.withValues(alpha: 0.65),
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildSkeleton();
    if (_error != null) return _buildError();
    final rutas = _rutasFiltradas;
    if (rutas.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      color: brandTeal,
      onRefresh: _fetchRutas,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: rutas.length,
        itemBuilder: (_, i) => _buildRutaCard(rutas[i], i),
      ),
    );
  }

  Widget _buildRutaCard(Map<String, dynamic> ruta, int index) {
    final bool iaGenerado = ruta['ia_generado'] as bool? ?? false;
    final int tipoId = ruta['id_tipo_ruta'] as int? ?? 0;
    final nombre = ruta['nombre'] as String? ?? '';
    final descripcion = ruta['descripcion'] as String? ?? '';

    // Color según tipo de ruta
    final Map<int, Color> colorMap = {
      701: brandEmerald,
      702: brandAmber,
      703: brandTeal,
      704: brandOrange,
    };
    final Map<int, IconData> iconMap = {
      701: Icons.history_edu_rounded,
      702: Icons.restaurant_rounded,
      703: Icons.landscape_rounded,
      704: Icons.route_rounded,
    };
    final Map<int, String> tipoLabel = {
      701: 'Histórica',
      702: 'Gastronómica',
      703: 'Panorámica',
      704: 'Mixta',
    };

    final color = colorMap[tipoId] ?? brandTeal;
    final iconData = iconMap[tipoId] ?? Icons.route_rounded;
    final label = tipoLabel[tipoId] ?? 'Ruta';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: brandDark.withValues(alpha: 0.07),
          blurRadius: 14,
          offset: const Offset(0, 4),
        )],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              // Ícono de tipo
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(iconData, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              // Contenido
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(nombre,
                      style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: brandDark),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (iaGenerado)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: brandTeal.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.auto_awesome, size: 10, color: brandTeal),
                        SizedBox(width: 3),
                        Text('IA', style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800, color: brandTeal)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(descripcion,
                  style: TextStyle(fontSize: 12, color: brandDark.withValues(alpha: 0.55), height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                // Badge tipo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(iconData, size: 10, color: color),
                    const SizedBox(width: 4),
                    Text(label, style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                  ]),
                ),
              ])),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: brandDark.withValues(alpha: 0.25), size: 22),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: 5,
      itemBuilder: (_, i) => _SkeletonCard(),
    );
  }

  Widget _buildError() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off_rounded, size: 36, color: Color(0xFF7A3928)),
      const SizedBox(height: 10),
      const Text('Sin conexión', style: TextStyle(fontWeight: FontWeight.w700, color: brandDark)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: _fetchRutas,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: brandTeal, borderRadius: BorderRadius.circular(12)),
          child: const Text('Reintentar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    ]));
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.map_outlined, size: 48, color: brandDark.withValues(alpha: 0.18)),
      const SizedBox(height: 12),
      Text('No hay rutas en esta categoría',
        style: TextStyle(color: brandDark.withValues(alpha: 0.42), fontSize: 14)),
    ]));
  }
}

// ─────────────────────────────────────────
//  MODELOS INTERNOS
// ─────────────────────────────────────────

class _TipoFiltro {
  final String label;
  final IconData icon;
  final int id;
  const _TipoFiltro({required this.label, required this.icon, required this.id});
}

// ─────────────────────────────────────────
//  SKELETON CARD
// ─────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final color = Color.lerp(const Color(0xFFDCF0FA), const Color(0xFFBCD8EC), _anim.value)!;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Row(children: [
            Container(width: 54, height: 54, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 14, width: 140, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 8),
              Container(height: 10, width: double.infinity, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 5),
              Container(height: 10, width: 100, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
            ])),
          ]),
        );
      },
    );
  }
}