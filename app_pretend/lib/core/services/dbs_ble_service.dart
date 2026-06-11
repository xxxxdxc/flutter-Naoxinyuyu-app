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

  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;
  StreamSubscription? _deviceNotifySub;
  StreamSubscription? _streamDataSub;
  StreamSubscription? _storageDataSub;
  Timer? _scanTimeout;

  bool get isConnected => _isConnected;
  String? get deviceName => _deviceName;

  Future<bool> connect({Duration timeout = const Duration(seconds: 15)}) async {
    try {
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

      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: [serviceUuid]),
      );

      DbsBluetoothDevice? device;
      final completer = Completer<DbsBluetoothDevice?>();

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

      await UniversalBle.connect(device!.deviceId, timeout: timeout);
      final services = await UniversalBle.discoverServices(
        device!.deviceId,
        withDescriptors: true,
      );

      for (final svc in services) {
        if (svc.uuid.toUpperCase() != serviceUuid) continue;
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
          }

          if (props.contains(CharacteristicProperty.notify)) {
            if (charUuid == deviceNotifyCharUuid) {
              await UniversalBle.subscribeNotifications(
                device!.deviceId,
                svc.uuid,
                char.uuid,
              );
              _deviceNotifySub = UniversalBle.characteristicValueStream(
                device!.deviceId,
                char.uuid,
              ).listen(_onDeviceNotify);
            } else if (charUuid == streamDataCharUuid) {
              await UniversalBle.subscribeNotifications(
                device!.deviceId,
                svc.uuid,
                char.uuid,
              );
              _streamDataSub = UniversalBle.characteristicValueStream(
                device!.deviceId,
                char.uuid,
              ).listen(_onStreamData);
            } else if (charUuid == storageDataCharUuid) {
              await UniversalBle.subscribeNotifications(
                device!.deviceId,
                svc.uuid,
                char.uuid,
              );
              _storageDataSub = UniversalBle.characteristicValueStream(
                device!.deviceId,
                char.uuid,
              ).listen(_onStorageData);
            }
          }
        }
      }

      if (_writeCharUuid == null || _deviceNotifySub == null) {
        await disconnect();
        throw const DbsConnectException(
          DbsConnectError.missingService,
          'DBS 服务或特征值不完整',
        );
      }

      _isConnected = true;
      _stateController.add(true);
      await queryInitialState();
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

  Future<void> setStimulatorEnabled(bool enabled) async {
    await sendCommand(DbsProtocol.commandRunConfig, [
      DbsPdu(opcode: 0x08, data: DbsFrameCodec.u8(enabled ? 1 : 0)),
    ]);
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

class DbsBluetoothDevice {
  final String deviceId;
  final String name;

  const DbsBluetoothDevice({required this.deviceId, required this.name});
}
