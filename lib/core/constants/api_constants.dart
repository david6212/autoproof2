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

  // Usage:
  // GET https://data.gov.il/api/3/action/datastore_search
  //   ?resource_id=053cea08-09bc-40ec-8f7a-156f0677aff3
  //   &q=1234567          ← plate number WITHOUT dashes
  //   &limit=1
}
