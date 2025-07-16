// ignore_for_file: unnecessary_this

import 'package:get/get_utils/src/get_utils/get_utils.dart';
import 'package:intl/intl.dart';

extension DateTimeExtensions on DateTime {
  bool isToday() {
    final now = DateTime.now();
    return this.year == now.year &&
        this.month == now.month &&
        this.day == now.day;
  }
}

class Helpers {
  static String getNetworkFromPhone(String phone) {
    // Remove spaces from the phone number
    phone = phone.replaceAll(' ', '');

    // Remove the country code if present
    if (phone.startsWith('+234')) {
      phone = phone.replaceFirst('+234', '0');
    }

    if (phone.startsWith('0803') ||
        phone.startsWith('0806') ||
        phone.startsWith('07025') ||
        phone.startsWith('07026') ||
        phone.startsWith('0703') ||
        phone.startsWith('0704') ||
        phone.startsWith('0706') ||
        phone.startsWith('0813') ||
        phone.startsWith('0816') ||
        phone.startsWith('0810') ||
        phone.startsWith('0814') ||
        phone.startsWith('0903') ||
        phone.startsWith('0906') ||
        phone.startsWith('0913') ||
        phone.startsWith('0916')) {
      return 'MTN';
    } else if (phone.startsWith('0805') ||
        phone.startsWith('0807') ||
        phone.startsWith('0705') ||
        phone.startsWith('0905') ||
        phone.startsWith('0815') ||
        phone.startsWith('0811')) {
      return 'Glo';
    } else if (phone.startsWith('0802') ||
        phone.startsWith('0808') ||
        phone.startsWith('0701') ||
        phone.startsWith('0708') ||
        phone.startsWith('0812') ||
        phone.startsWith('0901') ||
        phone.startsWith('0902') ||
        phone.startsWith('0904') ||
        phone.startsWith('0907') ||
        phone.startsWith('0912') ||
        phone.startsWith('0911')) {
      return 'Airtel';
    } else if (phone.startsWith('0809') ||
        phone.startsWith('0909') ||
        phone.startsWith('0907') ||
        phone.startsWith('0908') ||
        phone.startsWith('0817') ||
        phone.startsWith('0818')) {
      return '9mobile';
    }
    return 'Unknown Network'; // Default case if no match
  }

  static String getInitials(String name) {
    List<String> nameParts = name.split(' ');
    String initials = '';
    for (var part in nameParts) {
      if (part.isNotEmpty && initials.length < 2) {
        initials += part[0].toUpperCase();
      }
    }
    return initials;
  }

  static String formatDate(DateTime date) {
    return (date.isToday())
        ? 'Today'
        : DateFormat('MMM d, yyyy').format(date); // Format as "July 3, 2024"
  }

  static formatDateTime(DateTime date, {bool showFullDate = true}) {
    final timePart =
        DateFormat('h:mma').format(date).toLowerCase(); // "11:59pm"

    if (date.isToday()) {
      return 'Today • $timePart';
    }

    final datePart = DateFormat('d MMMM').format(date); // "10 July"
    return showFullDate ? '$datePart • $timePart' : '• $timePart';
  }

  static String formatAmount(dynamic amount) {
    // Handle null or empty values
    if (amount == null || (amount is String && amount.isEmpty)) {
      return '0';
    }

    // Convert to double if it's a string
    double numericAmount;
    if (amount is String) {
      // Remove any existing commas or currency symbols
      String cleanAmount = amount.replaceAll(RegExp(r'[^\d.]'), '');
      try {
        numericAmount = double.parse(cleanAmount);
      } catch (e) {
        return '0'; // Return 0 if parsing fails
      }
    } else if (amount is int) {
      numericAmount = amount.toDouble();
    } else if (amount is double) {
      numericAmount = amount;
    } else {
      return '0'; // Return 0 for unsupported types
    }

    // Format with commas
    final formatter = NumberFormat('#,##0.##', 'en_US');
    return formatter.format(numericAmount);
  }


  String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name cannot be empty';
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email cannot be empty';
    }
    if (!GetUtils.isEmail(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password cannot be empty';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Confirm Password cannot be empty';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }



  String generateAvatarName(String? userName) {
  String theName = userName?.trim() ?? "Blu kard";
  List<String> nameParts =
      theName.split(RegExp('\\s+')).where((part) => part.isNotEmpty).toList();

  if (nameParts.length >= 2) {
    String firstNameInitial = nameParts[0][0].toUpperCase();
    String lastNameInitial = nameParts[1][0].toUpperCase();

    return '$firstNameInitial $lastNameInitial';
  } else if (nameParts.length == 1) {
    // Handle cases where there is only one name part
    String usernameInitial = nameParts[0][0].toUpperCase();
    return usernameInitial;
  } else {
    // Handle the case when there are not enough name parts
    return 'Invalid';
  }
}

  
}

String formatDuration(int totalSeconds) {
  int hours = totalSeconds ~/ 3600;
  int minutes = (totalSeconds % 3600) ~/ 60;
  int seconds = totalSeconds % 60;

  String formattedDuration = '';
  if (hours > 0) {
    formattedDuration += '${hours}hrs ';
  }
  if (minutes > 0 || (hours > 0 && seconds > 0)) {
    // Also show minutes if hours are present and there are seconds, to avoid e.g. 1hrs 5sec
    formattedDuration += '${minutes}min ';
  }
  // Always show seconds if it's the only unit or if other units are present
  if (seconds > 0 || (hours == 0 && minutes == 0)) {
    formattedDuration += '${seconds}sec';
  }

  return formattedDuration.trim(); // Trim any trailing space
}


