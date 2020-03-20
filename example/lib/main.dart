import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:web_mercator/web_mercator.dart' show MercatorViewport, bbox;

const bearingDragFactor = .25;
const pitchDragFactor = .5;
const scaleDrageFactor = .5;

void main() => runApp(MyApp());

num mapRange(num value, num minIn, num maxIn, num minOut, num maxOut) {
  return (value - minIn) / (minIn - maxIn) * (maxOut - minIn) + minIn;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hello Mercator',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _scaling = false;
  double _pitch = .0, _bearing = .0, _zoom = .0;
  Offset _lastFocalPoint;
  MercatorViewport _viewport;
  Future<Map<String, List>> _martinique;

  @override
  void initState() {
    _martinique = _parsePolygons(context, 'json/martinique_poly.json');
    super.initState();
  }

  Future<Map<String, List>> _parsePolygons(BuildContext context, String file) async {
    final data = await DefaultAssetBundle.of(context).loadString(file);
    final dynamic map = await json.decode(data);

    List<List<Vector2>> polygons = [];
    List<List<double>> points = [];

    for (final polygon in map['geometries'][0]['coordinates']) {
      polygons.add([]);
      for (final p in polygon[0]) // don't mind holes
      {
        polygons.last.add(Vector2(p[0], p[1]));
        points.add([p[0], p[1]]);
      }
    }

    return {'polygons': polygons, 'bounds': bbox(points)};
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (scale) {
        _lastFocalPoint = scale.focalPoint;
        _zoom = _viewport.zoom;
        _scaling = true;
      },
      onScaleEnd: (scale) {
        _scaling = false;
      },
      onScaleUpdate: (scale) {
        if (_scaling && _viewport != null) {
          final focalPoint = scale.focalPoint;
          if (_lastFocalPoint == null) {
            _lastFocalPoint = focalPoint;
            return;
          }

          final size = MediaQuery.of(context).size;
          final deltaOffset = focalPoint - _lastFocalPoint;

          _pitch -= deltaOffset.dy * pitchDragFactor;
          if (focalPoint.dy > size.height * .5) {
            _bearing += deltaOffset.dx * bearingDragFactor;
          } else {
            _bearing -= deltaOffset.dx * bearingDragFactor;
          }

          double zoom = _zoom * scale.scale;
          zoom = max(7, min(zoom, 15));

          setState(() {
            _viewport = MercatorViewport.copyWith(
              _viewport,
              pitch: _pitch,
              bearing: _bearing,
              zoom: zoom,
            );
          });

          _lastFocalPoint = focalPoint;
        }
      },
      child: FutureBuilder<Map<String, List>>(
        future: _martinique,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final size = MediaQuery.of(context).size;
            if (_viewport == null) {
              _viewport = MercatorViewport.fitBounds(
                width: size.width,
                height: size.height,
                bounds: snapshot.data['bounds'],
                padding: 20,
              );
            }

            return CustomPaint(
              painter: PolygonPainter(_viewport, snapshot.data['polygons']),
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class PolygonPainter extends CustomPainter {
  final MercatorViewport viewport;
  final List<List<Vector2>> polygons;

  PolygonPainter(this.viewport, this.polygons);

  void _paintPolygon(Canvas canvas, List<Vector2> polygon) {
    for (int i = 0; i < polygon.length - 1; i++) {
      final projFrom = viewport.project(polygon[i]) as Vector2;
      final projTo = viewport.project(polygon[i + 1]) as Vector2;

      canvas.drawLine(
          Offset(projFrom[0], projFrom[1]),
          Offset(projTo[0], projTo[1]),
          Paint()
            ..color = Color.fromARGB(255, 255, 255, 255)
            ..style = PaintingStyle.stroke);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (viewport == null || polygons == null || polygons.isEmpty) {
      return;
    }

    for (final polygon in polygons) {
      _paintPolygon(canvas, polygon);
    }
  }

  @override
  bool shouldRepaint(PolygonPainter oldDelegate) => true; // oldDelegate.viewport.pitch != viewport.pitch;
}
