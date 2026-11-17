import 'package:servora/features/auth/data/auth_repository.dart';
import 'package:servora/features/auth/domain/auth_result.dart';

/// A scriptable [AuthRepository]. Set [onLogin] / [onRegister] to decide what each
/// call does (return a result, throw an AppFailure, or wait on a Completer to hold a
/// request "in flight").
class FakeAuthRepository implements AuthRepository {
  Future<AuthResult> Function(String email, String password)? onLogin;
  Future<AuthResult> Function(String name, String email, String password)?
  onRegister;

  final List<({String email, String password})> loginCalls = [];
  final List<({String name, String email, String password})> registerCalls = [];

  @override
  Future<AuthResult> login({required String email, required String password}) {
    loginCalls.add((email: email, password: password));
    final handler = onLogin;
    if (handler == null) throw StateError('FakeAuthRepository.onLogin not set');
    return handler(email, password);
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) {
    registerCalls.add((name: name, email: email, password: password));
    final handler = onRegister;
    if (handler == null) {
      throw StateError('FakeAuthRepository.onRegister not set');
    }
    return handler(name, email, password);
  }
}
