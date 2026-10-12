import 'package:flutter/material.dart';

import '../../../app/aangan_app.dart';
import '../services/onboarding_store.dart';
import '../widgets/common_widgets.dart';
import 'app_shell.dart';

/// What a person picked on the last onboarding page.
enum OnboardingIntent { exploreHomes, listProperty }

/// First-run welcome tour: house rules first, contact and address privacy,
/// admin review, and then a simple "find a home" or "list a home" choice.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinished,
    this.replay = false,
  });

  /// Called once the person skips the tour or makes a choice.
  final ValueChanged<OnboardingIntent> onFinished;

  /// Replay mode (Profile → "How Aangan works") replaces Skip with a close
  /// button; nothing is written to [OnboardingStore] from here either way.
  final bool replay;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _tourPages = 3;
  static const int _pageCount = _tourPages + 1;

  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (page < 0 || page >= _pageCount) return;
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool onChoicePage = _page == _tourPages;
    return Scaffold(
      backgroundColor: AanganColors.canvas,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _header(),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (int page) => setState(() => _page = page),
                children: <Widget>[
                  const _TourPage(
                    eyebrow: 'WELCOME',
                    title: 'Bihar ka ghar,\nsaaf rules ke saath.',
                    body:
                        'Aangan par owner aur local broker rent, deposit aur house rules pehle hi likh dete hain, taaki call karne se pehle sab clear ho.',
                    visual: _WelcomeVisual(),
                  ),
                  const _TourPage(
                    eyebrow: 'HOUSE RULES',
                    title: 'Rules pehle,\nphir visit.',
                    body:
                        'Pets, bachelors, couples, mehmaan, late entry, smoking — har rule ka saaf jawab: Yes, No ya "Discuss first".',
                    visual: _RulesVisual(),
                  ),
                  const _TourPage(
                    eyebrow: 'PRIVACY & TRUST',
                    title: 'Number aur address,\naapke control mein.',
                    body:
                        'Mobile number public listing mein kabhi nahi dikhta, exact address host ke show karne par hi khulta hai, aur nayi listing admin review ke baad live hoti hai.',
                    visual: _PrivacyVisual(),
                  ),
                  _ChoicePage(
                    onChoose: (OnboardingIntent intent) =>
                        widget.onFinished(intent),
                  ),
                ],
              ),
            ),
            _dots(),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
              child: onChoicePage
                  ? const Text(
                      'Apna option upar chunein — ye sirf pehla screen set karta hai.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AanganColors.muted,
                        fontSize: 10,
                        height: 1.45,
                      ),
                    )
                  : PrimaryButton(
                      label: 'Aage badhein',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => _goTo(_page + 1),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        children: <Widget>[
          if (_page > 0)
            IconButton(
              tooltip: 'Peeche',
              onPressed: () => _goTo(_page - 1),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          else
            const SizedBox(width: 48),
          const Spacer(),
          const AanganBrand(compact: true),
          const Spacer(),
          if (widget.replay)
            IconButton(
              tooltip: 'Band karein',
              onPressed: () => widget.onFinished(OnboardingIntent.exploreHomes),
              icon: const Icon(Icons.close_rounded),
            )
          else
            TextButton(
              onPressed: () => widget.onFinished(OnboardingIntent.exploreHomes),
              child: const Text('Skip'),
            ),
        ],
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int index = 0; index < _pageCount; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: index == _page ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: index == _page ? AanganColors.forest : AanganColors.line,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ],
    );
  }
}

/// Keeps the first-run tour in front of the app until it is finished once.
class AanganOnboardingGate extends StatefulWidget {
  const AanganOnboardingGate({super.key, required this.store});

  final OnboardingStore store;

  @override
  State<AanganOnboardingGate> createState() => _AanganOnboardingGateState();
}

class _AanganOnboardingGateState extends State<AanganOnboardingGate> {
  OnboardingIntent? _intent;

  Future<void> _finish(OnboardingIntent intent) async {
    setState(() => _intent = intent);
    await widget.store.complete();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (BuildContext context, Widget? child) {
        if (!widget.store.isCompleted) {
          return OnboardingScreen(onFinished: _finish);
        }
        return AppShell(
          startWithCreateListing: _intent == OnboardingIntent.listProperty,
        );
      },
    );
  }
}

class _TourPage extends StatelessWidget {
  const _TourPage({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.visual,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            eyebrow,
            style: const TextStyle(
              color: AanganColors.leaf,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AanganColors.ink,
              fontSize: 27,
              height: 1.16,
              letterSpacing: -1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              color: AanganColors.muted,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          visual,
        ],
      ),
    );
  }
}

class _ChoicePage extends StatelessWidget {
  const _ChoicePage({required this.onChoose});

  final ValueChanged<OnboardingIntent> onChoose;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'SHURU KAREIN',
            style: TextStyle(
              color: AanganColors.leaf,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Aap kya karna chahte hain?',
            style: TextStyle(
              color: AanganColors.ink,
              fontSize: 27,
              height: 1.16,
              letterSpacing: -1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pehla screen chunein. Owner listing aur renter search dono ek hi app mein chalti hain.',
            style: TextStyle(
              color: AanganColors.muted,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          _ChoiceCard(
            icon: Icons.search_rounded,
            title: 'Ghar dhoondhna hai',
            subtitle:
                'Bihar ke live homes, filters aur house rules Explore mein dekhein.',
            onTap: () => onChoose(OnboardingIntent.exploreHomes),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            icon: Icons.add_home_work_outlined,
            title: 'Ghar dena hai',
            subtitle:
                'Owner ya broker bankar property submit karein — admin review ke saath.',
            onTap: () => onChoose(OnboardingIntent.listProperty),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(color: AanganColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AanganColors.paleGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AanganColors.forest, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: AanganColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AanganColors.muted,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: AanganColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisualCard extends StatelessWidget {
  const _VisualCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AanganColors.paleGreen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AanganColors.line),
      ),
      child: child,
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AanganColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AanganColors.forest),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AanganColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: AanganColors.forest),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AanganColors.ink,
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeVisual extends StatelessWidget {
  const _WelcomeVisual();

  @override
  Widget build(BuildContext context) {
    return _VisualCard(
      child: Column(
        children: <Widget>[
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AanganColors.forest,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.other_houses_rounded,
              color: AanganColors.cream,
              size: 44,
            ),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: <Widget>[
              _MiniChip(icon: Icons.place_outlined, label: '38 districts'),
              _MiniChip(icon: Icons.tune_rounded, label: 'Clear filters'),
              _MiniChip(icon: Icons.verified_outlined, label: 'Admin checked'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RulesVisual extends StatelessWidget {
  const _RulesVisual();

  @override
  Widget build(BuildContext context) {
    return _VisualCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AanganColors.line),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '2 BHK · Danapur, Patna',
                  style: TextStyle(
                    color: AanganColors.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '₹8,500/month · Deposit 1 month · Semi-furnished',
                  style: TextStyle(
                    color: AanganColors.terracotta,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'HOUSE RULES',
            style: TextStyle(
              color: AanganColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              RulePill(label: 'Pets', value: 'allowed'),
              RulePill(label: 'Bachelors', value: 'not_allowed'),
              RulePill(label: 'Couples', value: 'discuss'),
              RulePill(label: 'Visitors', value: 'discuss'),
              RulePill(label: 'Smoking', value: 'not_allowed'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrivacyVisual extends StatelessWidget {
  const _PrivacyVisual();

  @override
  Widget build(BuildContext context) {
    return _VisualCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _BulletLine(
            icon: Icons.phone_iphone_rounded,
            text: 'Mobile number public listing mein kabhi nahi.',
          ),
          const _BulletLine(
            icon: Icons.chat_bubble_outline_rounded,
            text: 'In-app chat se baat karein, number share kiye bina.',
          ),
          const _BulletLine(
            icon: Icons.location_off_outlined,
            text:
                'Road, landmark aur PIN host ke show karne par hi dikhte hain.',
          ),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AanganColors.line),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    StatusPill(status: 'pending'),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: AanganColors.muted,
                    ),
                    SizedBox(width: 8),
                    StatusPill(status: 'published'),
                  ],
                ),
                SizedBox(height: 9),
                Text(
                  'Nayi listing pehle admin review mein jaati hai. Approve hone ke baad hi renter use dekh sakte hain.',
                  style: TextStyle(
                    color: AanganColors.muted,
                    fontSize: 10.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
