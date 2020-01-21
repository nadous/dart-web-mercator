# web_mercator

Dart implementation of the uber [@math.gl/web-mercator](https://github.com/uber-web/math.gl/tree/master/modules/web-mercator) javascript module.

## Getting Started

Here is a basic example using the `fitBounds` factory with end user device informations:
```dart
import 'package:web_mercator/viewport.dart';

final viewport = Viewport.fitBounds(width: screenWidth, height: screenHeight, lat: )
```