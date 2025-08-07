import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfTermsView extends StatelessWidget {
  const PdfTermsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Regulamin"),
        backgroundColor: const Color(0xFF101935),
      ),
      backgroundColor: const Color(0xFF101935),
      body: SfPdfViewer.asset('assets/docs/regulamin.pdf'), // 🛠 usunięto const
    );
  }
}
