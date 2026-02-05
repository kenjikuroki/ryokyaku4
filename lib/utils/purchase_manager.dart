import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ad_manager.dart';

class PurchaseManager {
  static final PurchaseManager instance = PurchaseManager._internal();
  PurchaseManager._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  final String _kPremiumProductId = 'unlock_ryokaku_4';
  static const String _kIsPremiumKey = 'is_premium_user';

  final ValueNotifier<bool> isPremium = ValueNotifier(false);
  
  // Stream subscription for purchase updates
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<void> init() async {
    // 1. Load local status first for speed
    final prefs = await SharedPreferences.getInstance();
    isPremium.value = prefs.getBool(_kIsPremiumKey) ?? false;
    
    // If already premium, ensure ads are disposed
    if (isPremium.value) {
      debugPrint('PurchaseManager: User is already Premium. Disabling ads.');
      AdManager.instance.disposeAll();
    }

    // 2. Listen to purchase updates
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        debugPrint('PurchaseManager: Error listening to purchase stream: $error');
      },
    );
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI if needed
        debugPrint('PurchaseManager: Purchase pending...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('PurchaseManager: Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          final bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            await _enablePremium();
          }
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // In a real app, verify receipt with backend.
    // Here we trust the store for simple unlock.
    return purchaseDetails.productID == _kPremiumProductId;
  }

  Future<void> _enablePremium() async {
    debugPrint('PurchaseManager: Enabling Premium features!');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsPremiumKey, true);
    isPremium.value = true;
    
    // Notify AdManager to remove all ads
    AdManager.instance.disposeAll();
  }

  Future<void> buyPremium() async {
    if (await _iap.isAvailable()) {
      final Set<String> kIds = {_kPremiumProductId};
      final ProductDetailsResponse response = await _iap.queryProductDetails(kIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('PurchaseManager: Product not found: ${response.notFoundIDs}');
        // Handle error (e.g. show toast)
        return;
      }
      
      final List<ProductDetails> products = response.productDetails;
      if (products.isEmpty) {
        debugPrint('PurchaseManager: No products found.');
        return;
      }

      final ProductDetails productDetails = products.first;
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
      
      // Attempt purchase
      _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      debugPrint('PurchaseManager: Store not available.');
    }
  }

  Future<void> restorePurchases() async {
    if (await _iap.isAvailable()) {
      await _iap.restorePurchases();
    }
  }
  
  void dispose() {
    _subscription?.cancel();
    isPremium.dispose();
  }
}
