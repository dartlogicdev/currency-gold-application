import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AffiliateOffer {
  final String title;
  final String description;
  final String commission;
  final String url;
  final IconData icon;
  final Color color;

  AffiliateOffer({
    required this.title,
    required this.description,
    required this.commission,
    required this.url,
    required this.icon,
    required this.color,
  });
}

class AffiliateTab extends StatelessWidget {
  AffiliateTab({super.key});

  final List<AffiliateOffer> offers = [
    AffiliateOffer(
      title: 'Trade Republic - Gold kaufen',
      description: 'Gold-Sparpläne ab 1€ monatlich. Keine Ordergebühren.',
      commission: '🎁 15€ Bonus für Neukunden',
      url: 'https://tradrepublic.com', // Placeholder - wird durch deinen Affiliate-Link ersetzt
      icon: Icons.savings,
      color: Colors.green,
    ),
    AffiliateOffer(
      title: 'Wise - Geld wechseln',
      description: 'Echte Wechselkurse ohne versteckte Gebühren. Bis zu 8x günstiger.',
      commission: '💰 Erste Überweisung bis 500€ gratis',
      url: 'https://wise.com', // Placeholder - wird durch deinen Affiliate-Link ersetzt
      icon: Icons.currency_exchange,
      color: Colors.blue,
    ),
    AffiliateOffer(
      title: 'BullionVault - Gold sicher lagern',
      description: 'Physisches Gold kaufen und in Zürich, London oder New York lagern.',
      commission: '🔒 Kostenlose Registrierung + 4g Silber',
      url: 'https://www.bullionvault.com', // Placeholder - wird durch deinen Affiliate-Link ersetzt
      icon: Icons.security,
      color: Colors.amber,
    ),
    AffiliateOffer(
      title: 'Gold.de - Goldpreis Vergleich',
      description: 'Vergleiche Goldpreise von über 30 Händlern und spare bis zu 5%.',
      commission: '📊 Kostenloser Preisvergleich',
      url: 'https://www.gold.de', // Placeholder - wird durch deinen Affiliate-Link ersetzt
      icon: Icons.compare_arrows,
      color: Colors.orange,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header mit Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Empfohlene Partner',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sichere und vertrauenswürdige Partner für Gold-Investments und Währungstausch',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                ),
              ],
            ),
          ),

          // Offers List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: offers.length,
              itemBuilder: (context, index) {
                final offer = offers[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: InkWell(
                    onTap: () => _openAffiliate(context, offer),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Icon
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: offer.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              offer.icon,
                              size: 32,
                              color: offer.color,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Text Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  offer.title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  offer.description,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    offer.commission,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Arrow
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAffiliate(BuildContext context, AffiliateOffer offer) async {
    final Uri url = Uri.parse(offer.url);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication, // Öffnet im Browser
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Link konnte nicht geöffnet werden: ${offer.url}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Öffnen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
