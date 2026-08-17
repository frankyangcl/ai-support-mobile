import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../errors/api_exception.dart';

typedef RequestHeadersProvider = FutureOr<Map<String, String>> Function();
typedef StreamingClientFactory = http.Client Function();

class ApiStreamResponse {
  const ApiStreamResponse({required this.bytes, required this.cancel});

  final Stream<List<int>> bytes;
  final Future<void> Function() cancel;
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
    this.headersProvider,
    StreamingClientFactory? streamingClientFactory,
    this.onUnauthorized,
  })  : _baseUri = Uri.parse(baseUrl),
        _client = client ?? http.Client(),
        _streamingClientFactory = streamingClientFactory ?? http.Client.new;

  final Uri _baseUri;
  final http.Client _client;
  final Duration timeout;
  final RequestHeadersProvider? headersProvider;
  final StreamingClientFactory _streamingClientFactory;
  final FutureOr<void> Function()? onUnauthorized;

  Future<Map<String, Object?>> getJson(String path) async {
    final response = await _send(
      () async => _client.get(_resolve(path), headers: await _headers()),
    );
    return _decodeObject(response);
  }

  Future<Map<String, Object?>> deleteJson(String path) async {
    final response = await _send(
      () async => _client.delete(_resolve(path), headers: await _headers()),
    );
    if (response.bodyBytes.isEmpty) return const <String, Object?>{};
    return _decodeObject(response);
  }

  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    required String fieldName,
    required String filename,
    required List<int> bytes,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _resolve(path))
        ..headers.addAll(await _headers())
        ..files.add(http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: filename,
        ));
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) await onUnauthorized?.call();
        throw ApiException(
          _readErrorMessage(response.body),
          type: ApiErrorType.server,
          statusCode: response.statusCode,
        );
      }
      return _decodeObject(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'The request timed out. Please try again.',
        type: ApiErrorType.timeout,
      );
    } on SocketException {
      throw const ApiException(
        'Unable to connect to the server.',
        type: ApiErrorType.network,
      );
    } on http.ClientException {
      throw const ApiException(
        'Unable to connect to the server.',
        type: ApiErrorType.network,
      );
    }
  }

  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> body,
  }) async {
    final response = await _send(
      () async => _client.post(
        _resolve(path),
        headers: await _headers(json: true),
        body: jsonEncode(body),
      ),
    );
    return _decodeObject(response);
  }

  Future<Map<String, Object?>> patchJson(
    String path, {
    required Map<String, Object?> body,
  }) async {
    final response = await _send(
      () async => _client.patch(
        _resolve(path),
        headers: await _headers(json: true),
        body: jsonEncode(body),
      ),
    );
    return _decodeObject(response);
  }

  Future<ApiStreamResponse> postJsonStream(
    String path, {
    required Map<String, Object?> body,
  }) async {
    final client = _streamingClientFactory();
    try {
      final request = http.Request('POST', _resolve(path))
        ..headers.addAll(await _headers(json: true))
        ..headers['Accept'] = 'text/event-stream'
        ..body = jsonEncode(body);
      final response = await client.send(request).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) await onUnauthorized?.call();
        final responseBody = await response.stream.bytesToString();
        client.close();
        throw ApiException(
          _readErrorMessage(responseBody),
          type: ApiErrorType.server,
          statusCode: response.statusCode,
        );
      }

      var cancelled = false;
      Future<void> cancel() async {
        if (cancelled) return;
        cancelled = true;
        client.close();
      }

      return ApiStreamResponse(bytes: response.stream, cancel: cancel);
    } on ApiException {
      client.close();
      rethrow;
    } on TimeoutException {
      client.close();
      throw const ApiException(
        'The request timed out. Please try again.',
        type: ApiErrorType.timeout,
      );
    } on SocketException {
      client.close();
      throw const ApiException(
        'Unable to connect to the server.',
        type: ApiErrorType.network,
      );
    } on http.ClientException {
      client.close();
      throw const ApiException(
        'Unable to connect to the server.',
        type: ApiErrorType.network,
      );
    }
  }

  Uri _resolve(String path) {
    final base = _baseUri.toString().replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base${path.startsWith('/') ? path : '/$path'}');
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final additional =
        await headersProvider?.call() ?? const <String, String>{};
    return {if (json) 'Content-Type': 'application/json', ...additional};
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) await onUnauthorized?.call();
        throw ApiException(
          _readErrorMessage(response.body),
          type: ApiErrorType.server,
          statusCode: response.statusCode,
        );
      }
      return response;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'The request timed out. Please try again.',
        type: ApiErrorType.timeout,
      );
    } on SocketException {
      throw const ApiException(
        'Unable to connect to the server.',
        type: ApiErrorType.network,
      );
    } on http.ClientException {
      throw const ApiException(
        'Unable to connect to the server.',
        type: ApiErrorType.network,
      );
    }
  }

  Map<String, Object?> _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return decoded.cast<String, Object?>();
    } on FormatException {
      throw const ApiException(
        'The server returned an invalid response.',
        type: ApiErrorType.invalidResponse,
      );
    }
  }

  String _readErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.isNotEmpty) return error;
      }
    } on FormatException {
      // Use the stable fallback below.
    }
    return 'The server could not complete the request.';
  }
}
