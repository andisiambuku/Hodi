import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/core/sync/hlc.dart';

void main() {
  test('stamps are strictly increasing even if the wall clock stalls', () {
    final t = DateTime(2026, 10, 6, 9);
    final clock = HlcClock(nodeId: 'a', now: () => t);
    final stamps = List.generate(5, (_) => clock.next());
    expect([...stamps]..sort(), stamps);
    expect(stamps.toSet(), hasLength(5));
  });

  test('stays monotonic when the wall clock steps back', () {
    var t = DateTime(2026, 10, 6, 9);
    final clock = HlcClock(nodeId: 'a', now: () => t);
    final first = clock.next();
    t = t.subtract(const Duration(minutes: 5));
    expect(clock.next().compareTo(first), greaterThan(0));
  });

  test('receive() makes later local stamps sort after the remote one', () {
    final clock = HlcClock(nodeId: 'a', now: () => DateTime(2026, 1, 1));
    final remote = Hlc(DateTime(2026, 12, 1).millisecondsSinceEpoch, 3, 'b');
    clock.receive(remote.toString());
    expect(clock.next().compareTo(remote.toString()), greaterThan(0));
  });

  test('parse round-trips', () {
    final h = Hlc(1760000000000, 255, 'dev-1');
    final p = Hlc.parse(h.toString());
    expect((p.ms, p.counter, p.node), (1760000000000, 255, 'dev-1'));
  });
}
