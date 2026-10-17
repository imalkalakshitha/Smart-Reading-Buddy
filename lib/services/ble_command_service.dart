import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleCommandService {
  BleCommandService._();
  static final BleCommandService instance = BleCommandService._();

  static const _deviceName = 'SmartReadingBuddy';
  static const _serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const _charUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  // Re-entrancy guard — without this, a still-advertising device can appear
  // in multiple onScanResults batches before stopScan()/cancelling _scanSub
  // actually takes effect, causing _connect() to fire repeatedly against an
  // already-connected/connecting device. That flood of redundant GATT calls
  // is what was causing the BLASTBufferQueue frame-buffer crash shortly
  // after a successful connect.
  bool _connecting = false;

  /// Notifies listeners when the connection state changes.
  final connected = ValueNotifier<bool>(false);

  /// Last command sent — observed by UI for the buddy status indicator.
  String? lastCommand;

  bool get isConnected => _characteristic != null;

  Future<void> scanAndConnect() async {
    if (isConnected || _connecting) return;
    try {
      // Android 12+ (API 31+) requires these as RUNTIME permissions even
      // though they're already declared in AndroidManifest.xml. Requesting
      // ones the manifest doesn't declare (or on older Android/iOS, where
      // these are no-ops) is harmless — permission_handler just resolves
      // them as granted/not-applicable. Denial isn't specially handled:
      // the scan below simply finds nothing and this fails silently, same
      // as every other failure path here.
      await [Permission.bluetoothScan, Permission.bluetoothConnect].request();

      await _scanSub?.cancel();
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      _scanSub = FlutterBluePlus.onScanResults.listen((results) {
        // A still-advertising device can appear in more than one results
        // batch before the cancel()/stopScan() below actually takes
        // effect — without this guard that re-enters _connect() on an
        // already-connecting/connected device, flooding the GATT stack.
        if (_connecting || isConnected) return;
        for (final r in results) {
          if (r.device.platformName.contains(_deviceName)) {
            _connecting = true;
            _scanSub?.cancel();
            _scanSub = null;
            FlutterBluePlus.stopScan();
            _connect(r.device);
            break;
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _device = device;
      await _connSub?.cancel();
      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _characteristic = null;
          connected.value = false;
        }
      });
      final services = await device.discoverServices();
      for (final s in services) {
        if (s.serviceUuid.toString() == _serviceUuid) {
          for (final c in s.characteristics) {
            if (c.characteristicUuid.toString() == _charUuid) {
              _characteristic = c;
              connected.value = true;
              return;
            }
          }
        }
      }
    } catch (_) {
      connected.value = false;
    } finally {
      _connecting = false;
    }
  }

  Future<void> send(String command) async {
    lastCommand = command;
    if (_characteristic == null) {
      debugPrint('[BLE stub] → $command');
      return;
    }
    try {
      await _characteristic!.write(command.codeUnits, withoutResponse: false);
    } catch (_) {}
  }

  Future<void> disconnect() async {
    await _scanSub?.cancel();
    await _connSub?.cancel();
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
    try { await _device?.disconnect(); } catch (_) {}
    _characteristic = null;
    _device = null;
    _connecting = false;
    connected.value = false;
  }
}
