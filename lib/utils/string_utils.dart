/// Natural alphanumeric comparator for human sorting (e.g., "Room 1", "Room 2", ..., "Room 10").
int naturalCompare(String? a, String? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;

  final regex = RegExp(r'(\d+|\D+)');
  final aChunks = regex.allMatches(a).map((m) => m.group(0)!).toList();
  final bChunks = regex.allMatches(b).map((m) => m.group(0)!).toList();

  final minLen = aChunks.length < bChunks.length ? aChunks.length : bChunks.length;
  for (int i = 0; i < minLen; i++) {
    final aChunk = aChunks[i];
    final bChunk = bChunks[i];

    final aNum = int.tryParse(aChunk);
    final bNum = int.tryParse(bChunk);

    if (aNum != null && bNum != null) {
      final diff = aNum.compareTo(bNum);
      if (diff != 0) return diff;
    } else {
      final diff = aChunk.toLowerCase().compareTo(bChunk.toLowerCase());
      if (diff != 0) return diff;
    }
  }

  return aChunks.length.compareTo(bChunks.length);
}
