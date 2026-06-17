import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class DohProxyServer {
  ServerSocket? _server;
  int port = 0;
  final String dohUrl = "https://cloudflare-dns.com/dns-query";
  final Dio _dio = Dio();

  Future<int> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    port = _server!.port;
    _server!.listen(_handleConnection);
    debugPrint("DohProxyServer started on port $port");
    return port;
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    debugPrint("DohProxyServer stopped");
  }

  void _handleConnection(Socket client) async {
    final iterator = StreamIterator(client);
    final buffer = BytesBuilder();
    
    Future<Uint8List> readExactly(int len) async {
      while (buffer.length < len) {
        if (!await iterator.moveNext()) throw Exception("Closed");
        buffer.add(iterator.current);
      }
      final all = buffer.takeBytes();
      if (all.length > len) {
        buffer.add(all.sublist(len));
      }
      return all.sublist(0, len);
    }

    try {
      // 1. Greeting
      final greeting = await readExactly(2);
      if (greeting[0] != 0x05) throw Exception("Not SOCKS5");
      await readExactly(greeting[1]);
      client.add([0x05, 0x00]);

      // 2. Request
      final header = await readExactly(4);
      if (header[1] != 0x01) {
        client.add([0x05, 0x07, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
        client.destroy();
        return;
      }

      String host;
      if (header[3] == 0x01) {
        final addr = await readExactly(4);
        host = addr.join('.');
      } else if (header[3] == 0x03) {
        final len = (await readExactly(1))[0];
        host = String.fromCharCodes(await readExactly(len));
      } else {
        client.add([0x05, 0x08, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
        client.destroy();
        return;
      }

      final portBytes = await readExactly(2);
      final targetPort = (portBytes[0] << 8) | portBytes[1];

      // 3. Resolve
      InternetAddress targetAddr;
      try {
        targetAddr = await _resolveHost(host);
      } catch (e) {
        client.add([0x05, 0x04, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
        client.destroy();
        return;
      }

      // 4. Connect
      final target = await Socket.connect(targetAddr, targetPort, timeout: const Duration(seconds: 10));
      client.add([0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);

      // 5. Relay
      if (buffer.length > 0) {
        target.add(buffer.takeBytes());
      }
      
      // Relay the rest of the stream from iterator
      Future.wait([
        _relayStream(iterator, target),
        _relaySocket(target, client)
      ]).then((_) {
        client.destroy();
        target.destroy();
      }).catchError((_) {
        client.destroy();
        target.destroy();
      });

    } catch (e) {
      client.destroy();
    }
  }

  Future<void> _relayStream(StreamIterator<Uint8List> iterator, Socket target) async {
    try {
      while (await iterator.moveNext()) {
        target.add(iterator.current);
      }
    } catch (_) {}
  }

  Future<void> _relaySocket(Socket source, Socket destination) async {
    try {
      await for (final data in source) {
        destination.add(data);
      }
    } catch (_) {}
  }

  @visibleForTesting
  Uint8List constructDnsQuery(String host) {
    BytesBuilder builder = BytesBuilder();
    builder.add([0x00, 0x00, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]);
    for (var part in host.split('.')) {
      builder.addByte(part.length);
      builder.add(part.codeUnits);
    }
    builder.addByte(0);
    builder.add([0x00, 0x01, 0x00, 0x01]);

    int currentSize = builder.length + 11;
    int targetSize = ((currentSize + 4 + 127) ~/ 128) * 128;
    int paddingLen = targetSize - (currentSize + 4);

    builder.add([0x00, 0x00, 0x29, 0x10, 0x00, 0x00, 0x00, 0x00]);
    int totalDataLen = paddingLen + 4;
    builder.addByte((totalDataLen >> 8) & 0xFF);
    builder.addByte(totalDataLen & 0xFF);
    builder.add([0x00, 0x0C]);
    builder.addByte((paddingLen >> 8) & 0xFF);
    builder.addByte(paddingLen & 0xFF);
    builder.add(Uint8List(paddingLen));

    return builder.toBytes();
  }

  Future<InternetAddress> _resolveHost(String host) async {
    try {
      final query = constructDnsQuery(host);
      final response = await _dio.post(
        dohUrl,
        data: query,
        options: Options(
          headers: {
            "Content-Type": "application/dns-message",
            "Accept": "application/dns-message",
          },
          responseType: ResponseType.bytes,
        ),
      );
      return _parseDnsResponse(Uint8List.fromList(response.data));
    } catch (e) {
      debugPrint("DohProxy: DoH error: $e");
      final addrs = await InternetAddress.lookup(host);
      return addrs.first;
    }
  }

  InternetAddress _parseDnsResponse(Uint8List data) {
    int pos = 12;
    int qdCount = (data[4] << 8) | data[5];
    for (int i = 0; i < qdCount; i++) {
      while (data[pos] != 0) {
        if ((data[pos] & 0xC0) == 0xC0) { pos += 2; break; }
        pos += data[pos] + 1;
      }
      if (data[pos] == 0) pos++;
      pos += 4;
    }
    int anCount = (data[6] << 8) | data[7];
    for (int i = 0; i < anCount; i++) {
      while (data[pos] != 0) {
        if ((data[pos] & 0xC0) == 0xC0) { pos += 2; break; }
        pos += data[pos] + 1;
        if (data[pos] == 0) { pos++; break; }
      }
      int type = (data[pos] << 8) | data[pos + 1];
      int rdLen = (data[pos + 8] << 8) | data[pos + 9];
      pos += 10;

      if (type == 5) { // CNAME
        String cname = _parseName(data, pos, rdLen);
        if (_isTracker(cname)) {
          debugPrint("DohProxy: Blocked CNAME tracker: $cname");
          throw Exception("Blocked tracker CNAME");
        }
      }

      if (type == 1 && rdLen == 4) { // Type A
        return InternetAddress("${data[pos]}.${data[pos+1]}.${data[pos+2]}.${data[pos+3]}");
      }
      pos += rdLen;
    }

    throw Exception("No A record");
  }

  String _parseName(Uint8List data, int start, int len) {
    // Very simple name parser for CNAME data
    int pos = start;
    List<String> parts = [];
    while (pos < start + len) {
      int b = data[pos];
      if (b == 0) break;
      if ((b & 0xC0) == 0xC0) {
        // Pointer - for simplicity in CNAME data we'll just stop here 
        // as full pointer following in RDATA is complex
        break;
      }
      parts.add(String.fromCharCodes(data.sublist(pos + 1, pos + 1 + b)));
      pos += b + 1;
    }
    return parts.join('.');
  }

  bool _isTracker(String host) {
    final lower = host.toLowerCase();
    return lower.contains("track") || 
           lower.contains("telemetry") || 
           lower.contains("analytics") || 
           lower.contains("metrics") ||
           lower.contains("doubleclick") ||
           lower.contains("google-analytics");
  }
}
