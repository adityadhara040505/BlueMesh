/// Functional Result pattern for deterministic error handling.
library;

/// Represents either a successful value of type [T] or a failure of type [E].
sealed class Result<T, E> {
  const Result();

  /// Create a successful result.
  factory Result.success(T value) = Success<T, E>;

  /// Create an error failure result.
  factory Result.failure(E error) = Failure<T, E>;

  /// Returns true if this instance represents a success.
  bool get isSuccess => this is Success<T, E>;

  /// Returns true if this instance represents a failure.
  bool get isFailure => this is Failure<T, E>;

  /// Returns the wrapped value if successful, or null on failure.
  T? get valueOrNull => switch (this) {
        Success(value: final v) => v,
        Failure() => null,
      };

  /// Returns the wrapped error if failure, or null on success.
  E? get errorOrNull => switch (this) {
        Success() => null,
        Failure(error: final e) => e,
      };

  /// Pattern-matches over the result.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(E error) onFailure,
  }) {
    return switch (this) {
      Success(value: final v) => onSuccess(v),
      Failure(error: final e) => onFailure(e),
    };
  }

  /// Maps the success value to another type.
  Result<R, E> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success(value: final v) => Result.success(transform(v)),
      Failure(error: final e) => Result.failure(e),
    };
  }
}

/// Successful variant of [Result].
final class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Result.success($value)';
}

/// Failure variant of [Result].
final class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T, E> && runtimeType == other.runtimeType && error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Result.failure($error)';
}
