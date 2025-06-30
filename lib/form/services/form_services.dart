import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart'; // Import MediaType

class FormService {
  final Dio dio = Dio();

  Future<Map<String, dynamic>?> uploadImage(
      File image, String folderName) async {
    try {
      var formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          image.path,
          contentType: MediaType('image', 'jpeg'), // Correct MediaType usage
        ),
        'folderName': folderName,
      });

      final response = await dio.post(
        'https://stove-transaction-backend.vercel.app/api/images',
        data: formData,
      );
      print(response);
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        return response.data['body'];
      }
    } catch (e) {
      print("Error uploading image: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> submitTransaction(
      Map<String, dynamic> transactionData) async {
    print(transactionData);

    try {
      final response = await dio.post(
        'https://stove-transaction-backend.vercel.app/api/transactions',
        data: transactionData,
      );
      print(response);

      return response.data;
    } catch (e) {
      print("Error submitting transaction: $e");
    }
    return null;
  }
}
