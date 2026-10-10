import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LegalDisclaimerDialog extends StatelessWidget {
  const LegalDisclaimerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F1726),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF25334A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gavel_rounded, color: Color(0xFF00F0FF), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'DISCLAIMER & TERMS',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF1E2B3E), height: 20),
              _disclaimerSection(
                title: '1. Educational & Simulation Purpose Only',
                content:
                    'StockPulse is strictly an analytical, educational, and virtual backtesting environment. All trade buttons (BUY/SELL) and virtual capital represent simulated paper-trading without real monetary risk.',
              ),
              const SizedBox(height: 10),
              _disclaimerSection(
                title: '2. Not a SEBI Registered Advisory',
                content:
                    'StockPulse, its creators, and its automated market scans do NOT provide investment advice, buy/sell recommendations, or portfolio management services. We are not registered with SEBI as an investment advisor or research analyst.',
              ),
              const SizedBox(height: 10),
              _disclaimerSection(
                title: '3. Market Risk Warning',
                content:
                    'Securities trading and investment in financial markets involve high risk of capital loss. Past backtested performance is no guarantee of future returns. Users must consult a qualified financial advisor before making real market investments.',
              ),
              const SizedBox(height: 10),
              _disclaimerSection(
                title: '4. Data Accuracy',
                content:
                    'Market prices, OHLC records, delivery percentages, and news feeds are sourced from publicly available financial portals. While efforts are made for data integrity, we do not guarantee zero latency or 100% real-time accuracy.',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF162032),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFF25334A)),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('I Understand', style: TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _disclaimerSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          content,
          style: const TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.35),
        ),
      ],
    );
  }
}
