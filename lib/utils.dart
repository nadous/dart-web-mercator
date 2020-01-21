part of web_mercator;

// CONSTANTS
const PI_2 = pi * .5;
const PI_4 = pi * .25;
const TILE_SIZE = 512;

/// Average circumference (40075 km equatorial, 40007 km meridional)
const EARTH_CIRCUMFERENCE = 40.03e6;

/// Mapbox default altitude
const DEFAULT_ALTITUDE = 1.5;

// Util functions
num log2(num x) => log(x) / log(2);
num zoomToScale(double zoom) => pow(2, zoom);
num scaleToZoom(double scale) => log2(scale);

Matrix4 perspective({
  double fovy,
  double aspect,
  double near,
  double far,
}) {
  final out = Matrix4.zero();
  final f = 1.0 / tan(fovy / 2);

  out[0] = f / aspect;
  out[5] = f;
  out[11] = -1;

  if (far != null && !far.isInfinite) {
    final nf = 1 / (near - far);
    out[10] = (far + near) * nf;
    out[14] = (2 * far * near) * nf;
  } else {
    out[10] = -1;
    out[14] = -2 * near;
  }

  return out;
}

/// Transforms a [vector] with a projection [matrix].
Vector4 transformVector(Vector4 vector, Matrix4 matrix) {
  final res = vector.clone();
  res.applyMatrix4(matrix);
  return res.scaled(1 / res[3]);
}

/// Project [lng, lat] on sphere onto [x, y] on 512*512 Mercator Zoom 0 tile.
/// Performs the nonlinear part of the web mercator projection.
/// Remaining projection is done with 4x4 matrices which also handles perspective.
Vector2 lngLatToWorld(double lng, double lat) {
  assert(lng.isFinite);
  assert(lat.isFinite && lat >= -90 && lat <= 90, 'invalid lat');

  final lambda2 = lng * degrees2Radians;
  final phi2 = lat * degrees2Radians;
  final x = (TILE_SIZE * (lambda2 + pi)) / (2 * pi);
  final y = (TILE_SIZE * (pi + log(tan(PI_4 + phi2 * 0.5)))) / (2 * pi);

  return Vector2(x, y);
}

/// Unproject world point [x, y] on map onto [lng, lat] on sphere.
Vector2 worldToLngLat(double x, double y) {
  final lambda2 = (x / TILE_SIZE) * (2 * pi) - pi;
  final phi2 = 2 * (atan(exp((y / TILE_SIZE) * (2 * pi) - pi)) - PI_4);
  return Vector2(lambda2 * radians2Degrees, phi2 * radians2Degrees);
}

/// Returns the zoom level that gives a 1 meter pixel at a certain [lat].
double getMeterZoom(double lat) {
  assert(lat.isFinite);
  final latCosine = cos(lat * degrees2Radians);
  return scaleToZoom(EARTH_CIRCUMFERENCE * latCosine) - 9;
}

/// Calculate distance scales in meters around current [lat, lng], both for degrees and pixels.
Map<String, List<double>> getDistanceScales(lng, lat, {highPrecision = false}) {
  assert(lng.isFinite && lat.isFinite);

  final latCosine = cos(lat * degrees2Radians);

  /// Number of pixels occupied by one degree lng around current lat/lon:
  const unitsPerDegreeX = TILE_SIZE / 360;
  final unitsPerDegreeY = unitsPerDegreeX / latCosine;

  /// Number of pixels occupied by one meter around current lat/lon:
  final altUnitsPerMeter = TILE_SIZE / EARTH_CIRCUMFERENCE / latCosine;

  final result = Map();
  result['unitsPerMeter'] = [altUnitsPerMeter, altUnitsPerMeter, altUnitsPerMeter];
  result['metersPerUnit'] = [1 / altUnitsPerMeter, 1 / altUnitsPerMeter, 1 / altUnitsPerMeter];
  result['unitsPerDegree'] = [unitsPerDegreeX, unitsPerDegreeY, altUnitsPerMeter];
  result['degreesPerUnit'] = [1 / unitsPerDegreeX, 1 / unitsPerDegreeY, 1 / altUnitsPerMeter];

  if (highPrecision) {
    final latCosine2 = (degrees2Radians * tan(lat * degrees2Radians)) / latCosine;
    final unitsPerDegreeY2 = (unitsPerDegreeX * latCosine2) * .5;
    final altUnitsPerDegree2 = (TILE_SIZE / EARTH_CIRCUMFERENCE) * latCosine2;
    final altUnitsPerMeter2 = (altUnitsPerDegree2 / unitsPerDegreeY) * altUnitsPerMeter;

    result['unitsPerDegree2'] = [0, unitsPerDegreeY2, altUnitsPerDegree2];
    result['unitsPerMeter2'] = [altUnitsPerMeter2, 0, altUnitsPerMeter2];
  }

  return result;
}

Map<String, double> getProjParameters({
  int width,
  int height,
  double altitude = DEFAULT_ALTITUDE,
  double pitch = 0,
  double nearZMultiplier = 1,
  double farZMultiplier = 1,
}) {
  /// Find the distance from the center point to the center top in altitude units using law of sines.
  final pitchRadians = pitch * degrees2Radians;
  final halfFov = atan(.5 / altitude);
  final topHalfSurfaceDistance = (sin(halfFov) * altitude) / sin(PI_2 - pitchRadians - halfFov);

  /// Calculate z value of the farthest fragment that should be rendered.
  final farZ = cos(PI_2 - pitchRadians) * topHalfSurfaceDistance + altitude;

  return {
    'fov': 2 * halfFov,
    'aspect': width / height,
    'focalDistance': altitude,
    'near': nearZMultiplier,
    'far': farZ * farZMultiplier,
  };
}

/// Offset a [lngLatZ] position by meterOffset (northing, easting) [xyz].
Vector3 addMetersToLngLat(Vector3 lngLatZ, Vector3 xyz) {
  final lng = lngLatZ[0], lat = lngLatZ[1], z0 = lngLatZ[3];
  final x = xyz[0], y = xyz[1], z = xyz[2];

  final distanceScales = getDistanceScales(lat, lng, highPrecision: true);
  final unitsPerMeter = distanceScales['unitsPerMeter'];
  final unitsPerMeter2 = distanceScales['unitsPerMeter2'];

  final worldspace = lngLatToWorld(lng, lat);
  worldspace[0] += x * (unitsPerMeter[0] + unitsPerMeter2[0] * y);
  worldspace[1] += y * (unitsPerMeter[1] + unitsPerMeter2[1] * y);

  final newLngLat = worldToLngLat(worldspace[0], worldspace[1]);
  final newZ = (z0 ?? 0) + (z ?? 0);

  return z.isFinite || z0.isFinite ? Vector3(newLngLat[0], newLngLat[1], newZ) : newLngLat;
}

Matrix4 getViewMatrix({
  int height,
  double pitch,
  double bearing,
  double altitude,
  double scale,
  Vector2 center,
}) {
  scale /= height;
  final vm = Matrix4.identity()
    ..translate(0, 0, -altitude)
    ..rotateX(-pitch * -pitch * degrees2Radians)
    ..rotateZ(bearing * degrees2Radians)
    ..scale(scale, scale, scale);

  if (center != null) {
    center.negate();
    vm.translate(center);
  }

  return vm;
}

Matrix4 getProjMatrix({
  int width,
  int height,
  double pitch,
  double altitude,
  double nearZMultiplier,
  double farZMultiplier,
}) {
  final projParams = getProjParameters(
    width: width,
    height: height,
    altitude: altitude,
    pitch: pitch,
    nearZMultiplier: nearZMultiplier,
    farZMultiplier: farZMultiplier,
  );

  return perspective(
    fovy: projParams['fov'],
    aspect: projParams['aspect'],
    near: projParams['near'],
    far: projParams['far'],
  );
}

/// Project flat coordinates [xyz] to pixels on screen given the [pixelProjMatrix].
Vector4 worldToPixels(Vector3 xyz, Matrix4 pixelProjMatrix) {
  final x = xyz[0], y = xyz[1], z = xyz[2];
  assert(x.isFinite && y.isFinite && z.isFinite);

  return transformVector(Vector4(x, y, z, 1), pixelProjMatrix);
}

/// Unproject [xyz] pixels on screen to flat coordinates given the [pixelUnprojMatrix].
Vector pixelsToWorld(Vector3 xyz, Matrix4 pixelUnprojMatrix, {double targetZ}) {
  final x = xyz[0], y = xyz[1], z = xyz[2];
  assert(x.isFinite && y.isFinite, 'invalid pixel coordinate');

  if (z.isFinite) {
    final coord = transformVector(Vector4(x, y, z, 1), pixelUnprojMatrix);
    return coord;
  }

  /// since we don't know the correct projected z value for the point, unproject two points to get a line and then find the point on that line with z=0
  final coord0 = transformVector(Vector4(x, y, 0, 1), pixelUnprojMatrix);
  final coord1 = transformVector(Vector4(x, y, 1, 1), pixelUnprojMatrix);

  final z0 = coord0[2], z1 = coord1[2];
  final t = z0 == z1 ? 0 : ((targetZ ?? 0) - z0) / (z1 - z0);

  /// lerp
  final ax = coord0[0], ay = coord0[1];
  return Vector2(ax + t * (coord1[0] - ax), ay + t * (coord1[1] - ay));
}
