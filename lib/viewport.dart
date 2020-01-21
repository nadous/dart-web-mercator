part of web_mercator;

class Viewport {
  final int width, height;
  final double lat, lng, zoom, pitch, bearing, altitude, unitsPerMeter;
  final Vector2 center;

  Matrix4 viewMatrix, projMatrix;
  Matrix4 _viewProjMatrix, _pixelProjMatrix, _pixelUnprojMatrix;

  Viewport({
    @required this.width,
    @required this.height,
    this.lng = 0,
    this.lat = 0,
    this.zoom = 0,
    this.pitch = 0,
    this.bearing = 0,
    this.altitude = 1.5,
    double nearZMultiplier = .02,
    double farZMultiplier = 1.01,
  })  : assert(width >= 1 && height >= 1, 'invalid viewport dimension'),
        assert(altitude >= .75, 'invalid altitude'),
        unitsPerMeter = getDistanceScales(lng, lat)['unitsPerMeter'][2],
        center = lngLatToWorld(lng, lat) {
    viewMatrix = getViewMatrix(
      height: height,
      pitch: pitch,
      bearing: bearing,
      altitude: max(.75, altitude),
      scale: zoomToScale(zoom),
      center: center,
    );

    projMatrix = getProjMatrix(
      width: width,
      height: height,
      pitch: pitch,
      altitude: altitude,
      nearZMultiplier: nearZMultiplier,
      farZMultiplier: farZMultiplier,
    );

    _viewProjMatrix = Matrix4.identity()..multiplied(projMatrix)..multiplied(viewMatrix);

    _pixelProjMatrix = Matrix4.identity()
      ..scale(this.width * .5, -this.height * .5, 1)
      ..translate(1, -1, 0)
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
    List<int> offset = const [0, 0],
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

    return Viewport(width: width, height:height, lng:centerLngLat[0], lat:centerLngLat[1], zoom:zoom);
  }

  /// Project [vector] to pixel coordinates.
  Vector project(Vector vector, {bool topLeft = true}) {
    assert(vector is Vector2 || vector is Vector3);

    final projPosition = projectPosition(vector);
    final viewPosition = worldToPixels(projPosition, _pixelProjMatrix);
    final y = topLeft ? viewPosition[1] : height - viewPosition[1];

    return vector is Vector2 ? Vector2(viewPosition[0], y) : Vector3(viewPosition[2], y, viewPosition[2]);
  }

  ///  Unproject [xyz] coordinates onto world coordinates.
  Vector unproject(Vector3 xyz, {bool topLeft = true, double targetZ}) {
    final y = topLeft ? xyz[1] : height - xyz[1];
    final worldPosition = pixelsToWorld(Vector3(xyz[0], y, xyz[2]), _pixelUnprojMatrix, targetZ: targetZ ?? targetZ * unitsPerMeter);
    final unprojPosition = unprojectPosition(worldPosition);

    if (targetZ != null) {
      return Vector3(unprojPosition[0], unprojPosition[1], targetZ);
    } else {
      return Vector2(unprojPosition[0], unprojPosition[1]);
    }
  }

  Vector3 projectPosition(Vector vector) {
    assert(vector is Vector2 || vector is Vector3 || vector is Vector4);

    final flatVector = vector as Vector2;
    final flatProjection = projectFlat(flatVector[0], flatVector[1]);
    final z = (vector is Vector3 ? vector[2] : 0) * unitsPerMeter;

    return Vector3(flatProjection[0], flatProjection[1], z);
  }

  Vector3 unprojectPosition(Vector vector) {
    assert(vector is Vector2 || vector is Vector3 || vector is Vector4);

    final flatVector = vector as Vector2;
    final flatUnprojection = unprojectFlat(flatVector[0], flatVector[1]);
    final z = (vector is Vector3 ? vector[2] : 0) / unitsPerMeter;

    return Vector3(flatUnprojection[0], flatUnprojection[1], z);
  }

  Vector2 projectFlat(double x, double y) => lngLatToWorld(x, y);

  Vector2 unprojectFlat(double x, double y) => worldToLngLat(x, y);

  /// Get the map center that places a given [lngLat] coordinate at screen point [pos].
  Vector2 getMapCenterByLngLatPosition({Vector2 lngLat, Vector2 pos}) {
    final fromLocation = pixelsToWorld(Vector3(pos[0], pos[1], double.nan), _pixelUnprojMatrix) as Vector2;
    final toLocation = lngLatToWorld(lngLat[0], lngLat[1]);

    fromLocation.negate();
    final translate = toLocation.clone();
    translate.add(fromLocation);
    final newCenter = center.clone();
    newCenter.add(translate);

    return worldToLngLat(newCenter[0], newCenter[1]);
  }

  @override
  int get hashCode => quiver.hashObjects([width, height, viewMatrix, projMatrix]);

  @override
  bool operator ==(Object other) => (other is Viewport) && (other.width == this.width && other.height == this.height && other.viewMatrix == this.viewMatrix);

// /**
//  * Returns a new viewport that fit around the given rectangle.
//  * Only supports non-perspective mode.
//  * @param {Array} bounds - [[lon, lat], [lon, lat]]
//  * @param {Number} [options.padding] - The amount of padding in pixels to add to the given bounds.
//  * @param {Array} [options.offset] - The center of the given bounds relative to the map's center,
//  *    [x, y] measured in pixels.
//  * @returns {Viewport}
//  */
// fitBounds(bounds, options = {}) {
//   const {width, height} = this;
//   const {longitude, latitude, zoom} = fitBounds(Object.assign({width, height, bounds}, options));
//   return new Viewport({width, height, longitude, latitude, zoom});
// }
}
