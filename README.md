# web_mercator

Dart implementation of the uber [@math.gl/web-mercator](https://github.com/uber-web/math.gl/tree/master/modules/web-mercator) javascript module.

## Getting Started

See the `tests` for in-depth implementation methods.
Here is a basic example using the `fitBounds` factory with end user device informations:
```dart
import 'package:web_mercator/viewport.dart';

final viewport = Viewport.fitBounds(width: deviceWidth, height: deviceHeight, bounds: northEastSoutWest);
```

With that viewport, you can now project coordinates.