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
  missingService,
  encryptedUnsupported,
  unknown,
}

class DbsConnectException implements Exception {
  final DbsConnectError error;
  final String message;

  const DbsConnectException(this.error, this.message);

  @override
  String toString() => message;
}

class DbsBleService {
  static const String serviceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9F';
  static const String writeConfigCharUuid =
      '6E400002-B5A3-F393-E0A9-E50E24DCCA9F';
  static const String deviceNotifyCharUuid =
      '6E400003-B5A3-F393-E0A9-E50E24DCCA9F';
  static const String streamDataCharUuid =
      '6E400004-B5A3-F393-E0A9-E50E24DCCA9F';
  static const String storageDataCharUuid =
      '6E400005-B5A3-F393-E0A9-E50E24DCCA9F';

  final DbsFrameCodec _codec;

  DbsBleService({DbsFrameCodec? codec}) : _codec = codec ?? DbsFrameCodec();

  final StreamController<DbsEvent> _eventController =
      StreamController<DbsEvent>.broadcast();
  final StreamController<bool> _stateController =
      StreamController<bool>.broadcast();

  Stream<DbsEvent> get eventStream => _eventController.stream;
  Stream<bool> get connectionStateStream => _stateController.stream;

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

  void _setStage(String stage, {String? error, bool clearError = false}) {
    _gattDiagnostic = _gattDiagnostic.copyWith(
      connectionStage: stage,
      lastError: error,
      clearLastError: clearError,
    );
  }

  Future<bool> connect({Duration timeout = const Duration(seconds: 15)}) async {
    try {
      _gattDiagnostic = const DbsGattDiagnostic(
        connectionStage: '检查蓝牙状态',
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
      final completer = Completer<DbsBluetoothDevice?>();

      _setStage('扫描 DBS 广播');
      _scanSub = UniversalBle.scanStream.listen(
        (result) {
          final name = result.name ?? 'DBS 设备';
          device = DbsBluetoothDevice(deviceId: result.deviceId, name: name);
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

      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: [serviceUuid]),
      );

      _scanTimeout = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      device = await completer.future;
      await _stopScanCleanup();
      if (device == null) {
        throw const DbsConnectException(
          DbsConnectError.deviceNotFound,
          '未找到 DBS 设备',
        );
      }

      _deviceId = device!.deviceId;
      _deviceName = device!.name;
      _codec.resetCounter();
      _gattDiagnostic = const DbsGattDiagnostic(connectionStage: '连接 DBS');

      _connSub = UniversalBle.connectionStream(device!.deviceId).listen(
        (connected) {
          _isConnected = connected;
          _stateController.add(connected);
        },
        onError: (_) {
          _isConnected = false;
          _stateController.add(false);
        },
      );

      _setStage('建立 BLE 连接');
      await UniversalBle.connect(device!.deviceId, timeout: timeout);
      try {
        _setStage('协商 MTU');
        final mtu = await UniversalBle.requestMtu(device!.deviceId, 247);
        _gattDiagnostic = _gattDiagnostic.copyWith(mtuStatus: 'MTU $mtu');
      } catch (e) {
        _gattDiagnostic = _gattDiagnostic.copyWith(mtuStatus: 'MTU 协商失败: $e');
      }
      _setStage('发现 GATT 服务');
      final services = await UniversalBle.discoverServices(
        device!.deviceId,
        withDescriptors: true,
      );

      for (final svc in services) {
        if (svc.uuid.toUpperCase() != serviceUuid) continue;
        _gattDiagnostic = _gattDiagnostic.copyWith(serviceFound: true);
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
            _gattDiagnostic = _gattDiagnostic.copyWith(writeFound: true);
          }

          if (props.contains(CharacteristicProperty.notify)) {
            if (charUuid == deviceNotifyCharUuid) {
              _setStage('订阅 Device Notify');
              await UniversalBle.subscribeNotifications(
                device!.deviceId,
                svc.uuid,
                char.uuid,
              );
              _deviceNotifySub = UniversalBle.characteristicValueStream(
                device!.deviceId,
                char.uuid,
              ).listen(_onDeviceNotify);
              _gattDiagnostic = _gattDiagnostic.copyWith(
                deviceNotifyFound: true,
              );
            } else if (charUuid == streamDataCharUuid) {
              _setStage('订阅 Stream Data');
              await UniversalBle.subscribeNotifications(
                device!.deviceId,
                svc.uuid,
                char.uuid,
              );
              _streamDataSub = UniversalBle.characteristicValueStream(
                device!.deviceId,
                char.uuid,
              ).listen(_onStreamData);
              _gattDiagnostic = _gattDiagnostic.copyWith(streamDataFound: true);
            } else if (charUuid == storageDataCharUuid) {
              _setStage('订阅 Storage Data');
              await UniversalBle.subscribeNotifications(
                device!.deviceId,
                svc.uuid,
                char.uuid,
              );
              _storageDataSub = UniversalBle.characteristicValueStream(
                device!.deviceId,
                char.uuid,
              ).listen(_onStorageData);
              _gattDiagnostic = _gattDiagnostic.copyWith(
                storageDataFound: true,
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
        _setStage('GATT 特征不完整', error: detail);
        final failedDiagnostic = _gattDiagnostic;
        await disconnect();
        _gattDiagnostic = failedDiagnostic;
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
      _setStage(_gattDiagnostic.connectionStage, error: e.toString());
      throw DbsConnectException(DbsConnectError.unknown, 'DBS 连接异常: $e');
    }
  }

  Future<void> queryInitialState() async {
    if (!_isConnected) return;
    await sendCommand(DbsProtocol.commandDeviceStatus, const []);
    await sendCommand(DbsProtocol.commandSensingConfig, const []);
    await sendCommand(DbsProtocol.commandStimQuery, [
      DbsPdu(opcode: 0x00, data: DbsFrameCodec.u8(1)),
    ]);
    await sendCommand(DbsProtocol.commandRunStatus, const []);
  }

  Future<void> sendStressScore(DbsStressScore score) async {
    await sendCommand(DbsProtocol.commandStressScore, [
      DbsPdu(opcode: 0x00, data: DbsFrameCodec.buildStressPayload(score)),
    ]);
  }

  Future<DbsCommandResult> sendStressScoreAndWaitAck(
    DbsStressScore score, {
    Duration timeout = const Duration(seconds: 3),
  }) {
    return sendCommandAndWaitAck(DbsProtocol.commandStressScore, [
      DbsPdu(opcode: 0x00, data: DbsFrameCodec.buildStressPayload(score)),
    ], timeout: timeout);
  }

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
    await UniversalBle.write(
      deviceId,
      serviceUuid,
      charUuid,
      frame,
      withoutResponse: false,
    );
  }

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
    _gattDiagnostic = const DbsGattDiagnostic();
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

  void _onDeviceNotify(Uint8List data) {
    _handleFrame(data, source: 'DeviceNotify');
  }

  void _onStreamData(Uint8List data) {
    _handleFrame(data, source: 'StreamData', forceCommand: 0xC0);
  }

  void _onStorageData(Uint8List data) {
    _handleFrame(data, source: 'StorageData', forceCommand: 0xE0);
  }

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
  }
}

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

class DbsBluetoothDevice {
  final String deviceId;
  final String name;

  const DbsBluetoothDevice({required this.deviceId, required this.name});
}
