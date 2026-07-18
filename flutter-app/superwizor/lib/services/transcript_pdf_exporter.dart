// PDF export for transcripts (Etap 5a.8, D2 — in MVP).
//
// Uses `pdf` package to render an A4 multi-page document with
// metadata header, per-segment rows (speaker + timerange + text),
// and a PHI footer. Returns a temp file ready to share via
// `share_plus`. Caller MUST first show the EuphirePopup PHI warning
// before calling shareXFiles().

import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../cache/dto/transcript_dto.dart';

class TranscriptPdfMeta {
  final String sessionId;
  final String patientName;
  final DateTime sessionDate;
  final Duration duration;

  const TranscriptPdfMeta({
    required this.sessionId,
    required this.patientName,
    required this.sessionDate,
    required this.duration,
  });
}

class TranscriptPdfExporter {
  Future<File> export({
    required TranscriptDto transcript,
    required TranscriptPdfMeta meta,
    required PdfStrings strings,
  }) async {
    final pdf = pw.Document(
      title: strings.title,
      author: 'Superwizor AI',
      creator: 'Superwizor AI Flutter app',
      subject: strings.title,
    );

    final dateFmt = DateFormat('dd.MM.yyyy', 'pl_PL');

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.copyWith(
        marginLeft: 32,
        marginRight: 32,
        marginTop: 36,
        marginBottom: 36,
      ),
      header: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(strings.title,
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                // ignore: avoid_hardcoded_strings_in_widgets
                'Superwizor AI',
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey700)),
          ],
        ),
      ),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(strings.footer,
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey700)),
            pw.Text('${ctx.pageNumber}/${ctx.pagesCount}',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
      ),
      build: (ctx) {
        return [
          pw.Paragraph(
              text: strings.metaPatient(meta.patientName),
              style: const pw.TextStyle(fontSize: 11)),
          pw.Paragraph(
              text: strings.metaDate(dateFmt.format(meta.sessionDate)),
              style: const pw.TextStyle(fontSize: 11)),
          pw.Paragraph(
              text: strings.metaDuration(_formatDuration(meta.duration)),
              style: const pw.TextStyle(fontSize: 11)),
          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 8),
          // Iterate `turns` (speaker-grouped spans) rather than raw
          // segments — matches what the TranscriptScreen renders and
          // what the legacy TranscriptCacheStore was actually storing
          // under the misleading `segments` name.
          ...transcript.turns.map((s) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${_speakerLabel(s)}  ·  ${_formatTimeRange(s)}',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(s.text,
                        style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5)),
                  ],
                ),
              )),
        ];
      },
    ));

    final dir = await getTemporaryDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, 'transkrypcja_${meta.sessionId}.pdf'));
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  String _speakerLabel(SpeakerTurnDto s) =>
      s.speakerLabel.isNotEmpty ? s.speakerLabel : '—';

  String _formatTimeRange(SpeakerTurnDto s) {
    final start = Duration(milliseconds: s.startOffsetMs);
    final end = Duration(milliseconds: s.endOffsetMs);
    return '${_fmt(start)} – ${_fmt(end)}';
  }

  String _fmt(Duration d) {
    final mins = d.inMinutes.toString().padLeft(2, '0');
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }
}

/// Localized PDF strings — passed in from AppLocalizations so the
/// PDF respects the current locale (D7).
class PdfStrings {
  final String title;
  final String Function(String) metaPatient;
  final String Function(String) metaDate;
  final String Function(String) metaDuration;
  final String footer;

  const PdfStrings({
    required this.title,
    required this.metaPatient,
    required this.metaDate,
    required this.metaDuration,
    required this.footer,
  });
}
