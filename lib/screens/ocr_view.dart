import 'package:flutter/material.dart';

class OcrView extends StatelessWidget {
  const OcrView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Center(child: Text("Vista de Cámara", style: TextStyle(color: Colors.white))),
          // Marco de escaneo
          Center(
            child: Container(
              width: 250, height: 150,
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(15)),
            ),
          ),
          Positioned(
            bottom: 50, left: 0, right: 0,
            child: Column(
              children: [
                const Text("Escanea un letrero o menú", style: TextStyle(color: Colors.white)),
                const SizedBox(height: 20),
                CircleAvatar(radius: 35, backgroundColor: Colors.white, child: IconButton(onPressed: () {}, icon: const Icon(Icons.camera, size: 35, color: Colors.black))),
              ],
            ),
          ),
          Positioned(top: 40, left: 20, child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white))),
        ],
      ),
    );
  }
}