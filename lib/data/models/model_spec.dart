/// Per-MODEL specification from the Ministry of Transport "WLTP models"
/// dataset.
///
/// The per-vehicle registry describes a specific car (plate, colour, owner,
/// test dates) but says nothing about how the model is built. Engine capacity,
/// seat count, drivetrain and body type only exist here, keyed by
/// manufacturer + model + production year.
class ModelSpec {
  /// Engine capacity in cc. Null for electric models, which legitimately have
  /// none — don't treat that as missing data.
  final int? engineCc;

  final int? seats;
  final int? doors;
  final int? horsepower;

  /// Drivetrain as published, e.g. "4X2", "4X4".
  final String drivetrain;

  /// Body type as published, e.g. "סדאן", "פנאי-שטח", "האצ'בק".
  final String bodyType;

  final bool automatic;

  const ModelSpec({
    this.engineCc,
    this.seats,
    this.doors,
    this.horsepower,
    this.drivetrain = '',
    this.bodyType = '',
    this.automatic = false,
  });

  bool get isEmpty =>
      engineCc == null &&
      seats == null &&
      drivetrain.isEmpty &&
      bodyType.isEmpty;

  static int? _int(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    final n = int.tryParse('$v'.trim());
    return (n == null || n == 0) ? null : n;
  }

  factory ModelSpec.fromApi(Map<String, dynamic> r) {
    String s(Object? v) => (v?.toString() ?? '').trim();
    final auto = s(r['automatic_ind']);
    return ModelSpec(
      engineCc: _int(r['nefah_manoa']),
      seats: _int(r['mispar_moshavim']),
      doors: _int(r['mispar_dlatot']),
      horsepower: _int(r['koah_sus']),
      drivetrain: s(r['hanaa_nm']),
      bodyType: s(r['merkav']),
      automatic: auto == '1',
    );
  }

  Map<String, dynamic> toMap() => {
        'engineCc': engineCc,
        'seats': seats,
        'doors': doors,
        'horsepower': horsepower,
        'drivetrain': drivetrain,
        'bodyType': bodyType,
        'automatic': automatic,
      };

  factory ModelSpec.fromMap(Map<String, dynamic> m) => ModelSpec(
        engineCc: _int(m['engineCc']),
        seats: _int(m['seats']),
        doors: _int(m['doors']),
        horsepower: _int(m['horsepower']),
        drivetrain: (m['drivetrain'] ?? '').toString(),
        bodyType: (m['bodyType'] ?? '').toString(),
        automatic: m['automatic'] == true,
      );
}
