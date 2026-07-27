/// data.gov.il — Israeli Ministry of Transport public vehicle registry.
class ApiConstants {
  ApiConstants._();

  static const govApiBase =
      'https://data.gov.il/api/3/action/datastore_search';

  static const vehicleResourceId = '053cea08-09bc-40ec-8f7a-156f0677aff3';

  // Additional Ministry of Transport datasets.
  static const vehicleHistoryResourceId =
      '56063a99-8a3e-4ff4-912e-5966c0279bad'; // km at last test, structural change
  static const openRecallResourceId =
      '36bf1404-0be4-49d2-82dc-2f1ead4a8b93'; // open (unperformed) recalls
  static const offRoadResourceId =
      '851ecab1-0622-4dbe-a6c7-f950cf82abf9'; // off-road / final cancellation
  static const disabilityTagResourceId =
      'c8b9f9c8-4612-4068-934f-d4acd2e3c06e'; // disability parking tag

  // Licensed garages & inspection institutes ("מוסכים ומכוני רישוי").
  static const garagesResourceId = 'bb68386a-a331-4bbc-b668-bba2766d517d';

  // The `miktzoa` (specialty) value marking a pre-purchase/sale inspection
  // center — exactly the "בדיקת רכב לפני קנייה" a buyer needs (~134 nationwide).
  static const inspectionMiktzoa = 'בדיקות-רכב )קניה ומכירה)';

  // Usage:
  // GET https://data.gov.il/api/3/action/datastore_search
  //   ?resource_id=053cea08-09bc-40ec-8f7a-156f0677aff3
  //   &q=1234567          ← plate number WITHOUT dashes
  //   &limit=1
}
