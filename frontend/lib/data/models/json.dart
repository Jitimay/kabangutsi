// Small helpers for hand-written DTOs (no code generation).
typedef Json = Map<String, dynamic>;

DateTime parseTs(Object? v) => DateTime.parse(v as String).toUtc();
DateTime? parseTsOrNull(Object? v) => v == null ? null : parseTs(v);
String tsOf(DateTime d) => d.toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), 'Z');
String? tsOrNull(DateTime? d) => d == null ? null : tsOf(d);

List<T> parseList<T>(Object? v, T Function(Json) f) =>
    (v as List? ?? const []).map((e) => f(e as Json)).toList();

List<String> parseStrings(Object? v) =>
    (v as List? ?? const []).map((e) => e as String).toList();

double toDouble(Object? v) => (v as num).toDouble();
double? toDoubleOrNull(Object? v) => (v as num?)?.toDouble();
