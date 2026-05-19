import 'dart:async';

/// BLE 通信服务框架
///
/// 具体实现需在拿到硬件 BLE 协议文档后填充。
/// 当前提供接口定义，方便上层代码先对接。
///
/// 待硬件团队确认:
/// - 设备广播名 / Service UUID
/// - Notify Characteristic UUID
/// - Write Characteristic UUID（如需下发指令）
/// - 数据包格式
class BleService {
  BleService() {
    _dataController = StreamController<List<int>>.broadcast();
  }

  late StreamController<List<int>> _dataController;

  /// 原始 BLE 数据流（字节数组）
  Stream<List<int>> get dataStream => _dataController.stream;

  /// 连接设备
  /// [config] 设备配置（UUID 等从协议文档获取后填入）
  Future<bool> connect(BleDeviceConfig config) async {
    // TODO: 实现 BLE 连接逻辑
    // 1. FlutterBluePlus.scan 扫描设备
    // 2. 按名称/UUID 过滤
    // 3. target.connect 连接
    // 4. discoverServices 发现服务
    // 5. characteristic.setNotifyValue(true) 订阅数据
    // 6. characteristic.onValueReceived.listen 监听数据
    throw UnimplementedError('等待硬件协议文档后实现');
  }

  /// 断开连接
  Future<void> disconnect() async {
    _dataController = StreamController<List<int>>.broadcast();
  }

  /// 释放资源
  void dispose() {
    _dataController.close();
  }
}

/// BLE 设备配置（从协议文档填充）
class BleDeviceConfig {
  final String deviceName;
  final String serviceUuid;
  final String notifyCharUuid;
  final String? writeCharUuid;

  const BleDeviceConfig({
    required this.deviceName,
    required this.serviceUuid,
    required this.notifyCharUuid,
    this.writeCharUuid,
  });
}
