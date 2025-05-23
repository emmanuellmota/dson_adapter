// ignore_for_file: avoid_catching_errors

import 'dart:convert';

import '../dson_adapter.dart';

/// Function to transform the value of an object based on its key
typedef ResolverCallback = Object? Function(
    String key, dynamic value, String type);

/// Convert JSON to Dart Class withless code generate(build_runner)
class DSON {
  /// Common resolvers
  final List<ResolverCallback> commonResolvers;

  /// Convert JSON to Dart Class withless code generate(build_runner)
  const DSON({List<ResolverCallback>? resolvers})
      : commonResolvers = resolvers ?? const [];

  ///
  /// For complex objects it is necessary to declare the constructor in
  /// the [inner] property and declare the list resolver in the [resolvers]
  /// property.
  ///
  /// The [aliases] parameter can be used to create alias to specify the name
  /// of a field when it is deserialized.
  ///
  /// For example:
  /// ```dart
  /// Home home = dson.fromJson(
  ///   // json Map or List
  ///   jsonMap,
  ///   // Main constructor
  ///   Home.new,
  ///   // external types
  ///   inner: {
  ///     'owner': Person.new,
  ///     'parents': ListParam<Person>(Person.new),
  ///   },
  ///   // Param names Object <-> Param name in API
  ///   aliases: {
  ///     Home: {'owner': 'master'},
  ///     Person: {'id': 'key'}
  ///   }
  /// );
  /// ```

  ///
  /// For more information, see the
  /// [documentation](https://pub.dev/documentation/dson_adapter/latest/).
  T fromJson<T>(
    dynamic map,
    Function mainConstructor, {
    Map<String, dynamic> inner = const {},
    List<ResolverCallback> resolvers = const [],
    Map<Type, Map<String, String>> aliases = const {},
    String Function(String)? propNameConverter,
  }) {
    final mainConstructorNamed = mainConstructor.runtimeType.toString();
    final aliasesWithTypeInString =
        aliases.map((key, value) => MapEntry(key.toString(), value));
    final hasOnlyNamedParams =
        RegExp(r'\(\{(.+)\}\)').firstMatch(mainConstructorNamed);
    final parentClass = mainConstructorNamed.split(' => ').last;
    if (hasOnlyNamedParams == null) {
      throw ParamsNotAllowed('$parentClass must have named params only!');
    }

    final regExp = _namedParamsRegExMatch(parentClass, mainConstructorNamed);
    final functionParams =
        _parseFunctionParams(regExp, aliasesWithTypeInString[parentClass]);

    final allResolvers = [...commonResolvers, ...resolvers];

    final props = <String, dynamic>{};

    try {
      final mapEntryParams = functionParams
          .map(
            (functionParam) {
              dynamic value;

              final hasSubscriptOperator =
                  map is Map || map is List || map is Set;

              if (!hasSubscriptOperator) {
                throw ParamInvalidType.notIterable(
                  functionParam: functionParam,
                  receivedType: map.runtimeType.toString(),
                  parentClass: parentClass,
                  stackTrace: StackTrace.current,
                );
              }

              var workflowKey = functionParam.aliasOrName;
              if (propNameConverter != null) {
                workflowKey = propNameConverter(workflowKey);
              }

              if (aliases.containsKey(parentClass) &&
                  aliases[parentClass]!.containsKey(workflowKey)) {
                workflowKey = aliases[parentClass]![workflowKey]!;
              }

              final workflow = map[workflowKey];

              if (workflow is Map || workflow is List || workflow is Set) {
                final innerParam = inner[functionParam.name];

                if (innerParam is IParam) {
                  value = innerParam.call(
                    this,
                    workflow,
                    inner,
                    allResolvers,
                    aliases,
                  );

                  if (value is List) {
                    value = value.toList();
                  }
                } else if (innerParam is Function) {
                  value = fromJson(
                    workflow,
                    innerParam,
                    resolvers: allResolvers,
                    aliases: aliases,
                    propNameConverter: propNameConverter,
                  );
                } else {
                  value = workflow;
                }
              } else {
                value = workflow;
              }

              value = allResolvers.fold(
                value,
                (previousValue, element) {
                  return element(
                    functionParam.name,
                    previousValue,
                    functionParam.type,
                  );
                },
              );

              final snakeCaseKey = toSnakeCase(workflowKey);
              if (value == null && map.containsKey(snakeCaseKey)) {
                value = map[snakeCaseKey];
              }

              if (value == null) {
                if (!functionParam.isRequired) return null;
                if (!functionParam.isNullable) {
                  throw ParamNullNotAllowed(
                    functionParam: functionParam,
                    parentClass: parentClass,
                    stackTrace: StackTrace.current,
                  );
                }

                props[functionParam.name] = null;
                return MapEntry(Symbol(functionParam.name), null);
              }

              props[functionParam.name] = value;
              return MapEntry(Symbol(functionParam.name), value);
            },
          )
          .where((entry) => entry != null)
          .cast<MapEntry<Symbol, dynamic>>()
          .toList();

      final namedParams = <Symbol, dynamic>{}..addEntries(mapEntryParams);

      final result = Function.apply(mainConstructor, [], namedParams);

      if (result is Serializable) {
        result._props.addAll(props);
        result
          .._entries = namedParams
          .._builder = (Map<Symbol, dynamic> params) {
            final n = Function.apply(mainConstructor, [], params);

            n._props.addAll(props);
            n
              .._entries = params
              .._builder = result._builder;

            return n;
          };
      }

      return result;
    } on TypeError catch (error, stackTrace) {
      throw ParamInvalidType.typeError(
        error: error,
        stackTrace: stackTrace,
        functionParams: functionParams,
        parentClass: parentClass,
      );
    }
  }

  RegExpMatch _namedParamsRegExMatch(
    String parentClass,
    String mainConstructorNamed,
  ) {
    final result = RegExp(r'\(\{(.+)\}\)').firstMatch(mainConstructorNamed);

    if (result == null) {
      throw ParamsNotAllowed('$parentClass must have named params only!');
    }

    return result;
  }

  Iterable<FunctionParam> _parseFunctionParams(
    RegExpMatch regExp,
    Map<String, String>? aliases,
  ) {
    return regExp
        .group(1)!
        .split(RegExp(',(?![^<]*>)'))
        .map((e) => e.trim())
        .map(
          (element) => FunctionParam.fromString(element)
              .copyWith(alias: aliases?[element.split(' ').last]),
        );
  }
}

abstract class Serializable {
  final Map<String, dynamic> _props = {};
  final Map<String, dynamic> _updateValues = {};

  Map<Symbol, dynamic> _entries = {};
  late Function(Map<Symbol, dynamic> params) _builder;

  Map<String, dynamic> toMap({
    Map<Type, Map<String, String>> aliases = const {},
    String Function(String)? propNameConverter,
  }) =>
      _recursiveMap(_props, aliases, propNameConverter);

  String toJson({
    Map<Type, Map<String, String>> aliases = const {},
    String Function(String)? propNameConverter,
  }) =>
      json.encode(
          toMap(aliases: aliases, propNameConverter: propNameConverter));

  Map<String, dynamic> _recursiveMap(
    Map<String, dynamic> props,
    Map<Type, Map<String, String>> aliases,
    String Function(String)? propNameConverter, [
    Type? entryType,
  ]) {
    final map = <String, dynamic>{};

    for (final entry in props.entries) {
      final originalKey = entry.key;
      final value = entry.value;

      entryType ??= runtimeType;

      String key = originalKey;

      if (propNameConverter != null) {
        key = propNameConverter(key);
      }

      final alias = aliases[entryType];
      key =
          alias?.containsKey(originalKey) == true ? alias![originalKey]! : key;

      if (value is Serializable) {
        map[key] = _recursiveMap(
            value.toMap(), aliases, propNameConverter, value.runtimeType);
      } else if (value is List) {
        map[key] = value.map((e) {
          if (e is Serializable) {
            return _recursiveMap(
                e.toMap(), aliases, propNameConverter, e.runtimeType);
          }
          return e;
        }).toList();
      } else if (value is Map) {
        map[key] = _recursiveMap(
          value as Map<String, dynamic>,
          aliases,
          propNameConverter,
          value.runtimeType,
        );
      } else if (value is Enum) {
        map[key] = (value is SerializableEnum)
            ? (value as SerializableEnum).name
            : value.name;
      } else if (value is DateTime) {
        map[key] = value.toIso8601String();
      } else {
        map[key] = value;
      }
    }

    return map;
  }

  bool equals<T extends Serializable>(T? other) {
    return _deepEquals(_props, other?._props);
  }

  bool _deepEquals(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;

      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) {
          return false;
        }
      }
      return true;
    } else if (a is List && b is List) {
      if (a.length != b.length) return false;

      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) {
          return false;
        }
      }
      return true;
    } else {
      return a == b;
    }
  }

  @override
  String toString() => '$runtimeType($_props)';
}

extension SerializableExtension<T extends Serializable> on T {
  T copyWith(
    void Function(
      void Function<R, Z extends R>(R field, Z newValue) set,
      T t,
    ) e,
  ) {
    _updateValues.clear();

    e(_setValue, this);

    return _copy();
  }

  void _setValue<R, Z extends R>(R field, Z newValue) {
    final entry = _props.entries
        .where((e) => e.value.hashCode == field.hashCode)
        .firstOrNull;

    if (entry != null) {
      _updateValues[entry.key] = newValue;
      _props[entry.key] = newValue;
    }
  }

  T _copy() {
    final updatedEntries = {
      ..._entries,
      ...Map.fromEntries(
        _updateValues.entries
            .map((entry) => MapEntry(Symbol(entry.key), entry.value)),
      ),
    };

    return _builder(updatedEntries);
  }
}

abstract class SerializableEnum {
  String get name;
}

String toSnakeCase(String input) {
  return input.replaceAllMapped(RegExp('[A-Z]'), (Match match) {
    return '_${match.group(0)!.toLowerCase()}';
  });
}

String toKebabCase(String input) {
  return input.replaceAllMapped(RegExp('[A-Z]'), (Match match) {
    return '-${match.group(0)!.toLowerCase()}';
  });
}

String toCamelCase(String input) {
  return input.replaceAllMapped(RegExp('(_|-)([a-zA-Z])'), (Match match) {
    return match.group(2)!.toUpperCase();
  });
}
