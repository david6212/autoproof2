import '../../core/utils/date_formatter.dart';

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
  });

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
    );
  }

  /// A short, human-friendly title for the vehicle.
  String get title {
    final name = commercialName.isNotEmpty ? commercialName : model;
    return '$make $name'.trim();
  }
}
