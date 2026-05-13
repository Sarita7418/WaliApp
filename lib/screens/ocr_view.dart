import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OcrView extends StatefulWidget {
  const OcrView({super.key});

  @override
  State<OcrView> createState() => _OcrViewState();
}

class _OcrViewState extends State<OcrView> {
  final _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  
  bool _estaProcesando = false;
  File? _imagenSeleccionada;
  List<dynamic> _platosDetectados = [];

  // Colores alineados con tu módulo de Itinerarios
  final Color brandTeal = const Color(0xFF0F988A);
  final Color brandOrange = const Color(0xFFF57C00);
  final Color backgroundColor = const Color(0xFFF8FAFB);

  // --- LÓGICA DE NEGOCIO ---

  Future<void> _capturarImagen(ImageSource fuente) async {
    try {
      final XFile? imagen = await _picker.pickImage(source: fuente);
      if (imagen == null) return; 

      setState(() {
        _imagenSeleccionada = File(imagen.path);
        _estaProcesando = true;
        _platosDetectados = [];
      });

      await _procesarMenuOCR(imagen.path);
    } catch (e) {
      _mostrarMensaje("Error: $e", esError: true);
      setState(() => _estaProcesando = false);
    }
  }

  String _normalizarTexto(String texto) {
    return texto.toLowerCase()
      .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
      .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ñ', 'n');
  }

  Future<void> _procesarMenuOCR(String pathImagen) async {
    try {
      final inputImage = InputImage.fromFilePath(pathImagen);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      String textoMenuLimpio = _normalizarTexto(recognizedText.text);
      await textRecognizer.close();

      // CONSULTA LIMPIA: Sin "hints" raros, volviendo a lo que funcionaba
      final List<dynamic> catalogoPlatos = await _supabase
          .from('platos')
          .select('''
            *,
            plato_ingredientes (
              ingredientes (
                nombre, 
                es_alergeno, 
                id_tipo_alergeno
              )
            )
          ''')
          .eq('estado', true);

      List<dynamic> encontrados = [];
      for (var plato in catalogoPlatos) {
        if (textoMenuLimpio.contains(_normalizarTexto(plato['nombre']))) {
          encontrados.add(plato);
        }
      }

      setState(() {
        _platosDetectados = encontrados;
        _estaProcesando = false;
      });

    } catch (e) {
      _mostrarMensaje("Error en la BDD: $e", esError: true);
      setState(() => _estaProcesando = false);
    }
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: esError ? Colors.redAccent : brandTeal)
    );
  }

  // --- INTERFAZ DE USUARIO ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('', style: TextStyle(color: brandTeal, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        centerTitle: true,
      ),
      body: _estaProcesando 
          ? _buildLoadingView()
          : (_imagenSeleccionada == null ? _buildWelcomeView() : _buildResultsView()),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: brandTeal),
          const SizedBox(height: 20),
          Text("Identificando sabores paceños...", style: TextStyle(color: brandTeal, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildWelcomeView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_enhance_outlined, size: 80, color: brandTeal.withOpacity(0.3)),
          const SizedBox(height: 25),
          const Text("Analizador de Menús", textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF001F1A))),
          const SizedBox(height: 15),
          const Text("Toma una foto al menú para descubrir la historia, ingredientes y alertas de salud de los platos paceños.", 
            textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5)),
          const SizedBox(height: 40),
          _buildActionBtn("USAR CÁMARA", Icons.camera_alt, brandTeal, () => _capturarImagen(ImageSource.camera)),
          const SizedBox(height: 15),
          _buildActionBtn("SUBIR GALERÍA", Icons.image, brandOrange, () => _capturarImagen(ImageSource.gallery)),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _buildResultsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cuadro de imagen capturada
        Container(
          height: 160, width: double.infinity,
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            image: DecorationImage(image: FileImage(_imagenSeleccionada!), fit: BoxFit.cover),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]
          ),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: Colors.black26),
            child: Center(
              child: IconButton(
                icon: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.refresh, color: Colors.black)),
                onPressed: () => setState(() => _imagenSeleccionada = null),
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text("PLATOS IDENTIFICADOS (${_platosDetectados.length})", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: _platosDetectados.isEmpty
            ? const Center(child: Text("No se encontraron platos conocidos."))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _platosDetectados.length,
                itemBuilder: (context, index) => _buildPlatoCard(_platosDetectados[index]),
              ),
        ),
      ],
    );
  }

  Widget _buildPlatoCard(Map<String, dynamic> plato) {
    return GestureDetector(
      onTap: () => _mostrarDetallePlato(plato),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
              child: Image.network(
                plato['imagen_url'] ?? '', width: 90, height: 90, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 90, height: 90, color: brandTeal.withOpacity(0.1), child: Icon(Icons.broken_image, color: brandTeal)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plato['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF001F1A))),
                    const SizedBox(height: 4),
                    Text("Ver ficha técnica", style: TextStyle(color: brandTeal, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade300),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODAL DE DETALLE ---

  void _mostrarDetallePlato(Map<String, dynamic> plato) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => _buildDetalleModal(plato),
    );
  }

  Widget _buildDetalleModal(Map<String, dynamic> plato) {
    final List ingredientesRaw = plato['plato_ingredientes'] ?? [];
    
    // Filtros por categoría de ingrediente
    final alergenos = ingredientesRaw.where((i) => i['ingredientes']['es_alergeno'] == true && i['ingredientes']['id_tipo_alergeno'] != 604).toList();
    final picantes = ingredientesRaw.where((i) => i['ingredientes']['id_tipo_alergeno'] == 604).toList();
    final normales = ingredientesRaw.where((i) => i['ingredientes']['es_alergeno'] == false).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        children: [
          // Header con imagen
          Stack(
            children: [
              Container(
                height: 200, width: double.infinity,
                decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  child: Image.network(
                    plato['imagen_url'] ?? '', fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: brandTeal.withOpacity(0.1), child: Icon(Icons.restaurant, size: 50, color: brandTeal)),
                  ),
                ),
              ),
              Positioned(top: 20, right: 20, child: GestureDetector(onTap: () => Navigator.pop(context), child: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.close, color: Colors.black)))),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plato['nombre'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(plato['historia_origen'] ?? '', style: const TextStyle(color: Colors.black54, height: 1.5)),
                  
                  const SizedBox(height: 30),
                  
                  _buildSeccion(
                    titulo: "ALERTA DE ALÉRGENOS",
                    color: Colors.redAccent,
                    icon: Icons.warning_amber_rounded,
                    items: alergenos,
                    msgVacio: "No se detectaron alérgenos conocidos.",
                  ),

                  const SizedBox(height: 25),

                  _buildSeccion(
                    titulo: "NIVEL DE PICANTE",
                    color: brandOrange,
                    icon: Icons.whatshot_rounded,
                    items: picantes,
                    msgVacio: "Este plato no es picante.",
                  ),

                  const SizedBox(height: 25),

                  _buildSeccion(
                    titulo: "INGREDIENTES BASE",
                    color: brandTeal,
                    icon: Icons.check_circle_outline,
                    items: normales,
                    msgVacio: "Sin ingredientes base registrados.",
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccion({required String titulo, required Color color, required IconData icon, required List items, required String msgVacio}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1)),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(msgVacio, style: const TextStyle(color: Colors.black38, fontSize: 13, fontStyle: FontStyle.italic))
        else
          Wrap(
            spacing: 8, runSpacing: 8,
            children: items.map<Widget>((i) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
              child: Text(i['ingredientes']['nombre'], style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            )).toList(),
          ),
      ],
    );
  }
}