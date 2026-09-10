import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class PassportRequest {
  const PassportRequest(this.options, this.body);
  final RequestOptions options;
  final String body;
  Map<String, String> get form => Uri.splitQueryString(body);
  String get cookie => options.headers['Cookie']?.toString() ?? '';
}

class PassportAdapter implements HttpClientAdapter {
  PassportAdapter(this.respond);
  final FutureOr<ResponseBody> Function(PassportRequest) respond;
  final requests = <PassportRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (stream != null) {
      await for (final chunk in stream) {
        bytes.addAll(chunk);
      }
    }
    final request = PassportRequest(options, utf8.decode(bytes));
    requests.add(request);
    return respond(request);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody passportResponse(
  String body, {
  int status = 200,
  List<String>? cookies,
}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
    if (cookies != null) 'set-cookie': cookies,
  },
);

ResponseBody passportImageResponse(List<int> bytes) => ResponseBody.fromBytes(
  bytes,
  200,
  headers: {
    Headers.contentTypeHeader: ['application/octet-stream'],
  },
);
