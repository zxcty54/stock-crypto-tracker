import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunitySentimentCard extends StatefulWidget {
  final double niftyLivePrice;
  final String niftyChangeStr; // e.g. "+0.17%" or "-0.45%"
  final String marketStatus;
  final bool isVotingAllowed;

  const CommunitySentimentCard({
    super.key,
    required this.niftyLivePrice,
    this.niftyChangeStr = "+0.00%", // Safe default: Compilation error fix
    this.marketStatus = "POST_MARKET",
    this.isVotingAllowed = true,
  });

  @override
  State<CommunitySentimentCard> createState() => _CommunitySentimentCardState();
}

class _CommunitySentimentCardState extends State<CommunitySentimentCard>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _activeTab = 0; // 0 = Daily Mood, 1 = Monthly Outlook
  String? _myVote;
  String? _myTargetLevel;
  bool _isSubmitting = false;

  // Real Dynamic Accountability State
  String? _yesterdayResultText;
  bool _isCrowdWinner = false;
  bool _hasYesterdayData = false;

  late AnimationController _pulseController;

  static const List<String> _monthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  // Dynamic Current Month Name
  String get _currentMonthName {
    final now = DateTime.now();
    return _monthNames[now.month - 1];
  }

  // Dynamic Rolling Keys (Month rollover handled automatically)
  String get _dailyPeriodKey {
    final now = DateTime.now();
    return "DAILY-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String get _monthlyPeriodKey {
    final now = DateTime.now();
    return "MONTHLY-${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  String get _currentPeriod => _activeTab == 0 ? _dailyPeriodKey : _monthlyPeriodKey;

  // Dynamic 500-Strike Ranges from Nifty CMP
  List<String> get _dynamicRanges {
    final p = widget.niftyLivePrice > 0 ? widget.niftyLivePrice : 22459.80;
    final base = ((p / 500).round() * 500).toInt();
    return [
      "> ${base + 500}",
      "${base - 500} - ${base + 500}",
      "< ${base - 500}",
    ];
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _loadUserExistingVote();
    _calculateYesterdayAccountability();
  }

  @override
  void didUpdateWidget(covariant CommunitySentimentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.niftyChangeStr != widget.niftyChangeStr) {
      _calculateYesterdayAccountability();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // Realtime Accuracy & Yesterday Validation
  // -------------------------------------------------------------
  Future<void> _calculateYesterdayAccountability() async {
    try {
      final now = DateTime.now();
      DateTime prevTradingDay = now.subtract(const Duration(days: 1));
      if (now.weekday == DateTime.monday) {
        prevTradingDay = now.subtract(const Duration(days: 3)); // Monday skips to Friday
      }

      final prevKey = "DAILY-${prevTradingDay.year}-${prevTradingDay.month.toString().padLeft(2, '0')}-${prevTradingDay.day.toString().padLeft(2, '0')}";

      final res = await _supabase
          .from('sentiment_stats')
          .select('bullish_pct, bearish_pct, total_votes')
          .eq('target_month', prevKey)
          .maybeSingle();

      if (res != null && (res['total_votes'] ?? 0) > 0) {
        final double prevBullPct = (res['bullish_pct'] as num).toDouble();
        final bool wasCrowdBullish = prevBullPct >= 50.0;

        final String changeStr = widget.niftyChangeStr;
        final bool isNiftyGreen = !changeStr.startsWith("-");

        final bool crowdWon = (wasCrowdBullish && isNiftyGreen) || (!wasCrowdBullish && !isNiftyGreen);

        if (mounted) {
          setState(() {
            _hasYesterdayData = true;
            _isCrowdWinner = crowdWon;
            _yesterdayResultText =
                "Yesterday: ${prevBullPct.toStringAsFixed(0)}% Bullish → NIFTY $changeStr [${crowdWon ? 'CROWD WON ✓' : 'CROWD TRAPPED ✗'}]";
          });
        }
      } else {
        if (mounted) setState(() => _hasYesterdayData = false);
      }
    } catch (_) {
      if (mounted) setState(() => _hasYesterdayData = false);
    }
  }

  Future<void> _loadUserExistingVote() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await _supabase
          .from('user_predictions')
          .select('prediction, target_level')
          .eq('user_id', user.id)
          .eq('target_month', _currentPeriod)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _myVote = res['prediction'] as String?;
          _myTargetLevel = res['target_level'] as String?;
        });
      }
    } catch (_) {}
  }

  void _switchTab(int index) {
    if (_activeTab == index) return;
    setState(() {
      _activeTab = index;
      _myVote = null;
      _myTargetLevel = null;
    });
    _loadUserExistingVote();
  }

  Future<void> _castVote(String type, {String? targetLevel}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0F1726),
          content: Text('Please create trader handle to vote!'),
        ),
      );
      return;
    }

    if (_activeTab == 0 && !widget.isVotingAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF141C2B),
          content: Text('Voting locked! Market is currently ${widget.marketStatus}.'),
        ),
      );
      return;
    }

    final bool isUpdate = _myVote != null;
    final bool isOnlyRangeChange = isUpdate && _myVote == type && _myTargetLevel != targetLevel;

    setState(() => _isSubmitting = true);
    HapticFeedback.selectionClick();

    try {
      final payload = {
        'user_id': user.id,
        'target_month': _currentPeriod,
        'prediction': type,
        'target_level': targetLevel ?? _myTargetLevel,
      };

      await _supabase.from('user_predictions').upsert(
        payload,
        onConflict: 'user_id,target_month',
      );

      if (mounted) {
        setState(() {
          _myVote = type;
          if (targetLevel != null) _myTargetLevel = targetLevel;
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10192A),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 1500),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                Icon(
                  isOnlyRangeChange ? Icons.tune_rounded : Icons.check_circle_rounded,
                  color: const Color(0xFF00E5FF),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOnlyRangeChange
                        ? 'Range Updated: $targetLevel'
                        : (isUpdate ? 'Vote Changed to $type' : 'Vote Recorded: $type'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vote error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF162035),
            Color(0xFF0D1424),
            Color(0xFF0B101D),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 2,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xFF00E5FF), Color(0xFF7000FF), Colors.transparent],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _supabase
                    .from('sentiment_stats')
                    .stream(primaryKey: ['target_month'])
                    .eq('target_month', _currentPeriod),
                builder: (context, snapshot) {
                  final data = snapshot.data?.isNotEmpty == true ? snapshot.data!.first : null;

                  final totalVotes = data?['total_votes'] ?? 0;
                  final bullPct = (data?['bullish_pct'] ?? 50.0).toDouble();
                  final bearPct = (data?['bearish_pct'] ?? 50.0).toDouble();
                  final sidePct = (data?['sideways_pct'] ?? 0.0).toDouble();

                  String dominantText = "⚖️ EVEN MATCH";
                  Color dominantColor = Colors.white70;

                  if (totalVotes > 0) {
                    if (bullPct > bearPct && bullPct > sidePct) {
                      dominantText = "🔥 BULL DOMINANCE (${bullPct.toStringAsFixed(0)}%)";
                      dominantColor = const Color(0xFF00FF88);
                    } else if (bearPct > bullPct && bearPct > sidePct) {
                      dominantText = "⚡ BEAR ATTACK (${bearPct.toStringAsFixed(0)}%)";
                      dominantColor = const Color(0xFFFF2A6D);
                    } else if (sidePct > bullPct && sidePct > bearPct) {
                      dominantText = "⚖️ RANGEBOUND (${sidePct.toStringAsFixed(0)}%)";
                      dominantColor = const Color(0xFFFFB300);
                    }
                  }

                  final bool isDailyLocked = _activeTab == 0 && !widget.isVotingAllowed;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. DYNAMIC ACCOUNTABILITY STRIP (Only visible when verified yesterday data exists)
                      if (_hasYesterdayData && _yesterdayResultText != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090E1A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isCrowdWinner
                                  ? const Color(0xFF00FF88).withOpacity(0.35)
                                  : const Color(0xFFFF2A6D).withOpacity(0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isCrowdWinner ? Icons.verified_rounded : Icons.warning_amber_rounded,
                                color: _isCrowdWinner ? const Color(0xFF00FF88) : const Color(0xFFFF2A6D),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _yesterdayResultText!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: _isCrowdWinner ? const Color(0xFF00FF88) : const Color(0xFFFF2A6D),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 2. HEADER ROW: BADGE + DYNAMIC TABS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDailyLocked
                                          ? Colors.orange.withOpacity(0.12)
                                          : const Color(0xFF00FF88).withOpacity(0.12 + (_pulseController.value * 0.1)),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDailyLocked
                                            ? Colors.orange.withOpacity(0.5)
                                            : const Color(0xFF00FF88).withOpacity(0.4 + (_pulseController.value * 0.4)),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: isDailyLocked ? Colors.orange : const Color(0xFF00FF88),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isDailyLocked ? "MARKET LIVE" : "LIVE POLL",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: isDailyLocked ? Colors.orange : const Color(0xFF00FF88),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "$totalVotes voted",
                                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF090D16),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF26354D)),
                            ),
                            child: Row(
                              children: [
                                _buildTabChip("Daily", 0),
                                _buildTabChip(_currentMonthName, 1),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 3. CLEAN QUESTION
                      Text(
                        _activeTab == 0
                            ? "Kal Nifty Bullish rahega ya Bearish?"
                            : "$_currentMonthName me Nifty ka Major Trend?",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 4. FLOATING DOMINANCE BADGE (Separate Row)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: dominantColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: dominantColor.withOpacity(0.35), width: 1),
                          ),
                          child: Text(
                            dominantText,
                            style: TextStyle(
                              color: dominantColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 5. UNCLUTTERED SPLIT SCOREBOARD
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                totalVotes == 0 ? "50%" : "${bullPct.toStringAsFixed(0)}%",
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF00FF88),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "BULLISH",
                                style: TextStyle(color: Color(0xFF00FF88), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          if (_activeTab == 1)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  totalVotes == 0 ? "0%" : "${sidePct.toStringAsFixed(0)}%",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFFFB300),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  "RANGE",
                                  style: TextStyle(color: Color(0xFFFFB300), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                totalVotes == 0 ? "50%" : "${bearPct.toStringAsFixed(0)}%",
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFFF2A6D),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "BEARISH",
                                style: TextStyle(color: Color(0xFFFF2A6D), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 6. 3D RATIO BAR
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0F1A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: totalVotes == 0 ? 50 : bullPct.round().clamp(2, 98),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF00C853), Color(0xFF00FF88)],
                                    ),
                                  ),
                                ),
                              ),
                              if (_activeTab == 1 && sidePct > 0) ...[
                                const SizedBox(width: 2),
                                Expanded(
                                  flex: sidePct.round().clamp(1, 98),
                                  child: Container(color: const Color(0xFFFFB300)),
                                ),
                              ],
                              const SizedBox(width: 2),
                              Expanded(
                                flex: totalVotes == 0 ? 50 : bearPct.round().clamp(2, 98),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFFF2A6D), Color(0xFFD50000)],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 7. ACTION BUTTONS & CHIPS
                      if (_activeTab == 0) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildHeroActionBtn(
                                label: "BULLISH",
                                type: "BULLISH",
                                icon: Icons.trending_up_rounded,
                                baseColor: const Color(0xFF00FF88),
                                isSelected: _myVote == "BULLISH",
                                isLocked: isDailyLocked,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildHeroActionBtn(
                                label: "BEARISH",
                                type: "BEARISH",
                                icon: Icons.trending_down_rounded,
                                baseColor: const Color(0xFFFF2A6D),
                                isSelected: _myVote == "BEARISH",
                                isLocked: isDailyLocked,
                              ),
                            ),
                          ],
                        ),
                        if (isDailyLocked) ...[
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              "🔒 Market is live. Daily voting opens at 3:30 PM.",
                              style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ] else ...[
                        // Spacious Monthly Container
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090E1A).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF1E2B3E)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "1. SELECT PRIMARY BIAS",
                                style: TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildHeroActionBtn(
                                      label: "BULLISH",
                                      type: "BULLISH",
                                      icon: Icons.trending_up_rounded,
                                      baseColor: const Color(0xFF00FF88),
                                      isSelected: _myVote == "BULLISH",
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildHeroActionBtn(
                                      label: "RANGE",
                                      type: "SIDEWAYS",
                                      icon: Icons.swap_horiz_rounded,
                                      baseColor: const Color(0xFFFFB300),
                                      isSelected: _myVote == "SIDEWAYS",
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildHeroActionBtn(
                                      label: "BEARISH",
                                      type: "BEARISH",
                                      icon: Icons.trending_down_rounded,
                                      baseColor: const Color(0xFFFF2A6D),
                                      isSelected: _myVote == "BEARISH",
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "2. TARGET RANGE",
                                    style: TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                  ),
                                  Text(
                                    "Nifty: ${widget.niftyLivePrice.toStringAsFixed(1)}",
                                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: _dynamicRanges.map((range) {
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      child: _buildRangeChip(range),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(String title, int idx) {
    final active = _activeTab == idx;
    return GestureDetector(
      onTap: () => _switchTab(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00E5FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? Colors.black : Colors.white60,
            fontWeight: FontWeight.w900,
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroActionBtn({
    required String label,
    required String type,
    required IconData icon,
    required Color baseColor,
    required bool isSelected,
    bool isLocked = false,
  }) {
    return InkWell(
      onTap: (_isSubmitting || isLocked) ? null : () => _castVote(type, targetLevel: _myTargetLevel),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isLocked
              ? Colors.white.withOpacity(0.04)
              : (isSelected ? baseColor.withOpacity(0.25) : const Color(0xFF0A0F1D)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLocked
                ? Colors.white12
                : (isSelected ? baseColor : baseColor.withOpacity(0.35)),
            width: isSelected ? 2.0 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: baseColor.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLocked ? Icons.lock_outline_rounded : icon,
              size: 15,
              color: isLocked ? Colors.white30 : (isSelected ? baseColor : Colors.white70),
            ),
            const SizedBox(width: 5),
            Text(
              isLocked ? "LOCKED" : (isSelected ? "$label ✓" : label),
              style: TextStyle(
                color: isLocked ? Colors.white30 : (isSelected ? baseColor : Colors.white),
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeChip(String range) {
    final isSelected = _myTargetLevel == range;
    return InkWell(
      onTap: _isSubmitting
          ? null
          : () {
              if (_myVote != null) {
                _castVote(_myVote!, targetLevel: range);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF141C2B),
                    content: Text('Pehle Bullish, Range ya Bearish select karein!'),
                  ),
                );
              }
            },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.2) : const Color(0xFF0E1524),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF26354D),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          range,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
