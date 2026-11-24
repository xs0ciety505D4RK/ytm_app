import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> refreshNotifications() async =>
      Permission.notification.isGranted;

  static Future<bool> requestNotifications() async =>
      (await Permission.notification.request()).isGranted;

  static Future<bool> openSystemSettings() => openAppSettings();
}
