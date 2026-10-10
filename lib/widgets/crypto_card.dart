import 'package:flutter/material.dart';

class CryptoCard extends StatelessWidget {
  final String coinKey;
  final dynamic data;

  const CryptoCard({super.key, required this.coinKey, required this.data});

  @override
  Widget build(BuildContext context) {
    final double change = (data['usd_24h_change'] ?? 0.0).toDouble();
    final bool isUp = change >= 0;
    final color = isUp ? const Color(0xFF00E676) : const Color(0xFFFF5252);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF202C42)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF223048),
            child: Text(coinKey.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(coinKey.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              Text('₹ ${data['inr'] ?? 0}', style: const TextStyle(fontSize: 12, color: Color(0xFF8896AB))),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${data['usd'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              Text('${isUp ? '+' : ''}${change.toStringAsFixed(2)}%',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ],
          )
        ],
      ),
    );
  }
}
