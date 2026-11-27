class AdminSetting {
  const AdminSetting(
      {required this.key,
      required this.group,
      required this.type,
      required this.value,
      required this.defaultValue,
      required this.description,
      required this.isDefault});
  final String key;
  final String group;
  final String type;
  final Object? value;
  final Object? defaultValue;
  final String description;
  final bool isDefault;
}

abstract interface class AdminSettingsRepository {
  Future<List<AdminSetting>> list();
  Future<void> update(String key, Object value, String reason);
  Future<void> rollback(String key, int auditId, String reason);
}
