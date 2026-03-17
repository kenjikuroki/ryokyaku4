import 'package:flutter/material.dart';
import '../utils/purchase_manager.dart';

class PremiumUnlockCard extends StatelessWidget {
  final VoidCallback onTap;
  const PremiumUnlockCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PurchaseManager.instance.isPremium,
      builder: (context, isPremium, child) {
        if (isPremium) {
          // Hide if already premium
          return const SizedBox.shrink(); 
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 0),
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFB300)], // Gold to Honey
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Row(
                      children: [
                        // Icon Badge
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.stars, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        
                        // Text Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "プレミアムプランに\nアップグレード",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "広告を非表示にして集中！",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 12),

                        // Purchase Button
                        ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFFFB300),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            "購入",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Restore Purchase Button (Outside card)
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: TextButton(
                onPressed: () {
                  PurchaseManager.instance.restorePurchases();
                },
                style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  "購入を復元する",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
