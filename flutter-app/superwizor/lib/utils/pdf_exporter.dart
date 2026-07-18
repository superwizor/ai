import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExporter {
  /// Exports the given markdown content to a PDF and presents a native share/save dialog.
  static Future<void> exportReportAsPdf({
    required String title,
    required String markdownContent,
    String? subtitle,
  }) async {
    final pdf = pw.Document();

    // Load Montserrat fonts to support Polish characters
    final fontRegular = await PdfGoogleFonts.montserratRegular();
    final fontBold = await PdfGoogleFonts.montserratBold();
    final fontItalic = await PdfGoogleFonts.montserratItalic();

    // Strip basic markdown to avoid raw symbols in the PDF, since we don't have
    // a full Markdown-to-PDF parser included in the dependencies.
    String plainText = markdownContent
        .replaceAll(RegExp(r'\*\*([^\*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*([^\*]+)\*'), r'$1')
        .replaceAll(RegExp(r'#+\s'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (pw.Context context) {
          return [
            // Header
            pw.Text(
              title,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 24,
                color: PdfColors.black,
              ),
            ),
            if (subtitle != null) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                subtitle,
                style: pw.TextStyle(
                  font: fontItalic,
                  fontSize: 14,
                  color: PdfColors.grey700,
                ),
              ),
            ],
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 24),
            
            // Content
            pw.Text(
              plainText,
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 11,
                lineSpacing: 1.5,
                color: PdfColors.black,
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();

    // Open native share dialog (iOS/Android/Web)
    final filename = 'raport_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
