import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'haptic_service.dart';
import 'language_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _pageCount = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticService().light();
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService();
    final pages = _buildPages(l, context);
    final isLastPage = _currentPage == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isLastPage ? 0.0 : 1.0,
                  child: TextButton(
                    onPressed: isLastPage ? null : _finish,
                    child: Text(l.t('onboarding_skip')),
                  ),
                ),
              ),
            ),

            // Seiten
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: pages,
              ),
            ),

            // Dots + Button
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 36),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dot-Indicator
                  Row(
                    children: List.generate(_pageCount, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Weiter / Loslegen
                  FilledButton(
                    onPressed: _nextPage,
                    child: Text(
                      isLastPage
                          ? l.t('onboarding_start')
                          : l.t('onboarding_next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPages(LanguageService l, BuildContext context) {
    return [
      _OnboardingPage(
        emoji: '💱',
        title: l.t('onboarding_welcome_title'),
        description: l.t('onboarding_welcome_desc'),
      ),
      _OnboardingPage(
        emoji: '📊',
        title: l.t('onboarding_currency_title'),
        description: l.t('onboarding_currency_desc'),
        bullets: [
          l.t('onboarding_currency_b1'),
          l.t('onboarding_currency_b2'),
          l.t('onboarding_currency_b3'),
        ],
      ),
      _OnboardingPage(
        emoji: '🥇',
        title: l.t('onboarding_gold_title'),
        description: l.t('onboarding_gold_desc'),
        bullets: [
          l.t('onboarding_gold_b1'),
          l.t('onboarding_gold_b2'),
          l.t('onboarding_gold_b3'),
        ],
      ),
      _OnboardingPage(
        emoji: '📱',
        title: l.t('onboarding_widget_title'),
        description: l.t('onboarding_widget_desc'),
        bullets: [
          l.t('onboarding_widget_b1'),
          l.t('onboarding_widget_b2'),
        ],
      ),
      _OnboardingPage(
        emoji: '✅',
        title: l.t('onboarding_ready_title'),
        description: l.t('onboarding_ready_desc'),
      ),
    ];
  }
}

class _OnboardingPage extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final List<String>? bullets;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.description,
    this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 76)),
          const SizedBox(height: 36),
          Text(
            title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: TextStyle(fontSize: 15, height: 1.55, color: textSecondary),
            textAlign: TextAlign.center,
          ),
          if (bullets != null && bullets!.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...bullets!.map(
              (b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(b,
                          style:
                              TextStyle(fontSize: 14, color: textSecondary)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
