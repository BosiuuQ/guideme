import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';

class RegulationsView extends StatefulWidget {
  const RegulationsView({super.key});

  @override
  State<RegulationsView> createState() => _RegulationsViewState();
}

class _RegulationsViewState extends State<RegulationsView> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Regulamin')),
      body: Column(
        children: [
         Expanded(
  child: SfPdfViewer.asset('assets/docs/regulamin.pdf'),
),
          CheckboxListTile(
            title: const Text('Akceptuję regulamin'),
            value: _accepted,
            onChanged: (val) => setState(() => _accepted = val ?? false),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _accepted
                    ? () => context.goNamed(AppRoutes.loginView)
                    : null,
                child: const Text('Dalej'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
