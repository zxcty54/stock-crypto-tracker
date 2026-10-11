import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/data/local_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../data/welcome_preferences.dart';

class FirstLaunchGate extends StatefulWidget {
  const FirstLaunchGate({
    super.key,
    required this.store,
    required this.child,
    this.localSamples = false,
    this.bypass = false,
  });
  final LocalStore store;
  final Widget child;
  final bool localSamples, bypass;
  @override
  State<FirstLaunchGate> createState() => _FirstLaunchGateState();
}

class _FirstLaunchGateState extends State<FirstLaunchGate> {
  late bool _completed = WelcomePreferences.hasCompleted(widget.store);
  Future<void> _finish() async {
    var stored = true;
    try {
      await WelcomePreferences.complete(widget.store);
    } catch (_) {
      stored = false;
    }
    if (!mounted) {
      return;
    }
    setState(() => _completed = true);
    if (!stored) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          toast(
            context,
            'The intro could not be saved on this device. You can still continue; it may appear next time.',
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => _completed || widget.bypass
      ? widget.child
      : WelcomeScreen(onComplete: _finish, localSamples: widget.localSamples);
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.onComplete,
    this.localSamples = false,
  });
  final Future<void> Function() onComplete;
  final bool localSamples;
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _index = 0;
  bool _busy = false;
  String? _error;
  static const _titles = [
    'Apna bazaar.\nApne log.',
    'Cash par order.\nDelivery ya pickup.',
    'Orders aur kharche,\nek jagah.',
  ];
  static const _descriptions = [
    'Danapur ke approved retailers aur wholesalers ko discover karo. Categories, product prices aur dated mandi rates ek simple app mein.',
    'Shop aur product delivery allow karein, aur accurate location se 500 m straight-line limit meet ho, toh home-delivery COD. Otherwise shop pickup aur wahin cash payment.',
    'Order complete/cancel status dekho, completed purchases ka expense record rakho, aur completion ke baad rating do. Apni shop list karni hai? My shop se apply karo—admin approval required hai.',
  ];
  static const _eyebrows = [
    'WELCOME TO DANAPUR BAZAAR',
    'LOCAL SHOPPING, CLEAR CHOICES',
    'YOUR EVERYDAY MARKETPLACE',
  ];
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not continue. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: canvas,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 16, 10),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 18,
                  runSpacing: 4,
                  children: [
                    const Brand(small: true),
                    TextButton(
                      key: const ValueKey('welcome-skip'),
                      onPressed: _busy ? null : _finish,
                      child: const Text('Skip intro'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  key: const ValueKey('welcome-pages'),
                  controller: _pages,
                  itemCount: 3,
                  physics: _busy ? const NeverScrollableScrollPhysics() : null,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (ctx, index) => _page(ctx, index),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (dot) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Semantics(
                            label: 'Welcome page ${dot + 1} of 3',
                            selected: _index == dot,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: _index == dot ? 30 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _index == dot ? green : line,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        if (_index > 0)
                          TextButton.icon(
                            key: const ValueKey('welcome-back'),
                            onPressed: _busy
                                ? null
                                : () => _pages.previousPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                  ),
                            icon: const Icon(Icons.arrow_back, size: 16),
                            label: const Text('Back'),
                          )
                        else
                          const Text(
                            '1 / 3',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        FilledButton.icon(
                          key: const ValueKey('welcome-next'),
                          onPressed: _busy
                              ? null
                              : _index == 2
                              ? _finish
                              : () => _pages.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                ),
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _index == 2
                                      ? Icons.storefront_outlined
                                      : Icons.arrow_forward,
                                  size: 18,
                                ),
                          label: Text(
                            _busy
                                ? 'Opening…'
                                : _index == 2
                                ? 'Get started'
                                : 'Next',
                          ),
                        ),
                      ],
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (widget.localSamples)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'This build uses labelled device-local sample records. Real accounts/shared orders need Supabase; test orders do not collect cash or deliver goods.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 10,
                            height: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _page(BuildContext context, int index) => LayoutBuilder(
    builder: (ctx, box) {
      final wide = box.maxWidth >= 760;
      final scale = MediaQuery.textScalerOf(ctx).scale(14) / 14;
      final artworkHeight =
          (wide
              ? 320.0
              : box.maxHeight < 380
              ? 130.0
              : 220.0) /
          scale.clamp(1.0, 1.8);
      final text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _eyebrows[index],
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: green,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _titles[index],
            key: ValueKey('welcome-title-$index'),
            style: TextStyle(
              fontSize: wide ? 42 : 32,
              fontWeight: FontWeight.w800,
              height: 1.16,
              letterSpacing: -0.8,
              color: ink,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _descriptions[index],
            style: const TextStyle(color: muted, fontSize: 14, height: 1.7),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: index == 0
                ? const [
                    Tag('Approved shops', icon: Icons.fact_check_outlined),
                    Tag('Retail + wholesale', icon: Icons.storefront_outlined),
                  ]
                : index == 1
                ? const [
                    Tag('No online payment', icon: Icons.payments_outlined),
                    Tag('Precise location', icon: Icons.my_location),
                  ]
                : const [
                    Tag(
                      'Private expenses',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    Tag('Rate completed orders', icon: Icons.star_outline),
                  ],
          ),
          if (index == 2)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text(
                'Browse without signing in. Real orders and personal expenses require your account. Location is requested for eligible delivery, not during this introduction.',
                style: TextStyle(color: muted, fontSize: 11, height: 1.6),
              ),
            ),
        ],
      );
      final art = _WelcomeArtwork(stage: index, height: artworkHeight);
      return SingleChildScrollView(
        key: ValueKey('welcome-scroll-$index'),
        padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 24, vertical: 16),
        child: wide
            ? Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 36),
                  Expanded(child: art),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [art, const SizedBox(height: 26), text],
              ),
      );
    },
  );
}

class _WelcomeArtwork extends StatelessWidget {
  const _WelcomeArtwork({required this.stage, required this.height});
  final int stage;
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFFEAF3E7),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFFDCE8D9)),
    ),
    child: stage == 0
        ? Padding(
            padding: const EdgeInsets.all(20),
            child: SvgPicture.asset(
              'assets/illustrations/market.svg',
              fit: BoxFit.contain,
            ),
          )
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tile(
                      stage == 1
                          ? Icons.local_shipping_outlined
                          : Icons.receipt_long_outlined,
                      stage == 1 ? 'Eligible COD delivery' : 'Your orders',
                    ),
                    const SizedBox(width: 18),
                    Icon(
                      stage == 1
                          ? Icons.swap_horiz_rounded
                          : Icons.arrow_forward_rounded,
                      color: green,
                      size: 24,
                    ),
                    const SizedBox(width: 18),
                    _tile(
                      stage == 1
                          ? Icons.storefront_outlined
                          : Icons.account_balance_wallet_outlined,
                      stage == 1 ? 'Shop pickup' : 'Your spending',
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
  Widget _tile(IconData icon, String label) => Container(
    width: 122,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: line),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: green, size: 36),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
      ],
    ),
  );
}
