import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import 'ble_parser.dart';

/// BLE 连接错误类型
enum BleConnectError {
  /// 蓝牙未开启
  bluetoothOff,

  /// 未找到目标设备
  deviceNotFound,

  /// 连接超时
  timeout,

  /// 权限未授予
  unauthorized,

  /// 硬件不支持
  unsupported,

  /// 其他未知错误
  unknown,
}

/// BLE 连接异常
class BleConnectException implements Exception {
  final BleConnectError error;
  final String message;

  BleConnectException(this.error, this.message);

  @override
  String toString() => message;
}

/// BLE 通信服务（基于 universal_ble）
///
/// 使用 universal_ble 跨平台插件连接 KT6368A 设备，
/// 支持 Windows / Android / iOS / macOS / Linux 平台。
class BleService {
  final BleParser _parser = BleParser();
  StreamController<BlePacket>? _packetController;

  String? _deviceId;
  String? _notifyCharUuid;
  String? _writeServiceUuid;
  String? _writeCharUuid;

  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;
  StreamSubscription? _notifySub;
  Timer? _scanTimeout;

  /// 解析后的数据包流
  Stream<BlePacket> get packetStream =>
      (_packetController ??= StreamController<BlePacket>.broadcast()).stream;

  /// 当前是否已连接
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// 连接状态流
  final StreamController<bool> _stateController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _stateController.stream;

  /// 目标设备信息
  static const String targetDeviceName = 'KT6368A';
  static const String serviceUuid = '0000FFF0-0000-1000-8000-00805F9B34FB';
  static const String notifyCharUuid = '0000FFF1-0000-1000-8000-00805F9B34FB';
  static const String writeCharUuid = '0000FFF0-0000-1000-8000-00805F9B34FB';

  /// 扫描并连接设备
  ///
  /// 连接失败时抛出 [BleConnectException] 区分错误原因。
  Future<bool> connect({Duration timeout = const Duration(seconds: 15)}) async {
    try {
      // 0. 检查蓝牙状态
      final btState = await UniversalBle.getBluetoothAvailabilityState();
      switch (btState) {
        case AvailabilityState.poweredOff:
          throw BleConnectException(
              BleConnectError.bluetoothOff, '蓝牙未开启，请先开启蓝牙');
        case AvailabilityState.unauthorized:
          throw BleConnectException(
              BleConnectError.unauthorized, '蓝牙权限未授予');
        case AvailabilityState.unsupported:
          throw BleConnectException(
              BleConnectError.unsupported, '此设备不支持蓝牙');
        case AvailabilityState.poweredOn:
        // 正常，继续
        case AvailabilityState.unknown:
        case AvailabilityState.resetting:
        // 未知或重置中，尝试扫描
      }
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: [serviceUuid]),
      );

      // 2. 找目标设备
      BluetoothDevice? device;
      final completer = Completer<BluetoothDevice?>();

      _scanSub = UniversalBle.scanStream.listen(
        (result) {
          final name = result.name ?? '';
          if (name.contains(targetDeviceName)) {
            device = BluetoothDevice(
              deviceId: result.deviceId,
              name: name,
            );
            completer.complete(device);
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
      );

      // 3. 超时处理
      _scanTimeout = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      device = await completer.future;

      // 无论是否找到设备，都停止扫描
      await _stopScanCleanup();

      if (device == null) {
        throw BleConnectException(
            BleConnectError.deviceNotFound, '未找到 $targetDeviceName 设备');
      }

      final d = device!;
      _deviceId = d.deviceId;

      // 4. 监听连接状态
      _connSub = UniversalBle.connectionStream(d.deviceId).listen(
        (connected) {
          _isConnected = connected;
          _stateController.add(connected);
        },
        onError: (_) {
          _isConnected = false;
          _stateController.add(false);
        },
      );

      // 5. 连接
      await UniversalBle.connect(
        d.deviceId,
        timeout: timeout,
      );

      // 6. 发现服务
      final services = await UniversalBle.discoverServices(
        d.deviceId,
        withDescriptors: true,
      );

      // 7. 匹配特征值
      for (final svc in services) {
        final svcUuid = svc.uuid.toUpperCase();
        if (svcUuid == serviceUuid) {
          for (final char in svc.characteristics) {
            final charUuid = char.uuid.toUpperCase();
            final props = char.properties;

            if (charUuid == notifyCharUuid &&
                props.contains(CharacteristicProperty.notify)) {
              _notifyCharUuid = char.uuid;
              await UniversalBle.subscribeNotifications(
                d.deviceId,
                svc.uuid,
                char.uuid,
              );
              _notifySub =
                  UniversalBle.characteristicValueStream(
                    d.deviceId,
                    char.uuid,
                  ).listen(_onDataReceived);
            }

            if (charUuid == writeCharUuid &&
                (props.contains(CharacteristicProperty.writeWithoutResponse) ||
                    props.contains(CharacteristicProperty.write))) {
              _writeServiceUuid = svc.uuid;
              _writeCharUuid = char.uuid;
            }
          }
        }
      }

      if (_notifyCharUuid == null) {
        await disconnect();
        return false;
      }

      _isConnected = true;
      _stateController.add(true);
      return true;
    } on BleConnectException {
      await _stopScanCleanup();
      _isConnected = false;
      _stateController.add(false);
      rethrow;
    } catch (e) {
      await _stopScanCleanup();
      _isConnected = false;
      _stateController.add(false);
      throw BleConnectException(
          BleConnectError.unknown, '连接异常: $e');
    }
  }

  /// 停止扫描并清理资源
  Future<void> _stopScanCleanup() async {
    _scanTimeout?.cancel();
    _scanTimeout = null;
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await UniversalBle.stopScan();
    } catch (_) {}
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    await _connSub?.cancel();
    _connSub = null;
    if (_deviceId != null) {
      try {
        await UniversalBle.disconnect(_deviceId!);
      } catch (_) {}
    }
    _deviceId = null;
    _notifyCharUuid = null;
    _writeServiceUuid = null;
    _writeCharUuid = null;
    _isConnected = false;
    _stateController.add(false);
  }

  /// 发送控制命令
  Future<void> sendCommand(String cmd) async {
    if (_deviceId == null ||
        _writeServiceUuid == null ||
        _writeCharUuid == null) {
      throw Exception('BLE 写特征值不可用');
    }
    final bytes = utf8.encode(cmd);
    await UniversalBle.write(
      _deviceId!,
      _writeServiceUuid!,
      _writeCharUuid!,
      Uint8List.fromList(bytes),
      withoutResponse: true,
    );
  }

  /// BLE Notify 数据回调
  void _onDataReceived(Uint8List data) {
    final packets = _parser.feed(data.toList());
    final controller = _packetController;
    if (controller == null) return;
    for (final packet in packets) {
      controller.add(packet);
    }
  }

  /// 释放资源
  void dispose() {
    _scanTimeout?.cancel();
    _notifySub?.cancel();
    _connSub?.cancel();
    _parser.clear();
    _packetController?.close();
    _stateController.close();
  }
}

/// 内部模型：扫描到的 BLE 设备信息
class BluetoothDevice {
  final String deviceId;
  final String name;

  BluetoothDevice({required this.deviceId, required this.name});
}
