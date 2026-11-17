import 'package:servora/core/session/stored_session.dart';
import 'package:servora/core/session/token_store.dart';

/// In-memory [TokenStore] for tests. [writes] and [clears] let tests assert on use.
class FakeTokenStore implements TokenStore {
  FakeTokenStore([this.session]);

  StoredSession? session;
  int writes = 0;
  int clears = 0;

  /// Make [read], [write] or [clear] throw, like a broken keystore.
  bool failReads = false;
  bool failWrites = false;
  bool failClears = false;

  @override
  Future<StoredSession?> read() async {
    if (failReads) throw StateError('keystore unavailable');
    return session;
  }

  @override
  Future<void> write(StoredSession value) async {
    if (failWrites) throw StateError('keystore unavailable');
    writes++;
    session = value;
  }

  @override
  Future<void> clear() async {
    if (failClears) throw StateError('keystore unavailable');
    clears++;
    session = null;
  }
}
