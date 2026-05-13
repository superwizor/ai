import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool isPremium;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final DateTime? lastSeenAt;
  final bool isOnline;
  final String? currentSessionToken;
  final String? fcmToken;
  final List<Map<String, dynamic>> favoritesRaw;

  // Duo Mode fields
  final List<String> pairIds; // List of all connected pairs
  final String? activePairId; // Currently selected pair

  // Computed legacy getter for backward compatibility
  String? get pairId => activePairId;

  // PartnerId is now derived/cached for the active pair,
  // but we might keep it in the doc for easy access or remove it.
  // For now, let's keep reading it if it exists, but primarily rely on the active pair.
  final String? partnerId;

  // Asymmetric Premium fields
  final String? premiumPairId; // The pair currently gifted with Premium
  final DateTime?
  premiumPairChangedAt; // When it was last changed (for 30-day cooldown)

  final bool onboardingComplete;
  final List<String> goals; // ["deep_talk", "fun", "spice_up"]
  final String? relationshipStatus; // "dating", "married", "friends", etc.
  final String? attributionSource; // "instagram", "podcast", "friend", etc.
  final bool partnerIsNearby;
  final List<int> seenQuestions;
  final int freeQuizTokens; // Free tokens for creating quizzes

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.isPremium = false,
    required this.createdAt,
    required this.lastLoginAt,
    this.lastSeenAt,
    this.isOnline = false,
    this.currentSessionToken,
    this.fcmToken,
    this.favoritesRaw = const [],
    this.pairIds = const [],
    this.activePairId,
    this.partnerId,
    this.premiumPairId,
    this.premiumPairChangedAt,
    this.onboardingComplete = false,
    this.goals = const [],
    this.relationshipStatus,
    this.attributionSource,
    this.partnerIsNearby = false,
    this.seenQuestions = const [],
    this.freeQuizTokens = 0,
  });

  /// Returns true if this user has any linked pair.
  bool get hasPair => pairIds.isNotEmpty;

  /// Returns true if an active pair is selected.
  bool get hasActivePair => activePairId != null;

  /// Returns true if 30 days have passed since the last premium pair change
  bool get canChangePremiumPair {
    if (premiumPairChangedAt == null) return true;
    return DateTime.now().difference(premiumPairChangedAt!).inDays >= 30;
  }

  factory UserProfile.fromDocument(DocumentSnapshot doc) {
    if (!doc.exists) throw Exception("User document does not exist");
    final data = doc.data() as Map<String, dynamic>;

    // Migration Logic:
    // If pairIds doesn't exist but pairId does, migrate it.
    List<String> pairIds = List<String>.from(data['pairIds'] ?? []);
    String? activePairId = data['activePairId'];

    // Legacy support/migration
    if (pairIds.isEmpty && data['pairId'] != null) {
      final legacyPairId = data['pairId'] as String;
      if (legacyPairId.isNotEmpty) {
        pairIds = [legacyPairId];
        activePairId ??= legacyPairId;
      }
    }

    return UserProfile(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      isPremium: data['isPremium'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt:
          (data['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate(),
      isOnline: data['isOnline'] ?? false,
      currentSessionToken: data['currentSessionToken'],
      fcmToken: data['fcmToken'],
      favoritesRaw: List<Map<String, dynamic>>.from(data['favorites'] ?? []),
      pairIds: pairIds,
      activePairId: activePairId,
      partnerId: data['partnerId'], // Still read specific partnerId if needed
      premiumPairId: data['premiumPairId'],
      premiumPairChangedAt: (data['premiumPairChangedAt'] as Timestamp?)
          ?.toDate(),
      onboardingComplete: data['onboardingComplete'] ?? false,
      goals: List<String>.from(data['goals'] ?? []),
      relationshipStatus: data['relationshipStatus'],
      attributionSource: data['attributionSource'],
      partnerIsNearby: data['partnerIsNearby'] ?? false,
      seenQuestions: List<int>.from(data['seenQuestions'] ?? []),
      freeQuizTokens: data['freeQuizTokens'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isPremium': isPremium,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'lastSeenAt': lastSeenAt != null ? Timestamp.fromDate(lastSeenAt!) : null,
      'isOnline': isOnline,
      'currentSessionToken': currentSessionToken,
      'fcmToken': fcmToken,
      'favorites': favoritesRaw,
      'pairIds': pairIds,
      'activePairId': activePairId,
      'partnerId': partnerId,
      'premiumPairId': premiumPairId,
      'premiumPairChangedAt': premiumPairChangedAt != null
          ? Timestamp.fromDate(premiumPairChangedAt!)
          : null,
      'onboardingComplete': onboardingComplete,
      'goals': goals,
      'relationshipStatus': relationshipStatus,
      'attributionSource': attributionSource,
      'partnerIsNearby': partnerIsNearby,
      'seenQuestions': seenQuestions,
      'freeQuizTokens': freeQuizTokens,
    };
  }

  UserProfile copyWith({
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isPremium,
    DateTime? lastLoginAt,
    DateTime? lastSeenAt,
    bool? isOnline,
    String? currentSessionToken,
    String? fcmToken,
    List<Map<String, dynamic>>? favoritesRaw,
    List<String>? pairIds,
    String? activePairId,
    String? partnerId,
    String? premiumPairId,
    DateTime? premiumPairChangedAt,
    bool? onboardingComplete,
    List<String>? goals,
    String? relationshipStatus,
    String? attributionSource,
    bool? partnerIsNearby,
    List<int>? seenQuestions,
    int? freeQuizTokens,
  }) {
    return UserProfile(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isOnline: isOnline ?? this.isOnline,
      currentSessionToken: currentSessionToken ?? this.currentSessionToken,
      fcmToken: fcmToken ?? this.fcmToken,
      favoritesRaw: favoritesRaw ?? this.favoritesRaw,
      pairIds: pairIds ?? this.pairIds,
      activePairId: activePairId ?? this.activePairId,
      partnerId: partnerId ?? this.partnerId,
      premiumPairId: premiumPairId ?? this.premiumPairId,
      premiumPairChangedAt: premiumPairChangedAt ?? this.premiumPairChangedAt,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      goals: goals ?? this.goals,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      attributionSource: attributionSource ?? this.attributionSource,
      partnerIsNearby: partnerIsNearby ?? this.partnerIsNearby,
      seenQuestions: seenQuestions ?? this.seenQuestions,
      freeQuizTokens: freeQuizTokens ?? this.freeQuizTokens,
    );
  }
}
