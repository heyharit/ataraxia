import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Needed for PlatformException
import 'package:purchases_flutter/purchases_flutter.dart';
import '../data/identity_store.dart';
import '../supabase/supabase_service.dart';

class PurchaseService {
  // 🚀 Replace with your real RevenueCat Public API Keys!
  static const _appleApiKey = 'appl_YOUR_KEY_HERE';
  static const _googleApiKey = 'goog_DUjVscKMZDVwamOBJrtxnZBKioC';

  static Future<void> initialize() async {
    await Purchases.setLogLevel(LogLevel.info);

    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_googleApiKey);
    } else {
      configuration = PurchasesConfiguration(_appleApiKey);
    }

    await Purchases.configure(configuration);
  }

  /// Call this right after your user successfully logs into your app
  static Future<void> loginUserToRevenueCat(String userId) async {
    await Purchases.logIn(userId);
  }

  /// Call this when the user logs out of your app
  static Future<void> logoutUserFromRevenueCat() async {
    await Purchases.logOut();
  }

  static Future<bool> buyProduct(String productId) async {
    // 1. SAFETY FIRST: Check identity BEFORE asking for money
    final identity = await IdentityStore.active();
    if (identity == null) {
      debugPrint("Purchase blocked: User is not logged in.");
      return false;
    }

    try {
      // 2. Trigger the Apple Pay / Google Play bottom sheet
      // 🚀 THE FIX: It now returns a PurchaseResult, not CustomerInfo directly
      final purchaseResult = await Purchases.purchaseProduct(productId);

      // Extract the CustomerInfo from the result
      final customerInfo = purchaseResult.customerInfo;

      // 3. Grant the Rewards
      if (productId.startsWith('sub_ascended_')) {
        // Now you can safely check entitlements inside customerInfo
        if (customerInfo.entitlements.all["ascended"]?.isActive == true) {
          await SupabaseService.grantAscension(identity.id);
        }
      } else if (productId == 'unlock_infinite_archives') {
        await SupabaseService.grantInfiniteArchives(identity.id);
      } else if (productId == 'axiom_pack_100') {
        await SupabaseService.adjustAxioms(identity.id, 100);
      } else if (productId == 'axiom_pack_500') {
        await SupabaseService.adjustAxioms(identity.id, 500);
      } else if (productId == 'axiom_pack_1500') {
        await SupabaseService.adjustAxioms(identity.id, 1500);
      }

      // 4. Sync the local app so the UI updates instantly
      await IdentityStore.syncFromNetwork();
      return true;
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("Purchase failed: ${e.message}");
      } else {
        debugPrint("User cancelled the purchase.");
      }
      return false;
    } catch (e) {
      debugPrint("Unknown purchase error: $e");
      return false;
    }
  }

  // 🚀 THE PROPER WAY: Buying the Package object directly from the Offering
  static Future<bool> buyPackage(Package package) async {
    final identity = await IdentityStore.active();
    if (identity == null) {
      debugPrint("Purchase blocked: User is not logged in.");
      return false;
    }

    try {
      // 1. Trigger the Apple Pay / Google Play bottom sheet using the exact Package
      final purchaseResult = await Purchases.purchasePackage(package);
      final customerInfo = purchaseResult.customerInfo;

      // Extract the clean ID we need for your database logic (e.g., 'axiom_pack_100')
      final productId = package.storeProduct.identifier.split(':').first;

      // 2. Grant the Rewards
      if (productId.startsWith('sub_ascended_')) {
        if (customerInfo.entitlements.all["ascended"]?.isActive == true) {
          await SupabaseService.grantAscension(identity.id);
        }
      } else if (productId == 'unlock_infinite_archives') {
        await SupabaseService.grantInfiniteArchives(identity.id);
      } else if (productId == 'axiom_pack_100') {
        await SupabaseService.adjustAxioms(identity.id, 100);
      } else if (productId == 'axiom_pack_500') {
        await SupabaseService.adjustAxioms(identity.id, 500);
      } else if (productId == 'axiom_pack_1500') {
        await SupabaseService.adjustAxioms(identity.id, 1500);
      }

      // 3. Sync the local app so the UI updates instantly
      await IdentityStore.syncFromNetwork();
      return true;
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("Purchase failed: ${e.message}");
      }
      return false;
    } catch (e) {
      debugPrint("Unknown purchase error: $e");
      return false;
    }
  }
}
