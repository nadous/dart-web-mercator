import 'package:flutter_test/flutter_test.dart';

import 'package:web_mercator/web_mercator.dart';

void main() {
  test('test log2 implementation', () {
    expect(log2(5), 2.321928094887362);
    expect(log2(10), 3.3219280948873626);
  });

  test('test viewport construction', () {});
}
