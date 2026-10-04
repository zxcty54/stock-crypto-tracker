import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: PortfolioTrackerWidget(),
  ));
}

// ---------------- MODEL CLASSES ---------------- //

class Stock {
  final String name;
  final double currentPrice;
  final String change;

  Stock({
    required this.name,
    required this.currentPrice,
    required this.change,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    // API keys handle karne ke multiple fallbacks (name, Stock, price, etc.)
    final rawName = json['name'] ?? json['Stock'] ?? json['symbol'] ?? 'UNKNOWN';
    final rawPrice = json['price'] ?? json['currentPrice'] ?? json['Current_Price'] ?? 0;
    final rawChange = json['change'] ?? json['Change'] ?? '0%';

    return Stock(
      name: rawName.toString().toUpperCase().trim(),
      currentPrice: double.tryParse(rawPrice.toString()) ?? 0.0,
      change: rawChange.toString(),
    );
  }
}

class Position {
  final String id;
  final String symbol;
  final int qty;
  final double buyPrice;
  final DateTime buyTime;

  Position({
    required this.id,
    required this.symbol,
    required this.qty,
    required this.buyPrice,
    required this.buyTime,
  });
}

// ---------------- MAIN WIDGET ---------------- //

class PortfolioTrackerWidget extends StatefulWidget {
  const PortfolioTrackerWidget({super.key});

  @override
  State<PortfolioTrackerWidget> createState() => _PortfolioTrackerWidgetState();
}

class _PortfolioTrackerWidgetState extends State<PortfolioTrackerWidget> {
  // Google Apps Script endpoint URL
  final String apiUrl =
      "[https://script.google.com/macros/s/AKfycbzE5FVwepYICR2SPsubssC8zdvCrFbEJqh1lEawkjb8DxVrAv2hTnOzKfozz4Sj3uW8vQ/exec](https://script.google.com/macros/s/AKfycbzE5FVwepYICR2SPsubssC8zdvCrFbEJqh1lEawkjb8DxVrAv2hTnOzKfozz4Sj3uW8vQ/exec)";

  // State variables
  double virtualCash = 500000.0; // ₹5,00,000 initial balance
  List<Position> portfolio = [];
  List<String> watchlist = [];
  Map<String, Stock> marketStocks = {};

  bool isLoading = true;
  Timer? refreshTimer;

  // Controllers for search and quantity
  final TextEditingController searchController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: "1");
  String? selectedStock;

  @override
  void initState() {
    super.initState();
    fetchMarketData();
    // Auto-refresh prices every 15 seconds
    refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => fetchMarketData());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    searchController.dispose();
    qtyController.dispose();
    super.dispose();
  }

  // API Call to fetch real-time Sheet data
  Future<void> fetchMarketData() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 302) {
        final List<dynamic> data = jsonDecode(response.body);
        final Map<String, Stock> loaded = {};
        for (var item in data) {
          final stock = Stock.fromJson(item);
          if (stock.name.isNotEmpty) {
            loaded[stock.name] = stock;
          }
        }
        setState(() {
          marketStocks = loaded;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Data fetch error: $e");
      setState(() => isLoading = false);
    }
  }

  // Trade Execution Logic
  void buyStock() {
    final symbol = selectedStock ?? searchController.text.toUpperCase().trim();
    final qty = int.tryParse(qtyController.text) ?? 0;

    if (!marketStocks.containsKey(symbol)) {
      showSnackbar("Kripya valid stock select karein!");
      return;
    }
    if (qty <= 0) {
      showSnackbar("Quantity kam se kam 1 honi chahiye!");
      return;
    }

    final currentPrice = marketStocks[symbol]!.currentPrice;
    final totalCost = currentPrice * qty;

    if (totalCost > virtualCash) {
      showSnackbar("Virtual balance kam hai!");
      return;
    }

    setState(() {
      virtualCash -= totalCost;
      portfolio.add(Position(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        symbol: symbol,
        qty: qty,
        buyPrice: currentPrice,
        buyTime: DateTime.now(),
      ));
      searchController.clear();
      selectedStock = null;
    });

    showSnackbar("$qty x $symbol ₹${currentPrice.toStringAsFixed(2)} par buy ho gaya!");
  }

  // Settle / Exit Position
  void exitPosition(Position pos) {
    final currentPrice = marketStocks[pos.symbol]?.currentPrice ?? pos.buyPrice;
    final settleAmount = currentPrice * pos.qty;
    final pnl = settleAmount - (pos.buyPrice * pos.qty);

    setState(() {
      virtualCash += settleAmount;
      portfolio.removeWhere((p) => p.id == pos.id);
    });

    final pnlText = pnl >= 0
        ? "+₹${pnl.toStringAsFixed(2)} Profit"
        : "-₹${pnl.abs().toStringAsFixed(2)} Loss";
    showSnackbar("${pos.symbol} settle hua ($pnlText)");
  }

  // Watchlist Actions
  void toggleWatchlist() {
    final symbol = selectedStock ?? searchController.text.toUpperCase().trim();
    if (!marketStocks.containsKey(symbol)) {
      showSnackbar("Valid stock select karein!");
      return;
    }

    setState(() {
      if (watchlist.contains(symbol)) {
        watchlist.remove(symbol);
        showSnackbar("$symbol Watchlist se hataya gaya");
      } else {
        watchlist.add(symbol);
        showSnackbar("$symbol Watchlist me add hua");
      }
    });
  }

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculation: Total portfolio value aur Unrealized P&L
    double totalInvested = 0;
    double currentPortfolioValue = 0;

    for (var pos in portfolio) {
      final curPrice = marketStocks[pos.symbol]?.currentPrice ?? pos.buyPrice;
      totalInvested += pos.buyPrice * pos.qty;
      currentPortfolioValue += curPrice * pos.qty;
    }

    final double unrealizedPnL = currentPortfolioValue - totalInvested;
    final double netWorth = virtualCash + currentPortfolioValue;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate theme
      appBar: AppBar(
        title: const Text("Virtual Trader & Portfolio"),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchMarketData,
            tooltip: "Refresh Prices",
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            onPressed: () {
              setState(() {
                virtualCash = 500000.0;
                portfolio.clear();
                watchlist.clear();
              });
              showSnackbar("Balance reset to ₹5,00,000");
            },
            tooltip: "Reset Balance",
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Metric Cards
                  _buildMetricsGrid(netWorth, virtualCash, totalInvested, unrealizedPnL),
                  const SizedBox(height: 20),

                  // 2. Search & Order Panel
                  _buildOrderPanel(),
                  const SizedBox(height: 25),

                  // 3. Open Positions (Copy-Trading Table)
                  _buildSectionHeader("Active Portfolio (Positions)", portfolio.length),
                  const SizedBox(height: 10),
                  _buildPortfolioList(),
                  const SizedBox(height: 25),

                  // 4. Watchlist
                  _buildSectionHeader("Watchlist", watchlist.length),
                  const SizedBox(height: 10),
                  _buildWatchlist(),
                ],
              ),
            ),
    );
  }

  // --- UI Components ---

  Widget _buildMetricsGrid(
      double netWorth, double cash, double invested, double pnl) {
    final isProfit = pnl >= 0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _metricTile("Total Net Worth", "₹${netWorth.toStringAsFixed(2)}", Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: _metricTile("Virtual Cash", "₹${cash.toStringAsFixed(2)}", Colors.blueAccent)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _metricTile("Invested Value", "₹${invested.toStringAsFixed(2)}", Colors.white70)),
            const SizedBox(width: 12),
            Expanded(
              child: _metricTile(
                "Unrealized P&L",
                "${isProfit ? '+' : ''}₹${pnl.toStringAsFixed(2)}",
                isProfit ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricTile(String title, String value, Color valColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valColor)),
        ],
      ),
    );
  }

  Widget _buildOrderPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Select Stock & Trade", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue val) {
              if (val.text.isEmpty) return const Iterable<String>.empty();
              return marketStocks.keys.where((stock) => stock.contains(val.text.toUpperCase()));
            },
            onSelected: (String sel) {
              selectedStock = sel;
            },
            fieldViewBuilder: (ctx, controller, focus, onSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focus,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Search stock (e.g. RELIANCE)...",
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Color(0xFF0F172A),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Qty",
                    labelStyle: TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Color(0xFF0F172A),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: buyStock,
                  child: const Text("BUY / COPY"),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF334155)),
                icon: const Icon(Icons.bookmark_add, color: Colors.cyanAccent),
                onPressed: toggleWatchlist,
                tooltip: "Add/Remove Watchlist",
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioList() {
    if (portfolio.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text("Koi active trade nahi hai. Upar se stock buy karein.",
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: portfolio.length,
      itemBuilder: (context, index) {
        final pos = portfolio[index];
        final curPrice = marketStocks[pos.symbol]?.currentPrice ?? pos.buyPrice;
        final invested = pos.buyPrice * pos.qty;
        final curVal = curPrice * pos.qty;
        final pnl = curVal - invested;
        final isProfit = pnl >= 0;

        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(pos.symbol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              "Qty: ${pos.qty} | Buy: ₹${pos.buyPrice.toStringAsFixed(2)} | LTP: ₹${curPrice.toStringAsFixed(2)}",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${isProfit ? '+' : ''}₹${pnl.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isProfit ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                    Text(
                      "₹${curVal.toStringAsFixed(2)}",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  onPressed: () => exitPosition(pos),
                  child: const Text("EXIT", style: TextStyle(fontSize: 12)),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWatchlist() {
    if (watchlist.isEmpty) {
      return const Text("Watchlist khali hai.", style: TextStyle(color: Colors.grey));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: watchlist.length,
      itemBuilder: (context, index) {
        final sym = watchlist[index];
        final stock = marketStocks[sym];

        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(sym, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stock != null) ...[
                  Text("₹${stock.currentPrice.toStringAsFixed(2)}  ",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text(stock.change,
                      style: TextStyle(
                        color: stock.change.contains('-') ? Colors.redAccent : Colors.greenAccent,
                      )),
                ],
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                  onPressed: () {
                    setState(() => watchlist.removeAt(index));
                  },
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(12)),
          child: Text("$count", style: const TextStyle(fontSize: 12, color: Colors.white)),
        )
      ],
    );
  }
}
