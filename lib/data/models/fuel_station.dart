import '../../presentation/widgets/map_cluster.dart';

/// A public fuel station from the Ministry of Energy register.
///
/// Read-only official data: where the legal stations are, who runs each one.
/// It carries **no prices** — see [FuelReference] for why there are none to
/// carry.
class FuelStation implements MapPoint {
  const FuelStation({
    required this.id,
    required this.company,
    required this.name,
    required this.address,
    required this.city,
    this.lat,
    this.lng,
  });

  /// The Fuel Administration's station number.
  final String id;

  /// Operator — פז, דלק, סונול, דור אלון, טן… or "אחר \ עצמאי".
  final String company;

  final String name;
  final String address;

  /// Local authority. Doubles as the clustering key, which is why it is named
  /// `city` rather than `authority`.
  @override
  final String city;

  @override
  final double? lat;
  @override
  final double? lng;

  /// The dataset ships coordinates for all but two stations, so unlike the
  /// inspection centres nothing here needs geocoding.
  @override
  bool get hasCoords => lat != null && lng != null;

  factory FuelStation.fromApi(Map<String, dynamic> r) {
    String s(Object? v) => (v?.toString() ?? '').trim();

    // The two coordinate columns are named with a space and a full stop, and
    // אורך/רוחב are longitude/latitude — easy to swap by accident.
    double? num_(Object? v) {
      final d = double.tryParse(s(v));
      return d == null || d == 0 ? null : d;
    }

    return FuelStation(
      id: s(r['מס_מינהל_הדלק']).isNotEmpty ? s(r['מס_מינהל_הדלק']) : s(r['_id']),
      company: s(r['חברה']),
      name: s(r['שם_תחנה']),
      address: s(r['כתובת']),
      city: s(r['רשות_מקומית']),
      lat: num_(r['נ.צ. רוחב']),
      lng: num_(r['נ.צ. אורך']),
    );
  }

  /// Guards against a latitude/longitude swap and against stray rows: Israel
  /// spans roughly 29.4–33.4 N and 34.2–35.9 E.
  bool get plausible =>
      hasCoords && lat! > 29.4 && lat! < 33.4 && lng! > 34.2 && lng! < 35.9;

  String get fullAddress =>
      [address, city].where((p) => p.isNotEmpty).join(', ');

  /// Title for a card: the operator and the station's own name read as one
  /// thing ("פז ראש פינה"), but only when they differ.
  String get displayName =>
      name.contains(company) || company.isEmpty ? name : '$company $name';

  String get mapsQuery =>
      [company, name, address, city].where((p) => p.isNotEmpty).join(' ');
}

/// The only official fuel price that exists — and it is not a pump price.
///
/// The Ministry of Energy publishes maximum prices at the **refinery gate**,
/// monthly, nationally. Retail diesel is not price-controlled in Israel, so no
/// per-station figure is published anywhere. Anything shown from this must say
/// what it is; presenting it as "the price of diesel" would be wrong by about
/// a factor of two.
class FuelReference {
  const FuelReference({
    required this.product,
    required this.shekelsPerLitre,
    required this.date,
  });

  final String product;
  final double shekelsPerLitre;
  final DateTime date;

  factory FuelReference.fromApi(Map<String, dynamic> r) {
    final raw = double.tryParse(r['מחיר']?.toString() ?? '') ?? 0;
    return FuelReference(
      product: (r['מוצר']?.toString() ?? '').trim(),
      // The dataset is priced per kilolitre.
      shekelsPerLitre: raw / 1000,
      date: DateTime.tryParse(r['תאריך']?.toString() ?? '') ?? DateTime(2000),
    );
  }

  String get monthLabel =>
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
