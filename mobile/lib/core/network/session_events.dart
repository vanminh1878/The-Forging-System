import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped when the refresh token is rejected; the auth controller listens to it
/// and signs the user out. This indirection keeps networking free of any
/// dependency on the auth feature.
class SessionExpiredNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void expire() => state = state + 1;
}

final sessionExpiredProvider =
    NotifierProvider<SessionExpiredNotifier, int>(SessionExpiredNotifier.new);
