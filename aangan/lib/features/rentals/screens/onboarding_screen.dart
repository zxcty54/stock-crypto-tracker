import 'package:flutter/material.dart';

import '../../../app/aangan_app.dart';
import '../services/onboarding_store.dart';

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.badgeIcon,
    required this.headline,
    required this.body,
    required this.heroGradient,
    required this.iconColor,
  });

  final IconData icon;
  final IconData badgeIcon;
  final String headline;
  final String body;
  final List<Color> heroGradient;
  final Color iconColor;
}

/// First-launch welcome flow shown before the rental app shell.
///
/// Completion is remembered through [OnboardingStore]; [onCompleted] is
/// invoked once the user finishes or skips the flow.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<_OnboardingSlide> _slides = <_OnboardingSlide>[
    _OnboardingSlide(
      icon: Icons.other_houses_rounded,
      badgeIcon: Icons.apartment_rounded,
      headline: 'बिहार का अपना रेंटल आँगन',
      body: 'Ghar, flat ya room — poore Bihar ki listings ek hi app mein.',
      heroGradient: <Color>[AanganColors.forest, AanganColors.leaf],
      iconColor: AanganColors.forest,
    ),
    _OnboardingSlide(
      icon: Icons.forum_rounded,
      badgeIcon: Icons.lock_rounded,
      headline: 'सीधा बात कीजिए',
      body: 'Owner ya broker se private chat — mobile number bhi private.',
      heroGradient: <Color>[AanganColors.terracotta, AanganColors.gold],
      iconColor: AanganColors.terracotta,
    ),
    _OnboardingSlide(
      icon: Icons.verified_user_rounded,
      badgeIcon: Icons.fact_check_rounded,
      headline: 'जाँची-परखी हर लिस्टिंग',
      body: 'Har listing admin approval ke baad hi publish hoti hai.',
      heroGradient: <Color>[AanganColors.forest, AanganColors.leaf],
      iconColor: AanganColors.forest,
    ),
    _OnboardingSlide(
      icon: Icons.location_on_rounded,
      badgeIcon: Icons.map_rounded,
      headline: 'अपना ज़िला चुनिए',
      body: 'Poore Bihar ke 38 districts — apne area mein ghar khojein.',
      heroGradient: <Color>[AanganColors.terracotta, AanganColors.gold],
      iconColor: AanganColors.terracotta,
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingStore.markCompleted();
    widget.onCompleted();
  }

  void _goToNextPage() {
    if (_currentPage >= _slides.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: AanganColors.cream,
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) =>
                      _OnboardingPage(slide: _slides[index]),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const _AanganMark(),
                          _SkipPill(onPressed: _finish),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 18),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (var index = 0; index < _slides.length; index += 1)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: index == _currentPage ? 26 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: index == _currentPage
                                ? AanganColors.forest
                                : AanganColors.line,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _goToNextPage,
                      style: FilledButton.styleFrom(
                        backgroundColor: AanganColors.forest,
                        foregroundColor: AanganColors.cream,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: isLastPage
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text('शुरू करें'),
                                SizedBox(width: 8),
                                Icon(Icons.rocket_launch_rounded, size: 20),
                              ],
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text('आगे'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single onboarding page: gradient hero on top, content sheet below.
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: slide.heroGradient,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(36),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -46,
                right: -34,
                child: _HeroCircle(size: 150, color: const Color(0x1AFFFFFF)),
              ),
              Positioned(
                bottom: 54,
                left: -38,
                child: _HeroCircle(size: 104, color: const Color(0x22FFFFFF)),
              ),
              Positioned(
                top: 98,
                right: 38,
                child: _HeroCircle(size: 20, color: const Color(0x38FFFFFF)),
              ),
              Center(child: _HeroIcon(slide: slide)),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 18, 32, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  slide.headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AanganColors.ink,
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  slide.body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AanganColors.muted,
                    fontSize: 15.5,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Layered icon composition shown in the middle of the gradient hero.
class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      height: 196,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 196,
            height: 196,
            decoration: const BoxDecoration(
              color: Color(0x14FFFFFF),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 152,
            height: 152,
            decoration: const BoxDecoration(
              color: Color(0x24FFFFFF),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(38),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x2E000000),
                  blurRadius: 30,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Icon(slide.icon, size: 58, color: slide.iconColor),
          ),
          Positioned(
            right: 2,
            bottom: 10,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(slide.badgeIcon, size: 22, color: slide.iconColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Translucent decorative circle clipped by the hero edges.
class _HeroCircle extends StatelessWidget {
  const _HeroCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// White brand mark shown on the gradient hero.
class _AanganMark extends StatelessWidget {
  const _AanganMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.other_houses_rounded,
            color: Colors.white,
            size: 19,
          ),
        ),
        const SizedBox(width: 9),
        const Text(
          'aangan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// Translucent skip control on the hero.
class _SkipPill extends StatelessWidget {
  const _SkipPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x2EFFFFFF),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            'Skip',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
