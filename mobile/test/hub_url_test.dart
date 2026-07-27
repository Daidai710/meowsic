import 'package:flutter_test/flutter_test.dart';
import 'package:music_hub_app/util/hub_url.dart';

void main() {
  test('extract full url', () {
    expect(extractHubUrl('http://192.168.0.8:8787'), 'http://192.168.0.8:8787');
    expect(extractHubUrl('http://192.168.0.8:8787/'), 'http://192.168.0.8:8787');
  });

  test('extract host port', () {
    expect(extractHubUrl('192.168.0.8:8787'), 'http://192.168.0.8:8787');
    expect(extractHubUrl('192.168.0.8'), 'http://192.168.0.8:8787');
  });

  test('extract from noise', () {
    expect(
      extractHubUrl('打开这个 http://192.168.0.8:8787 即可'),
      'http://192.168.0.8:8787',
    );
  });
}
