import 'package:flutter/material.dart';
import '../utils/purchase_manager.dart';

class SpecialOfferDialog extends StatelessWidget {
  const SpecialOfferDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Icon
            const Icon(Icons.stars, color: Colors.orange, size: 48),
            const SizedBox(height: 12),
            
            // Title
            const Text(
              "期間限定オファー！",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Subtitle / Urgency
            const Text(
              "特別価格で広告を非表示にしませんか？\n2026年3月1日までの限定価格です。",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Price Comparison Box
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   // Original Price
                   const Text(
                     "¥390",
                     style: TextStyle(
                       fontSize: 16,
                       color: Colors.grey,
                       decoration: TextDecoration.lineThrough,
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                   const SizedBox(width: 12),
                   const Icon(Icons.arrow_forward, size: 20, color: Colors.orange),
                   const SizedBox(width: 12),
                   // Discount Price
                   Text(
                     "¥190",
                     style: TextStyle(
                       fontSize: 28,
                       color: Colors.orange[800],
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Buy Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog first
                  PurchaseManager.instance.buyPremium();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "今すぐ購入する",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            // Cancel Button
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "結構です",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
