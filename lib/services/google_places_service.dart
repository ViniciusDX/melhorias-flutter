import 'package:google_place/google_place.dart';
import 'package:uuid/uuid.dart';

class GooglePlacesService {
  final GooglePlace _api;
  String _sessionToken = const Uuid().v4();

  GooglePlacesService(String apiKey) : _api = GooglePlace(apiKey);

  void resetSession() => _sessionToken = const Uuid().v4();

  Future<List<AutocompletePrediction>> autocomplete(
      String input, {
        required int mode,
        bool strictBounds = false,
        double? lat,
        double? lng,
        int? radiusMeters,
      }) async {
    if (input.trim().isEmpty) return [];

    final types = switch (mode) {
      1 => 'establishment',
      2 => 'address',
      3 => 'geocode',
      _ => null
    };

    final resp = await _api.autocomplete.get(
      input,
      language: 'pt-BR',
      types: types,
      components: [Component('country', 'br')],
      location: (lat != null && lng != null) ? LatLon(lat, lng) : null,
      radius: (lat != null && lng != null) ? (radiusMeters ?? 500000) : null,
      strictbounds: strictBounds,
      sessionToken: _sessionToken,
      region: 'br',
    );

    return resp?.predictions ?? [];
  }

  Future<DetailsResult?> details(String placeId) async {
    final resp = await _api.details.get(
      placeId,
      fields: 'name,formatted_address,geometry/location',
      language: 'pt-BR',
      sessionToken: _sessionToken,
    );
    return resp?.result;
  }
}
