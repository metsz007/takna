/// Per-reminder alert sounds. One shared catalog, read by both platforms:
/// the same keys drive a non-platform-conditional picker, while the audio
/// assets are per-platform (Android `res/raw/<key>.ogg`, iOS `<key>.caf`).
///
/// (key stored in DB, UI label, iOS bundle filename).
/// key == null is "System default" and is deliberately not in this list.
const soundCatalog = <({String key, String label, String iosFile})>[
  (key: 'chime', label: 'Chime', iosFile: 'chime.caf'),
  (key: 'classic', label: 'Classic', iosFile: 'classic.caf'),
  (key: 'buzzer', label: 'Buzzer', iosFile: 'buzzer.caf'),
];

/// iOS sound filename for [key]; null (→ system default) for null or any key
/// not in the catalog. Pure, never throws — the trust boundary for a
/// stale/hand-edited soundKey.
String? iosSoundFor(String? key) {
  for (final s in soundCatalog) {
    if (s.key == key) return s.iosFile;
  }
  return null;
}

/// UI label for [key]; "System default" for null or any unknown key.
String soundLabelFor(String? key) {
  for (final s in soundCatalog) {
    if (s.key == key) return s.label;
  }
  return 'Default';
}
