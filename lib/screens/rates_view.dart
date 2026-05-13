import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RatesView extends StatefulWidget {
  const RatesView({super.key});

  @override
  State<RatesView> createState() => _RatesViewState();
}

class _RatesViewState extends State<RatesView> {
  // Colores WALI
  final Color brandTeal = const Color(0xFF0F988A);
  final Color brandOrange = const Color(0xFFF57C00);
  final Color textDark = const Color(0xFF2D3E42);
  final Color textLight = const Color(0xFF546E7A);

  // Listas para los Dropdowns
  List<Map<String, dynamic>> zonas = [];
  List<Map<String, dynamic>> transportes = [];

  // Variables de selección
  int? selectedOrigenId;
  int? selectedDestinoId;
  int? selectedTransporteId; // Opcional para filtrar

  List<Map<String, dynamic>> resultados = [];
  bool isLoading = false;
  bool isLoadingCombos = true;
  bool _busquedaRealizada = false;

  @override
  void initState() {
    super.initState();
    _cargarCombos();
  }

  // 1. CARGAMOS LOS SUBDOMINIOS DESDE SUPABASE
  Future<void> _cargarCombos() async {
    try {
      final client = Supabase.instance.client;

      // Zonas (id_dominio = 10)
      final dataZonas = await client
          .from('subdominios')
          .select('id, descripcion')
          .eq('id_dominio', 10)
          .order('descripcion');

      // Transportes (id_dominio = 9)
      final dataTransporte = await client
          .from('subdominios')
          .select('id, descripcion')
          .eq('id_dominio', 9)
          .order('descripcion');

      if (mounted) {
        setState(() {
          zonas = List<Map<String, dynamic>>.from(dataZonas);
          transportes = List<Map<String, dynamic>>.from(dataTransporte);
          isLoadingCombos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar zonas: $e')));
        setState(() => isLoadingCombos = false);
      }
    }
  }

  // 2. BUSCAMOS LAS TARIFAS (VERSIÓN CON DEBUGGING)
  Future<void> _buscarTarifa() async {
    if (selectedOrigenId == null || selectedDestinoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona origen y destino')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      _busquedaRealizada = true;
    });

    try {
      // 1. Traemos TODAS las tarifas activas (Sin filtros complejos de origen/destino)
      var query = Supabase.instance.client
          .from('tarifas_transporte')
          .select('*')
          .eq('estado', true);

      // Si eligió un transporte específico, lo filtramos en la base de datos
      if (selectedTransporteId != null) {
        query = query.eq('id_tipo_transporte', selectedTransporteId!);
      }

      final response = await query;

      // --- INICIO DE DEPURACIÓN EN CONSOLA ---
      debugPrint('=== WALI DEBUG ===');
      debugPrint('Tarifas activas en la BD: ${response.length}');
      debugPrint(
        'Buscando ruta: Origen ($selectedOrigenId) <-> Destino ($selectedDestinoId)',
      );
      // ---------------------------------------

      // 2. Filtramos manualmente del lado de Flutter (Lógica Ida y Vuelta)
      final datosFiltrados = response.where((tarifa) {
        int origenDb = tarifa['id_zona_origen'] as int;
        int destinoDb = tarifa['id_zona_destino'] as int;

        bool esIda =
            (origenDb == selectedOrigenId && destinoDb == selectedDestinoId);
        bool esVuelta =
            (origenDb == selectedDestinoId && destinoDb == selectedOrigenId);

        return esIda || esVuelta;
      }).toList();

      debugPrint('Tarifas que coinciden con la ruta: ${datosFiltrados.length}');

      if (mounted) {
        setState(() {
          resultados = List<Map<String, dynamic>>.from(datosFiltrados);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al buscar: $e')));
        debugPrint('ERROR WALI: $e');
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // FUNCIONES AUXILIARES PARA LA UI
  String _obtenerNombre(int id, List<Map<String, dynamic>> lista) {
    final item = lista.firstWhere(
      (element) => element['id'] == id,
      orElse: () => {'descripcion': 'Desconocido'},
    );
    return item['descripcion'];
  }

  IconData _obtenerIconoTransporte(int idTransporte) {
    switch (idTransporte) {
      case 901:
        return Icons.local_taxi; // Radio Taxi
      case 902:
        return Icons.tram; // Mi Teleférico
      case 903:
        return Icons.directions_bus; // PumaKatari
      case 904:
        return Icons.airport_shuttle; // Minibús
      case 905:
        return Icons.directions_car; // Trufi
      default:
        return Icons.commute;
    }
  }

  Widget _buildBadge(String text, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 6, top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lógica para saber si es de noche en La Paz (20:00 a 06:00)
    final horaActual = DateTime.now().hour;
    final esDeNoche = horaActual >= 20 || horaActual <= 6;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFA),
      appBar: AppBar(
        title: Text(
          'Calculadora de Rutas',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textDark),
      ),
      body: isLoadingCombos
          ? Center(child: CircularProgressIndicator(color: brandTeal))
          : Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10,
              ),
              child: Column(
                children: [
                  // --- FORMULARIO DE BÚSQUEDA ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          decoration: _inputStyle(
                            "¿Desde dónde sales?",
                            Icons.my_location,
                          ),
                          initialValue:
                              selectedOrigenId, // <-- Cambiado de value a initialValue
                          isExpanded: true,
                          items: zonas.map((z) {
                            return DropdownMenuItem(
                              value:
                                  z['id']
                                      as int, // (Este value SÍ se queda, porque es del item)
                              child: Text(
                                z['descripcion'],
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => selectedOrigenId = val),
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<int>(
                          decoration: _inputStyle(
                            "¿A dónde vas?",
                            Icons.location_on_outlined,
                          ),
                          initialValue: selectedDestinoId, // <-- Cambiado aquí
                          isExpanded: true,
                          items: zonas.map((z) {
                            return DropdownMenuItem(
                              value: z['id'] as int,
                              child: Text(
                                z['descripcion'],
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => selectedDestinoId = val),
                        ),
                        const SizedBox(height: 15),
                        // Filtro opcional de transporte
                        DropdownButtonFormField<int>(
                          decoration: _inputStyle(
                            "Tipo de Transporte (Opcional)",
                            Icons.commute,
                          ),
                          initialValue:
                              selectedTransporteId, // <-- Cambiado aquí
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text("Todos los transportes"),
                            ),
                            ...transportes.map((t) {
                              return DropdownMenuItem(
                                value: t['id'] as int,
                                child: Text(t['descripcion']),
                              );
                            }),
                          ],
                          onChanged: (val) =>
                              setState(() => selectedTransporteId = val),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandTeal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: isLoading ? null : _buscarTarifa,
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Ver Tarifas',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- RESULTADOS ---

                  // ESTADO 1: AÚN NO HA BUSCADO NADA (Bienvenida)
                  if (!isLoading && !_busquedaRealizada)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: brandTeal.withValues(alpha: 0.05),
                            ),
                            child: Icon(
                              Icons.map_outlined,
                              size: 70,
                              color: brandTeal.withValues(alpha: 0.3),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "¿A dónde te lleva tu aventura hoy?",
                            style: TextStyle(
                              color: textDark,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Selecciona tu origen y destino para\ndescubrir la mejor ruta paceña.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textLight,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ESTADO 2: BUSCÓ, PERO NO HAY DATOS EN LA BASE DE DATOS
                  if (!isLoading && _busquedaRealizada && resultados.isEmpty)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "Sin resultados",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Aún no tenemos tarifas registradas\npara esta ruta específica.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textLight),
                          ),
                        ],
                      ),
                    ),

                  // ESTADO 3: ¡ENCONTRÓ TARIFAS! (Mostramos la lista)
                  if (!isLoading && resultados.isNotEmpty)
                    Expanded(
                      child: Builder(
                        // Usamos un Builder para calcular el mínimo antes de dibujar
                        builder: (context) {
                          // 1. Encontrar el precio más bajo de toda la lista
                          double minCosto = double.infinity;
                          for (var r in resultados) {
                            double costo =
                                double.tryParse(
                                  r['costo_estimado'].toString(),
                                ) ??
                                0.0;
                            if (costo < minCosto) minCosto = costo;
                          }

                          // 2. Ordenar los resultados (Opcional, pero bueno: del más barato al más caro)
                          resultados.sort((a, b) {
                            double costoA =
                                double.tryParse(
                                  a['costo_estimado'].toString(),
                                ) ??
                                0.0;
                            double costoB =
                                double.tryParse(
                                  b['costo_estimado'].toString(),
                                ) ??
                                0.0;
                            return costoA.compareTo(costoB);
                          });

                          return ListView.builder(
                            itemCount: resultados.length,
                            itemBuilder: (context, index) {
                              final tarifa = resultados[index];

                              final nombreTransporte = _obtenerNombre(
                                tarifa['id_tipo_transporte'],
                                transportes,
                              );
                              final costoBase = tarifa['costo_estimado']?.toString() ?? '0.00';
                              final extra =
                                  tarifa['observaciones']?.toString().trim() ??
                                  '';
                              final icono = _obtenerIconoTransporte(
                                tarifa['id_tipo_transporte'],
                              );

                              // Nuevo: Obtenemos el tiempo (si no hay dato en BD, mostramos '--')
                              final tiempo =
                                  tarifa['tiempo_estimado_minutos']
                                      ?.toString() ??
                                  '--';

                              // Lógica de costo final (Noche)
                              bool tieneTarifaNocturna =
                                  extra.isNotEmpty &&
                                  double.tryParse(extra) != null;
                              String costoMostrar =
                                  esDeNoche && tieneTarifaNocturna
                                  ? extra
                                  : costoBase;

                              // LÓGICA DE ETIQUETAS (BADGES)
                              double costoActual =
                                  double.tryParse(costoBase) ?? 0.0;
                              bool esElMasBarato = costoActual == minCosto;
                              bool esTeleferico =
                                  tarifa['id_tipo_transporte'] == 902;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 15),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: brandTeal.withValues(alpha: 0.12),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start, // Alineamos arriba
                                    children: [
                                      // Ícono principal
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundColor: brandTeal.withValues(
                                          alpha: 0.1,
                                        ),
                                        child: Icon(
                                          icono,
                                          color: brandTeal,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 15),

                                      // Columna central (Nombres, tiempo y badges)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nombreTransporte,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: textDark,
                                              ),
                                            ),

                                            const SizedBox(height: 4),

                                            // NUEVO: Estimación de tiempo
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.schedule,
                                                  size: 14,
                                                  color: textLight,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Aprox. $tiempo min',
                                                  style: TextStyle(
                                                    color: textLight,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            // NUEVO: Fila de Medallas (Badges)
                                            Wrap(
                                              children: [
                                                if (esElMasBarato)
                                                  _buildBadge(
                                                    "Más económico",
                                                    const Color(0xFF43A047),
                                                    Icons.local_offer,
                                                  ), // Verde
                                                if (esTeleferico)
                                                  _buildBadge(
                                                    "Mejor Experiencia",
                                                    brandOrange,
                                                    Icons.star,
                                                  ), // Naranja WALI
                                              ],
                                            ),

                                            if (tieneTarifaNocturna) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(
                                                    esDeNoche
                                                        ? Icons.nightlight_round
                                                        : Icons.wb_sunny,
                                                    size: 14,
                                                    color: brandOrange,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    esDeNoche
                                                        ? 'Tarifa nocturna aplicada'
                                                        : 'Tarifa estándar',
                                                    style: TextStyle(
                                                      color: textLight,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Precio a la derecha
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$costoMostrar Bs.',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: brandTeal,
                                            ),
                                          ),
                                          if (tieneTarifaNocturna && !esDeNoche)
                                            Text(
                                              'Noche: $extra Bs.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: brandOrange,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // Estilo reutilizable para los Dropdowns
  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF546E7A)),
      prefixIcon: Icon(icon, color: brandTeal.withValues(alpha: 0.7)),
      filled: true,
      fillColor: const Color(0xFFF8FAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: brandTeal.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: brandTeal, width: 1.5),
      ),
    );
  }
}
