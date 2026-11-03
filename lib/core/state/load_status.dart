/// Lifecycle of data that is decrypted into memory only while the vault is
/// unlocked. `idle` means nothing is loaded (e.g. the vault is locked).
enum LoadStatus { idle, loading, ready }
