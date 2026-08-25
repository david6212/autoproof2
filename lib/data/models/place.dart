/// What kind of place this is.
///
/// **There is no `inspection` member, deliberately.** Licensed pre-purchase
/// inspection centres already exist in this app: they ship as
/// `assets/data/inspection_centers_geo.json`, come from Ministry of Transport
/// data, and have their own screen. Adding them here would give the same
/// centres two homes and two sources of truth, and the community copy would
/// drift from the official one the first time somebody edited it.
///
/// This collection is for what the app does NOT already have: garages that
/// repair cars, and car washes.
enum PlaceCategory {
  garageMechanical,
  garageBody,
  garageElectric,
  garageTires,
  carWash,
}

extension PlaceCategoryX on PlaceCategory {
  /// Stored in Firestore. Never localise — the label below is what changes.
  String get id => switch (this) {
        PlaceCategory.garageMechanical => 'garage_mechanical',
        PlaceCategory.garageBody => 'garage_body',
        PlaceCategory.garageElectric => 'garage_electric',
        PlaceCategory.garageTires => 'garage_tires',
        PlaceCategory.carWash => 'car_wash',
      };

  String get label => switch (this) {
        PlaceCategory.garageMechanical => 'מוסך מכונאות',
        PlaceCategory.garageBody => 'פחחות וצבע',
        PlaceCategory.garageElectric => 'חשמל רכב',
        PlaceCategory.garageTires => 'צמיגים',
        PlaceCategory.carWash => 'שטיפת רכב',
      };

  bool get isGarage => this != PlaceCategory.carWash;

  static PlaceCategory? fromId(String id) {
    for (final c in PlaceCategory.values) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Where the entry came from, which decides what the app may say about it.
enum PlaceSource {
  /// From an official register. Nothing writes this yet — no government list
  /// of repair garages has been wired in — but the field exists so a community
  /// entry can never be silently promoted to look official.
  gov,

  /// Added by a user.
  community,
}

/// A garage or a car wash.
///
/// **The rating is stored three ways on purpose:** a count, a sum and an
/// average. Firestore has no aggregate query on the free plan, so the average
/// has to be maintained on write — and keeping the count and the sum beside it
/// means a wrong average can be recomputed rather than guessed at.
///
/// The average is NOT shown below three reviews. Two people's opinion rendered
/// as "5.0 ★" reads as a verdict on a business, and it is not one. That rule
/// lives in the widgets; [hasEnoughRatings] is what they ask.
class Place {
  final String id;
  final PlaceSource source;
  final PlaceCategory category;
  final String name;
  final String address;
  final String city;
  final double lat;
  final double lng;
  final String? phone;

  /// Only meaningful for [PlaceSource.gov].
  final String? govLicenseNumber;

  /// Who added it, for a community entry. Null for an official one.
  final String? addedByUid;

  /// Set once three people report that the place does not exist. Hidden, not
  /// deleted: a deletion cannot be reviewed, and three taps is a low bar.
  final bool isHidden;

  final int ratingCount;
  final int ratingSum;
  final double ratingAvg;
  final DateTime? lastReviewAt;
  final DateTime createdAt;

  const Place({
    required this.id,
    required this.source,
    required this.category,
    required this.name,
    this.address = '',
    this.city = '',
    this.lat = 0,
    this.lng = 0,
    this.phone,
    this.govLicenseNumber,
    this.addedByUid,
    this.isHidden = false,
    this.ratingCount = 0,
    this.ratingSum = 0,
    this.ratingAvg = 0,
    this.lastReviewAt,
    required this.createdAt,
  });

  /// Below this a rating is a couple of opinions, not a score.
  static const minRatingsToShow = 3;

  bool get hasEnoughRatings => ratingCount >= minRatingsToShow;

  bool get isCommunity => source == PlaceSource.community;

  factory Place.fromFirestore(Map<String, dynamic> data, String id) {
    int asInt(Object? v) =>
        v is int ? v : int.tryParse('${v ?? 0}') ?? 0;

    return Place(
      id: id,
      source: data['source'] == 'gov' ? PlaceSource.gov : PlaceSource.community,
      category: PlaceCategoryX.fromId('${data['category']}') ??
          PlaceCategory.garageMechanical,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      phone: data['phone'],
      govLicenseNumber: data['govLicenseNumber'],
      addedByUid: data['addedByUid'],
      isHidden: data['isHidden'] == true,
      ratingCount: asInt(data['ratingCount']),
      ratingSum: asInt(data['ratingSum']),
      ratingAvg: (data['ratingAvg'] as num?)?.toDouble() ?? 0,
      lastReviewAt: (data['lastReviewAt'] as dynamic)?.toDate(),
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'source': source == PlaceSource.gov ? 'gov' : 'community',
        'category': category.id,
        'name': name,
        // Written beside the name so the field can be searched at all.
        // Firestore has no substring query: a prefix range on `name` finds
        // "מוסך כהן" from "מוסך", and this array finds it from "כהן", which is
        // what people actually type. See `PlaceRepository.search`.
        'nameTokens': tokensFor(name),
        'address': address,
        'city': city,
        'lat': lat,
        'lng': lng,
        if (phone != null) 'phone': phone,
        if (govLicenseNumber != null) 'govLicenseNumber': govLicenseNumber,
        if (addedByUid != null) 'addedByUid': addedByUid,
        'isHidden': isHidden,
        'ratingCount': ratingCount,
        'ratingSum': ratingSum,
        'ratingAvg': ratingAvg,
        if (lastReviewAt != null) 'lastReviewAt': lastReviewAt,
        'createdAt': createdAt,
      };

  /// The words a name can be found by.
  ///
  /// Hebrew has no case to fold, so this is only about punctuation and
  /// spacing. Words of one letter are dropped: they match nearly everything
  /// and would make the array useless as a filter.
  static List<String> tokensFor(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'''["'`,.\-()׳״]'''), ' ')
        .trim();
    return <String>{
      for (final w in cleaned.split(RegExp(r'\s+')))
        if (w.length > 1) w,
    }.toList();
  }
}
