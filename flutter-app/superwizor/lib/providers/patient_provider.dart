import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/patient.dart';
import '../models/session.dart';

final patientsProvider = NotifierProvider<PatientsNotifier, List<Patient>>(() {
  return PatientsNotifier();
});

class PatientsNotifier extends Notifier<List<Patient>> {
  @override
  List<Patient> build() {
    return [];
  }

  void addPatient(String firstName, String lastName) {
    final newPatient = Patient(
      id: const Uuid().v4(),
      firstName: firstName,
      lastName: lastName,
    );
    state = [...state, newPatient];
  }

  void incrementSessionCount(String patientId) {
    state = state.map((p) {
      if (p.id == patientId) {
        return p.copyWith(sessionCount: p.sessionCount + 1);
      }
      return p;
    }).toList();
  }
}

final sessionsProvider = NotifierProvider<SessionsNotifier, List<Session>>(() {
  return SessionsNotifier();
});

class SessionsNotifier extends Notifier<List<Session>> {
  @override
  List<Session> build() {
    return [];
  }

  void addSession(Session session) {
    state = [...state, session];
  }

  List<Session> getSessionsForPatient(String patientId) {
    return state.where((s) => s.patientId == patientId).toList();
  }
}
