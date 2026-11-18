import 'package:servora/core/domain/app_user.dart';
import 'package:servora/features/profile/data/profile_repository.dart';

import 'fixtures.dart';

/// A scriptable [ProfileRepository]. By default it behaves like the real API for one
/// user: `me` returns it, `update` changes it, `changePassword` succeeds. Set the `on...`
/// handlers to hold a call open or throw an AppFailure.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository([AppUser? user]) : user = user ?? testUser;

  AppUser user;

  Future<AppUser> Function()? onMe;
  Future<AppUser> Function(String name, String? phone)? onUpdate;
  Future<void> Function(String current, String next)? onChangePassword;

  int meCalls = 0;
  final List<({String name, String? phone})> updateCalls = [];
  final List<({String current, String next})> passwordCalls = [];

  @override
  Future<AppUser> me() {
    meCalls++;
    final handler = onMe;
    if (handler != null) return handler();
    return Future.value(user);
  }

  @override
  Future<AppUser> update({required String name, String? phone}) {
    updateCalls.add((name: name, phone: phone));
    final handler = onUpdate;
    if (handler != null) return handler(name, phone);
    final blank = phone == null || phone.trim().isEmpty;
    user = user.copyWith(
      name: name.trim(),
      phone: blank ? null : phone.trim(),
      clearPhone: blank,
    );
    return Future.value(user);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    passwordCalls.add((current: currentPassword, next: newPassword));
    final handler = onChangePassword;
    if (handler != null) return handler(currentPassword, newPassword);
    return Future.value();
  }
}
