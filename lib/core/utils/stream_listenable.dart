import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts a [Stream] (e.g. a Cubit's state stream) to a [Listenable], so
/// GoRouter can re-run its redirect whenever the session changes.
class StreamListenable extends ChangeNotifier {
  StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
