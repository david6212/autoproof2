import '../../core/utils/date_formatter.dart';

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
  });

  /// Returns a copy with the vehicle-history + recall data merged in.
  GovData withExtras({
    required Map<String, dynamic>? history,
    required List<RecallItem> recalls,
  }) {
    int? km;
    bool flag(dynamic v) => v == 1 || v == '1';
    if (history != null) {
      final k = history['kilometer_test_aharon'];
      km = k is int ? k : int.tryParse('${k ?? ''}');
    }
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
      lastTestKm: km,
      structuralChange: flag(history?['shinui_mivne_ind']),
      colorChanged: flag(history?['shnui_zeva_ind']),
      tireChanged: flag(history?['shinui_zmig_ind']),
      originality: (history?['mkoriut_nm'] ?? '').toString().trim(),
      firstRegistration:
          (history?['rishum_rishon_dt'] ?? '').toString().split(' ').first,
      recalls: recalls,
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
