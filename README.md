# web_mercator

Dart implementation of the uber [@math.gl/web-mercator](https://github.com/uber-web/math.gl/tree/master/modules/web-mercator) javascript module.

## Getting Started

See the `tests` for in-depth implementation methods.
Here is a basic example using the `fitBounds` factory with end user device informations:
```dart
import 'package:web_mercator/web_mercator.dart' show MercatorViewport

final viewport = MercatorViewport.fitBounds(width: deviceWidth, height: deviceHeight, bounds: northEastSoutWest);
```

With that viewport, you can now project coordinates passing a `Vector` to the `project` method. Using a `Vector2` will result in a flat projection (onto a sphere) while a `Vector3` will consider the z component as an altidude expressed in meters.

The `example/` folder contains a sample app displaying the boudary of Martinique.