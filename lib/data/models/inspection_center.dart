/// A licensed pre-purchase vehicle inspection center ("מכון בדיקה") from the
/// Ministry of Transport garages dataset. Read-only public data — the buyer
/// finds one nearby, then calls it or navigates there for an inspection.
class InspectionCenter {
  final String id;
  final String name;
  final String city;
  final String address;
  final String phone;

  /// Coordinates from the bundled geocode asset — null when we couldn't place
  /// it (then it won't get a map pin, but still shows in the list).
  final double? lat;
  final double? lng;

  const InspectionCenter({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    required this.phone,
    this.lat,
    this.lng,
  });

  factory InspectionCenter.fromApi(Map<String, dynamic> r) {
    String s(Object? v) => (v?.toString() ?? '').trim();
    return InspectionCenter(
      id: s(r['_id']).isNotEmpty ? s(r['_id']) : s(r['mispar_mosah']),
      name: s(r['shem_mosah']),
      city: s(r['yishuv']),
      address: s(r['ktovet']),
      phone: s(r['telephone']),
    );
  }

  InspectionCenter withCoords(double? lat, double? lng) => InspectionCenter(
        id: id,
        name: name,
        city: city,
        address: address,
        phone: phone,
        lat: lat,
        lng: lng,
      );

  bool get hasCoords => lat != null && lng != null;

  /// Key matching the geocode asset (mirrors the Python `normkey`): name+city
  /// with whitespace and punctuation stripped.
  String get geoKey =>
      '${_norm(name)}|${_norm(city)}';

  static String _norm(String s) =>
      s.replaceAll(RegExp('''[\\s'".,\\-)(/]'''), '');

  bool get hasPhone => phone.isNotEmpty;

  /// Digits-only phone for a `tel:` link (drops dashes/spaces).
  String get phoneDigits => phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// Full one-line address for display / map search.
  String get fullAddress =>
      [address, city].where((p) => p.isNotEmpty).join(', ');

  /// A maps search string combining the name and address.
  String get mapsQuery =>
      [name, address, city].where((p) => p.isNotEmpty).join(' ');
}
