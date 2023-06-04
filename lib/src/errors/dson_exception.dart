/// Exception from DSON
class DSONException implements Exception {
  /// Message for exception
  final String message;

  /// stackTrace for exception
  final StackTrace? stackTrace;

  /// Received type
  final String? receivedType;

  /// Expected type
  final String? expectedType;

  /// Class name
  final String className;

  /// Param name
  final String? paramName;

  /// Alias
  final String? alias;

  /// Value
  final dynamic value;

  /// Exception from DSON
  DSONException(
    this.message, {
    this.stackTrace,
    this.receivedType,
    this.expectedType,
    required this.className,
    this.paramName,
    this.alias,
    this.value,
  });

  String get _className => 'DSONException';

  @override
  String toString() {
    var message = '$_className: ${this.message}';
    if (stackTrace != null) {
      message = '$message\n$stackTrace';
    }

    return message;
  }
}

/// Called when params is not allowed
class ParamsNotAllowed extends DSONException {
  /// Called when params is not allowed
  ParamsNotAllowed(
    super.message, {
    super.stackTrace,
    super.receivedType,
    super.expectedType,
    required super.className,
    super.paramName,
    super.alias,
    super.value,
  });

  @override
  String get _className => 'ParamsNotAllowed';
}
