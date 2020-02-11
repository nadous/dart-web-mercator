import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:web_mercator/web_mercator.dart' show MercatorViewport, bbox;

void main() => runApp(MyApp());

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
  dynamic _parsePolygons(BuildContext context, String file) async {
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

    return {'polygons': polygons, 'boundary': bbox(points)};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _parsePolygons(context, 'json/martinique_poly.json'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return CustomPaint(
              painter: PolygonPainter(
            snapshot.data['polygons'],
            bounds: snapshot.data['boundary'],
            size: MediaQuery.of(context).size,
          ));
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}

class PolygonPainter extends CustomPainter {
  final Size size;
  final List<double> bounds;
  final List<List<Vector2>> polygons;

  PolygonPainter(this.polygons, {this.bounds, this.size});

  void _paintPolygon(Canvas canvas, MercatorViewport viewport, List<Vector2> polygon) {
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
    if (polygons == null || polygons.isEmpty) {
      return;
    }

    final viewport = MercatorViewport.fitBounds(
      width: size.width,
      height: size.height,
      bounds: bounds,
      padding: 20,
    );

    for (final polygon in polygons) {
      _paintPolygon(canvas, viewport, polygon);
    }
  }

  @override
  bool shouldRepaint(PolygonPainter oldDelegate) => true;
}
