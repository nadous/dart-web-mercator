import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_mercator/web_mercator.dart';
import 'package:vector_math/vector_math_64.dart';

import 'viewport_samples.dart' as vp_samples;

const DISTANCE_TOLERANCE = .0005;
const DISTANCE_TOLERANCE_PIXELS = 2;
const DISTANCE_SCALE_TEST_ZOOM = 12;

Map<String, dynamic> getDiff(Map<int, num> value, Map<int, num> baseValue, num scale) {
  final errorPixels = value.map((i, v) => MapEntry(i, ((v - baseValue[i]) * scale).abs()));
  final error = value.map((i, v) => (MapEntry(i, (v - baseValue[i]).abs() / min(v.abs(), baseValue[i].abs()))));

  String message = 'off by (';
  message += errorPixels.values.map((d) => d.toStringAsFixed(3)).join(', ');
  message += ') pixels, (';
  message += error.values.map((d) => '${(d * 100).toStringAsFixed(3)}%').join(', ');
  message += ')';

  return {'errorPixels': errorPixels, 'error': error, 'message': message};
}

void main() {
  group('testing utils', () {
    test('log2 implementation', () {
      expect(log2(5), 2.321928094887362);
      expect(log2(10), 3.3219280948873626);
    });

    test('lngLatToWorld', () {
      expect(() => lngLatToWorld(38, -122), throwsAssertionError);
      expect(lngLatToWorld(-122, 38), Vector2(82.4888888888889, 314.50692551385134));
    });

    test('getDistanceScales', () {
      for (final vpd in vp_samples.data) {
        final distanceScales = getDistanceScales(vpd.lng, vpd.lat);

        final metersPerUnit = distanceScales['metersPerUnit'];
        final unitsPerMeter = distanceScales['unitsPerMeter'];
        final degreesPerUnit = distanceScales['degreesPerUnit'];
        final unitsPerDegree = distanceScales['unitsPerDegree'];

        expect((metersPerUnit[0] * unitsPerMeter[0]).toStringAsFixed(11), '1.00000000000');
        expect((metersPerUnit[1] * unitsPerMeter[1]).toStringAsFixed(11), '1.00000000000');
        expect((metersPerUnit[2] * unitsPerMeter[2]).toStringAsFixed(11), '1.00000000000');

        expect((degreesPerUnit[0] * unitsPerDegree[0]).toStringAsFixed(11), '1.00000000000');
        expect((degreesPerUnit[1] * unitsPerDegree[1]).toStringAsFixed(11), '1.00000000000');
        expect((degreesPerUnit[2] * unitsPerDegree[2]).toStringAsFixed(11), '1.00000000000');
      }
    });

    test('getDistanceScales#unitsPerDegree', () {
      final scale = pow(2, DISTANCE_SCALE_TEST_ZOOM);
      const z = 1000;

      for (final vpd in vp_samples.data) {
        print('\n$vpd');

        final lng = vpd.lng, lat = vpd.lat;

        final distanceScales = getDistanceScales(lng, lat, highPrecision: true);
        final unitsPerDegree = distanceScales['unitsPerDegree'];
        final unitsPerDegree2 = distanceScales['unitsPerDegree2'];

        /// Test degree offsets
        for (final delta in [.001, .01, .05, .1, .3]) {
          print('> R = $delta degrees');

          /// To pixels
          final coords = [delta * unitsPerDegree[0], delta * unitsPerDegree[1], z * unitsPerDegree[2]];
          final coordsAdjusted = [
            delta * (unitsPerDegree[0] + unitsPerDegree2[0] * delta),
            delta * (unitsPerDegree[1] + unitsPerDegree2[1] * delta),
            z * (unitsPerDegree[2] + unitsPerDegree2[2] * delta),
          ];

          final pt = [lng + delta, lat + delta];
          final realCoords = [
            lngLatToWorld(pt[0], pt[1])[0] - lngLatToWorld(lng, lat)[0],
            lngLatToWorld(pt[0], pt[1])[1] - lngLatToWorld(lng, lat)[1],
            z * getDistanceScales(pt[0], pt[1])['unitsPerMeter'][2],
          ];

          final diff = getDiff(coords.asMap(), realCoords.asMap(), scale);
          final diffAdjusted = getDiff(coordsAdjusted.asMap(), realCoords.asMap(), scale);

          print('  unadjusted ${diff['message']}\n  adjusted ${diffAdjusted['message']}');

          diffAdjusted['error'].values.forEach((v) => expect(v, lessThan(DISTANCE_TOLERANCE)));
          diffAdjusted['errorPixels'].values.forEach((v) => expect(v, lessThan(DISTANCE_TOLERANCE_PIXELS)));
        }
      }
    });

    test('getDistanceScales#unitsPerMeter', () {
      final scale = pow(2, DISTANCE_SCALE_TEST_ZOOM);
      const z = 1000;

      for (final vpd in vp_samples.data) {
        print('\n$vpd');

        final lng = vpd.lng, lat = vpd.lat;

        final distanceScales = getDistanceScales(lng, lat, highPrecision: true);
        final unitsPerMeter = distanceScales['unitsPerMeter'];
        final unitsPerMeter2 = distanceScales['unitsPerMeter2'];

        /// Test meters offsets
        for (final delta in [10, 100, 1000, 5000, 10000, 30000]) {
          print('> R = $delta meters');

          /// To pixels
          final coords = [delta * unitsPerMeter[0], delta * unitsPerMeter[1], z * unitsPerMeter[2]];
          final coordsAdjusted = [
            delta * (unitsPerMeter[0] + unitsPerMeter2[0] * delta),
            delta * (unitsPerMeter[1] + unitsPerMeter2[1] * delta),
            z * (unitsPerMeter[2] + unitsPerMeter2[2] * delta),
          ];

          final pt = destination(lng, lat, distance: (delta * .001) * sqrt(2), bearing: 45);
          final realCoords = [
            lngLatToWorld(pt[0], pt[1])[0] - lngLatToWorld(lng, lat)[0],
            lngLatToWorld(pt[0], pt[1])[1] - lngLatToWorld(lng, lat)[1],
            z * getDistanceScales(pt[0], pt[1])['unitsPerMeter'][2]
          ];

          final diff = getDiff(coords.asMap(), realCoords.asMap(), scale);
          final diffAdjusted = getDiff(coordsAdjusted.asMap(), realCoords.asMap(), scale);

          print('  unadjusted ${diff['message']}\n  adjusted ${diffAdjusted['message']}');

          diffAdjusted['error'].values.forEach((v) => expect(v, lessThan(DISTANCE_TOLERANCE)));
          diffAdjusted['errorPixels'].values.forEach((v) => expect(v, lessThan(DISTANCE_TOLERANCE_PIXELS)));
        }
      }
    });

    test('addMetersToLngLat', () {
      for (final vpd in vp_samples.data) {
        print('\n$vpd');

        final lng = vpd.lng, lat = vpd.lat;

        // Test meters offsets
        for (final delta in [10.0, 100.0, 1000.0, 5000.0]) {
          print('> R = $delta meters');

          final destPt = destination(lng, lat, distance: (delta * .001) * sqrt(2), bearing: 45);
          final pt = Vector3(destPt[0], destPt[1], delta);
          final result = addMetersToLngLat(Vector3(lng, lat, 0), Vector3.all(delta));

          print('comparing: $result with $pt');
          // -122.37309574680621,37.79495261124374,5000,  with -122.37309604668772,37.794952343211726,5000
          // -122.37309574680621,37.79495261124374,5000.0 with -122.37309604668772,37.79495234321173,5000.0
          result.storage.asMap().forEach((i, v) => expect(v, closeTo(pt[i], 1e-7)));
        }
      }
    });

    test('getMeterZoom', () {
      for (final lat in [.0, 37.5, 75.0]) {
        final zoom = getMeterZoom(lat);
        final scale = zoomToScale(zoom);

        final unitsPerMeter = getDistanceScales(0, lat)['unitsPerMeter'];
        unitsPerMeter.map((v) => v * scale).forEach((v) => expect(v.toStringAsFixed(11), '1.00000000000'));
      }
    });
  });
}
