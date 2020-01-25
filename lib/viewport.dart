part of web_mercator;

class Viewport {
  final num width, height;
  final double lat, lng, zoom, pitch, bearing, altitude, unitsPerMeter;
  final Vector2 center;

  Matrix4 viewMatrix, projMatrix;
  Matrix4 _viewProjMatrix, _pixelProjMatrix, _pixelUnprojMatrix;

  Viewport({
    @required width,
    @required height,
    this.lng = .0,
    this.lat = .0,
    this.zoom = .0,
    this.pitch = .0,
    this.bearing = .0,
    this.altitude = 1.5,
    double nearZMultiplier = .02,
    double farZMultiplier = 1.01,
  })  : assert(altitude >= .75, 'invalid altitude'),
        this.width = max(1, width),
        this.height = max(1, height),
        unitsPerMeter = getDistanceScales(lng, lat)['unitsPerMeter'][2],
        center = lngLatToWorld(lng, lat) {
    viewMatrix = getViewMatrix(
      height: this.height,
      pitch: pitch,
      bearing: bearing,
      altitude: max(.75, altitude),
      scale: zoomToScale(zoom),
      center: center,
    );

    projMatrix = getProjMatrix(
      width: this.width,
      height: this.height,
      pitch: pitch,
      altitude: altitude,
      nearZMultiplier: nearZMultiplier,
      farZMultiplier: farZMultiplier,
    );

    _viewProjMatrix = Matrix4.identity()..multiply(projMatrix)..multiply(viewMatrix);

    _pixelProjMatrix = Matrix4.identity()
      ..scale(this.width * .5, -this.height * .5, 1)
      ..translate(1.0, -1.0, .0)
      ..multiply(_viewProjMatrix);

    _pixelUnprojMatrix = Matrix4.inverted(_pixelProjMatrix);
  }

  factory Viewport.fitBounds({
    @required int width,
    @required int height,
    @required List<num> bounds,
    double minExtent = 0,
    double maxZoom = 24,
    dynamic padding = 0,
    List<num> offset = const [0, 0],
  }) {
    assert(bounds.length == 4);
    assert(offset.length == 2);

    final west = bounds[0], south = bounds[1], east = bounds[2], north = bounds[3];

    if (padding is int) {
      final p = padding;
      padding = {'top': p, 'right': p, 'bottom': p, 'left': p};
    } else {
      assert(padding is Map<String, num>);
      assert(padding['top'] is num && padding['right'] is num && padding['bottom'] is num && padding['left'] is num);
    }

    final viewport = Viewport(width: width, height: height);

    final nw = viewport.project(Vector2(west, north)) as Vector2;
    final se = viewport.project(Vector2(east, south)) as Vector2;

    /// width/height on the Web Mercator plane
    final size = <num>[
      max((se[0] - nw[0]).abs(), minExtent),
      max((se[1] - nw[1]).abs(), minExtent),
    ];

    final targetSize = <num>[
      width - padding['left'] - padding['right'] - offset[0].abs() * 2,
      height - padding['top'] - padding['bottom'] - offset[1].abs() * 2,
    ];

    assert(targetSize[0] > 0 && targetSize[1] > 0);

    /// scale = screen pixels per unit on the Web Mercator plane
    final scaleX = targetSize[0] / size[0];
    final scaleY = targetSize[1] / size[1];

    /// Find how much we need to shift the center
    final offsetX = (padding['right'] - padding['left']) * .5 / scaleX;
    final offsetY = (padding['bottom'] - padding['top']) * .5 / scaleY;

    final center = Vector3((se[0] + nw[0]) * .5 + offsetX, (se[1] + nw[1]) * .5 + offsetY, double.nan);
    final centerLngLat = viewport.unproject(center) as Vector2;
    final zoom = min(maxZoom, viewport.zoom + log2(min(scaleX, scaleY)).abs());

    assert(zoom.isFinite);

    return Viewport(width: width, height: height, lng: centerLngLat[0], lat: centerLngLat[1], zoom: zoom);
  }

  /// Project [vector] to pixel coordinates.
  Vector project(Vector vector, {bool topLeft = true}) {
    assert(vector is Vector2 || vector is Vector3);

    final worldPosition = projectPosition(vector);
    final coord = worldToPixels(worldPosition, _pixelProjMatrix);
    final y = topLeft ? coord[1] : height - coord[1];

    return vector is Vector2 ? Vector2(coord[0], y) : Vector3(coord[0], y, coord[2]);
  }

  ///  Unproject [xyz] coordinates onto world coordinates.
  Vector unproject(Vector xyz, {bool topLeft = true, double targetZ}) {
    assert(xyz is Vector2 || xyz is Vector3);

    var vec, z;
    try {
      vec = xyz as Vector2;
      z = double.nan;
    } on CastError {
      vec = xyz as Vector3;
      z = vec[2];
    }

    final coord = pixelsToWorld(
      Vector3(vec[0], topLeft ? vec[1] : height - vec[1], z),
      _pixelUnprojMatrix,
      targetZ: targetZ != null ? targetZ * unitsPerMeter : null,
    );

    final unprojPosition = unprojectPosition(coord);
    if (vec is Vector3) {
      return unprojPosition;
    } else if (targetZ != null) {
      return Vector3(unprojPosition[0], unprojPosition[1], targetZ);
    } else {
      return Vector2(unprojPosition[0], unprojPosition[1]);
    }
  }

  Vector3 projectPosition(Vector vector) {
    assert(vector is Vector2 || vector is Vector3 || vector is Vector4);

    var vec;
    try {
      vec = vector as Vector2;
    } on CastError {
      try {
        vec = vector as Vector3;
      } on CastError {
        vec = vector as Vector4;
      }
    }

    final flatProjection = projectFlat(vec[0], vec[1]);
    final z = (vector is Vector3 ? vector[2] : 0) * unitsPerMeter;

    return Vector3(flatProjection[0], flatProjection[1], z);
  }

  Vector3 unprojectPosition(Vector vector) {
    assert(vector is Vector2 || vector is Vector3 || vector is Vector4);

    var vec;
    try {
      vec = vector as Vector2;
    } on CastError {
      try {
        vec = vector as Vector3;
      } on CastError {
        vec = vector as Vector4;
      }
    }

    final unprojection = unprojectFlat(vec[0], vec[1]);
    final z = (vec is Vector3 || vec is Vector4 ? vec[2] : 0) / unitsPerMeter;

    return Vector3(unprojection[0], unprojection[1], z);
  }

  Vector2 projectFlat(double x, double y) => lngLatToWorld(x, y);

  Vector2 unprojectFlat(double x, double y) => worldToLngLat(x, y);

  /// Get the map center that places a given [lngLat] coordinate at screen point [pos].
  Vector2 getLocationAtPoint({Vector2 lngLat, Vector2 pos}) {
    final fromLocation = pixelsToWorld(Vector3(pos[0], pos[1], double.nan), _pixelUnprojMatrix) as Vector2;
    final toLocation = lngLatToWorld(lngLat[0], lngLat[1]);

    print('fromLocation: $fromLocation, toLocation: $toLocation');

    final translate = toLocation.clone();
    fromLocation.negate();
    translate.add(fromLocation);

    final newCenter = center.clone();
    newCenter.add(translate);

    print('translate: $translate, newCenter: $newCenter');
    return worldToLngLat(newCenter[0], newCenter[1]);
  }

  @override
  int get hashCode => quiver.hashObjects([width, height, viewMatrix, projMatrix]);

  @override
  bool operator ==(Object other) => (other is Viewport) && (other.width == this.width && other.height == this.height && other.viewMatrix == this.viewMatrix);
}
