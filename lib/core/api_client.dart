import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

/// Error devuelto por la API con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Cliente HTTP con el token JWT y manejo de errores en español.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? token;

  /// Se llama cuando el servidor responde 401 (sesión expirada).
  void Function()? onUnauthorized;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    final params = <String, String>{
      for (final e in (query ?? const <String, dynamic>{}).entries)
        if (e.value != null) e.key: e.value.toString(),
    };
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _client.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Object? body, Duration? timeout]) => _send(
        () => _client.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})),
        timeout: timeout,
      );

  Future<dynamic> put(String path, Object body) =>
      _send(() => _client.put(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> patch(String path, Object body) =>
      _send(() => _client.patch(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> delete(String path, [Object? body]) => _send(
        () => _client.delete(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body)),
      );

  Future<dynamic> _send(Future<http.Response> Function() request, {Duration? timeout}) async {
    http.Response response;
    try {
      response = await request().timeout(timeout ?? AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder. Intenta de nuevo.');
    } on SocketException {
      throw ApiException('No hay conexión con el servidor (${AppConfig.apiUrl}).');
    } on http.ClientException {
      throw ApiException('No hay conexión con el servidor (${AppConfig.apiUrl}).');
    }

    final dynamic body = response.body.isEmpty ? null : _tryDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    if (response.statusCode == 401 && token != null) onUnauthorized?.call();

    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final details = map['details'] is Map<String, dynamic> ? map['details'] as Map<String, dynamic> : null;
    var message = (map['error'] as String?) ?? 'Ocurrió un error (${response.statusCode})';
    if (details != null && details.isNotEmpty) message = details.values.first.toString();
    throw ApiException(message, statusCode: response.statusCode, details: details);
  }

  dynamic _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }
}
