import 'package:flutter/material.dart';

class ChatView extends StatelessWidget {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente Wali')),
      body: Column(
        children: [
          const Expanded(
            child: Center(child: Text('¿En qué puedo ayudarte hoy en La Paz?')),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pregunta sobre tradiciones o rutas...',
                suffixIcon: const Icon(Icons.send, color: Color(0xFF0F988A)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}