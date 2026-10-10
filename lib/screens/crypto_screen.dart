import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../widgets/crypto_card.dart';

class CryptoScreen extends StatefulWidget {
  const CryptoScreen({super.key});

  @override
  State<CryptoScreen> createState() => _CryptoScreenState();
}

class _CryptoScreenState extends State<CryptoScreen> {
  Map<String, dynamic> prices = {};
  bool isLoading = true;

  Future<void> fetchPrices() async {
    setState(() => isLoading = true);
    final url = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,binancecoin,solana,ripple,cardano&vs_currencies=usd,inr&include_24hr_change=true');
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        setState(() {
          prices = jsonDecode(res.body);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchPrices();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: const Color(0xFF00E5FF),
        backgroundColor: const Color(0xFF131B2A),
        onRefresh: fetchPrices,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Crypto Spot',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 2),
                        const Text('Live INR & USD Spot Tracker',
                            style: TextStyle(fontSize: 12, color: Color(0xFF8896AB))),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF)),
                      onPressed: fetchPrices,
                    ),
                  ],
                ),
              ),
            ),
            isLoading
                ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final coinKey = prices.keys.elementAt(index);
                          return CryptoCard(coinKey: coinKey, data: prices[coinKey]);
                        },
                        childCount: prices.keys.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
