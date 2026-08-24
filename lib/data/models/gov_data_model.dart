import '../../core/utils/date_formatter.dart';
import 'model_spec.dart';

/// A single open manufacturer recall (קריאת שירות שלא בוצעה).
class RecallItem {
  final String system; // SUG_TAKALA
  final String description; // TEUR_TAKALA
  final String date; // TAARICH_PTICHA
  const RecallItem(
      {required this.system, required this.description, required this.date});
}

/// Vehicle data as returned by the data.gov.il registry
/// (resource 053cea08-09bc-40ec-8f7a-156f0677aff3).
///
/// Note: this dataset does NOT include last-test KM or the misgeret_yeud
/// lease/rental flags — those live in separate datasets. Commercial-use is
/// derived here from `baalut` (ownership type) instead, which this dataset
/// does provide.
/// The registry endpoints a plate lookup touches beyond the base record.
enum GovDataset {
  /// Test history: official odometer, structural change, colour, originality.
  history,

  /// Open manufacturer recalls.
  recalls,

  /// Off the road / finally cancelled (scrapped).
  ///
  /// It only became a member of this enum on 24/08/2026, and that is the
  /// finding rather than a detail: the register was consulted **only** when
  /// the active lookup failed, while the listing page said flatly that it had
  /// been checked. For every car that is in the registry — which is every real
  /// listing — the app was naming a check it had not run.
  offRoad,
}

class GovData {
  final String plate; // mispar_rechev
  final String make; // tozeret_nm
  final String commercialName; // kinuy_mishari
  final String model; // degem_nm
  final int year; // shnat_yitzur
  final String color; // tzeva_rechev
  final String fuelType; // sug_delek_nm (already Hebrew)
  final String ownershipType; // baalut (e.g. "פרטי", "ליסינג", "השכרה")
  final String trim; // ramat_gimur
  final DateTime? lastTestDate; // mivchan_acharon_dt
  final DateTime? licenseExpiry; // tokef_dt
  final String? safetyRating; // ramat_eivzur_betihuty
  final String chassis; // misgeret (VIN)
  final String pollutionGroup; // kvutzat_zihum
  final String engineModel; // degem_manoa
  final String frontTire; // zmig_kidmi
  final String rearTire; // zmig_ahori
  final String firstOnRoad; // moed_aliya_lakvish (e.g. "2017-8")
  // From the vehicle-history dataset.
  final int? lastTestKm; // kilometer_test_aharon (official odometer)
  final bool structuralChange; // shinui_mivne_ind
  final bool colorChanged; // shnui_zeva_ind
  final bool tireChanged; // shinui_zmig_ind
  final String originality; // mkoriut_nm (e.g. "פרטי", "החכר", "ביס לנהיגה")
  final String firstRegistration; // rishum_rishon_dt
  // From the open-recall dataset.
  final List<RecallItem> recalls;
  // From the off-road dataset.
  final bool offRoad; // vehicle scrapped / finally cancelled
  final String offRoadDate; // bitul_dt
  // Join keys into the models dataset (manufacturer + model codes).
  final String tozeretCd;
  final String degemCd;
  /// Per-model build spec (engine cc, seats, drivetrain, body). Null until the
  /// models dataset has been consulted.
  final ModelSpec? spec;

  const GovData({
    required this.plate,
    required this.make,
    required this.commercialName,
    required this.model,
    required this.year,
    required this.color,
    required this.fuelType,
    required this.ownershipType,
    required this.trim,
    required this.lastTestDate,
    required this.licenseExpiry,
    required this.safetyRating,
    required this.chassis,
    this.pollutionGroup = '',
    this.engineModel = '',
    this.frontTire = '',
    this.rearTire = '',
    this.firstOnRoad = '',
    this.lastTestKm,
    this.structuralChange = false,
    this.colorChanged = false,
    this.tireChanged = false,
    this.originality = '',
    this.firstRegistration = '',
    this.recalls = const [],
    this.offRoad = false,
    this.offRoadDate = '',
    this.tozeretCd = '',
    this.degemCd = '',
    this.spec,
    this.missingDatasets = const {},
  });

  /// Enrichment datasets that did not answer for this lookup.
  ///
  /// The registry is five separate endpoints, and any one of them can time out
  /// or rate-limit on its own. Before this existed a single flaky auxiliary
  /// dataset threw, the provider swallowed it, and every government fact
  /// vanished from the listing at once — the odometer comparison, the recall
  /// check, the lot.
  ///
  /// Recording the gap rather than papering over it is the whole point. An
  /// empty recall list means two completely different things depending on
  /// whether the recall dataset answered, and the app is not allowed to
  /// present the second one as the first: "no open recalls found" when we
  /// never reached the recall dataset is a claim about a check we did not run.
  final Set<GovDataset> missingDatasets;

  bool answered(GovDataset d) => !missingDatasets.contains(d);

  /// The registry's answer, as it can be stored on a public listing.
  ///
  /// **Without the plate and without the VIN.** That is the entire reason this
  /// exists: `cars/{id}` is world-readable, so a buyer's copy of the registry
  /// answer must not carry the two identifiers that point back at a named
  /// keeper. Everything else here is a fact about a car that is openly for
  /// sale, and is already on the screen.
  ///
  /// Dates go out as ISO strings rather than Timestamps so the map is a plain
  /// JSON document — the same shape whether it came from Firestore, a test, or
  /// a file.
  Map<String, dynamic> toSnapshot() => {
        'make': make,
        'commercialName': commercialName,
        'model': model,
        'year': year,
        'color': color,
        'fuelType': fuelType,
        'ownershipType': ownershipType,
        'trim': trim,
        'lastTestDate': lastTestDate?.toIso8601String(),
        'licenseExpiry': licenseExpiry?.toIso8601String(),
        'safetyRating': safetyRating,
        'pollutionGroup': pollutionGroup,
        'engineModel': engineModel,
        'frontTire': frontTire,
        'rearTire': rearTire,
        'firstOnRoad': firstOnRoad,
        'lastTestKm': lastTestKm,
        'structuralChange': structuralChange,
        'colorChanged': colorChanged,
        'tireChanged': tireChanged,
        'originality': originality,
        'firstRegistration': firstRegistration,
        'offRoad': offRoad,
        'offRoadDate': offRoadDate,
        'tozeretCd': tozeretCd,
        'degemCd': degemCd,
        'recalls': [
          for (final r in recalls)
            {'system': r.system, 'description': r.description, 'date': r.date}
        ],
        // Which datasets did NOT answer when this was taken. Dropping it would
        // turn "we never reached the recall list" into "no recalls", which is
        // the one substitution this app is built to refuse.
        'missing': [for (final d in missingDatasets) d.name],
        'spec': spec?.toMap(),
      };

  /// Rebuilds the answer a listing stored.
  ///
  /// [plate] and [chassis] come back empty, because they were never written.
  /// Every screen that draws them masks them anyway.
  factory GovData.fromSnapshot(Map<String, dynamic> m) {
    DateTime? date(Object? v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

    return GovData(
      plate: '',
      chassis: '',
      make: '${m['make'] ?? ''}',
      commercialName: '${m['commercialName'] ?? ''}',
      model: '${m['model'] ?? ''}',
      year: (m['year'] as num?)?.toInt() ?? 0,
      color: '${m['color'] ?? ''}',
      fuelType: '${m['fuelType'] ?? ''}',
      ownershipType: '${m['ownershipType'] ?? ''}',
      trim: '${m['trim'] ?? ''}',
      lastTestDate: date(m['lastTestDate']),
      licenseExpiry: date(m['licenseExpiry']),
      safetyRating: m['safetyRating'] as String?,
      pollutionGroup: '${m['pollutionGroup'] ?? ''}',
      engineModel: '${m['engineModel'] ?? ''}',
      frontTire: '${m['frontTire'] ?? ''}',
      rearTire: '${m['rearTire'] ?? ''}',
      firstOnRoad: '${m['firstOnRoad'] ?? ''}',
      lastTestKm: (m['lastTestKm'] as num?)?.toInt(),
      structuralChange: m['structuralChange'] == true,
      colorChanged: m['colorChanged'] == true,
      tireChanged: m['tireChanged'] == true,
      originality: '${m['originality'] ?? ''}',
      firstRegistration: '${m['firstRegistration'] ?? ''}',
      offRoad: m['offRoad'] == true,
      offRoadDate: '${m['offRoadDate'] ?? ''}',
      tozeretCd: '${m['tozeretCd'] ?? ''}',
      degemCd: '${m['degemCd'] ?? ''}',
      recalls: [
        for (final r in (m['recalls'] as List? ?? const []))
          RecallItem(
            system: '${(r as Map)['system'] ?? ''}',
            description: '${r['description'] ?? ''}',
            date: '${r['date'] ?? ''}',
          ),
      ],
      missingDatasets: {
        for (final name in (m['missing'] as List? ?? const []))
          for (final d in GovDataset.values)
            if (d.name == name) d,
      },
      spec: m['spec'] is Map
          ? ModelSpec.fromMap(Map<String, dynamic>.from(m['spec'] as Map))
          : null,
    );
  }


  /// Returns a copy carrying the per-model build spec.
  GovData withSpec(ModelSpec? s) => _copy(spec: s);

  /// Returns a copy with the extra datasets (history, recalls, off-road,
  /// structural change) merged in.
  GovData withExtras({
    required Map<String, dynamic>? history,
    required List<RecallItem> recalls,
    Map<String, dynamic>? offRoad,
    Set<GovDataset> missing = const {},
  }) {
    int? km;
    bool flag(dynamic v) => v == 1 || v == '1';
    if (history != null) {
      final k = history['kilometer_test_aharon'];
      km = k is int ? k : int.tryParse('${k ?? ''}');
    }
    return _copy(
      lastTestKm: km,
      structuralChange: flag(history?['shinui_mivne_ind']),
      colorChanged: flag(history?['shnui_zeva_ind']),
      tireChanged: flag(history?['shinui_zmig_ind']),
      originality: (history?['mkoriut_nm'] ?? '').toString().trim(),
      firstRegistration:
          (history?['rishum_rishon_dt'] ?? '').toString().split(' ').first,
      recalls: recalls,
      offRoad: offRoad != null,
      offRoadDate: (offRoad?['bitul_dt'] ?? '').toString().split(' ').first,
      missing: missing,
    );
  }

  /// Single copy point, so adding a field doesn't mean editing several
  /// hand-written constructor calls that each risk dropping one.
  GovData _copy({
    int? lastTestKm,
    bool? structuralChange,
    bool? colorChanged,
    bool? tireChanged,
    String? originality,
    String? firstRegistration,
    List<RecallItem>? recalls,
    bool? offRoad,
    String? offRoadDate,
    ModelSpec? spec,
    Set<GovDataset>? missing,
  }) {
    return GovData(
      plate: plate,
      make: make,
      commercialName: commercialName,
      model: model,
      year: year,
      color: color,
      fuelType: fuelType,
      ownershipType: ownershipType,
      trim: trim,
      lastTestDate: lastTestDate,
      licenseExpiry: licenseExpiry,
      safetyRating: safetyRating,
      chassis: chassis,
      pollutionGroup: pollutionGroup,
      engineModel: engineModel,
      frontTire: frontTire,
      rearTire: rearTire,
      firstOnRoad: firstOnRoad,
      lastTestKm: lastTestKm ?? this.lastTestKm,
      structuralChange: structuralChange ?? this.structuralChange,
      colorChanged: colorChanged ?? this.colorChanged,
      tireChanged: tireChanged ?? this.tireChanged,
      originality: originality ?? this.originality,
      firstRegistration: firstRegistration ?? this.firstRegistration,
      recalls: recalls ?? this.recalls,
      offRoad: offRoad ?? this.offRoad,
      offRoadDate: offRoadDate ?? this.offRoadDate,
      tozeretCd: tozeretCd,
      degemCd: degemCd,
      spec: spec ?? this.spec,
      missingDatasets: missing ?? missingDatasets,
    );
  }

  /// True when the vehicle is privately owned (ownership contains "פרטי").
  bool get isPrivate => ownershipType.contains('פרטי');

  /// True when the vehicle had commercial use (leasing, rental, taxi, etc.).
  bool get isCommercialUse => !isPrivate && ownershipType.isNotEmpty;

  String get lastTestDisplay => DateFormatter.fromGov(lastTestDate);
  String get licenseExpiryDisplay => DateFormatter.fromGov(licenseExpiry);

  factory GovData.fromApi(Map<String, dynamic> r) {
    String s(dynamic v) => (v ?? '').toString().trim();

    int parseYear(dynamic v) {
      if (v == null) return 0;
      return int.tryParse(v.toString()) ?? 0;
    }

    return GovData(
      plate: s(r['mispar_rechev']),
      tozeretCd: s(r['tozeret_cd']),
      degemCd: s(r['degem_cd']),
      make: s(r['tozeret_nm']),
      commercialName: s(r['kinuy_mishari']),
      model: s(r['degem_nm']),
      year: parseYear(r['shnat_yitzur']),
      color: s(r['tzeva_rechev']),
      fuelType: s(r['sug_delek_nm']),
      ownershipType: s(r['baalut']),
      trim: s(r['ramat_gimur']),
      lastTestDate: DateFormatter.parseGov(r['mivchan_acharon_dt']),
      licenseExpiry: DateFormatter.parseGov(r['tokef_dt']),
      safetyRating: (r['ramat_eivzur_betihuty'] == null ||
              s(r['ramat_eivzur_betihuty']).isEmpty)
          ? null
          : s(r['ramat_eivzur_betihuty']),
      chassis: s(r['misgeret']),
      pollutionGroup: s(r['kvutzat_zihum']),
      engineModel: s(r['degem_manoa']),
      frontTire: s(r['zmig_kidmi']),
      rearTire: s(r['zmig_ahori']),
      firstOnRoad: s(r['moed_aliya_lakvish']),
    );
  }

  /// "יצרן · דגם · שנה" style extras.
  String get firstOnRoadDisplay {
    if (firstOnRoad.isEmpty) return '—';
    final parts = firstOnRoad.split('-');
    if (parts.length == 2) {
      final m = parts[1].padLeft(2, '0');
      return '$m/${parts[0]}';
    }
    return firstOnRoad;
  }

  /// A short, human-friendly title for the vehicle.
  String get title {
    final name = commercialName.isNotEmpty ? commercialName : model;
    return '$make $name'.trim();
  }
}
