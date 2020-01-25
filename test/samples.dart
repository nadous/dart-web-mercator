class ViewportData {
  final String name;
  final double width, height;
  final double lng, lat;
  final double zoom, bearing;
  final double pitch, altitude;

  const ViewportData._(this.name, this.width, this.height, this.lng, this.lat, this.zoom, this.bearing, {this.pitch, this.altitude});

  factory ViewportData.flat() => ViewportData._("Flat", 800, 600, -122.43, 37.75, 11.5, 0);
  factory ViewportData.pitched() => ViewportData._("Pitched", 800, 600, -122.43, 37.75, 11.5, 0, pitch: 30);
  factory ViewportData.rotated() => ViewportData._("Rotated", 1267, 400, -122.4194, 37.7749, 11, 180, pitch: 60, altitude: 1.5);
  factory ViewportData.highLatitude() => ViewportData._("HighLatitude", 500, 500, 42.42694, 75.751537, 15.5, -40, pitch: 20, altitude: 1.5);

  factory ViewportData.copyWith(ViewportData original, {double lng, double lat}) => ViewportData._(
        original.name,
        original.width,
        original.height,
        lng ?? original.lng,
        lat ?? original.lat,
        original.zoom,
        original.bearing,
        pitch: original.pitch,
        altitude: original.altitude,
      );

  @override
  String toString() => name;
  // - width: $width, height: $height
  // - lng: $lng, lat: $lat
  // - zoom: $zoom, bearing: $bearing
  // - pitch: ${pitch ?? 'nan'}, altitude: ${altitude ?? 'nan'}''';
}

List<ViewportData> get viewports => [ViewportData.flat(), ViewportData.pitched(), ViewportData.rotated(), ViewportData.highLatitude()];
