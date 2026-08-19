/// The kinds of work a driver looks for, mapped onto the ministry's own
/// profession names.
///
/// The registry does not think in categories — it lists 35 licence
/// professions, several of which are the same errand to a driver. Somebody
/// after body work does not know whether they want `תיקון מרכבי רכב` or
/// `צבעות רכב`; they want the dent gone. Each entry here gathers the licence
/// strings that answer one question, and the strings are exact because the
/// dataset filters on them literally.
enum GarageTrade {
  mechanics,
  bodywork,
  electrics,
  tyres,
  aircon,
  suspension,
  brakes,
  gearbox,

  /// Car washes, and the reason this enum has a member with no licence behind
  /// it. Washing a car is not a licensed automotive profession in Israel, so
  /// the registry has nothing to say about these places — no licence number,
  /// no supervision, no record that they exist at all.
  ///
  /// It stays in the list because drivers want it, and it carries
  /// [isLicensed] `false` so every screen showing it is forced to say which
  /// kind of place it is. Listing it beside a licensed garage without that
  /// distinction would be the app implying an official standing that nobody
  /// granted.
  carWash,
}

extension GarageTradeX on GarageTrade {
  String get label => switch (this) {
        GarageTrade.mechanics => 'מכונאות',
        GarageTrade.bodywork => 'פחחות וצבע',
        GarageTrade.electrics => 'חשמל רכב',
        GarageTrade.tyres => 'צמיגים',
        GarageTrade.aircon => 'מיזוג',
        GarageTrade.suspension => 'מתלים',
        GarageTrade.brakes => 'בלמים',
        GarageTrade.gearbox => 'תיבת הילוכים',
        GarageTrade.carWash => 'שטיפת רכב',
      };

  /// Whether the Ministry of Transport licenses this trade at all.
  bool get isLicensed => this != GarageTrade.carWash;

  /// The exact `miktzoa` values this trade covers. Empty for anything the
  /// registry does not license.
  List<String> get miktzoaValues => switch (this) {
        GarageTrade.mechanics => const [
            'מכונאות רכב בנזין',
            'מכונאות רכב דיזל',
          ],
        GarageTrade.bodywork => const [
            'תיקון מרכבי רכב',
            'צבעות רכב',
          ],
        GarageTrade.electrics => const [
            'חשמלאות רכב',
            'תיקון אחזקת רכב חשמלי/היברידי',
          ],
        GarageTrade.tyres => const ['תיקון והחלפת צמיגים'],
        GarageTrade.aircon => const ['שירות תיקון למזגן אויר לרכב'],
        GarageTrade.suspension => const ['תיקון וכוון מתלים ברכב'],
        GarageTrade.brakes => const ['רפידות ותופי בלם'],
        GarageTrade.gearbox => const ['תיקון תיבות הילוכים אוטומטיות'],
        GarageTrade.carWash => const [],
      };
}

/// One licensed garage, exactly as the Ministry of Transport lists it.
///
/// Nothing here is our opinion. The licence number is the useful part: it is
/// the one fact a driver can check against the ministry themselves, and it is
/// what lets a recommendation from a stranger be attached to a real, supervised
/// business rather than to a name somebody typed.
class LicensedGarage {
  const LicensedGarage({
    required this.licenceNumber,
    required this.name,
    required this.trade,
    required this.rawProfession,
    required this.town,
    required this.address,
    required this.phone,
  });

  /// `mispar_mosah` — the garage licence number.
  final String licenceNumber;

  final String name;

  /// Which of our categories this record fell into, if any.
  final GarageTrade? trade;

  /// The ministry's own profession string, kept verbatim. Shown as-is so a
  /// reader always sees the official wording, not only our grouping of it.
  final String rawProfession;

  final String town;
  final String address;
  final String phone;

  /// Same garage, same licence — the registry lists one row per profession, so
  /// a shop licensed for three trades appears three times.
  String get id => '$licenceNumber|$rawProfession';

  static GarageTrade? tradeFor(String miktzoa) {
    for (final t in GarageTrade.values) {
      if (t.miktzoaValues.contains(miktzoa)) return t;
    }
    return null;
  }

  factory LicensedGarage.fromApi(Map<String, dynamic> r) {
    String s(dynamic v) => (v ?? '').toString().trim();
    final profession = s(r['miktzoa']);
    return LicensedGarage(
      licenceNumber: s(r['mispar_mosah']),
      name: s(r['shem_mosah']),
      trade: tradeFor(profession),
      rawProfession: profession,
      town: s(r['yishuv']),
      address: s(r['ktovet']),
      phone: s(r['telephone']),
    );
  }
}
