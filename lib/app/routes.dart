abstract final class Routes {
  static const welcome = '/welcome';
  static const setupPin = '/setup/pin';
  static const setupRecovery = '/setup/recovery';
  static const setupVerify = '/setup/verify';
  static const setupBiometric = '/setup/biometric';

  static const lock = '/lock';
  static const recover = '/recover';

  // Bottom-navigation tabs.
  static const home = '/home';
  static const gallery = '/gallery';
  static const files = '/files';
  static const notes = '/notes';

  static String file(String id) => '/file/$id';
  static String note(String id) => '/note/$id';
  static const newNote = '/note/new';

  static const scanner = '/scanner';
  static const backup = '/backup';
  static const security = '/security';
  static const settings = '/settings';
  static const changePin = '/settings/change-pin';
}
