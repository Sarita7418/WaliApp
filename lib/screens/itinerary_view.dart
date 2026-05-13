import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'diary_screen.dart';

class ItineraryView extends StatefulWidget {
  const ItineraryView({super.key});

  @override
  State<ItineraryView> createState() => _ItineraryViewState();
}

class _ItineraryViewState extends State<ItineraryView> {
  final _supabase = Supabase.instance.client;
  bool _estaCargando = false;
  Map<String, dynamic>? _itinerarioExistente;

  // 1. Datos de Fechas
  DateTime _fechaInicio = DateTime.now();
  DateTime _fechaFin = DateTime.now().add(const Duration(days: 3));

  // 2. Configuración de Comidas
  TimeOfDay _hDesayuno = const TimeOfDay(hour: 8, minute: 0);
  bool _incluirDesayuno = true;
  TimeOfDay _hAlmuerzo = const TimeOfDay(hour: 13, minute: 0);
  bool _incluirAlmuerzo = true;
  TimeOfDay _hCena = const TimeOfDay(hour: 20, minute: 0);
  bool _incluirCena = true;

  // 3. Intereses y Prioridades
  final Map<String, int> _mapaCategorias = {
    'Historia': 401, 'Miradores': 402, 'Naturaleza': 403, 'Cultura': 405, 'Gastronomía': 406
  };
  final Set<String> _preferenciasSeleccionadas = {'Historia', 'Miradores'};
  
  final List<Map<String, dynamic>> _lugaresPrioritarios = [];
  final List<Map<String, dynamic>> _rutasPrioritarias = [];

  @override
  void initState() {
    super.initState();
  }

  // --- ALGORITMO ACTUALIZADO (2h Actividad / 1h Comida / Precios Reales) ---
  Future<void> _generarItinerarioReal() async {
    setState(() => _estaCargando = true);
    
    // Inclusión del día de salida completo
    DateTime d1 = DateTime(_fechaInicio.year, _fechaInicio.month, _fechaInicio.day);
    DateTime d2 = DateTime(_fechaFin.year, _fechaFin.month, _fechaFin.day);
    int totalDias = d2.difference(d1).inDays + 1;

    final sugerenciasBDD = await _supabase.from('punto_turistico').select().inFilter(
        'id_categoria', _preferenciasSeleccionadas.map((p) => _mapaCategorias[p]!).toList());

    // Pool unificado y aleatorio (Prioridades + Sugerencias)
    List<Map<String, dynamic>> combinedMaster = [];
    for (var p in [..._rutasPrioritarias, ..._lugaresPrioritarios]) {
      combinedMaster.add({...p, 'es_prioridad': true});
    }
    for (var s in sugerenciasBDD) {
      combinedMaster.add({...s, 'es_prioridad': false});
    }
    
    combinedMaster.shuffle(); 
    List<Map<String, dynamic>> workingPool = List.from(combinedMaster);

    Map<String, dynamic> itinerario = {
      'titulo': 'Itinerario',
      'fecha_inicio': _fechaInicio,
      'fecha_fin': _fechaFin,
      'dias': [],
    };

    for (int d = 0; d < totalDias; d++) {
      List<Map<String, dynamic>> agendaDia = [];
      double horaProgreso = 8.0; 
      const double horaLimite = 22.0;

      while (horaProgreso < horaLimite) {
        // COMIDAS (1 hora de duración)
        if (_incluirDesayuno && _esHoraDeComer(horaProgreso, _hDesayuno)) {
          agendaDia.add(_crearBloqueComida('Desayuno', _hDesayuno, 1.0));
          horaProgreso += 1.0;
        } else if (_incluirAlmuerzo && _esHoraDeComer(horaProgreso, _hAlmuerzo)) {
          agendaDia.add(_crearBloqueComida('Almuerzo', _hAlmuerzo, 1.0));
          horaProgreso += 1.0;
        } else if (_incluirCena && _esHoraDeComer(horaProgreso, _hCena)) {
          agendaDia.add(_crearBloqueComida('Cena', _hCena, 1.0));
          horaProgreso += 1.0;
        } else {
          // ACTIVIDADES (2 horas de duración)
          if (workingPool.isEmpty && combinedMaster.isNotEmpty) {
            workingPool = List.from(combinedMaster);
          }

          if (workingPool.isNotEmpty) {
            var item = workingPool.removeAt(0);
            agendaDia.add({
              'hora_inicio': _formatHora(horaProgreso),
              'hora_fin': _formatHora(horaProgreso + 2.0), // Salto de 2 horas
              'nombre': item['nombre'],
              'es_prioridad': item['es_prioridad'] ?? false,
              'precio': item['precio_nacional'] ?? 0, // COTEJO REAL CON BDD
            });
          } else {
            agendaDia.add({
              'hora_inicio': _formatHora(horaProgreso),
              'hora_fin': _formatHora(horaProgreso + 2.0),
              'nombre': 'Exploración Libre',
              'es_prioridad': false,
              'precio': 0,
            });
          }
          horaProgreso += 2.0;
        }
      }
      itinerario['dias'].add({
        'numero_dia': d + 1,
        'fecha_calendario': _fechaInicio.add(Duration(days: d)),
        'actividades': agendaDia,
      });
    }

    setState(() => _estaCargando = false);
    Navigator.push(context, MaterialPageRoute(builder: (context) => DiaryScreen(itinerarioData: itinerario)));
  }

  bool _esHoraDeComer(double actual, TimeOfDay comida) {
    double tComida = comida.hour + (comida.minute / 60.0);
    return actual >= tComida - 0.1 && actual <= tComida + 0.1;
  }

  Map<String, dynamic> _crearBloqueComida(String nombre, TimeOfDay hora, double duracion) {
    double inicio = hora.hour + (hora.minute / 60.0);
    return {'hora_inicio': _formatHora(inicio), 'hora_fin': _formatHora(inicio + duracion), 'nombre': '🍴 $nombre', 'es_prioridad': false, 'tipo': 'comida'};
  }

  String _formatHora(double horaDecimal) {
    int h = horaDecimal.toInt();
    int m = ((horaDecimal - h) * 60).round();
    if (m >= 60) { h++; m = 0; }
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // --- UI ---
  void _abrirBuscador(bool esRuta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => _SearchComponent(
        esRuta: esRuta,
        onSelected: (item) => setState(() {
          if (esRuta) {
            if (!_rutasPrioritarias.any((r) => r['id'] == item['id'])) _rutasPrioritarias.add(item);
          } else {
            if (!_lugaresPrioritarios.any((l) => l['id'] == item['id'])) _lugaresPrioritarios.add(item);
          }
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_estaCargando) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF006D5B))));

    // --- NUEVO: SI YA TIENE ITINERARIO, MOSTRAMOS ESTO ---
    if (_itinerarioExistente != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFB),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: const BoxDecoration(color: Color(0xFFE8F6F3), shape: BoxShape.circle),
                  child: const Icon(Icons.flight_takeoff, color: Color(0xFF006D5B), size: 50),
                ),
                const SizedBox(height: 25),
                const Text("¡Tienes una aventura en curso!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF001F1A))),
                const SizedBox(height: 10),
                const Text("Ya tienes un itinerario configurado y guardado en la nube.", textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, height: 1.5)),
                const SizedBox(height: 35),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Solo saltamos a la agenda cuando el usuario hace CLIC
                      Navigator.push(context, MaterialPageRoute(builder: (context) => DiaryScreen(itinerarioData: _itinerarioExistente!)));
                    },
                    icon: const Icon(Icons.menu_book, color: Colors.white),
                    label: const Text('Ver mi Agenda', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006D5B),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // --- SI NO TIENE ITINERARIO, SE MUESTRA TU UI NORMAL DE CREACIÓN ---
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text('Configura tu Viaje', style: TextStyle(color: Color(0xFF006D5B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0, leading: const BackButton(color: Color(0xFF006D5B)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera Centrada y Estilizada
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
          
                const SizedBox(height: 20),
                const Text(
                  "¡Crea ya tu itinerario personalizado!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF001F1A), letterSpacing: -0.5),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    "WALI te ayudará a organizar tu estadía en La Paz de forma inteligente. Selecciona tus fechas, dinos tus horarios preferidos para comer y qué lugares no pueden faltar.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.blueGrey, height: 1.6),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),

            _buildSectionHeader(Icons.calendar_today, 'Tus Fechas'),
            _buildDateCard(),
            const SizedBox(height: 25),
            _buildSectionHeader(Icons.restaurant, 'Tus Comidas'),
            _buildMealCard(),
            const SizedBox(height: 25),
            _buildSectionHeader(Icons.favorite, 'Tus Intereses'),
            _buildInterestGrid(),
            const SizedBox(height: 25),
            _buildSectionHeader(Icons.star, 'Lugares Infaltables'),
            _buildPriorityActions(),
            const SizedBox(height: 40),
            _buildGenerateButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(children: [Icon(icon, size: 18, color: const Color(0xFF006D5B)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)))]),
    );
  }

  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _dateColumn('Llegada', _fechaInicio, true),
          Container(height: 30, width: 1, color: Colors.grey.shade200),
          _dateColumn('Salida', _fechaFin, false),
        ],
      ),
    );
  }

  Widget _dateColumn(String label, DateTime fecha, bool isStart) {
    return InkWell(
      onTap: () async {
        final pick = await showDatePicker(context: context, initialDate: fecha, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
        if (pick != null) setState(() => isStart ? _fechaInicio = pick : _fechaFin = pick);
      },
      child: Column(children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)), const SizedBox(height: 5), Text(DateFormat('dd MMM').format(fecha), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF006D5B)))]),
    );
  }

  Widget _buildMealCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Column(
        children: [
          _mealTile('Desayuno', _incluirDesayuno, _hDesayuno, (v) => setState(() => _incluirDesayuno = v!), 1),
          _mealTile('Almuerzo', _incluirAlmuerzo, _hAlmuerzo, (v) => setState(() => _incluirAlmuerzo = v!), 2),
          _mealTile('Cena', _incluirCena, _hCena, (v) => setState(() => _incluirCena = v!), 3),
        ],
      ),
    );
  }

  Widget _mealTile(String title, bool active, TimeOfDay time, Function(bool?) onCheck, int type) {
    return CheckboxListTile(
      value: active, onChanged: onCheck, activeColor: const Color(0xFF006D5B),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: active ? Colors.black : Colors.grey)),
      subtitle: Text(active ? 'A las ${time.format(context)}' : 'Ocupar con actividad'),
      secondary: IconButton(
        icon: Icon(Icons.access_time, color: active ? const Color(0xFF006D5B) : Colors.grey.shade300),
        onPressed: active ? () async {
          final t = await showTimePicker(context: context, initialTime: time);
          if (t != null) setState(() { if (type == 1) _hDesayuno = t; if (type == 2) _hAlmuerzo = t; if (type == 3) _hCena = t; });
        } : null,
      ),
    );
  }

  Widget _buildInterestGrid() {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: _mapaCategorias.keys.map((cat) {
        bool sel = _preferenciasSeleccionadas.contains(cat);
        return FilterChip(
          label: Text(cat), selected: sel,
          onSelected: (v) => setState(() => v ? _preferenciasSeleccionadas.add(cat) : _preferenciasSeleccionadas.remove(cat)),
          selectedColor: const Color(0xFF006D5B).withOpacity(0.1), checkmarkColor: const Color(0xFF006D5B),
          labelStyle: TextStyle(color: sel ? const Color(0xFF006D5B) : Colors.black87, fontWeight: sel ? FontWeight.bold : FontWeight.normal),
          backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      }).toList(),
    );
  }

  Widget _buildPriorityActions() {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _actionBtn('Añadir Punto', Icons.place, const Color(0xFF006D5B), () => _abrirBuscador(false))),
          const SizedBox(width: 12),
          Expanded(child: _actionBtn('Añadir Ruta', Icons.map, const Color(0xFFE67E22), () => _abrirBuscador(true))),
        ]),
        const SizedBox(height: 15),
        ..._lugaresPrioritarios.map((item) => _fullWidthItem(item, false)),
        ..._rutasPrioritarias.map((item) => _fullWidthItem(item, true)),
      ],
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback tap) {
    return ElevatedButton.icon(
      onPressed: tap, icon: Icon(icon, size: 18), label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  Widget _fullWidthItem(Map<String, dynamic> item, bool esRuta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: esRuta ? const Color(0xFFFDEBD0) : const Color(0xFFE8F6F3))),
      child: Row(children: [
        Icon(esRuta ? Icons.map : Icons.place, size: 18, color: esRuta ? const Color(0xFFE67E22) : const Color(0xFF006D5B)),
        const SizedBox(width: 12),
        Expanded(child: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.w500))),
        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20), onPressed: () => setState(() => esRuta ? _rutasPrioritarias.remove(item) : _lugaresPrioritarios.remove(item)))
      ]),
    );
  }

  Widget _buildGenerateButton() {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: ElevatedButton(
          onPressed: _generarItinerarioReal,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF006D5B),
            padding: const EdgeInsets.symmetric(vertical: 15),
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text(
            'Generar mi agenda sugerida',
            style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}

class _SearchComponent extends StatefulWidget {
  final bool esRuta;
  final Function(Map<String, dynamic>) onSelected;
  const _SearchComponent({required this.esRuta, required this.onSelected});
  @override
  State<_SearchComponent> createState() => _SearchComponentState();
}

class _SearchComponentState extends State<_SearchComponent> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _resultados = [];
  bool _cargando = false;

  @override
  void initState() { super.initState(); _buscar(''); }

  void _buscar(String query) async {
    setState(() => _cargando = true);
    var q = _supabase.from(widget.esRuta ? 'rutas' : 'punto_turistico').select();
    if (query.isNotEmpty) q = q.ilike('nombre', '%$query%');
    final data = await q.limit(20);
    if (mounted) setState(() { _resultados = List<Map<String, dynamic>>.from(data); _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 25, left: 25, right: 25, bottom: MediaQuery.of(context).viewInsets.bottom + 25),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(children: [
        const Text('¿Qué lugar quieres asegurar?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        TextField(autofocus: true, decoration: InputDecoration(hintText: 'Escribe para filtrar...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))), onChanged: _buscar),
        const SizedBox(height: 20),
        if (_cargando) const LinearProgressIndicator(color: Color(0xFF006D5B)),
        Expanded(child: ListView.builder(itemCount: _resultados.length, itemBuilder: (context, i) {
          final item = _resultados[i];
          return ListTile(
            title: Text(item['nombre']), leading: Icon(widget.esRuta ? Icons.map : Icons.place, color: Colors.grey),
            trailing: const Icon(Icons.add_circle_outline, color: Color(0xFF006D5B)),
            onTap: () { widget.onSelected(item); Navigator.pop(context); },
          );
        })),
      ]),
    );
  }
}