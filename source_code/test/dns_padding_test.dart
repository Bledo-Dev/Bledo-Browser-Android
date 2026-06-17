import 'package:flutter_test/flutter_test.dart';
import 'package:bledo/doh_proxy.dart';
import 'dart:typed_data';

void main() {
  test('DNS query should be padded to 128 byte boundary', () {
    final proxy = DohProxyServer();
    
    // Test with a short domain
    Uint8List query1 = proxy.constructDnsQuery("google.com");
    expect(query1.length % 128, 0);
    expect(query1.length, 128);

    // Test with a longer domain
    Uint8List query2 = proxy.constructDnsQuery("this.is.a.very.long.domain.name.example.com");
    expect(query2.length % 128, 0);
    // Even a longer domain should fit in 128 bytes unless it's extremely long
    expect(query2.length, 128);

    // Test with an extremely long domain to force 256 bytes
    String longDomain = "a" * 100 + ".com";
    Uint8List query3 = proxy.constructDnsQuery(longDomain);
    expect(query3.length % 128, 0);
    expect(query3.length, 256);
  });
}
