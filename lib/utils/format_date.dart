import 'package:intl/intl.dart';

String formatMonth(String month) {
  print(month);
  switch (month) {
    case '01':
      return 'janv.';
    case '02':
      return 'févr.';
    case '03':
      return 'mars';
    case '04':
      return 'avr.';
    case '05':
      return 'mai';
    case '06':
      return 'juin';
    case '07':
      return 'juil.';
    case '08':
      return 'août';
    case '09':
      return 'sept.';
    case '10':
      return 'oct.';
    case '11':
      return 'nov.';
    case '12':
      return 'déc.';
    default:
      return '';
  }
}

String formatDate(String dateToParse) {
  var date = DateTime.parse(dateToParse);

  var now = DateTime.now();
  var formatterDay = DateFormat('d');
  var formatterMonth = DateFormat('MM');
  var formatterTime = DateFormat('HH:mm');
  var formatterYear = DateFormat('yyyy');

  if (date.year == now.year) {
    if (date.day == now.day && date.month == now.month) {
      return formatterTime.format(date);
    } else {
      return '${formatterDay.format(date)} ${formatMonth(formatterMonth.format(date))} à ${formatterTime.format(date)}';
    }
  } else {
    return '${formatterDay.format(date)} ${formatMonth(formatterMonth.format(date))} ${formatterYear.format(date)}';
  }
}