/// data.gov.il — Israeli Ministry of Transport public vehicle registry.
class ApiConstants {
  ApiConstants._();

  static const govApiBase =
      'https://data.gov.il/api/3/action/datastore_search';

  static const vehicleResourceId = '053cea08-09bc-40ec-8f7a-156f0677aff3';

  // Usage:
  // GET https://data.gov.il/api/3/action/datastore_search
  //   ?resource_id=053cea08-09bc-40ec-8f7a-156f0677aff3
  //   &q=1234567          ← plate number WITHOUT dashes
  //   &limit=1
}
