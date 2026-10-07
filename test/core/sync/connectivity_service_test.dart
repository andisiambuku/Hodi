import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/core/sync/connectivity_service.dart';

class _Harness {
  _Harness({
    this.link = const [ConnectivityResult.wifi],
    this.reachable = true,
  }) {
    service = ConnectivityService(
      linkChanges: _links.stream,
      currentLink: () async => link,
      probe: () async {
        probes++;
        if (probeThrows) throw Exception('boom');
        return reachable;
      },
    );
    service.onChanged.listen(changes.add);
  }

  List<ConnectivityResult> link;
  bool reachable;
  bool probeThrows = false;
  int probes = 0;
  final changes = <bool>[];
  final _links = StreamController<List<ConnectivityResult>>.broadcast();
  late final ConnectivityService service;

  void setLink(List<ConnectivityResult> l) {
    link = l;
    _links.add(l);
  }
}

void main() {
  test('first answer applies immediately, without debounce', () {
    fakeAsync((async) {
      final h = _Harness()..service.start();
      async.flushMicrotasks();
      expect(h.service.isOnline, isTrue);
      expect(h.changes, [true]);
      h.service.dispose();
    });
  });

  test('starts pessimistic: not online before the first probe answers', () {
    final h = _Harness();
    expect(h.service.isOnline, isFalse);
    h.service.dispose();
  });

  test('no link: offline, and the server is not pinged', () {
    fakeAsync((async) {
      final h = _Harness(link: [ConnectivityResult.none])..service.start();
      async.flushMicrotasks();
      expect(h.service.isOnline, isFalse);
      expect(h.probes, 0);
      h.service.dispose();
    });
  });

  test('captive network: link up but /health fails → offline', () {
    fakeAsync((async) {
      final h = _Harness(reachable: false)..service.start();
      async.flushMicrotasks();
      expect(h.service.isOnline, isFalse);
      h.service.dispose();
    });
  });

  test('a probe that throws counts as unreachable', () {
    fakeAsync((async) {
      final h = _Harness()..probeThrows = true;
      h.service.start();
      async.flushMicrotasks();
      expect(h.service.isOnline, isFalse);
      h.service.dispose();
    });
  });

  test('a 1s blip does not flicker the pill', () {
    fakeAsync((async) {
      final h = _Harness()..service.start();
      async.flushMicrotasks();
      h.changes.clear();

      h.setLink([ConnectivityResult.none]);
      async.elapse(const Duration(seconds: 1));
      h.setLink([ConnectivityResult.wifi]);
      async.elapse(const Duration(seconds: 5));

      expect(h.changes, isEmpty);
      expect(h.service.isOnline, isTrue);
      h.service.dispose();
    });
  });

  test('sustained loss goes offline after the 2s debounce, not before', () {
    fakeAsync((async) {
      final h = _Harness()..service.start();
      async.flushMicrotasks();

      h.setLink([ConnectivityResult.none]);
      async.elapse(const Duration(milliseconds: 1900));
      expect(h.service.isOnline, isTrue);
      async.elapse(const Duration(milliseconds: 200));
      expect(h.service.isOnline, isFalse);
      h.service.dispose();
    });
  });

  test('reconnect is reported within 5 seconds of the link coming back', () {
    fakeAsync((async) {
      final h = _Harness(link: [ConnectivityResult.none])..service.start();
      async.flushMicrotasks();
      expect(h.service.isOnline, isFalse);

      h.setLink([ConnectivityResult.mobile]);
      async.elapse(const Duration(seconds: 5));
      expect(h.service.isOnline, isTrue);
      h.service.dispose();
    });
  });

  test('periodic re-probe recovers from a captive portal clearing', () {
    fakeAsync((async) {
      final h = _Harness(reachable: false)..service.start();
      async.flushMicrotasks();
      h.reachable = true; // no link event fires when a portal is cleared
      async.elapse(const Duration(seconds: 40));
      expect(h.service.isOnline, isTrue);
      h.service.dispose();
    });
  });

  test('simulate offline is immediate; clearing it re-checks', () {
    fakeAsync((async) {
      final h = _Harness()..service.start();
      async.flushMicrotasks();

      h.service.forceOffline(true);
      expect(h.service.isOnline, isFalse);
      h.service.forceOffline(false);
      async.flushMicrotasks();
      expect(h.service.isOnline, isTrue);
      expect(h.changes, [true, false, true]);
      h.service.dispose();
    });
  });
}
