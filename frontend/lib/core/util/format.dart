import 'dart:math';

/// `5000000` → `5 000 000 FBu` (FBu amounts are integers).
String formatFbu(int amount) => '${groupThousands(amount)} FBu';

String groupThousands(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// Annuity payment as in openapi.yaml `/v1/loans/simulate`:
/// round(P·r / (1 − (1 + r)^−n)), r = rate/1200; r = 0 → P / n. Rounded half up.
int monthlyPayment(int principal, double annualRatePct, int months) {
  final r = annualRatePct / 1200;
  final v = r == 0 ? principal / months : principal * r / (1 - pow(1 + r, -months));
  return (v + 0.5).floor();
}

/// `+25779000101` → `+257 79 00 01 01`.
String formatPhone(String phone) {
  final m = RegExp(r'^\+257(\d{2})(\d{2})(\d{2})(\d{2})$').firstMatch(phone);
  return m == null ? phone : '+257 ${m[1]} ${m[2]} ${m[3]} ${m[4]}';
}

/// `HH:mm` local time of a UTC timestamp in Africa/Bujumbura (UTC+2, no DST).
String bujumburaTime(DateTime utc) {
  final t = utc.toUtc().add(const Duration(hours: 2));
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Random UUID v4 (lowercase), as required by the contracts.
String uuidV4([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
