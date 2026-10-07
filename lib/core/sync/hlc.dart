/// Hybrid logical clock. Stamps are fixed-width strings, so plain string
/// comparison orders them: `<13-digit ms>-<4-hex counter>-<node>`.
class HlcClock {
  HlcClock({required this.nodeId, DateTime Function()? now, String? last})
    : _now = now ?? DateTime.now {
    if (last != null) _advanceTo(Hlc.parse(last));
  }

  final String nodeId;
  final DateTime Function() _now;
  int _ms = 0;
  int _counter = 0;

  /// Stamp for a local event. Always greater than any stamp issued or
  /// received before, even if the wall clock stalls or steps back.
  String next() {
    final wall = _now().millisecondsSinceEpoch;
    if (wall > _ms) {
      _ms = wall;
      _counter = 0;
    } else {
      _counter++;
    }
    return Hlc(_ms, _counter, nodeId).toString();
  }

  /// Merge a stamp seen from elsewhere so later local stamps sort after it.
  void receive(String remote) => _advanceTo(Hlc.parse(remote));

  void _advanceTo(Hlc h) {
    if (h.ms > _ms || (h.ms == _ms && h.counter > _counter)) {
      _ms = h.ms;
      _counter = h.counter;
    }
  }
}

class Hlc {
  const Hlc(this.ms, this.counter, this.node);

  final int ms;
  final int counter;
  final String node;

  factory Hlc.parse(String s) {
    final parts = s.split('-');
    if (parts.length < 3) throw FormatException('Bad HLC', s);
    return Hlc(
      int.parse(parts[0]),
      int.parse(parts[1], radix: 16),
      parts.sublist(2).join('-'),
    );
  }

  @override
  String toString() =>
      '${ms.toString().padLeft(13, '0')}-${counter.toRadixString(16).padLeft(4, '0')}-$node';
}
