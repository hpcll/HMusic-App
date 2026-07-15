abstract final class BuildEdition {
  static const bool isStore = bool.fromEnvironment(
    'HMUSIC_STORE_EDITION',
    defaultValue: false,
  );
}
