import 'package:dio/dio.dart';

class GoogleSheetService {
  final Dio dio = Dio();

  // Future<List<String>> fetchPartnerNames() async {
  //   final url =
  //       'https://docs.google.com/spreadsheets/d/1OtWwDqYIlV041YKrZVIdLlagcbiMofGShzFiS7hfICI/export?format=csv';

  //   try {
  //     final response = await dio.get(url);
  //     final lines = response.data.toString().split('\n');
  //     final partnerNames =
  //         lines.skip(1).map((line) => line.split(',')[3]).toList();
  //     return partnerNames;
  //   } catch (e) {
  //     rethrow;
  //   }
  // }

  // Future<List<String>> fetchStoveID() async {
  //   final url =
  //       'https://docs.google.com/spreadsheets/d/1OtWwDqYIlV041YKrZVIdLlagcbiMofGShzFiS7hfICI/export?format=csv';

  //   try {
  //     final response = await dio.get(url);
  //     final lines = response.data.toString().split('\n');
  //     final partnerNames =
  //         lines.skip(1).map((line) => line.split(',')[0]).toList();
  //     return partnerNames;
  //   } catch (e) {
  //     rethrow;
  //   }
  // }

  Future<List<Map<String, String>>> fetchAllData() async {
    final url =
        'https://docs.google.com/spreadsheets/d/1OtWwDqYIlV041YKrZVIdLlagcbiMofGShzFiS7hfICI/export?format=csv';

    try {
      final response = await dio.get(url);
      final lines = response.data.toString().split('\n');
      final data = lines.skip(1).map((line) {
        final columns = line.split(',');
        return {
          'stoveId': columns[0],
          'partnerName': columns[3],
        };
      }).toList();
      return data;
    } catch (e) {
      rethrow;
    }
  }
}
