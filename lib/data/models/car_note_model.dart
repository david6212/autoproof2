import 'package:cloud_firestore/cloud_firestore.dart';

/// Where an observation was made, so a bank of nearly thirty is readable.
///
/// The groups follow the order a person actually inspects a car: walk round
/// it, open the bonnet, drive it, sit in it, look at the tyres, and only then
/// compare what you saw against what the advert said.
enum NoteGroup { body, engine, driving, interior, tyres, listing }

extension NoteGroupX on NoteGroup {
  String get label => switch (this) {
        NoteGroup.body => 'מרכב וצבע',
        NoteGroup.engine => 'מנוע',
        NoteGroup.driving => 'נסיעה',
        NoteGroup.interior => 'פנים הרכב',
        NoteGroup.tyres => 'צמיגים',
        NoteGroup.listing => 'מול המודעה',
      };
}

/// One thing a visitor can report having found while inspecting a car.
///
/// **This is a closed list, and there is no "other".** An open box invites
/// accusations about a named seller ("he lied", "he hid an accident"), which is
/// where nearly all of the defamation exposure lived — and it invites the
/// vaguer kind of harm too, the note that says "משהו הרגיש לי לא בסדר" and
/// costs someone a sale without stating anything a reader can weigh.
///
/// Every entry below is an **observation about the car**, phrased so that two
/// people looking at the same vehicle would tick the same box. None of them is
/// about the seller: "who I met" was a feature here and was removed on
/// 24/08/2026, along with the free-text field this list replaces.
///
/// The free-text box that used to sit under "אחר" was accepted, stored and
/// never displayed pending a review that had no reviewer. Holding text nobody
/// will ever read is not moderation; it is a queue that pretends to be one.
enum NoteTag {
  // ---- body ----
  bodyDamage,
  paintMismatch,
  rust,
  panelGaps,
  glassChipped,

  // ---- engine ----
  warningLight,
  oilLeak,
  exhaustSmoke,
  engineNoise,
  hardStart,

  // ---- driving ----
  brakeNoise,
  pullsToSide,
  vibration,
  gearboxDelay,

  // ---- interior ----
  acWeak,
  dampSmell,
  wearVsKm,
  electricsFault,

  // ---- tyres ----
  tyresWorn,
  tyresMismatched,

  // ---- against the advert ----
  matchedPhotos,
  kmMatched,
  licenceShown,
  serviceHistoryShown,
  testDrive,
  inspectionDone,
  priceChanged,
}

extension NoteTagX on NoteTag {
  /// Value stored in Firestore — stable, never localise this.
  String get id => switch (this) {
        NoteTag.bodyDamage => 'body_damage',
        NoteTag.paintMismatch => 'paint_mismatch',
        NoteTag.rust => 'rust',
        NoteTag.panelGaps => 'panel_gaps',
        NoteTag.glassChipped => 'glass_chipped',
        NoteTag.warningLight => 'warning_light',
        NoteTag.oilLeak => 'oil_leak',
        NoteTag.exhaustSmoke => 'exhaust_smoke',
        NoteTag.engineNoise => 'engine_noise',
        NoteTag.hardStart => 'hard_start',
        NoteTag.brakeNoise => 'brake_noise',
        NoteTag.pullsToSide => 'pulls_to_side',
        NoteTag.vibration => 'vibration',
        NoteTag.gearboxDelay => 'gearbox_delay',
        NoteTag.acWeak => 'ac_weak',
        NoteTag.dampSmell => 'damp_smell',
        NoteTag.wearVsKm => 'wear_vs_km',
        NoteTag.electricsFault => 'electrics_fault',
        NoteTag.tyresWorn => 'tyres_worn',
        NoteTag.tyresMismatched => 'tyres_mismatched',
        NoteTag.matchedPhotos => 'matched_photos',
        NoteTag.kmMatched => 'km_matched',
        NoteTag.licenceShown => 'licence_shown',
        NoteTag.serviceHistoryShown => 'service_history_shown',
        NoteTag.testDrive => 'test_drive',
        NoteTag.inspectionDone => 'inspection_done',
        NoteTag.priceChanged => 'price_changed',
      };

  /// What the visitor saw. Present tense, no adjectives, no conclusions — the
  /// reader draws those. "סימני חלודה" and not "חלודה קשה"; "נורית אזהרה
  /// דולקת" and not "תקלה במנוע".
  String get label => switch (this) {
        NoteTag.bodyDamage => 'שריטות או מכות בפח',
        NoteTag.paintMismatch => 'הפרשי גוון בצבע בין חלקים',
        NoteTag.rust => 'סימני חלודה',
        NoteTag.panelGaps => 'מרווחים לא אחידים בין חלקי המרכב',
        NoteTag.glassChipped => 'שמשה סדוקה או מבזק',
        NoteTag.warningLight => 'נורית אזהרה דולקת בלוח המחוונים',
        NoteTag.oilLeak => 'סימני נזילת שמן',
        NoteTag.exhaustSmoke => 'עשן מהאגזוז',
        NoteTag.engineNoise => 'רעש חריג מהמנוע',
        NoteTag.hardStart => 'קושי בהתנעה',
        NoteTag.brakeNoise => 'רעש בבלמים',
        NoteTag.pullsToSide => 'ההגה מושך לצד',
        NoteTag.vibration => 'רעידות בנסיעה',
        NoteTag.gearboxDelay => 'תיבת ההילוכים מגיבה באיחור',
        NoteTag.acWeak => 'המיזוג לא מקרר',
        NoteTag.dampSmell => 'ריח עובש או סימני רטיבות',
        NoteTag.wearVsKm => 'בלאי בהגה ובדוושות שאינו תואם לקילומטראז\'',
        NoteTag.electricsFault => 'אביזר חשמלי שאינו פועל',
        NoteTag.tyresWorn => 'צמיגים שחוקים',
        NoteTag.tyresMismatched => 'צמיגים מדגמים שונים',
        NoteTag.matchedPhotos => 'הרכב תאם את התמונות במודעה',
        NoteTag.kmMatched => 'הקילומטראז\' תאם למודעה',
        NoteTag.licenceShown => 'הוצג רישיון רכב בתוקף',
        NoteTag.serviceHistoryShown => 'הוצגה היסטוריית טיפולים',
        NoteTag.testDrive => 'בוצעה נסיעת מבחן',
        NoteTag.inspectionDone => 'הרכב נבדק במכון בדיקה',
        NoteTag.priceChanged => 'המחיר השתנה בפגישה',
      };

  NoteGroup get group => switch (this) {
        NoteTag.bodyDamage ||
        NoteTag.paintMismatch ||
        NoteTag.rust ||
        NoteTag.panelGaps ||
        NoteTag.glassChipped =>
          NoteGroup.body,
        NoteTag.warningLight ||
        NoteTag.oilLeak ||
        NoteTag.exhaustSmoke ||
        NoteTag.engineNoise ||
        NoteTag.hardStart =>
          NoteGroup.engine,
        NoteTag.brakeNoise ||
        NoteTag.pullsToSide ||
        NoteTag.vibration ||
        NoteTag.gearboxDelay =>
          NoteGroup.driving,
        NoteTag.acWeak ||
        NoteTag.dampSmell ||
        NoteTag.wearVsKm ||
        NoteTag.electricsFault =>
          NoteGroup.interior,
        NoteTag.tyresWorn || NoteTag.tyresMismatched => NoteGroup.tyres,
        _ => NoteGroup.listing,
      };

  /// Reassuring observations render green, cautionary ones amber. Nothing here
  /// is an accusation, so there is no red — and a car with three amber chips
  /// is a car worth asking about, not a car worth avoiding.
  bool get isPositive => switch (this) {
        NoteTag.matchedPhotos ||
        NoteTag.kmMatched ||
        NoteTag.licenceShown ||
        NoteTag.serviceHistoryShown ||
        NoteTag.testDrive ||
        NoteTag.inspectionDone =>
          true,
        _ => false,
      };

  static NoteTag? fromId(String id) {
    for (final t in NoteTag.values) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// The bank, in inspection order, grouped for a sheet that would otherwise
  /// be twenty-seven chips in one heap.
  static List<NoteTag> inGroup(NoteGroup g) =>
      [for (final t in NoteTag.values) if (t.group == g) t];
}

/// A note left by someone who went to inspect a listing, so future buyers can
/// see what earlier visitors found. Stored at cars/{carId}/notes/{noteId}.
class CarNote {
  final String id;
  final String authorUid;
  final String authorName;
  final DateTime createdAt;

  /// The observations ticked from the fixed bank. This is the whole note —
  /// there is nothing else a visitor can say here.
  final List<NoteTag> tags;

  const CarNote({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    this.tags = const [],
  });

  bool get hasVisibleContent => tags.isNotEmpty;

  factory CarNote.fromFirestore(Map<String, dynamic> data, String id) {
    final rawTags = (data['tags'] as List?) ?? const [];
    return CarNote(
      id: id,
      authorUid: data['authorUid'] ?? '',
      authorName: (data['authorName'] as String?)?.trim().isNotEmpty == true
          ? data['authorName']
          : 'מבקר',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // An id this build does not know is dropped rather than shown raw. The
      // bank was replaced wholesale on 24/08 while no note existed anywhere,
      // so today this only guards a future rename.
      tags: [
        for (final t in rawTags)
          if (NoteTagX.fromId('$t') case final tag?) tag,
      ],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'authorUid': authorUid,
        'authorName': authorName,
        'createdAt': FieldValue.serverTimestamp(),
        'tags': [for (final t in tags) t.id],
      };
}
