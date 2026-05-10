// LegalPdfScreen — renders an offline PDF from `assets/legal/`.
// Used by the DPA link in AddPatientModal and (later, Etap 5c) by
// hamburger menu items "Regulamin" / "RODO".

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class LegalPdfScreen extends StatefulWidget {
  final String assetPath;
  final String? title;

  const LegalPdfScreen({super.key, required this.assetPath, this.title});

  @override
  State<LegalPdfScreen> createState() => _LegalPdfScreenState();
}

class _LegalPdfScreenState extends State<LegalPdfScreen> {
  late final PdfController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfController(document: PdfDocument.openAsset(widget.assetPath));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallbackTitle = widget.assetPath.split('/').last.replaceAll('.pdf', '');
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? fallbackTitle)),
      body: PdfView(controller: _controller),
    );
  }
}
