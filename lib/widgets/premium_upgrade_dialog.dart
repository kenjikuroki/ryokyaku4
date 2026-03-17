import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumUpgradeDialog extends StatelessWidget {
  final VoidCallback onPurchase;
  final String title;
  final String buyNowText;
  final String cancelText;
  final String unlockSequential;
  final String unlockSequentialDesc;
  final String hideAds;
  final String hideAdsDesc;

  const PremiumUpgradeDialog({
    super.key,
    required this.onPurchase,
    this.title = 'プレミアムアップグレード',
    this.buyNowText = '今すぐ購入',
    this.cancelText = 'キャンセル',
    this.unlockSequential = '「連続」モードの解放',
    this.unlockSequentialDesc = '1問目から順番にすべての問題を解くことができます。',
    this.hideAds = '広告を完全に非表示',
    this.hideAdsDesc = 'アプリ内のあらゆる広告（バナー、動画など）を非表示にします。',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium, color: Color(0xFFFFB300), size: 48),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Benefits List
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _BenefitItem(
                  icon: Icons.format_list_numbered,
                  title: unlockSequential,
                  description: unlockSequentialDesc,
                ),
                const SizedBox(height: 16),
                _BenefitItem(
                  icon: Icons.block,
                  title: hideAds,
                  description: hideAdsDesc,
                ),
              ],
            ),
          ),
          
          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: onPurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      buyNowText,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    cancelText,
                    style: const TextStyle(color: Colors.grey),
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

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFFFB300), size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
