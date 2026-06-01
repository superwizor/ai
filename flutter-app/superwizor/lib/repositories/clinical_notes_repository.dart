// ClinicalNotesRepository — thin wrapper over the clinical-svc patient
// notes + action-plan RPCs (docs/22). Mirrors how report_screen and the
// other repositories build the client: `ref.read(grpcClientsProvider).clinical`.
// Auth/metadata is handled by the existing client interceptors.
//
// The "send to patient" path can fail with FAILED_PRECONDITION
// "PATIENT_EMAIL_MISSING" when the patient has no e-mail on file (the
// note is still saved server-side). We surface that as a typed
// [PatientEmailMissingException] so the UI can branch on it cleanly
// instead of string-matching the raw gRPC error.

import 'package:grpc/grpc.dart';

import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../generated/clinical/v1/clinical.pbgrpc.dart' as clinical_grpc;

/// Thrown when SavePatientNote(send_to_patient=true) is called for a
/// patient with no e-mail on file. The note itself is still persisted —
/// only the e-mail delivery is skipped. The UI should prompt the
/// therapist to add an e-mail.
class PatientEmailMissingException implements Exception {
  const PatientEmailMissingException();
  @override
  String toString() => 'PatientEmailMissingException: PATIENT_EMAIL_MISSING';
}

/// Note kinds (mirror the server-side strings on PatientNote.kind).
class NoteKind {
  static const freeNote = 'FREE_NOTE';
  static const actionPlan = 'ACTION_PLAN';
}

class ClinicalNotesRepository {
  ClinicalNotesRepository(this._client);

  final clinical_grpc.ClinicalServiceClient _client;

  Future<List<clinical_pb.PatientNote>> listNotes(String patientFileId) async {
    final res = await _client.listPatientNotes(
      clinical_pb.ListPatientNotesRequest(patientFileId: patientFileId),
    );
    return res.notes;
  }

  Future<clinical_pb.PatientNote> createNote(
    String patientFileId,
    String title,
    String text, {
    String kind = NoteKind.freeNote,
    String sourceSessionId = '',
  }) {
    return _client.createPatientNote(
      clinical_pb.CreatePatientNoteRequest(
        patientFileId: patientFileId,
        title: title,
        text: text,
        kind: kind,
        sourceSessionId: sourceSessionId,
      ),
    );
  }

  Future<clinical_pb.PatientNote> updateNote(
    String noteId,
    String title,
    String text,
  ) {
    return _client.updatePatientNote(
      clinical_pb.UpdatePatientNoteRequest(
        noteId: noteId,
        title: title,
        text: text,
      ),
    );
  }

  Future<void> deleteNote(String noteId) {
    return _client.deletePatientNote(
      clinical_pb.DeletePatientNoteRequest(noteId: noteId),
    );
  }

  Future<clinical_pb.ActionPlanDraft> getActionPlanDraft(String sessionId) {
    return _client.getActionPlanDraft(
      clinical_pb.GetActionPlanDraftRequest(sessionId: sessionId),
    );
  }

  /// Create/update a note and optionally e-mail it to the patient.
  /// Throws [PatientEmailMissingException] when [sendToPatient] is true
  /// but the patient has no e-mail on file (FAILED_PRECONDITION
  /// "PATIENT_EMAIL_MISSING"). The note is still saved in that case.
  Future<clinical_pb.SavePatientNoteResponse> savePatientNote(
    String patientFileId, {
    String noteId = '',
    String title = '',
    String text = '',
    String kind = NoteKind.freeNote,
    String sourceSessionId = '',
    bool sendToPatient = false,
  }) async {
    try {
      return await _client.savePatientNote(
        clinical_pb.SavePatientNoteRequest(
          patientFileId: patientFileId,
          noteId: noteId,
          title: title,
          text: text,
          kind: kind,
          sourceSessionId: sourceSessionId,
          sendToPatient: sendToPatient,
        ),
      );
    } on GrpcError catch (e) {
      if (e.code == StatusCode.failedPrecondition &&
          (e.message ?? '').contains('PATIENT_EMAIL_MISSING')) {
        throw const PatientEmailMissingException();
      }
      rethrow;
    }
  }
}
