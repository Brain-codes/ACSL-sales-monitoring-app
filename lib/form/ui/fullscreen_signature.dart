// ... existing code ...
// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';


class FullScreenSignature extends StatelessWidget {
  final SignatureController signatureController;

  FullScreenSignature({required this.signatureController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Full Screen Signature'),
        actions: [
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: Signature(
          controller: signatureController,
          height: MediaQuery.of(context).size.height,
          backgroundColor: Colors.grey[200]!,
        ),
      ),
    );
  }
}

// ... existing code ...