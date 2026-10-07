/// `x of N` while a sync is running.
class SyncProgress {
  const SyncProgress({required this.done, required this.total});

  final int done;
  final int total;
}
