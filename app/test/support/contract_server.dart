import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yaml/yaml.dart';

/// A fake server built from `documentation/api/openapi.yaml`.
///
/// It answers only requests the contract declares (method, path, query parameters, bearer token,
/// request body checked against the request schema) and builds its answers from the response
/// schemas, so a repository that drifts from the contract fails here instead of in production.
/// A test can replace the answer of one operation with [respondWith].
class ContractServer {
  ContractServer._(this._spec);

  factory ContractServer.load() {
    final file = File('../documentation/api/openapi.yaml');
    return ContractServer._(_plain(loadYaml(file.readAsStringSync())));
  }

  final Map<String, Object?> _spec;
  final Map<String, _Answer> _overrides = {};

  /// Every request received, as `METHOD /path`, in order.
  final List<String> requests = [];

  /// The query string of the last request to each operation id.
  final Map<String, String> lastQuery = {};

  /// The JSON body of the last request to each operation id.
  final Map<String, Object?> lastBody = {};

  http.Client get client => MockClient(_handle);

  /// Makes [operationId] answer [status] with [body] instead of the schema-built answer.
  void respondWith(String operationId, int status, [Object? body]) {
    _overrides[operationId] = _Answer(status, body);
  }

  /// Values of the enum schema [name], for tests that cover every one.
  List<String> enumValues(String name) {
    final schema = _schemas[name];
    final values = schema is Map ? schema['enum'] : null;
    if (values is! List) {
      throw StateError('$name is not an enum in the contract');
    }
    return values.cast<String>();
  }

  Map<String, Object?> get _schemas =>
      ((_spec['components'] as Map)['schemas'] as Map).cast<String, Object?>();

  Future<http.Response> _handle(http.Request request) async {
    final method = request.method.toLowerCase();
    final path = request.url.path;
    requests.add('${request.method} $path');
    final match = _find(method, path);
    if (match == null) {
      throw StateError('Request not in the contract: ${request.method} $path');
    }
    final operation = match.operation;
    final id = operation['operationId'] as String;
    _checkQuery(request, operation);
    lastQuery[id] = request.url.query;
    if (request.headers['Authorization'] != 'Bearer test-token') {
      return _json(401, {'code': 'unauthorized', 'message': 'no token'});
    }
    _checkBody(request, operation, id);
    final override = _overrides[id];
    if (override != null) {
      return _json(override.status, override.body);
    }
    final responses = (operation['responses'] as Map).cast<String, Object?>();
    final status =
        (responses.keys.where((s) => s.startsWith('2')).toList()..sort()).first;
    final content = (responses[status] as Map)['content'];
    if (content is! Map) {
      return http.Response('', int.parse(status));
    }
    final schema = ((content['application/json'] as Map)['schema']);
    return _json(int.parse(status), _sample(schema));
  }

  _Match? _find(String method, String path) {
    final paths = (_spec['paths'] as Map).cast<String, Object?>();
    for (final entry in paths.entries) {
      final pattern = RegExp(
        '^${entry.key.replaceAllMapped(RegExp(r'\{[^}]+\}'), (_) => '[^/]+')}\$',
      );
      final operations = entry.value as Map;
      if (pattern.hasMatch(path) && operations[method] is Map) {
        return _Match((operations[method] as Map).cast<String, Object?>());
      }
    }
    return null;
  }

  void _checkQuery(http.Request request, Map<String, Object?> operation) {
    final declared = <String>{
      for (final parameter in (operation['parameters'] as List? ?? const []))
        if ((parameter as Map)['in'] == 'query') parameter['name'] as String,
    };
    for (final name in request.url.queryParameters.keys) {
      if (!declared.contains(name)) {
        throw StateError(
          'Query parameter $name is not in the contract for '
          '${operation['operationId']}',
        );
      }
    }
  }

  void _checkBody(
    http.Request request,
    Map<String, Object?> operation,
    String id,
  ) {
    final declared = operation['requestBody'];
    if (declared == null) {
      if (request.body.isNotEmpty) {
        throw StateError('$id sends a body the contract does not declare');
      }
      return;
    }
    final schema =
        (((declared as Map)['content'] as Map)['application/json']
            as Map)['schema'];
    if (request.body.isEmpty) {
      throw StateError('$id must send a JSON body');
    }
    final body = jsonDecode(request.body);
    lastBody[id] = body;
    final problem = _validate(schema, body, id);
    if (problem != null) {
      throw StateError('Request body of $id breaks the contract: $problem');
    }
  }

  Object? _resolve(Object? schema) {
    var current = schema;
    while (current is Map) {
      final ref = current[r'$ref'];
      if (ref is String) {
        current = _schemas[ref.split('/').last];
      } else if (current['allOf'] is List) {
        current = (current['allOf'] as List).first;
      } else {
        break;
      }
    }
    return current;
  }

  String? _validate(Object? rawSchema, Object? value, String at) {
    final schema = _resolve(rawSchema);
    if (schema is! Map) {
      return null;
    }
    final types = _types(schema);
    if (value == null) {
      return types.contains('null') ? null : '$at is null';
    }
    final enumValues = schema['enum'];
    if (enumValues is List && !enumValues.contains(value)) {
      return '$at: $value is not one of $enumValues';
    }
    final pattern = schema['pattern'];
    if (pattern is String && value is String) {
      if (!RegExp(pattern).hasMatch(value)) {
        return '$at: "$value" does not match $pattern';
      }
    }
    if (types.contains('string') && value is! String) {
      return '$at is not a string';
    }
    if (types.contains('integer') && value is! int) {
      return '$at is not an integer';
    }
    if (types.contains('boolean') && value is! bool) {
      return '$at is not a boolean';
    }
    if (types.contains('array') && value is List) {
      for (final (index, item) in value.indexed) {
        final problem = _validate(schema['items'], item, '$at[$index]');
        if (problem != null) {
          return problem;
        }
      }
    }
    if (types.contains('object') && value is Map) {
      final properties = (schema['properties'] as Map? ?? const {});
      for (final required in (schema['required'] as List? ?? const [])) {
        if (!value.containsKey(required)) {
          return '$at lacks required $required';
        }
      }
      final required = (schema['required'] as List? ?? const []);
      for (final entry in value.entries) {
        // The generated client writes an unset optional field as null; the services read it as absent.
        if (entry.value == null && !required.contains(entry.key)) {
          continue;
        }
        if (!properties.containsKey(entry.key)) {
          if (schema['additionalProperties'] == null) {
            return '$at has unknown property ${entry.key}';
          }
          continue;
        }
        final problem = _validate(
          properties[entry.key],
          entry.value,
          '$at.${entry.key}',
        );
        if (problem != null) {
          return problem;
        }
      }
    }
    return null;
  }

  List<String> _types(Map schema) {
    final type = schema['type'];
    if (type is String) {
      return [type];
    }
    return type is List ? type.cast<String>() : const [];
  }

  Object? _sample(Object? rawSchema) {
    final schema = _resolve(rawSchema);
    if (schema is! Map) {
      return null;
    }
    final enumValues = schema['enum'];
    if (enumValues is List) {
      return enumValues.first;
    }
    final type = _types(
      schema,
    ).firstWhere((t) => t != 'null', orElse: () => '');
    switch (type) {
      case 'object':
        final properties = (schema['properties'] as Map? ?? const {});
        return {
          for (final entry in properties.entries)
            entry.key: _sample(entry.value),
        };
      case 'array':
        return [_sample(schema['items'])];
      case 'integer':
        return (schema['minimum'] as num?)?.toInt().clamp(1, 1 << 30) ?? 1;
      case 'number':
        return 0.5;
      case 'boolean':
        return true;
      case 'string':
        return _sampleString(schema);
    }
    return null;
  }

  String _sampleString(Map schema) {
    const candidates = [
      'text',
      '08:00:00',
      '2026-01-15T10:00:00Z',
      '2f5b7c1e-0d3a-4c1b-9a53-6f0e5b8d1a42',
    ];
    final format = schema['format'];
    if (format == 'date-time') {
      return candidates[2];
    }
    final pattern = schema['pattern'];
    if (pattern is String) {
      return candidates.firstWhere(
        (c) => RegExp(pattern).hasMatch(c),
        orElse: () => throw StateError('No sample for pattern $pattern'),
      );
    }
    return candidates.first;
  }

  http.Response _json(int status, Object? body) => http.Response(
    body == null ? '' : jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  static Map<String, Object?> _plain(Object? node) =>
      (_toPlain(node) as Map).cast<String, Object?>();

  static Object? _toPlain(Object? node) {
    if (node is YamlMap) {
      return {for (final e in node.entries) e.key as String: _toPlain(e.value)};
    }
    if (node is YamlList) {
      return [for (final e in node) _toPlain(e)];
    }
    return node;
  }
}

class _Match {
  _Match(this.operation);

  final Map<String, Object?> operation;
}

class _Answer {
  _Answer(this.status, this.body);

  final int status;
  final Object? body;
}
