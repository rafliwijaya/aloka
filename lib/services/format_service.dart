import 'package:intl/intl.dart';

/// Layanan utilitas untuk pemformatan mata uang Rupiah (IDR),
/// pemformatan rasio pemenuhan target, dan tanggal Indonesia.
class FormatService {
  FormatService._();

  static final NumberFormat _rupiahFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static final NumberFormat _plainNumberFormatter = NumberFormat.decimalPattern('id_ID');

  /// Mengubah nilai bulat menjadi format "Rp1.200.000"
  static String formatRupiah(int amount, {bool showPlusSign = false}) {
    final formatted = _rupiahFormatter.format(amount.abs());
    if (amount < 0) {
      return '-$formatted';
    }
    if (showPlusSign && amount > 0) {
      return '+$formatted';
    }
    return formatted;
  }

  /// Mengubah nilai bulat menjadi string angka bertitik tanpa simbol Rp ("1.200.000")
  static String formatPlainNumber(int amount) {
    return _plainNumberFormatter.format(amount);
  }

  /// Mengurai input teks pengguna menjadi bilangan bulat Rupiah non-negatif.
  /// Mengembalikan null apabila tidak valid.
  static int? parseRupiahInput(String rawInput) {
    final cleaned = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  /// Memformat rasio 0.0 - 1.0 menjadi persentase bulat, contoh: "85%"
  static String formatPercentage(double ratio) {
    final clamped = (ratio * 100).clamp(0.0, 100.0);
    return '${clamped.round()}%';
  }

  /// Memformat tanggal untuk kartu riwayat (contoh: "12/11/2026" dan "14:30")
  static String formatShortDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    return '$day/$month/$year';
  }

  static String formatShortTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Nama bulan dalam Bahasa Indonesia
  static String formatMonthYear(DateTime dateTime) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.year}';
  }
}
