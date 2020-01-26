class ViewportData {
  final String name;
  final double width, height;
  final double lng, lat;
  final double zoom, bearing;
  final double pitch, altitude;

  const ViewportData._(this.name, this.width, this.height, this.lng, this.lat, this.zoom, this.bearing, {this.pitch, this.altitude});

  factory ViewportData.flat() => ViewportData._('Flat', 800, 600, -122.43, 37.75, 11.5, 0);
  factory ViewportData.pitched() => ViewportData._('Pitched', 800, 600, -122.43, 37.75, 11.5, 0, pitch: 30);
  factory ViewportData.rotated() => ViewportData._('Rotated', 1267, 400, -122.4194, 37.7749, 11, 180, pitch: 60, altitude: 1.5);
  factory ViewportData.highLatitude() => ViewportData._('HighLatitude', 500, 500, 42.42694, 75.751537, 15.5, -40, pitch: 20, altitude: 1.5);

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

dynamic get bounds => [
      [
        {
          'width': 100,
          'height': 100,
          // southwest bound first
          'bounds': [
            [-73.9876, 40.7661],
            [-72.9876, 41.7661]
          ]
        },
        {'lng': -73.48759999999997, 'lat': 41.26801443944763, 'zoom': 5.723804361273887}
      ],
      [
        {
          'width': 100,
          'height': 100,
          // northeast bound first
          'bounds': [
            [-72.9876, 41.7661],
            [-73.9876, 40.7661]
          ]
        },
        {'lng': -73.48759999999997, 'lat': 41.26801443944763, 'zoom': 5.723804361273887}
      ],
      [
        {
          'width': 100,
          'height': 100,
          'bounds': [
            [-73.0, 10.0],
            [-73.0, 10.0]
          ],
          'maxZoom': 22.0
        },
        {'lng': -73, 'lat': 10, 'zoom': 22}
      ],
      [
        {
          'width': 100,
          'height': 100,
          'bounds': [
            [-73.0, 10.0],
            [-73.0, 10.0]
          ],
          'minExtent': 0.01
        },
        {'lng': -73, 'lat': 10, 'zoom': 13.28771238}
      ],
      [
        {
          'width': 600,
          'height': 400,
          'bounds': [
            [-23.407, 64.863],
            [-23.406, 64.874]
          ],
          'padding': 20,
          'offset': [0, -40]
        },
        {'lng': -23.406499999999973, 'lat': 64.86850056273362, 'zoom': 12.89199533073045}
      ],
      [
        {
          'width': 600,
          'height': 400,
          'bounds': [
            [-23.407, 64.863],
            [-23.406, 64.874]
          ],
          'padding': {'top': 100, 'bottom': 10, 'left': 30, 'right': 30},
          'offset': [0, -40]
        },
        {'lng': -23.406499999999973, 'lat': 64.870857602, 'zoom': 12.476957831}
      ]
    ];
