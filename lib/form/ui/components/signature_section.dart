import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'dart:convert';

class SignatureSection extends StatelessWidget {
  final SignatureController signatureController;
  final String? existingSignature;

  const SignatureSection({
    Key? key,
    required this.signatureController,
    this.existingSignature,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Signature',
              style: TextThemes(context).getTextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primaryTextColor,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                signatureController.clear();
              },
              child: Text(
                'Clear',
                style: TextThemes(context).getTextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Show existing signature if available and current signature pad is empty
        if (existingSignature != null &&
            existingSignature!.isNotEmpty &&
            signatureController.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Signature:',
                style: TextThemes(context).getTextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: AppColors.secondaryTextColor,
                ),
              ),
              // Debug info
              if (existingSignature!.isNotEmpty)
                Text(
                  'Signature length: ${existingSignature!.length} chars',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.grey[500],
                  ),
                ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildSignatureImage(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Draw below to replace the current signature',
                style: TextThemes(context).getTextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 10,
                  color: AppColors.secondaryTextColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        Signature(
          controller: signatureController,
          height: 150,
          backgroundColor: Colors.grey[200]!,
        ),
      ],
    );
  }

  Widget _buildSignatureImage() {
    try {
      // Clean the signature string - remove any potential whitespace or newlines
      final cleanSignature = existingSignature!.trim();

      // The signature is already base64-encoded PNG data from toPngBytes()
      // So we can directly decode it as base64
      final bytes = base64Decode(cleanSignature);

      print('Signature decoding successful - ${bytes.length} bytes');

      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        width: double.infinity,
        height: 100,
        errorBuilder: (context, error, stackTrace) {
          print('Image.memory error: $error');
          return Container(
            color: Colors.grey[200],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.grey[600], size: 20),
                  Text(
                    'Invalid signature format',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Error decoding signature: $e');
      print(
          'Signature content preview: ${existingSignature!.length > 50 ? existingSignature!.substring(0, 50) + "..." : existingSignature!}');

      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.grey[600], size: 20),
              Text(
                'Could not load signature',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Error: ${e.toString().length > 50 ? e.toString().substring(0, 50) + "..." : e.toString()}',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
