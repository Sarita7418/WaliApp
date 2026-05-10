import 'package:flutter/material.dart';

class RatesView extends StatelessWidget {
  const RatesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tarifas de Transporte"), backgroundColor: const Color(0xFFF57C00), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Precios oficiales en La Paz", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _rateItem("Mi Teleférico", "3.00 Bs", Icons.cable),
            _rateItem("PumaKatari", "2.30 Bs", Icons.bus_alert),
            _rateItem("Minibús (Tramo corto)", "2.00 Bs", Icons.directions_bus),
          ],
        ),
      ),
    );
  }

  Widget _rateItem(String transport, String price, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [Icon(icon, color: const Color(0xFFF57C00)), const SizedBox(width: 15), Text(transport)]),
          Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}