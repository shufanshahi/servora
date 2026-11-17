import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Replaces the network layer in tests. Queue replies with [reply], [replyRaw] or
/// [fail]; every request that was made is kept in [requests].
class FakeHttpAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<FutureOr<ResponseBody> Function(RequestOptions)> _queue = [];

  RequestOptions get lastRequest => requests.last;

  /// Replies with a JSON body and the given status.
  void reply(int status, Object? json) {
    _queue.add(
      (_) => ResponseBody.fromString(
        jsonEncode(json),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
  }

  /// Replies with an arbitrary body (for example HTML from a proxy).
  void replyRaw(int status, String body, {String contentType = 'text/html'}) {
    _queue.add(
      (_) => ResponseBody.fromString(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: [contentType],
        },
      ),
    );
  }

  /// Makes the next request fail the way dio reports transport problems.
  void fail(DioException Function(RequestOptions options) build) {
    _queue.add((options) => throw build(options));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_queue.isEmpty) {
      throw StateError('FakeHttpAdapter: no reply queued for ${options.uri}');
    }
    return _queue.removeAt(0)(options);
  }

  @override
  void close({bool force = false}) {}
}
