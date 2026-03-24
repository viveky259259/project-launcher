/// Referral data model for tracking referral codes and rewards
class ReferralData {
  final String myCode;
  final int referralCount;
  final List<String> unlockedRewards;
  final List<String> enteredCodes;
  final DateTime createdAt;

  const ReferralData({
    required this.myCode,
    this.referralCount = 0,
    this.unlockedRewards = const [],
    this.enteredCodes = const [],
    required this.createdAt,
  });

  factory ReferralData.fromJson(Map<String, dynamic> json) {
    return ReferralData(
      myCode: json['myCode'] as String,
      referralCount: json['referralCount'] as int? ?? 0,
      unlockedRewards: (json['unlockedRewards'] as List<dynamic>?)?.cast<String>() ?? [],
      enteredCodes: (json['enteredCodes'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'myCode': myCode,
      'referralCount': referralCount,
      'unlockedRewards': unlockedRewards,
      'enteredCodes': enteredCodes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  ReferralData copyWith({
    String? myCode,
    int? referralCount,
    List<String>? unlockedRewards,
    List<String>? enteredCodes,
    DateTime? createdAt,
  }) {
    return ReferralData(
      myCode: myCode ?? this.myCode,
      referralCount: referralCount ?? this.referralCount,
      unlockedRewards: unlockedRewards ?? this.unlockedRewards,
      enteredCodes: enteredCodes ?? this.enteredCodes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Available rewards that can be unlocked through referrals
enum ReferralReward {
  earlyBirdBadge,
  darkThemeMidnight,
  darkThemeOcean,
  customAccentColor,
  founderBadge,
}

extension ReferralRewardExtension on ReferralReward {
  String get id {
    switch (this) {
      case ReferralReward.earlyBirdBadge:
        return 'early_bird_badge';
      case ReferralReward.darkThemeMidnight:
        return 'dark_theme_midnight';
      case ReferralReward.darkThemeOcean:
        return 'dark_theme_ocean';
      case ReferralReward.customAccentColor:
        return 'custom_accent_color';
      case ReferralReward.founderBadge:
        return 'founder_badge';
    }
  }

  String get name {
    switch (this) {
      case ReferralReward.earlyBirdBadge:
        return 'Early Bird';
      case ReferralReward.darkThemeMidnight:
        return 'Midnight Theme';
      case ReferralReward.darkThemeOcean:
        return 'Ocean Theme';
      case ReferralReward.customAccentColor:
        return 'Custom Accent Color';
      case ReferralReward.founderBadge:
        return 'Founder Badge';
    }
  }

  String get description {
    switch (this) {
      case ReferralReward.earlyBirdBadge:
        return 'Show you were here early — badge on your profile';
      case ReferralReward.darkThemeMidnight:
        return 'A deep, dark purple theme for late night coding';
      case ReferralReward.darkThemeOcean:
        return 'A calm, blue-tinted dark theme inspired by the ocean';
      case ReferralReward.customAccentColor:
        return 'Pick any accent color for the UI';
      case ReferralReward.founderBadge:
        return 'Exclusive founder badge and priority support access';
    }
  }

  int get requiredReferrals {
    switch (this) {
      case ReferralReward.earlyBirdBadge:
        return 1;
      case ReferralReward.darkThemeMidnight:
        return 3;
      case ReferralReward.darkThemeOcean:
        return 5;
      case ReferralReward.customAccentColor:
        return 7;
      case ReferralReward.founderBadge:
        return 10;
    }
  }

  bool get isTheme =>
      this == ReferralReward.darkThemeMidnight ||
      this == ReferralReward.darkThemeOcean;

  static ReferralReward? fromId(String id) {
    for (final reward in ReferralReward.values) {
      if (reward.id == id) return reward;
    }
    return null;
  }
}
