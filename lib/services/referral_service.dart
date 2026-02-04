import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../models/referral.dart';

class ReferralService {
  static const String _fileName = 'referrals.json';

  static String get _filePath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.project_launcher/$_fileName';
  }

  static Future<void> _ensureDirectoryExists() async {
    final home = Platform.environment['HOME'] ?? '';
    final dir = Directory('$home/.project_launcher');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Load referral data from disk
  static Future<ReferralData> loadReferralData() async {
    try {
      await _ensureDirectoryExists();
      final file = File(_filePath);
      if (!await file.exists()) {
        // Create new referral data with generated code
        final newData = ReferralData(
          myCode: _generateReferralCode(),
          createdAt: DateTime.now(),
        );
        await saveReferralData(newData);
        return newData;
      }
      final content = await file.readAsString();
      if (content.isEmpty) {
        final newData = ReferralData(
          myCode: _generateReferralCode(),
          createdAt: DateTime.now(),
        );
        await saveReferralData(newData);
        return newData;
      }
      return ReferralData.fromJson(json.decode(content));
    } catch (e) {
      return ReferralData(
        myCode: _generateReferralCode(),
        createdAt: DateTime.now(),
      );
    }
  }

  /// Save referral data to disk
  static Future<void> saveReferralData(ReferralData data) async {
    try {
      await _ensureDirectoryExists();
      final file = File(_filePath);
      await file.writeAsString(json.encode(data.toJson()));
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Generate a referral code in format PLR-XXXX-XXXX
  static String _generateReferralCode() {
    final random = Random();
    // Characters that are easy to read (no 0/O, 1/I/l confusions)
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    String generatePart() {
      return List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    }

    return 'PLR-${generatePart()}-${generatePart()}';
  }

  /// Validate a referral code format
  static bool isValidCodeFormat(String code) {
    final pattern = RegExp(r'^PLR-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$');
    return pattern.hasMatch(code.toUpperCase());
  }

  /// Enter a referral code (simulates receiving a referral)
  /// In a real app, this would validate against a server
  static Future<ReferralResult> enterReferralCode(String code) async {
    final normalizedCode = code.toUpperCase().trim();

    // Validate format
    if (!isValidCodeFormat(normalizedCode)) {
      return ReferralResult(
        success: false,
        message: 'Invalid code format. Codes should be like PLR-XXXX-XXXX',
      );
    }

    final data = await loadReferralData();

    // Check if it's the user's own code
    if (normalizedCode == data.myCode) {
      return ReferralResult(
        success: false,
        message: "You can't use your own referral code!",
      );
    }

    // Check if code was already entered
    if (data.enteredCodes.contains(normalizedCode)) {
      return ReferralResult(
        success: false,
        message: 'This code has already been entered',
      );
    }

    // Add the code and increment referral count
    // In a real app, this would also notify the code owner
    final updatedData = data.copyWith(
      enteredCodes: [...data.enteredCodes, normalizedCode],
    );
    await saveReferralData(updatedData);

    return ReferralResult(
      success: true,
      message: 'Code accepted! Thank you for supporting a fellow developer.',
    );
  }

  /// Simulate receiving a referral (for demo purposes)
  /// In a real app, this would be triggered by another user entering your code
  static Future<void> simulateReferral() async {
    final data = await loadReferralData();
    final newCount = data.referralCount + 1;
    final newRewards = _checkNewRewards(data.unlockedRewards, newCount);

    final updatedData = data.copyWith(
      referralCount: newCount,
      unlockedRewards: [...data.unlockedRewards, ...newRewards],
    );
    await saveReferralData(updatedData);
  }

  /// Check which new rewards should be unlocked
  static List<String> _checkNewRewards(List<String> current, int referralCount) {
    final newRewards = <String>[];

    for (final reward in ReferralReward.values) {
      if (referralCount >= reward.requiredReferrals &&
          !current.contains(reward.id)) {
        newRewards.add(reward.id);
      }
    }

    return newRewards;
  }

  /// Get list of available rewards and their unlock status
  static Future<List<RewardStatus>> getRewardStatuses() async {
    final data = await loadReferralData();
    return ReferralReward.values.map((reward) {
      return RewardStatus(
        reward: reward,
        isUnlocked: data.unlockedRewards.contains(reward.id),
        currentReferrals: data.referralCount,
        requiredReferrals: reward.requiredReferrals,
      );
    }).toList();
  }

  /// Check if a specific theme is unlocked
  static Future<bool> isThemeUnlocked(String themeId) async {
    final data = await loadReferralData();
    return data.unlockedRewards.contains(themeId);
  }

  /// Get all unlocked theme IDs
  static Future<List<String>> getUnlockedThemes() async {
    final data = await loadReferralData();
    return data.unlockedRewards
        .where((id) =>
            id == ReferralReward.darkThemeMidnight.id ||
            id == ReferralReward.darkThemeOcean.id)
        .toList();
  }
}

/// Result of entering a referral code
class ReferralResult {
  final bool success;
  final String message;

  const ReferralResult({
    required this.success,
    required this.message,
  });
}

/// Status of a reward
class RewardStatus {
  final ReferralReward reward;
  final bool isUnlocked;
  final int currentReferrals;
  final int requiredReferrals;

  const RewardStatus({
    required this.reward,
    required this.isUnlocked,
    required this.currentReferrals,
    required this.requiredReferrals,
  });

  double get progress => (currentReferrals / requiredReferrals).clamp(0.0, 1.0);
  int get referralsNeeded => (requiredReferrals - currentReferrals).clamp(0, requiredReferrals);
}
