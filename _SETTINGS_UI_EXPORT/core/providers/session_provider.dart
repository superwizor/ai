import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labirynt_premium/src/core/providers/user_provider.dart';
import 'package:labirynt_premium/src/features/auth/data/auth_repository.dart';
import 'package:labirynt_premium/src/features/auth/data/user_repository.dart';

class SessionState {
  final Set<int> seenQuestionIds;

  const SessionState({this.seenQuestionIds = const {}});

  SessionState copyWith({Set<int>? seenQuestionIds}) {
    return SessionState(
      seenQuestionIds: seenQuestionIds ?? this.seenQuestionIds,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  final Ref _ref;

  SessionNotifier(this._ref) : super(const SessionState()) {
    _init();
  }

  void _init() {
    // Listen to User Profile changes to sync persisted seen questions
    _ref.listen(userProfileProvider, (previous, next) {
      next.whenData((profile) {
        if (profile != null) {
          final profileSeen = profile.seenQuestions.toSet();
          // Merge with local state (just in case)
          final newSet = {...state.seenQuestionIds, ...profileSeen};
          if (newSet.length != state.seenQuestionIds.length) {
            state = state.copyWith(seenQuestionIds: newSet);
          }
        }
      });
    });
  }

  Future<void> markAsSeen(int questionId) async {
    if (!state.seenQuestionIds.contains(questionId)) {
      // Optimistic update
      state = state.copyWith(
        seenQuestionIds: {...state.seenQuestionIds, questionId},
      );

      // Persist to backend
      final user = _ref.read(authStateProvider).value;
      if (user != null) {
        await _ref
            .read(userRepositoryProvider)
            .markQuestionAsSeen(user.uid, questionId);
      }
    }
  }

  Future<void> resetSession() async {
    // Clear local
    state = const SessionState();

    // Clear backend
    final user = _ref.read(authStateProvider).value;
    if (user != null) {
      await _ref.read(userRepositoryProvider).resetSeenQuestions(user.uid);
    }
  }

  bool hasSeen(int questionId) {
    return state.seenQuestionIds.contains(questionId);
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((
  ref,
) {
  return SessionNotifier(ref);
});
