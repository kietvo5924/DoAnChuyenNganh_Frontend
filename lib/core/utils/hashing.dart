import 'dart:convert';

/// Deterministic 32-bit FNV-1a hash for stable IDs across app restarts.
int fnv1a32(String input) {
  const int fnvPrime = 0x01000193;
  int hash = 0x811c9dc5;
  final bytes = utf8.encode(input);
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  // Keep in signed 32-bit range for SQLite INTEGER compatibility
  if (hash & 0x80000000 != 0) {
    return hash - 0x100000000;
  }
  return hash;
}
