class ViewportData {
  final int width, height;
  final double lng, lat, zoom, bearing;
  final double pitch, altitude;

  ViewportData(this.width, this.height, this.lng, this.lat, this.zoom, this.bearing, {this.pitch, this.altitude});

  @override
  String toString() => '''
  - width: $width, height: $height
  - lng: $lng, lat: $lat
  - zoom: $zoom, bearing: $bearing
  - pitch: ${pitch ?? 'nan'}, altitude: ${altitude ?? 'nan'}''';
}

class FlatViewport extends ViewportData {
  FlatViewport() : super(800, 600, -122.43, 37.75, 11.5, 0);

  @override
  String toString() => 'FlatViewport';
}

class PitchedViewport extends ViewportData {
  PitchedViewport() : super(800, 600, -122.43, 37.75, 11.5, 0, pitch: 30);

  @override
  String toString() => 'PitchedViewport';
}

class RotatedViewport extends ViewportData {
  RotatedViewport() : super(1267, 400, -122.4194, 37.7749, 11, 180, pitch: 60, altitude: 1.5);

  @override
  String toString() => 'RotatedViewport';
}

class HighLatitudeViewport extends ViewportData {
  HighLatitudeViewport() : super(500, 500, 42.42694, 75.751537, 15.5, -40, pitch: 20, altitude: 1.5);

  @override
  String toString() => 'HighLatitudeViewport';
}

List<ViewportData> get data => [FlatViewport(), PitchedViewport(), RotatedViewport(), HighLatitudeViewport()];
