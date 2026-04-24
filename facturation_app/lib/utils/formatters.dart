import 'package:intl/intl.dart';

final _tn3 = NumberFormat('#,##0.000', 'fr_FR');
final _tn2 = NumberFormat('#,##0.00', 'fr_FR');
final _dateOut = DateFormat('dd/MM/yyyy');
final _dateIn = DateFormat('yyyy-MM-dd');

String formatAmount(double v) => _tn3.format(v);
String formatAmount2(double v) => _tn2.format(v);

String formatDate(String iso) {
  if (iso.isEmpty) return '';
  try {
    return _dateOut.format(_dateIn.parse(iso));
  } catch (_) {
    return iso;
  }
}

String todayIso() => DateFormat('yyyy-MM-dd').format(DateTime.now());
