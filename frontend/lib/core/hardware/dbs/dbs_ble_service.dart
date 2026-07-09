import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import 'dbs_frame_codec.dart';
import 'dbs_models.dart';

enum DbsConnectError {
  bluetoothOff,
  deviceNotFound,
  timeout,
  unauthorized,
  unsupported,
  pairingFailed,
  bleConnectionFailed,
  missingService,
  encryptedUnsupported,
  unknown,
}

/// DBS BLE 连接失败时抛出的业务异常，供 UI 展示明确原因。
class DbsConnectException implements Exception {
  final DbsConnectError error;
  final String message;

  const DbsConnectException(this.error, this.message);

  @override
  String toString() => message;
}

/// 独立的 DBS BLE 服务。
///
/// 职责包括：扫描 DBS 设备、连接 GATT、订阅状态/流数据 Notify、向 DBS 写命令、
/// 等待 ACK，并把上行二进制帧转换成 DbsEvent 事件流。
class DbsBleService {
  // 当前按 Nordic UART 风格 UUID 对接 DBS。改动前必须和硬件协议确认。
  static const String serviceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9F';
  static const String writeConfigCharUuid =
      '6E400002-B5A3-F393-E0A9-E50E24DCCA9F';
  static const String deviceNotifyCharUuid =
      '6E400003-B5A3-F393-E0A9-E50E24DCCA9F';
  static const String streamDataCharUuid =
      '6E400004-B5A3-F393-E0A9-E50E24DCCA9F';
  static const String storageDataCharUuid =
      '6E400005-B5A3-F393-E0A9-E50E24DCCA9F';
  static const int _manufacturerCompanyId = 0x0059;
  static const int _implantStimulatorDeviceType = 0x00;

  final DbsFrameCodec _codec;

  DbsBleService({DbsFrameCodec? codec}) : _codec = codec ?? DbsFrameCodec();

  final StreamController<DbsEvent> _eventController =
      StreamController<DbsEvent>.broadcast();
  final StreamController<bool> _stateController =
      StreamController<bool>.broadcast();
  final StreamController<DbsGattDiagnostic> _diagnosticController =
      StreamController<DbsGattDiagnostic>.broadcast();

  Stream<DbsEvent> get eventStream => _eventController.stream;
  Stream<bool> get connectionStateStream => _stateController.stream;
  Stream<DbsGattDiagnostic> get diagnosticStream =>
      _diagnosticController.stream;

  String? _deviceId;
  String? _deviceName;
  String? _writeServiceUuid;
  String? _writeCharUuid;
  int _streamSampleRate = 1000;
  bool _isConnected = false;
  DbsGattDiagnostic _gattDiagnostic = const DbsGattDiagnostic();
  final List<_PendingDbsAck> _pendingAcks = [];

  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;
  StreamSubscription? _deviceNotifySub;
  StreamSubscription? _streamDataSub;
  StreamSubscription? _storageDataSub;
  Timer? _scanTimeout;

  bool get isConnected => _isConnected;
  String? get deviceName => _deviceName;
  DbsGattDiagnostic get gattDiagnostic => _gattDiagnostic;

  void _updateDiagnostic(DbsGattDiagnostic diagnostic) {
    _gattDiagnostic = diagnostic;
    if (!_diagnosticController.isClosed) {
      _diagnosticController.add(_gattDiagnostic);
    }
  }

  void _setStage(
    String stage, {
    String? error,
    bool clearError = false,
    String? failureKind,
    String? currentStep,
  }) {
    _updateDiagnostic(
      _gattDiagnostic.copyWith(
        connectionStage: stage,
        lastError: error,
        clearLastError: clearError,
        failureKind: failureKind,
        currentStep: currentStep,
      ),
    );
  }

  /// 扫描并连接 DBS，随后发现 GATT 服务和订阅 Notify。
  ///
  /// 连接失败时，gattDiagnostic 会保留最后阶段和已发现的特征状态，便于联调排查。
  Future<bool> connect({Duration timeout = const Duration(seconds: 15)}) async {
    try {
      _updateDiagnostic(
        const DbsGattDiagnostic(
          connectionStage: '检查蓝牙状态',
          currentStep: 'bluetooth_state',
        ),
      );
      final btState = await UniversalBle.getBluetoothAvailabilityState();
      switch (btState) {
        case AvailabilityState.poweredOff:
          throw const DbsConnectException(
            DbsConnectError.bluetoothOff,
            '蓝牙未开启，请先开启蓝牙',
          );
        case AvailabilityState.unauthorized:
          throw const DbsConnectException(
            DbsConnectError.unauthorized,
            '蓝牙权限未授予',
          );
        case AvailabilityState.unsupported:
          throw const DbsConnectException(
            DbsConnectError.unsupported,
            '此设备不支持蓝牙',
          );
        case AvailabilityState.poweredOn:
        case AvailabilityState.unknown:
        case AvailabilityState.resetting:
      }

      DbsBluetoothDevice? device;
      device = await _findConnectedSystemDbsDevice(
        timeout: const Duration(seconds: 6),
      );
      try {
        device ??= await _scanForDbsDevice(
          timeout: timeout,
          stage: '扫描 DBS 广播(Service UUID)',
          scanFilter: ScanFilter(withServices: [serviceUuid]),
          scanSource: 'Service UUID 广播',
        );
      } catch (e) {
        _setStage('扫描 DBS 广播(Service UUID)失败，尝试名称兜底', error: e.toString());
      }
      device ??= await _scanForDbsDevice(
        timeout: const Duration(seconds: 8),
        stage: '扫描 DBS 广播(名称兜底)',
        scanSource: '名称/Manufacturer 兜底广播',
        allowNameFallback: true,
      );
      if (device == null) {
        _setStage(
          '未扫描到 DBS 设备',
          error:
              '系统已连接设备 ${_gattDiagnostic.systemDeviceCount} 个；扫描看到 ${_gattDiagnostic.scanSeenCount} 个广播，匹配 DBS ${_gattDiagnostic.scanMatchedCount} 个。最后候选: ${_gattDiagnostic.lastCandidateSummary ?? '无'}',
          failureKind: 'deviceNotFound',
          currentStep: 'device_not_found',
        );
        throw DbsConnectException(
          DbsConnectError.deviceNotFound,
          '未找到 DBS 设备。请确认设备正在广播 $serviceUuid，'
          '或 Manufacturer Data 为 company=0x0059/deviceType=0x00，或广播名包含 DBS',
        );
      }

      _deviceId = device.deviceId;
      _deviceName = device.name;
      _codec.resetCounter();
      _updateDiagnostic(
        _gattDiagnostic.copyWith(
          connectionStage: '连接 DBS',
          deviceName: device.name,
          rssi: device.rssi,
          paired: device.paired,
          advertisedServices: device.services,
          manufacturerData: device.manufacturerData,
          scanSource: device.source,
          currentStep: 'device_found',
          clearLastError: true,
        ),
      );

      _connSub = UniversalBle.connectionStream(device.deviceId).listen(
        (connected) {
          _isConnected = connected;
          _stateController.add(connected);
        },
        onError: (_) {
          _isConnected = false;
          _stateController.add(false);
        },
      );

      await _ensurePaired(device, timeout: const Duration(seconds: 30));
      await _connectBleDevice(device, timeout: timeout);
      try {
        _setStage('协商 MTU');
        final mtu = await UniversalBle.requestMtu(device.deviceId, 247);
        _updateDiagnostic(_gattDiagnostic.copyWith(mtuStatus: 'MTU $mtu'));
      } catch (e) {
        _updateDiagnostic(_gattDiagnostic.copyWith(mtuStatus: 'MTU 协商失败: $e'));
      }
      _setStage('发现 GATT 服务');
      final services = await UniversalBle.discoverServices(
        device.deviceId,
        withDescriptors: true,
      );

      // 找到 DBS 主 Service 后，分别保存写特征并订阅状态、流数据和存储数据 Notify。
      for (final svc in services) {
        if (svc.uuid.toUpperCase() != serviceUuid) continue;
        _updateDiagnostic(_gattDiagnostic.copyWith(serviceFound: true));
        for (final char in svc.characteristics) {
          final charUuid = char.uuid.toUpperCase();
          final props = char.properties;
          if (charUuid == writeConfigCharUuid &&
              (props.contains(CharacteristicProperty.write) ||
                  props.contains(
                    CharacteristicProperty.writeWithoutResponse,
                  ))) {
            _writeServiceUuid = svc.uuid;
            _writeCharUuid = char.uuid;
            _updateDiagnostic(_gattDiagnostic.copyWith(writeFound: true));
          }

          if (props.contains(CharacteristicProperty.notify)) {
            if (charUuid == deviceNotifyCharUuid) {
              _setStage('订阅 Device Notify');
              await UniversalBle.subscribeNotifications(
                device.deviceId,
                svc.uuid,
                char.uuid,
              );
              _deviceNotifySub = UniversalBle.characteristicValueStream(
                device.deviceId,
                char.uuid,
              ).listen(_onDeviceNotify);
              _updateDiagnostic(
                _gattDiagnostic.copyWith(deviceNotifyFound: true),
              );
            } else if (charUuid == streamDataCharUuid) {
              _setStage('订阅 Stream Data');
              await UniversalBle.subscribeNotifications(
                device.deviceId,
                svc.uuid,
                char.uuid,
              );
              _streamDataSub = UniversalBle.characteristicValueStream(
                device.deviceId,
                char.uuid,
              ).listen(_onStreamData);
              _updateDiagnostic(
                _gattDiagnostic.copyWith(streamDataFound: true),
              );
            } else if (charUuid == storageDataCharUuid) {
              _setStage('订阅 Storage Data');
              await UniversalBle.subscribeNotifications(
                device.deviceId,
                svc.uuid,
                char.uuid,
              );
              _storageDataSub = UniversalBle.characteristicValueStream(
                device.deviceId,
                char.uuid,
              ).listen(_onStorageData);
              _updateDiagnostic(
                _gattDiagnostic.copyWith(storageDataFound: true),
              );
            }
          }
        }
      }

      if (_writeCharUuid == null || _deviceNotifySub == null) {
        final detail =
            'Service=${_gattDiagnostic.serviceFound}, '
            'Write=${_gattDiagnostic.writeFound}, '
            'Notify=${_gattDiagnostic.deviceNotifyFound}, '
            'Stream=${_gattDiagnostic.streamDataFound}';
        _setStage(
          'GATT 特征不完整',
          error: detail,
          failureKind: 'missingService',
          currentStep: 'gatt_discovery',
        );
        final failedDiagnostic = _gattDiagnostic;
        await disconnect();
        _updateDiagnostic(failedDiagnostic);
        throw DbsConnectException(
          DbsConnectError.missingService,
          'DBS 服务或特征值不完整: $detail',
        );
      }

      _isConnected = true;
      _stateController.add(true);
      _setStage('BLE/GATT 已连接', clearError: true);
      return true;
    } on DbsConnectException {
      await _stopScanCleanup();
      _isConnected = false;
      _stateController.add(false);
      rethrow;
    } catch (e) {
      await _stopScanCleanup();
      _isConnected = false;
      _stateController.add(false);
      _setStage(
        _gattDiagnostic.connectionStage,
        error: e.toString(),
        failureKind: 'unknown',
      );
      throw DbsConnectException(DbsConnectError.unknown, 'DBS 连接异常: $e');
    }
  }

  Future<void> _connectBleDevice(
    DbsBluetoothDevice device, {
    required Duration timeout,
  }) async {
    _setStage('建立 BLE 连接: ${device.name}', currentStep: 'ble_connect');
    try {
      await UniversalBle.connect(device.deviceId, timeout: timeout);
      return;
    } catch (e) {
      final message = e.toString();
      _setStage(
        'BLE GATT 建立失败: ${device.name}',
        error: message,
        failureKind: 'bleConnectionFailed',
        currentStep: 'ble_connect',
      );
      if (message.toLowerCase().contains('unreachable')) {
        throw DbsConnectException(
          DbsConnectError.bleConnectionFailed,
          'Windows 无法建立 DBS 的 BLE GATT 连接(Unreachable)。请确认设备仍在广播且未被其他手机/电脑占用；'
          '如果系统蓝牙显示已连接但 App 未连接，请先在系统蓝牙中断开/删除该设备后让 App 独占连接。原始错误: $e',
        );
      }
      rethrow;
    }
  }

  Future<void> _ensurePaired(
    DbsBluetoothDevice device, {
    required Duration timeout,
  }) async {
    _setStage('检查 DBS 配对状态: ${device.name}', currentStep: 'pairing');
    bool? paired = device.paired;
    try {
      paired = await UniversalBle.isPaired(device.deviceId, timeout: timeout);
      _updateDiagnostic(_gattDiagnostic.copyWith(paired: paired));
    } catch (e) {
      _setStage('检查 DBS 配对状态: ${device.name}', error: e.toString());
    }

    if (paired == true) return;

    try {
      _setStage('配对 DBS: ${device.name}', currentStep: 'pairing');
      await UniversalBle.pair(device.deviceId, timeout: timeout);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final verified = await UniversalBle.isPaired(
        device.deviceId,
        timeout: const Duration(seconds: 8),
      );
      _updateDiagnostic(_gattDiagnostic.copyWith(paired: verified));
      if (verified == true) return;
      _setStage(
        'DBS 配对未完成',
        error: 'Windows 返回未配对',
        failureKind: 'pairingFailed',
        currentStep: 'pairing',
      );
      throw const DbsConnectException(
        DbsConnectError.pairingFailed,
        'DBS 配对未完成，请在 Windows 蓝牙中删除该设备后重新尝试',
      );
    } on DbsConnectException {
      rethrow;
    } catch (e) {
      _setStage(
        'DBS 配对失败: ${device.name}',
        error: e.toString(),
        failureKind: 'pairingFailed',
        currentStep: 'pairing',
      );
      throw DbsConnectException(
        DbsConnectError.pairingFailed,
        'DBS 配对失败。请确认 DBS 支持 LESC Just Works，且没有被其他手机/电脑绑定占用。原始错误: $e',
      );
    }
  }

  /// 连接成功后的初始状态查询：设备状态、感测配置、刺激参数和运行状态。
  Future<void> queryInitialState() async {
    if (!_isConnected) return;
    await sendCommand(DbsProtocol.commandDeviceStatus, const []);
    await sendCommand(DbsProtocol.commandSensingConfig, const []);
    await sendCommand(DbsProtocol.commandStimQuery, [
      DbsPdu(opcode: 0x00, data: DbsFrameCodec.u8(1)),
    ]);
    await sendCommand(DbsProtocol.commandRunStatus, const []);
  }

  /// 只发送压力分数，不等待 ACK。常规闭环转发优先使用等待 ACK 的版本。
  Future<void> sendStressScore(DbsStressScore score) async {
    await sendCommand(DbsProtocol.commandStressScore, [
      DbsPdu(opcode: 0x00, data: DbsFrameCodec.buildStressPayload(score)),
    ]);
  }

  /// 发送 HRV/STR 压力分数并等待 DBS 对应 opcode 的 ACK。
  Future<DbsCommandResult> sendStressScoreAndWaitAck(
    DbsStressScore score, {
    Duration timeout = const Duration(seconds: 3),
  }) {
    return sendCommandAndWaitAck(DbsProtocol.commandStressScore, [
      DbsPdu(opcode: 0x00, data: DbsFrameCodec.buildStressPayload(score)),
    ], timeout: timeout);
  }

  /// 下发刺激参数，不等待 ACK。控制页操作通常使用等待 ACK 的版本。
  Future<void> syncStimParams({
    required double intensityMa,
    required double frequencyHz,
    required double pulseWidthUs,
    int group = 1,
  }) async {
    await sendCommand(DbsProtocol.commandStimConfig, [
      DbsPdu(opcode: 0x00, data: DbsFrameCodec.u8(group)),
      DbsPdu(opcode: 0x01, data: DbsFrameCodec.u8(0)),
      DbsPdu(
        opcode: 0x02,
        data: DbsFrameCodec.buildStimFrequencyPayload(frequencyHz),
      ),
      DbsPdu(opcode: 0x03, data: DbsFrameCodec.u8(1)),
      DbsPdu(opcode: 0x04, data: Uint8List.fromList([0, 1])),
      DbsPdu(
        opcode: 0x05,
        data: DbsFrameCodec.buildStimIntensityPayload(intensityMa),
      ),
      DbsPdu(
        opcode: 0x06,
        data: DbsFrameCodec.buildStimPulseWidthPayload(pulseWidthUs),
      ),
    ]);
  }

  /// 下发刺激参数并等待每个 PDU 的 ACK。
  Future<DbsCommandResult> syncStimParamsAndWaitAck({
    required double intensityMa,
    required double frequencyHz,
    required double pulseWidthUs,
    int group = 1,
    Duration timeout = const Duration(seconds: 3),
  }) {
    return sendCommandAndWaitAck(DbsProtocol.commandStimConfig, [
      DbsPdu(opcode: 0x00, data: DbsFrameCodec.u8(group)),
      DbsPdu(opcode: 0x01, data: DbsFrameCodec.u8(0)),
      DbsPdu(
        opcode: 0x02,
        data: DbsFrameCodec.buildStimFrequencyPayload(frequencyHz),
      ),
      DbsPdu(opcode: 0x03, data: DbsFrameCodec.u8(1)),
      DbsPdu(opcode: 0x04, data: Uint8List.fromList([0, 1])),
      DbsPdu(
        opcode: 0x05,
        data: DbsFrameCodec.buildStimIntensityPayload(intensityMa),
      ),
      DbsPdu(
        opcode: 0x06,
        data: DbsFrameCodec.buildStimPulseWidthPayload(pulseWidthUs),
      ),
    ], timeout: timeout);
  }

  /// 下发刺激开关。E-STOP 当前复用关闭刺激命令。
  Future<void> setStimulatorEnabled(bool enabled) async {
    await sendCommand(DbsProtocol.commandRunConfig, [
      DbsPdu(opcode: 0x08, data: DbsFrameCodec.u8(enabled ? 1 : 0)),
    ]);
  }

  Future<DbsCommandResult> setStimulatorEnabledAndWaitAck(
    bool enabled, {
    Duration timeout = const Duration(seconds: 3),
  }) {
    return sendCommandAndWaitAck(DbsProtocol.commandRunConfig, [
      DbsPdu(opcode: 0x08, data: DbsFrameCodec.u8(enabled ? 1 : 0)),
    ], timeout: timeout);
  }

  Future<DbsCommandResult> emergencyStopAndWaitAck({
    Duration timeout = const Duration(seconds: 3),
  }) {
    return setStimulatorEnabledAndWaitAck(false, timeout: timeout);
  }

  /// 控制实时感测和 LFP 感测开关。
  Future<void> setSensingEnabled({
    required bool liveEnabled,
    required bool lfpEnabled,
  }) async {
    await sendCommand(DbsProtocol.commandRunConfig, [
      DbsPdu(opcode: 0x07, data: DbsFrameCodec.u8(liveEnabled ? 1 : 0)),
      DbsPdu(opcode: 0x0B, data: DbsFrameCodec.u8(lfpEnabled ? 1 : 0)),
    ]);
  }

  Future<DbsCommandResult> setSensingEnabledAndWaitAck({
    required bool liveEnabled,
    required bool lfpEnabled,
    Duration timeout = const Duration(seconds: 3),
  }) {
    return sendCommandAndWaitAck(DbsProtocol.commandRunConfig, [
      DbsPdu(opcode: 0x07, data: DbsFrameCodec.u8(liveEnabled ? 1 : 0)),
      DbsPdu(opcode: 0x0B, data: DbsFrameCodec.u8(lfpEnabled ? 1 : 0)),
    ], timeout: timeout);
  }

  /// 写命令后等待所有 PDU 对应的 ACK。超时通常表示 DBS 没有回 Notify，
  /// 或者返回 ACK 的 command/opcode 与待匹配项不一致。
  Future<DbsCommandResult> sendCommandAndWaitAck(
    int command,
    List<DbsPdu> pdus, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (pdus.isEmpty) {
      final now = DateTime.now();
      return DbsCommandResult.failure(
        command: command,
        opcode: 0,
        sentAt: now,
        message: '缺少 PDU',
      );
    }
    final sentAt = DateTime.now();
    final pending = [
      for (final pdu in pdus)
        _PendingDbsAck(
          command: command,
          opcode: pdu.opcode,
          sentAt: sentAt,
          completer: Completer<DbsAckEvent>(),
        ),
    ];
    _pendingAcks.addAll(pending);
    try {
      await sendCommand(command, pdus, ackRequested: true);
      final acks = await Future.wait(
        pending.map((item) => item.completer.future),
      ).timeout(timeout);
      for (final ack in acks) {
        if (!ack.isSuccess) {
          return DbsCommandResult.fromAck(ack, sentAt: sentAt);
        }
      }
      return DbsCommandResult.fromAck(acks.last, sentAt: sentAt);
    } on TimeoutException {
      _pendingAcks.removeWhere((item) => pending.contains(item));
      return DbsCommandResult.timeout(
        command: command,
        opcode: pdus.first.opcode,
        sentAt: sentAt,
      );
    } catch (e) {
      _pendingAcks.removeWhere((item) => pending.contains(item));
      return DbsCommandResult.failure(
        command: command,
        opcode: pdus.first.opcode,
        sentAt: sentAt,
        message: '发送失败: $e',
      );
    }
  }

  Future<void> sendCommand(
    int command,
    List<DbsPdu> pdus, {
    bool ackRequested = true,
  }) async {
    final deviceId = _deviceId;
    final serviceUuid = _writeServiceUuid;
    final charUuid = _writeCharUuid;
    if (deviceId == null || serviceUuid == null || charUuid == null) {
      throw StateError('DBS 写特征值不可用');
    }
    final frame = _codec.encode(
      command: command,
      pdus: pdus,
      ackRequested: ackRequested,
    );
    // 调试“发送了什么”时，可在这里给 frame 打断点或临时打印十六进制。
    await UniversalBle.write(
      deviceId,
      serviceUuid,
      charUuid,
      frame,
      withoutResponse: false,
    );
  }

  /// 释放订阅和连接资源。断开时清空 pending ACK，避免旧请求影响下次连接。
  Future<void> disconnect() async {
    await _deviceNotifySub?.cancel();
    _deviceNotifySub = null;
    await _streamDataSub?.cancel();
    _streamDataSub = null;
    await _storageDataSub?.cancel();
    _storageDataSub = null;
    await _connSub?.cancel();
    _connSub = null;
    if (_deviceId != null) {
      try {
        await UniversalBle.disconnect(_deviceId!);
      } catch (_) {}
    }
    _deviceId = null;
    _deviceName = null;
    _writeServiceUuid = null;
    _writeCharUuid = null;
    _updateDiagnostic(const DbsGattDiagnostic());
    _pendingAcks.clear();
    _isConnected = false;
    _stateController.add(false);
  }

  Future<void> _stopScanCleanup() async {
    _scanTimeout?.cancel();
    _scanTimeout = null;
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await UniversalBle.stopScan();
    } catch (_) {}
  }

  Future<DbsBluetoothDevice?> _scanForDbsDevice({
    required Duration timeout,
    required String stage,
    required String scanSource,
    ScanFilter? scanFilter,
    bool allowNameFallback = false,
  }) async {
    DbsBluetoothDevice? device;
    var seenCount = 0;
    var matchedCount = 0;
    String? lastCandidateSummary;
    final completer = Completer<DbsBluetoothDevice?>();

    _setStage(stage, currentStep: 'scan');
    _scanSub = UniversalBle.scanStream.listen(
      (result) {
        seenCount += 1;
        lastCandidateSummary = _scanResultSummary(result);
        final matches = _matchesDbsScanResult(
          result,
          allowNameFallback: allowNameFallback,
          acceptFilteredResult: scanFilter != null,
        );
        _updateDiagnostic(
          _gattDiagnostic.copyWith(
            scanSeenCount: seenCount,
            scanMatchedCount: matchedCount,
            lastCandidateSummary: lastCandidateSummary,
          ),
        );
        if (!matches) {
          return;
        }
        matchedCount += 1;
        device = _deviceFromBleResult(result, source: scanSource);
        _updateDiagnostic(
          _gattDiagnostic.copyWith(
            scanSource: scanSource,
            deviceName: device!.name,
            rssi: device!.rssi,
            paired: device!.paired,
            scanSeenCount: seenCount,
            scanMatchedCount: matchedCount,
            lastCandidateSummary: _deviceSummary(device!),
            advertisedServices: device!.services,
            manufacturerData: device!.manufacturerData,
            currentStep: 'scan_matched',
          ),
        );
        if (!completer.isCompleted) {
          completer.complete(device);
        }
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
    );

    _scanTimeout = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    try {
      await UniversalBle.startScan(scanFilter: scanFilter);
      device = await completer.future;
    } finally {
      await _stopScanCleanup();
    }
    if (device == null) {
      _setStage(
        '$stage 未命中',
        error:
            '扫描看到 $seenCount 个广播，匹配 DBS 0 个。最后候选: ${lastCandidateSummary ?? '无'}',
        currentStep: 'scan_timeout',
      );
    }
    return device;
  }

  Future<DbsBluetoothDevice?> _findConnectedSystemDbsDevice({
    required Duration timeout,
  }) async {
    try {
      _setStage('检查 Windows 已连接 DBS', currentStep: 'system_devices');
      final serviceDevices = await UniversalBle.getSystemDevices(
        withServices: [serviceUuid],
        timeout: timeout,
      );
      _updateDiagnostic(
        _gattDiagnostic.copyWith(systemDeviceCount: serviceDevices.length),
      );
      for (final result in serviceDevices) {
        final device = _deviceFromBleResult(
          result,
          source: 'Windows 系统已连接设备(Service UUID)',
        );
        _updateDiagnostic(
          _gattDiagnostic.copyWith(
            connectionStage: '发现 Windows 已连接 DBS',
            scanSource: device.source,
            deviceName: device.name,
            rssi: device.rssi,
            paired: device.paired,
            lastCandidateSummary: _deviceSummary(device),
            advertisedServices: device.services,
            manufacturerData: device.manufacturerData,
            currentStep: 'system_device_matched',
            clearLastError: true,
          ),
        );
        return device;
      }

      final devices = await UniversalBle.getSystemDevices(timeout: timeout);
      String? lastCandidateSummary;
      _updateDiagnostic(
        _gattDiagnostic.copyWith(systemDeviceCount: devices.length),
      );
      for (final result in devices) {
        lastCandidateSummary = _scanResultSummary(result);
        if (!_matchesDbsScanResult(
          result,
          allowNameFallback: true,
          acceptFilteredResult: false,
        )) {
          _updateDiagnostic(
            _gattDiagnostic.copyWith(
              lastCandidateSummary: lastCandidateSummary,
            ),
          );
          continue;
        }
        final device = _deviceFromBleResult(result, source: 'Windows 系统已连接设备');
        _updateDiagnostic(
          _gattDiagnostic.copyWith(
            connectionStage: '发现 Windows 已连接 DBS',
            scanSource: device.source,
            deviceName: device.name,
            rssi: device.rssi,
            paired: device.paired,
            lastCandidateSummary: _deviceSummary(device),
            advertisedServices: device.services,
            manufacturerData: device.manufacturerData,
            currentStep: 'system_device_matched',
            clearLastError: true,
          ),
        );
        return device;
      }
      _setStage(
        'Windows 已连接设备中未发现 DBS',
        error:
            '系统已连接设备 ${devices.length} 个，未发现 $serviceUuid 或 DBS Manufacturer/名称。最后候选: ${lastCandidateSummary ?? '无'}',
        currentStep: 'system_devices_not_found',
      );
    } catch (e) {
      _setStage('检查 Windows 已连接 DBS 失败，继续扫描广播', error: e.toString());
    }
    return null;
  }

  bool _matchesDbsScanResult(
    BleDevice result, {
    required bool allowNameFallback,
    required bool acceptFilteredResult,
  }) {
    if (acceptFilteredResult && !allowNameFallback) {
      return true;
    }

    final advertisedServices = result.services.map((s) => s.toUpperCase());
    if (advertisedServices.contains(serviceUuid)) {
      return true;
    }
    if (!allowNameFallback) return false;

    if (_matchesDbsManufacturerData(result)) {
      return true;
    }

    final name = (result.name ?? '').toLowerCase();
    return name.contains('dbs');
  }

  bool _matchesDbsManufacturerData(BleDevice result) {
    for (final data in result.manufacturerDataList) {
      if (data.companyId != _manufacturerCompanyId) continue;
      if (data.payload.isEmpty) continue;
      if (data.payload.first == _implantStimulatorDeviceType) {
        return true;
      }
    }
    return false;
  }

  DbsBluetoothDevice _deviceFromBleResult(
    BleDevice result, {
    required String source,
  }) {
    return DbsBluetoothDevice(
      deviceId: result.deviceId,
      name: result.name == null || result.name!.isEmpty
          ? 'DBS 设备'
          : result.name!,
      source: source,
      rssi: result.rssi,
      paired: result.paired,
      services: result.services.map((s) => s.toUpperCase()).toList(),
      manufacturerData: _manufacturerDataSummary(result),
    );
  }

  List<String> _manufacturerDataSummary(BleDevice result) {
    return result.manufacturerDataList.map((data) {
      final payload = data.payload
          .take(8)
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      return '0x${data.companyId.toRadixString(16).padLeft(4, '0')}: $payload';
    }).toList();
  }

  String _scanResultSummary(BleDevice result) {
    final name = result.name == null || result.name!.isEmpty
        ? '无名称'
        : result.name!;
    final services = result.services.isEmpty
        ? '无 Service 广播'
        : result.services.take(3).join(',');
    final manufacturer = _manufacturerDataSummary(result);
    final manufacturerText = manufacturer.isEmpty
        ? '无 Manufacturer'
        : manufacturer.take(2).join('; ');
    final rssi = result.rssi == null ? 'RSSI未知' : '${result.rssi} dBm';
    final paired = result.paired == null ? '配对未知' : 'paired=${result.paired}';
    return '$name · $rssi · $paired · $services · $manufacturerText';
  }

  String _deviceSummary(DbsBluetoothDevice device) {
    final services = device.services.isEmpty
        ? '无 Service 广播'
        : device.services.take(3).join(',');
    final manufacturer = device.manufacturerData.isEmpty
        ? '无 Manufacturer'
        : device.manufacturerData.take(2).join('; ');
    final rssi = device.rssi == null ? 'RSSI未知' : '${device.rssi} dBm';
    final paired = device.paired == null ? '配对未知' : 'paired=${device.paired}';
    return '${device.name} · ${device.source} · $rssi · $paired · $services · $manufacturer';
  }

  void _onDeviceNotify(Uint8List data) {
    _handleFrame(data, source: 'DeviceNotify');
  }

  /// Stream Data characteristic 专门承载 LFP 流；这里强制按 0xC0 分发。
  void _onStreamData(Uint8List data) {
    _handleFrame(data, source: 'StreamData', forceCommand: 0xC0);
  }

  void _onStorageData(Uint8List data) {
    _handleFrame(data, source: 'StorageData', forceCommand: 0xE0);
  }

  /// 统一处理 DBS 上行帧：先解码二进制帧，再按 command 转成业务事件。
  ///
  /// 调试“返回了什么”时，可在本函数入口查看 data 原始字节。
  void _handleFrame(
    Uint8List data, {
    required String source,
    int? forceCommand,
  }) {
    try {
      final decoded = _codec.decodeFrame(data);
      if (decoded == null) return;
      final frame = forceCommand == null || decoded.command == forceCommand
          ? decoded
          : DbsFrame(
              command: forceCommand,
              rollingCounter: decoded.rollingCounter,
              encrypted: decoded.encrypted,
              ackRequested: decoded.ackRequested,
              timestamp: decoded.timestamp,
              pdus: decoded.pdus,
              rawData: decoded.rawData,
            );
      final events = _eventsFromFrame(frame);
      for (final event in events) {
        if (event is DbsAckEvent) {
          _completePendingAck(event);
        }
        _eventController.add(event);
      }
    } on DbsEncryptedFrameException catch (e) {
      _eventController.addError(
        const DbsConnectException(
          DbsConnectError.encryptedUnsupported,
          'DBS 当前启用加密，本版本暂不支持',
        ),
      );
      debugPrint('[DBS] $source encrypted frame ignored: $e');
    } catch (e) {
      debugPrint('[DBS] $source parse failed: $e');
    }
  }

  /// 将收到的 ACK 与等待列表匹配。匹配条件是 command + opcode。
  void _completePendingAck(DbsAckEvent ack) {
    final index = _pendingAcks.indexWhere(
      (item) => item.command == ack.command && item.opcode == ack.opcode,
    );
    if (index < 0) return;
    final pending = _pendingAcks.removeAt(index);
    if (!pending.completer.isCompleted) {
      pending.completer.complete(ack);
    }
  }

  /// 把解码后的帧映射成 App 关心的事件。
  ///
  /// 状态类 command 转为状态对象；配置类 command 更新采样率；ACK 类 command
  /// 转成 DbsAckEvent；Stream Data 转成 LFP 采样块。
  List<DbsEvent> _eventsFromFrame(DbsFrame frame) {
    switch (frame.command) {
      case DbsProtocol.commandDeviceStatus:
        return [DbsFrameCodec.parseDeviceStatus(frame)];
      case DbsProtocol.commandSensingConfig:
        final config = DbsFrameCodec.parseSensingConfig(frame);
        _streamSampleRate =
            config.lfpSampleRate ?? config.liveSampleRate ?? 1000;
        return [config];
      case DbsProtocol.commandStimQuery:
        return [DbsFrameCodec.parseStimParams(frame)];
      case DbsProtocol.commandStimConfig:
        return frame.pdus
            .map(
              (pdu) => DbsAckEvent(
                command: frame.command,
                receivedAt: DateTime.now(),
                opcode: pdu.opcode,
                data: pdu.data,
              ),
            )
            .toList();
      case DbsProtocol.commandRunStatus:
        return [DbsFrameCodec.parseRunStatus(frame)];
      case DbsProtocol.commandRunConfig:
      case DbsProtocol.commandStressScore:
        return frame.pdus
            .map(
              (pdu) => DbsAckEvent(
                command: frame.command,
                receivedAt: DateTime.now(),
                opcode: pdu.opcode,
                data: pdu.data,
              ),
            )
            .toList();
      case DbsProtocol.commandStreamData:
        final event = DbsFrameCodec.parseStreamData(
          frame,
          sampleRate: _streamSampleRate,
        );
        return event == null ? const [] : [event];
      default:
        return frame.pdus
            .map(
              (pdu) => DbsAckEvent(
                command: frame.command,
                receivedAt: DateTime.now(),
                opcode: pdu.opcode,
                data: pdu.data,
              ),
            )
            .toList();
    }
  }

  void dispose() {
    _scanTimeout?.cancel();
    _scanSub?.cancel();
    _connSub?.cancel();
    _deviceNotifySub?.cancel();
    _streamDataSub?.cancel();
    _storageDataSub?.cancel();
    _eventController.close();
    _stateController.close();
    _diagnosticController.close();
  }
}

/// 等待中的 ACK 请求。sendCommandAndWaitAck 会为每个 PDU 建一个等待项。
class _PendingDbsAck {
  final int command;
  final int opcode;
  final DateTime sentAt;
  final Completer<DbsAckEvent> completer;

  const _PendingDbsAck({
    required this.command,
    required this.opcode,
    required this.sentAt,
    required this.completer,
  });
}

/// 扫描阶段缓存的 DBS 设备标识。
class DbsBluetoothDevice {
  final String deviceId;
  final String name;
  final String source;
  final int? rssi;
  final bool? paired;
  final List<String> services;
  final List<String> manufacturerData;

  const DbsBluetoothDevice({
    required this.deviceId,
    required this.name,
    required this.source,
    this.rssi,
    this.paired,
    this.services = const [],
    this.manufacturerData = const [],
  });
}
