import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// "Online" means the phone has a network link AND the server answered a
/// real `/health` ping. Link state alone lies on captive networks.
///
/// Changes are debounced so a weak signal doesn't flicker the pill; the first
/// answer after start is applied immediately.
class ConnectivityService {
  ConnectivityService({
    required this._linkChanges,
    required this._currentLink,
    required this._probe,
    this.debounce = const Duration(seconds: 2),
    this.reprobeEvery = const Duration(seconds: 30),
  });

  final Stream<List<ConnectivityResult>> _linkChanges;
  final Future<List<ConnectivityResult>> Function() _currentLink;
  final Future<bool> Function() _probe;
  final Duration debounce;
  final Duration reprobeEvery;

  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _periodic;
  Timer? _debounceTimer;
  bool? _pending;
  int _seq = 0;
  bool _resolved = false;
  bool _forcedOffline = false;
  bool _disposed = false;

  /// Starts pessimistic: until the first probe answers, claim nothing.
  bool _online = false;

  bool get isOnline => _online && !_forcedOffline;

  /// Distinct online/offline transitions.
  Stream<bool> get onChanged => _controller.stream;

  void start() {
    _sub = _linkChanges.listen((_) => recheck());
    _periodic = Timer.periodic(reprobeEvery, (_) => recheck());
    recheck();
  }

  /// Debug "Simulate offline": immediate, bypasses debounce.
  void forceOffline(bool value) {
    if (_forcedOffline == value) return;
    final before = isOnline;
    _forcedOffline = value;
    if (before != isOnline) _controller.add(isOnline);
    if (!value) recheck();
  }

  Future<void> recheck() async {
    final seq = ++_seq;
    var reachable = false;
    try {
      final link = await _currentLink();
      final hasLink = link.any((r) => r != ConnectivityResult.none);
      reachable = hasLink && await _probe();
    } catch (_) {
      reachable = false;
    }
    if (seq != _seq || _disposed) return; // a newer check superseded this one
    _apply(reachable);
  }

  void _apply(bool reachable) {
    if (!_resolved) {
      _resolved = true;
      _set(reachable);
      return;
    }
    if (reachable == _online) {
      _debounceTimer?.cancel();
      _pending = null;
      return;
    }
    if (_pending == reachable) return; // already waiting on this change
    _pending = reachable;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      _pending = null;
      _set(reachable);
    });
  }

  void _set(bool value) {
    if (_online == value) return;
    final before = isOnline;
    _online = value;
    if (before != isOnline) _controller.add(isOnline);
  }

  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _periodic?.cancel();
    _debounceTimer?.cancel();
    _controller.close();
  }
}
