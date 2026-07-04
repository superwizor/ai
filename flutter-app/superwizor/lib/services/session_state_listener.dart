// Firestore listener for live session status (Etap 0 + Etap 4).
//
// Backend writes `session_states/{sessionId}` with the four ADR-IMPL-012
// statuses: uploaded, analyzing, done. The notification-svc worker is
// the only writer; Flutter is read-only. Rules check
// `request.auth.uid == resource.data.therapistFirebaseUid`, so we
// don't need to filter ourselves.
//
// Two streams exposed:
//   watchSession(id):  Stream<SessionState> — single doc
//   inboxFor(uid):     Stream<List<InboxNotification>> — per-user inbox

import 'package:cloud_firestore/cloud_firestore.dart';

class SessionState {
  final String sessionId;
  final String? therapistFirebaseUid;
  final String status; // 'uploaded' | 'analyzing' | 'done' | 'failed' | other
  final int progressPercent;
  final DateTime? updatedAt;

  const SessionState({
    required this.sessionId,
    required this.status,
    required this.progressPercent,
    this.therapistFirebaseUid,
    this.updatedAt,
  });

  /// Synthetic "not yet written" snapshot — UI uses this while the
  /// worker hasn't created the doc yet (typical first 1-3 s after upload).
  factory SessionState.pending(String sessionId) =>
      SessionState(sessionId: sessionId, status: 'pending', progressPercent: 0);

  factory SessionState.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return SessionState.pending(doc.id);
    return SessionState(
      sessionId: (data['sessionId'] ?? doc.id).toString(),
      therapistFirebaseUid:
          (data['therapistFirebaseUid'] as String?)?.trim().isEmpty == false
              ? data['therapistFirebaseUid'] as String
              : null,
      status: (data['status'] ?? 'pending').toString(),
      progressPercent: (data['progressPercent'] ?? 0) is int
          ? data['progressPercent'] as int
          : ((data['progressPercent'] ?? 0) as num).toInt(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class InboxNotification {
  final String notificationId;
  final String notificationType;
  final String title;
  final String body;
  final String sessionId;
  // docs/39 PR12: the kartoteka a client-panel event (client_note_received /
  // item_shared) refers to, so the root inbox listener refreshes exactly
  // that notes/timeline list. Empty for session-pipeline notifications.
  final String patientFileId;
  final DateTime? createdAt;
  final DateTime? readAt;

  const InboxNotification({
    required this.notificationId,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.sessionId,
    this.patientFileId = '',
    this.createdAt,
    this.readAt,
  });

  bool get isUnread => readAt == null;

  factory InboxNotification.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return InboxNotification(
      notificationId: (data['notificationId'] ?? doc.id).toString(),
      notificationType: (data['notificationType'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      sessionId: (data['sessionId'] ?? '').toString(),
      patientFileId: (data['patientFileId'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
    );
  }
}

class SessionStateListener {
  SessionStateListener({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<SessionState> watchSession(String sessionId) {
    return _firestore
        .doc('session_states/$sessionId')
        .snapshots()
        .map((doc) =>
            doc.exists ? SessionState.fromFirestore(doc) : SessionState.pending(sessionId));
  }

  Stream<List<InboxNotification>> inboxFor(String firebaseUid) {
    return _firestore
        .collection('user_notifications/$firebaseUid/inbox')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(InboxNotification.fromDoc).toList());
  }

  /// Marks an inbox notification as read (the only field clients are
  /// allowed to write, per firestore.rules).
  Future<void> markRead({
    required String firebaseUid,
    required String notificationId,
  }) async {
    await _firestore
        .doc('user_notifications/$firebaseUid/inbox/$notificationId')
        .update({'readAt': FieldValue.serverTimestamp()});
  }
}
