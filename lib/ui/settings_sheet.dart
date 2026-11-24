import 'package:flutter/material.dart';

import '../services/dynamic_island_service.dart';
import '../services/permission_service.dart';
import 'glass.dart';

void showSettings(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _SettingsContent(),
  );
}

class _SettingsContent extends StatefulWidget {
  const _SettingsContent();

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent>
    with WidgetsBindingObserver {
  bool _notificationGranted = false;
  bool _overlayGranted = false;
  bool _checking = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final notification = await PermissionService.refreshNotifications();
    final overlay = await DynamicIslandService.instance.permissionGranted();
    if (!overlay && Perf.dynamicIsland.value) {
      await DynamicIslandService.instance.setEnabled(false);
    }
    if (!mounted) return;
    setState(() {
      _notificationGranted = notification;
      _overlayGranted = overlay;
      _checking = false;
    });
  }

  Future<void> _notificationChanged(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (enabled) {
      final granted = await PermissionService.requestNotifications();
      if (!granted) await PermissionService.openSystemSettings();
    } else {
      await PermissionService.openSystemSettings();
    }
    await _refreshPermissions();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _islandChanged(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    final accepted = await DynamicIslandService.instance.setEnabled(enabled);
    await _refreshPermissions();
    if (!mounted) return;
    setState(() => _busy = false);
    if (enabled && !accepted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Izin overlay belum diberikan atau Dynamic Island gagal dijalankan.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Glass(
          radius: 32,
          blur: 24,
          strength: 1.5,
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('Pengaturan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: Perf.blur,
                builder: (_, on, __) => SwitchListTile(
                  title: const Text('Efek blur kaca'),
                  subtitle: const Text('Matikan kalau terasa berat / patah-patah'),
                  value: on,
                  onChanged: Perf.setBlur,
                ),
              ),
              SwitchListTile(
                secondary: Icon(
                  _notificationGranted
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                ),
                title: const Text('Izin notifikasi pemutar'),
                subtitle: Text(_checking
                    ? 'Memeriksa izin sistem…'
                    : _notificationGranted
                        ? 'Notifikasi playback dan tombol kontrol diizinkan'
                        : 'Izinkan agar notifikasi playback dan kontrol tampil'),
                value: _notificationGranted,
                onChanged: _checking || _busy ? null : _notificationChanged,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: Perf.dynamicIsland,
                builder: (_, on, __) => SwitchListTile(
                  secondary: const Icon(Icons.graphic_eq_rounded),
                  title: const Text('Dynamic Island'),
                  subtitle: Text(_checking
                      ? 'Memeriksa izin overlay…'
                      : _overlayGranted
                          ? on
                              ? 'Mengambang aktif — putar lagu untuk kontrol'
                              : 'Izin siap — aktifkan untuk menampilkan island'
                          : 'Perlu izin “Tampil di atas aplikasi lain”'),
                  value: on,
                  onChanged: _checking || _busy ? null : _islandChanged,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: Text(
                  'Dynamic Island memiliki tombol lagu sebelumnya, putar/jeda, berikutnya, dan tutup. Izin overlay dapat dicabut kapan saja dari Setelan Android.',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                  textAlign: TextAlign.center,
                ),
              ),
            ]),
          ),
        ),
      );
}
