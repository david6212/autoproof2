import 'model_spec.dart';

enum CarStatus { active, removed, sold }

/// Who is selling the car. Every listing is labeled so buyers always know who
/// they're dealing with (transparency instead of banning dealers).
enum SellerType {
  private, // בעלים פרטי — selling their own car (verified vs gov ownership)
  agent, // סוכן — selling a car that isn't theirs, on someone's behalf
  dealer, // סוחר / מגרש — a car-dealing business
}

extension SellerTypeX on SellerType {
  String get label => switch (this) {
        SellerType.private => 'בעלים פרטי',
        SellerType.agent => 'סוכן',
        SellerType.dealer => 'סוחר',
      };
}

class CarModel {
  final String id;
  final String plate;
  final String make;
  final String model;
  final int year;
  final double price;
  final int km;
  final int hand; // number of previous owners
  final String area;
  final String sellerId;
  final CarStatus status;
  final Map<String, dynamic>? govData;

  /// The registry's answer as it stood when this listing was published or
  /// last refreshed — see `GovData.toSnapshot`.
  ///
  /// It exists so a buyer can be shown what the registry says **without being
  /// handed the plate to ask with**. It deliberately carries neither the plate
  /// nor the VIN.
  final Map<String, dynamic>? govSnapshot;

  /// This plate's earlier listings, copied onto this one at publish time.
  ///
  /// The odometer-rollback check is the app's signature finding, and it needs
  /// the car's past. `plate_history` is keyed by plate, so a buyer without the
  /// plate cannot read it — and taking the plate away from buyers is the whole
  /// point. So the seller's app, which does have the plate, brings the answer
  /// with it. The records name no one.
  final List<Map<String, dynamic>>? plateHistorySnapshot;

  /// When [govSnapshot] was taken. Shown to the reader, always: a stored
  /// answer presented as a live one is the same lie as an unchecked claim.
  final DateTime? govCheckedAt;
  final List<String> photos; // Storage download URLs
  final String reasonForSelling;
  final String description; // seller's free-text "a few words about the car"
  final SellerType sellerType;
  final DateTime createdAt;
  final int reviewCount;
  // Official fields copied from data.gov.il at listing time (for filtering).
  final String fuel; // e.g. "בנזין", "חשמל/בנזין"
  final String color; // e.g. "כסף", "שחור מטלי"
  final String ownership; // e.g. "פרטי", "ליסינג"

  /// Per-model build spec copied from the models dataset at publish time, so
  /// the buyer filters can use engine size / seats / drivetrain / body without
  /// hitting the API per listing. Null for listings created before this
  /// existed, or when the model isn't in the dataset.
  final ModelSpec? spec;

  /// The passport this listing was published from, when it was. Null for a
  /// listing created the ordinary way.
  final String? vehicleId;

  /// Copied from the vehicle at publish time rather than read live, for two
  /// reasons: the buyer list would otherwise need a read per card, and the
  /// badge should describe the car as it was advertised. A seller who logs
  /// another service does not silently change what an old listing claimed.
  final bool hasDocumentedHistory;
  final int serviceCount;
  final int historySpanMonths;

  /// A demonstration listing: the vehicle does not exist and every number on
  /// it was invented so the app has something to show.
  ///
  /// It has to be readable, not just written. Four of these are live, and
  /// because their plates are registered to nobody they have no registry data
  /// at all — so a demo is exactly the listing that looks, to a buyer, like a
  /// real car whose official sections happen to be empty. Saying nothing was
  /// the previous behaviour and it is the one thing this app cannot do.
  final bool isDemo;

  const CarModel({
    required this.id,
    required this.plate,
    required this.make,
    required this.model,
    required this.year,
    required this.price,
    required this.km,
    required this.hand,
    required this.area,
    required this.sellerId,
    required this.status,
    this.govData,
    this.govSnapshot,
    this.plateHistorySnapshot,
    this.govCheckedAt,
    required this.photos,
    required this.reasonForSelling,
    this.description = '',
    this.sellerType = SellerType.private,
    required this.createdAt,
    this.reviewCount = 0,
    this.fuel = '',
    this.color = '',
    this.ownership = '',
    this.spec,
    this.vehicleId,
    this.hasDocumentedHistory = false,
    this.serviceCount = 0,
    this.historySpanMonths = 0,
    this.isDemo = false,
  });

  /// Normalised drivetrain category for filtering.
  String get fuelCategory {
    final f = fuel;
    if (f.contains('חשמל') && f.contains('בנזין')) return 'היברידי';
    if (f.contains('חשמל')) return 'חשמלי';
    if (f.contains('היבר')) return 'היברידי';
    if (f.contains('דיזל')) return 'דיזל';
    if (f.contains('בנזין')) return 'בנזין';
    return '';
  }

  /// Normalised colour bucket for the colour-dot filter.
  ///
  /// The registry writes colours as free text with a finish attached — "כסף
  /// מטלי", "לבן פנינה", "אפור עכבר" — so these match on the word, not the
  /// whole string. Order matters: the more specific word has to be tested
  /// before the more general one.
  ///
  /// Silver is its own bucket rather than a shade of grey. It is one of the
  /// most common colours on Israeli roads, and a buyer who wants silver does
  /// not mean grey.
  String get colorCategory {
    final c = color;
    if (c.contains('לבן') || c.contains('שנהב')) return 'לבן';
    if (c.contains('שחור')) return 'שחור';
    if (c.contains('כסף') || c.contains('אלומיני')) return 'כסף';
    if (c.contains('אפור') || c.contains('גרפיט')) return 'אפור';
    if (c.contains('כחול') || c.contains('תכלת')) return 'כחול';
    if (c.contains('אדום') || c.contains('בורדו') || c.contains('יין')) {
      return 'אדום';
    }
    if (c.contains('ירוק') || c.contains('זית')) return 'ירוק';
    if (c.contains('חום') || c.contains('בז') || c.contains('שמפניה') ||
        c.contains('זהב')) {
      return 'חום';
    }
    if (c.contains('צהוב') || c.contains('כתום')) return 'צהוב';
    return 'אחר';
  }

  bool get isPrivateOwnership => ownership.contains('פרטי');

  factory CarModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CarModel(
      id: id,
      plate: data['plate'] ?? '',
      make: data['make'] ?? '',
      model: data['model'] ?? '',
      year: (data['year'] ?? 0) is int
          ? (data['year'] ?? 0)
          : int.tryParse('${data['year']}') ?? 0,
      price: (data['price'] ?? 0).toDouble(),
      km: (data['km'] ?? 0) is int
          ? (data['km'] ?? 0)
          : int.tryParse('${data['km']}') ?? 0,
      hand: (data['hand'] ?? 1) is int
          ? (data['hand'] ?? 1)
          : int.tryParse('${data['hand']}') ?? 1,
      area: data['area'] ?? '',
      sellerId: data['sellerId'] ?? '',
      status: CarStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => CarStatus.active,
      ),
      govData: (data['govData'] as Map?)?.cast<String, dynamic>(),
      govSnapshot: (data['govSnapshot'] as Map?)?.cast<String, dynamic>(),
      plateHistorySnapshot: (data['plateHistorySnapshot'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      govCheckedAt: (data['govCheckedAt'] as dynamic)?.toDate(),
      photos: List<String>.from(data['photos'] ?? const []),
      reasonForSelling: data['reasonForSelling'] ?? '',
      description: data['description'] ?? '',
      sellerType: SellerType.values.firstWhere(
        (t) => t.name == data['sellerType'],
        orElse: () => SellerType.private,
      ),
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      reviewCount: (data['reviewCount'] ?? 0) is int
          ? (data['reviewCount'] ?? 0)
          : int.tryParse('${data['reviewCount']}') ?? 0,
      fuel: data['fuel'] ?? '',
      color: data['color'] ?? '',
      ownership: data['ownership'] ?? '',
      spec: data['spec'] is Map
          ? ModelSpec.fromMap(Map<String, dynamic>.from(data['spec']))
          : null,
      vehicleId: data['vehicleId'],
      hasDocumentedHistory: data['hasDocumentedHistory'] == true,
      serviceCount: (data['serviceCount'] ?? 0) is int
          ? (data['serviceCount'] ?? 0)
          : int.tryParse('${data['serviceCount']}') ?? 0,
      historySpanMonths: (data['historySpanMonths'] ?? 0) is int
          ? (data['historySpanMonths'] ?? 0)
          : int.tryParse('${data['historySpanMonths']}') ?? 0,
      isDemo: data['demo'] == true,
    );
  }

  /// The listing as it is stored **publicly**.
  ///
  /// `cars/{id}` is `allow read: if true` — anyone with `curl` reads every
  /// field here, which is why the plate is not one of them. It goes to
  /// `cars/{id}/private/registry`, written by `CarRepository`, where only the
  /// seller can reach it. Masking the plate on screen while shipping it in
  /// this map was decoration.
  Map<String, dynamic> toFirestore() => {
        'make': make,
        'model': model,
        'year': year,
        'price': price,
        'km': km,
        'hand': hand,
        'area': area,
        'sellerId': sellerId,
        'status': status.name,
        'govData': govData,
        'govSnapshot': govSnapshot,
        'plateHistorySnapshot': plateHistorySnapshot,
        'govCheckedAt': govCheckedAt,
        'photos': photos,
        'reasonForSelling': reasonForSelling,
        'description': description,
        'sellerType': sellerType.name,
        'createdAt': createdAt,
        'reviewCount': reviewCount,
        'fuel': fuel,
        'color': color,
        'ownership': ownership,
        if (spec != null) 'spec': spec!.toMap(),
        if (vehicleId != null) 'vehicleId': vehicleId,
        'hasDocumentedHistory': hasDocumentedHistory,
        'serviceCount': serviceCount,
        'historySpanMonths': historySpanMonths,
        // Only when true. A real listing must not carry the key at all —
        // `demo: false` on every document invites the next reader to write
        // `data['demo'] != null` and label the whole marketplace.
        if (isDemo) 'demo': true,
      };

  String get title => '$make $model'.trim();
  String? get coverPhoto => photos.isNotEmpty ? photos.first : null;
}
