import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class DiaryScreen extends StatefulWidget {
  final Map<String, dynamic> itinerarioData;

  const DiaryScreen({super.key, required this.itinerarioData});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final _supabase = Supabase.instance.client;
  late Map<String, dynamic> _itinerario;
  double _presupuestoTotal = 0.0;
  bool _estaGuardando = false;

  @override
  void initState() {
    super.initState();
    // Clonamos los datos recibidos
    _itinerario = Map<String, dynamic>.from(widget.itinerarioData);
    
    // --- NORMALIZACIÓN DE DATOS ---
    if (_itinerario['itinerario_dias'] != null) {
      _itinerario['dias'] = List<Map<String, dynamic>>.from(_itinerario['itinerario_dias']);
      for (var dia in _itinerario['dias']) {
        if (dia['itinerario_actividades'] != null) {
          dia['actividades'] = List<Map<String, dynamic>>.from(dia['itinerario_actividades']);
        }
      }
    }

    // --- ORDENAMIENTO INICIAL CRONOLÓGICO ---
    _ordenarActividades();
    
    _calcularPresupuesto();

    // Solo intentamos guardar si no tiene un ID (es nuevo de paquete)
    if (_itinerario['id'] == null) {
      _guardarItinerarioEnBDD();
    }
  }

  // --- FUNCIÓN PARA ORDENAR POR HORA ---
  void _ordenarActividades() {
    if (_itinerario['dias'] != null) {
      for (var dia in _itinerario['dias']) {
        if (dia['actividades'] != null) {
          dia['actividades'].sort((a, b) {
            return _formatearHora(a['hora_inicio']).compareTo(_formatearHora(b['hora_inicio']));
          });
        }
      }
    }
  }

  // --- FUNCIÓN PARA LIMPIAR LOS SEGUNDOS ---
  String _formatearHora(String? horaRaw) {
    if (horaRaw == null || horaRaw.isEmpty) return "00:00";
    // Si la cadena tiene el formato HH:mm:ss (largo 8), cortamos los últimos 3 caracteres
    if (horaRaw.length >= 5) {
      return horaRaw.substring(0, 5);
    }
    return horaRaw;
  }

  // --- PARSEO DE FECHAS ---
  DateTime _parseDate(dynamic date) {
    if (date is DateTime) return date;
    return DateTime.tryParse(date.toString()) ?? DateTime.now();
  }

  // --- PERSISTENCIA EXACTA ---
  Future<void> _guardarItinerarioEnBDD() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _mostrarError('No hay usuario autenticado.');
      return;
    }

    setState(() => _estaGuardando = true);

    try {
      String fInicio = DateFormat('yyyy-MM-dd').format(_parseDate(_itinerario['fecha_inicio']));
      String fFin = DateFormat('yyyy-MM-dd').format(_parseDate(_itinerario['fecha_fin']));

      // 1. Guardar Itinerario
      final itinerarioResp = await _supabase.from('itinerarios').insert({
        'id_persona': user.id,
        'titulo': _itinerario['titulo'],
        'fecha_inicio': fInicio,
        'fecha_fin': fFin,
        'estado': true,
      }).select().single();

      _itinerario['id'] = itinerarioResp['id'];

      // 2. Guardar Días
      for (var dia in _itinerario['dias']) {
        String fDia = DateFormat('yyyy-MM-dd').format(_parseDate(dia['fecha_calendario']));

        final diaResp = await _supabase.from('itinerario_dias').insert({
          'id_itinerario': _itinerario['id'],
          'numero_dia': dia['numero_dia'],
          'fecha_calendario': fDia,
        }).select().single();

        dia['db_id'] = diaResp['id'];

        // 3. Guardar Actividades
        for (var act in dia['actividades']) {
          final actResp = await _supabase.from('itinerario_actividades').insert({
            'id_dia': dia['db_id'], 
            'nombre': act['nombre'], 
            'hora_inicio': "${_formatearHora(act['hora_inicio'])}:00",
            'hora_fin': "${_formatearHora(act['hora_fin'])}:00",
            'notas_usuario': act['notas'] ?? '', 
            'es_prioridad': act['es_prioridad'] ?? false,
            'precio': act['precio'] ?? 0, 
          }).select().single();
          act['db_id'] = actResp['id']; 
        }
      }
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFF006D5B), content: Text('¡Itinerario sincronizado!')));
      
    } catch (e) {
      _mostrarError('No se pudo guardar: Ya tienes un itinerario activo.');
      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomeScreen()), (route) => false);
        });
      }
    } finally {
      if (mounted) setState(() => _estaGuardando = false);
    }
  }

  Future<void> _actualizarActividadEnBDD(Map<String, dynamic> act) async {
    if (act['db_id'] == null) return;
    try {
      await _supabase.from('itinerario_actividades').update({
        'nombre': act['nombre'],
        'hora_inicio': '${_formatearHora(act['hora_inicio'])}:00',
        'hora_fin': '${_formatearHora(act['hora_fin'])}:00',
        'notas_usuario': act['notas'] ?? '',
      }).eq('id', act['db_id']);
    } catch (e) {
      _mostrarError("Error actualizando: $e");
    }
  }

  Future<void> _eliminarActividadEnBDD(Map<String, dynamic> act, int idxDia) async {
    if (act['db_id'] != null) {
      try {
        await _supabase.from('itinerario_actividades').delete().eq('id', act['db_id']);
      } catch (e) { debugPrint("Fallo al borrar de BD: $e"); }
    }
    setState(() {
      _itinerario['dias'][idxDia]['actividades'].remove(act);
      _calcularPresupuesto();
    });
  }

  Future<void> _eliminarItinerarioCompleto() async {
    if (_itinerario['id'] != null) {
      try {
        await _supabase.from('itinerarios').delete().eq('id', _itinerario['id']);
      } catch(e) {
        debugPrint("Error borrando: $e");
      }
    }
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomeScreen()), (route) => false);
  }

  void _mostrarError(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text(m)));

  void _calcularPresupuesto() {
    double total = 0;
    for (var dia in (_itinerario['dias'] ?? [])) {
      for (var actividad in (dia['actividades'] ?? [])) {
        total += (actividad['precio'] ?? 0).toDouble();
      }
    }
    setState(() => _presupuestoTotal = total);
  }

  // --- LÓGICA DE VALIDACIÓN DE HORARIOS ---
  bool _hayConflicto(int numDia, String hI, String hF, {String? ignorarNombre}) {
    var actividades = _itinerario['dias'][numDia - 1]['actividades'];
    double nStart = _toMinutes(hI);
    double nEnd = _toMinutes(hF);

    for (var act in actividades) {
      if (ignorarNombre != null && act['nombre'] == ignorarNombre) continue;
      double eStart = _toMinutes(act['hora_inicio']);
      double eEnd = _toMinutes(act['hora_fin']);
      
      // Choque: El nuevo inicia antes de que termine el actual, Y el nuevo termina después de que empiece el actual
      if (nStart < eEnd && nEnd > eStart) return true;
    }
    return false;
  }

  double _toMinutes(String hhmm) {
    var p = _formatearHora(hhmm).split(':');
    return double.parse(p[0]) * 60 + double.parse(p[1]);
  }

  // --- MODALES (EDICIÓN Y NUEVA) ---
  void _mostrarEditorActividad(Map<String, dynamic> actividad, int idxDia) {
    String nombreEditado = actividad['nombre'];
    String notas = actividad['notas'] ?? '';
    
    String horaLimpiaInicio = _formatearHora(actividad['hora_inicio']);
    String horaLimpiaFin = _formatearHora(actividad['hora_fin']);

    TimeOfDay inicio = TimeOfDay(hour: int.parse(horaLimpiaInicio.split(':')[0]), minute: int.parse(horaLimpiaInicio.split(':')[1]));
    TimeOfDay fin = TimeOfDay(hour: int.parse(horaLimpiaFin.split(':')[0]), minute: int.parse(horaLimpiaFin.split(':')[1]));

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Editar Actividad', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF001F1A))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                ],
              ),
              const SizedBox(height: 15),
              TextFormField(
                initialValue: nombreEditado,
                decoration: InputDecoration(labelText: 'Nombre de la actividad', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                onChanged: (v) => nombreEditado = v,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _timeBtn('Hora de inicio', inicio, (t) => setModalState(() => inicio = t))),
                  const SizedBox(width: 15),
                  Expanded(child: _timeBtn('Hora de fin', fin, (t) => setModalState(() => fin = t))),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                maxLines: 3,
                controller: TextEditingController(text: notas),
                decoration: InputDecoration(labelText: 'Notas personales', hintText: 'Ej: Preparar presentación...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                onChanged: (v) => notas = v,
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _eliminarActividadEnBDD(actividad, idxDia);
                      },
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        String hI = "${inicio.hour.toString().padLeft(2,'0')}:${inicio.minute.toString().padLeft(2,'0')}";
                        String hF = "${fin.hour.toString().padLeft(2,'0')}:${fin.minute.toString().padLeft(2,'0')}";
                        
                        if (_hayConflicto(_itinerario['dias'][idxDia]['numero_dia'], hI, hF, ignorarNombre: actividad['nombre'])) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.orange, content: Text('⚠️ Horario ocupado. Debes liberar espacio.')));
                        } else {
                          setState(() {
                            actividad['nombre'] = nombreEditado;
                            actividad['hora_inicio'] = hI;
                            actividad['hora_fin'] = hF;
                            actividad['notas'] = notas;
                            _ordenarActividades(); // Reordena si editaste la hora
                          });
                          await _actualizarActividadEnBDD(actividad);
                          if (mounted) Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text('Guardar Cambios', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006D5B), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeBtn(String label, TimeOfDay time, Function(TimeOfDay) onPick) {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: time);
        if (t != null) onPick(t);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Icon(Icons.access_time, size: 18, color: Color(0xFF006D5B)),
            ]),
          ),
        ],
      ),
    );
  }

  void _mostrarModalNuevaActividad() {
    int diaSel = 1;
    String nombre = "";
    TimeOfDay inicio = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay fin = const TimeOfDay(hour: 12, minute: 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setMState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nueva Actividad', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: diaSel,
                decoration: InputDecoration(labelText: 'Día de la Actividad', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: (_itinerario['dias'] as List).map<DropdownMenuItem<int>>((d) {
                  DateTime fecha = _parseDate(d['fecha_calendario']);
                  String fechaFormateada = DateFormat('EEEE, d MMM', 'es').format(fecha);
                  return DropdownMenuItem<int>(value: d['numero_dia'] as int, child: Text('Día ${d['numero_dia']} - ${fechaFormateada.capitalize()}'));
                }).toList(),
                onChanged: (v) => setMState(() => diaSel = v!),
              ),
              const SizedBox(height: 15),
              TextField(
                decoration: InputDecoration(labelText: '¿Qué harás?', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), 
                onChanged: (v) => nombre = v
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: TextButton.icon(onPressed: () async { final t = await showTimePicker(context: context, initialTime: inicio); if (t != null) setMState(() => inicio = t); }, icon: const Icon(Icons.timer), label: Text(inicio.format(context)))),
                  Expanded(child: TextButton.icon(onPressed: () async { final t = await showTimePicker(context: context, initialTime: fin); if (t != null) setMState(() => fin = t); }, icon: const Icon(Icons.timer_off), label: Text(fin.format(context)))),
                ],
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006D5B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                if (nombre.isEmpty) return;
                String hI = "${inicio.hour.toString().padLeft(2,'0')}:${inicio.minute.toString().padLeft(2,'0')}";
                String hF = "${fin.hour.toString().padLeft(2,'0')}:${fin.minute.toString().padLeft(2,'0')}";
                
                // VALIDACIÓN ACTIVA ANTES DE GUARDAR
                if (_hayConflicto(diaSel, hI, hF)) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.orange, content: Text('⚠️ Horario ocupado. Debes liberar espacio.')));
                   return; // Detiene la creación
                }

                var nuevaAct = {
                  'nombre': nombre, 'hora_inicio': hI, 'hora_fin': hF, 'es_prioridad': false, 'precio': 0, 'notas': ''
                };

                setState(() {
                  _itinerario['dias'][diaSel - 1]['actividades'].add(nuevaAct);
                  _ordenarActividades(); // Ordena de nuevo para insertarlo donde toca
                });
                
                // Guardar individualmente la nueva actividad
                if (_itinerario['dias'][diaSel - 1]['db_id'] != null) {
                  try {
                    final resp = await _supabase.from('itinerario_actividades').insert({
                      'id_dia': _itinerario['dias'][diaSel - 1]['db_id'],
                      'nombre': nombre,
                      'hora_inicio': '$hI:00',
                      'hora_fin': '$hF:00',
                    }).select().single();
                    var lista = _itinerario['dias'][diaSel - 1]['actividades'] as List;
                    int index = lista.indexOf(nuevaAct);
                    if (index != -1) lista[index]['db_id'] = resp['id'];
                  } catch (e) { debugPrint("Error insertando nueva act: $e"); }
                }
                
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF006D5B)), onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomeScreen()), (route) => false)),
        title: Text(_itinerario['titulo'], style: const TextStyle(color: Color(0xFF001F1A), fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFE8F6F3), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF006D5B)),
                  const SizedBox(width: 4),
                  Text('Bs. ${_presupuestoTotal.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF006D5B), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('¿Eliminar Itinerario?'), content: const Text('Esto borrará tu plan permanentemente.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                    ElevatedButton(onPressed: _eliminarItinerarioCompleto, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Sí, borrar', style: TextStyle(color: Colors.white))),
                  ],
                ),
              );
            },
          )
        ],
      ),
      // --- AQUÍ ESTÁ EL BOTÓN DE (+) QUE HABÍA DESAPARECIDO ---
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF006D5B), 
        onPressed: _mostrarModalNuevaActividad, 
        child: const Icon(Icons.add, color: Colors.white)
      ),
      body: _estaGuardando 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF006D5B)))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: (_itinerario['dias'] ?? []).length,
            itemBuilder: (context, idxDia) {
              var dia = _itinerario['dias'][idxDia];
              DateTime fechaDia = _parseDate(dia['fecha_calendario']);
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header de Fecha
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Color(0xFF006D5B), size: 20),
                      const SizedBox(width: 8),
                      Text('Día ${dia['numero_dia']} - ${DateFormat('EEEE d', 'es').format(fechaDia).capitalize()}', 
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF001F1A))),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Lista de actividades
                  ...(dia['actividades'] ?? []).map<Widget>((act) {
                    bool esComida = act['nombre'].contains('🍴');
                    bool esPrioridad = act['es_prioridad'] ?? false;
                    double precio = (act['precio'] ?? 0).toDouble();
                    String notas = act['notas'] ?? '';

                    return Dismissible(
                      key: UniqueKey(),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _eliminarActividadEnBDD(act, idxDia),
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 25),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.delete, color: Colors.white, size: 28),
                      ),
                      child: GestureDetector(
                        onTap: () => _mostrarEditorActividad(act, idxDia),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Horas y Línea conectora
                              SizedBox(
                                width: 55,
                                child: Column(
                                  children: [
                                    Text(_formatearHora(act['hora_inicio']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF2D3142))),
                                    const SizedBox(height: 2),
                                    Text(_formatearHora(act['hora_fin']), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                              
                              // Punto central
                              Column(
                                children: [
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 10, height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: esComida ? Colors.grey.shade400 : (esPrioridad ? const Color(0xFFE67E22) : const Color(0xFF006D5B)),
                                      border: Border.all(color: Colors.white, width: 2)
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),

                              // Tarjeta
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text(act['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1C1E)), maxLines: 2)),
                                          if (esPrioridad) const Icon(Icons.star_border, color: Color(0xFF006D5B), size: 22),
                                        ],
                                      ),
                                      if (notas.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(notas, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      ],
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          if (precio > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: const Color(0xFFE8F6F3), borderRadius: BorderRadius.circular(6)),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.payments, size: 12, color: Color(0xFF006D5B)),
                                                  const SizedBox(width: 4),
                                                  Text('Bs. ${precio.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF006D5B), fontSize: 11, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          if (precio == 0 && !esComida)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                                              child: Text('Gratuito', style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
    );
  }
}

// Extensión para capitalizar textos
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}