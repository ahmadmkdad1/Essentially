typedef Json = Map<String, dynamic>;

double toDouble(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

double? toDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int toInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

DateTime? toDateOrNull(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

DateTime toDate(Object? v) => toDateOrNull(v) ?? DateTime.now();

T enumFromName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name.toUpperCase() == name?.toString().toUpperCase()) return value;
  }
  return fallback;
}

/// `PENDING` -> `Pending`, `MISLEADING_PRICING` -> `Misleading pricing`
String humanize(String constant) {
  final lower = constant.replaceAll('_', ' ').toLowerCase();
  return lower.isEmpty ? lower : lower[0].toUpperCase() + lower.substring(1);
}

class Paginated<T> {
  const Paginated({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<T> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory Paginated.fromJson(Json json, T Function(Json) parse) => Paginated(
    items: (json['items'] as List? ?? const []).map((e) => parse(e as Json)).toList(),
    total: toInt(json['total']),
    page: toInt(json['page'], 1),
    limit: toInt(json['limit'], 20),
    totalPages: toInt(json['totalPages'], 1),
  );
}
