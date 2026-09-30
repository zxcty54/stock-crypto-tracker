import 'package:flutter/material.dart';

// 🪙 Bullion, Retail & Trend Cards Import
import '../widgets/metals_ticker_card.dart';
import '../widgets/ibja_retail_calculator_card.dart';
import '../widgets/retail_gold_trend_card.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: const Color(0xFF00E5FF),
          backgroundColor: const Color(0xFF0F1726),
          onRefresh: () async {
            // Screen refresh trigger
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 600));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: const [
              // 🪙 1. LIVE SPOT METALS, COPPER & FOREX TICKER
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: MetalsTickerCard(),
                ),
              ),

              // 🏬 2. IBJA GROUND REALITY RETAIL CALCULATOR (City + Karat + Making + GST)
              SliverToBoxAdapter(
                child: IbjaRetailCalculatorCard(),
              ),

              // 📈 3. 1-YEAR RETAIL ALPHA, NET LIQUIDATION & INFLATION TREND ENGINE
              SliverToBoxAdapter(
                child: RetailGoldTrendCard(),
              ),

              // Bottom Spacer taaki navigation dock content ko cut na kare
              SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
