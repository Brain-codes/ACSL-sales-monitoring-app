import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class SignatureInputWidget extends StatefulWidget {
  final ValueChanged<bool> onSigned;

  const SignatureInputWidget({
    Key? key,
    required this.onSigned,
  }) : super(key: key);

  @override
  State<SignatureInputWidget> createState() => _SignatureInputWidgetState();
}

class _SignatureInputWidgetState extends State<SignatureInputWidget> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  Uint8List? _signatureBytes;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.isNotEmpty) {
        widget.onSigned(true);
      } else {
        widget.onSigned(false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveSignature() async {
    if (_controller.isNotEmpty) {
      final Uint8List? data = await _controller.toPngBytes();
      if (data != null) {
        setState(() {
          _signatureBytes = data;
        });
      }
    }
  }

  void _clearSignature() {
    _controller.clear();
    setState(() {
      _signatureBytes = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Digital Signature',
          style: TextThemes(context).getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Signature(
                controller: _controller,
                height: 200,
                backgroundColor: AppColors.lightGrey,
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSignature,
                      color: AppColors.primaryColor,
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: _saveSignature,
                      color: AppColors.primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_signatureBytes != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved Signature Preview:',
                  style: TextThemes(context).getTextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.memory(
                    _signatureBytes!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
