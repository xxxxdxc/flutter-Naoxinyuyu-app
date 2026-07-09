import 'dart:convert';
import 'dart:typed_data';

import 'dbs_models.dart';

/// DBS 二进制协议的集中编解码器。
///
/// 这里负责把 App 内部的 command + PDU 列表打包成 BLE 写入字节，
/// 也负责把 DBS Notify / Stream Data 的原始字节解析成结构化事件数据。
class DbsFrameCodec {
  static const int preamble = 0xA5;
  static const int maxPlainDataLength = 232;
  static const int headerLength = 12;

  int _txCounter = 0;

  Uint8List encode({
    required int command,
    required List<DbsPdu> pdus,
    bool ackRequested = true,
    bool encrypted = false,
    DateTime? timestamp,
  }) {
    // PDU 区格式：opcode(1B) + length(2B, big-endian) + data(NB)。
    final dataBuilder = BytesBuilder(copy: false);
    for (final pdu in pdus) {
      dataBuilder.addByte(pdu.opcode & 0xFF);
      dataBuilder.add(_u16(pdu.length));
      dataBuilder.add(pdu.data);
    }
    final data = dataBuilder.toBytes();
    if (data.length > maxPlainDataLength) {
      throw ArgumentError.value(
        data.length,
        'data.length',
        'DBS single-frame data is limited to $maxPlainDataLength bytes',
      );
    }

    final frameTimestamp = timestamp ?? DateTime.now();
    final seconds = frameTimestamp.millisecondsSinceEpoch ~/ 1000;
    final millis = frameTimestamp.millisecondsSinceEpoch % 1000;
    final rolling = _txCounter & 0x0F;
    _txCounter = (_txCounter + 1) & 0x0F;

    // flags 高 4 位为 rolling counter，低位分别标记加密和是否请求 ACK。
    final flags =
        (rolling << 4) |
        ((encrypted ? 1 : 0) << 3) |
        ((ackRequested ? 1 : 0) << 2);

    final builder = BytesBuilder(copy: false)
      ..addByte(preamble)
      ..addByte(flags)
      ..addByte(command & 0xFF)
      ..add(_u32(seconds))
      ..add(_u16(millis))
      ..addByte(1)
      ..addByte(1)
      ..addByte(data.length)
      ..add(data);

    return builder.toBytes();
  }

  /// 解析 DBS 返回的一帧数据。
  ///
  /// 当前实现只支持单包明文帧；如果固件开启加密或分包，需要在这里扩展。
  DbsFrame? decodeFrame(List<int> bytes) {
    if (bytes.length < headerLength) return null;
    if (bytes[0] != preamble) return null;

    final flags = bytes[1];
    final encrypted = ((flags >> 3) & 0x01) == 1;
    if (encrypted) {
      throw const DbsEncryptedFrameException();
    }

    final rolling = (flags >> 4) & 0x0F;
    final ackRequested = ((flags >> 2) & 0x01) == 1;
    final command = bytes[2];
    final seconds = _readU32(bytes, 3);
    final millis = _readU16(bytes, 7);
    final totalPacket = bytes[9];
    final currentPacket = bytes[10];
    final dataLength = bytes[11];

    if (totalPacket != 1 || currentPacket != 1) {
      throw DbsUnsupportedFrameException(
        'Multi-packet DBS frame is not supported yet: $currentPacket/$totalPacket',
      );
    }
    if (bytes.length < headerLength + dataLength) return null;

    final data = Uint8List.fromList(
      bytes.sublist(headerLength, headerLength + dataLength),
    );
    final pdus = _decodePdus(data);
    return DbsFrame(
      command: command,
      rollingCounter: rolling,
      encrypted: encrypted,
      ackRequested: ackRequested,
      timestamp: DateTime.fromMillisecondsSinceEpoch(seconds * 1000 + millis),
      pdus: pdus,
      rawData: data,
    );
  }

  /// 将帧内 data 区拆成多个 PDU。长度不完整时停止解析，避免数组越界。
  List<DbsPdu> _decodePdus(Uint8List data) {
    final pdus = <DbsPdu>[];
    var offset = 0;
    while (offset + 3 <= data.length) {
      final opcode = data[offset];
      final length = _readU16(data, offset + 1);
      offset += 3;
      if (offset + length > data.length) break;
      pdus.add(
        DbsPdu(
          opcode: opcode,
          data: Uint8List.fromList(data.sublist(offset, offset + length)),
        ),
      );
      offset += length;
    }
    return pdus;
  }

  void resetCounter() {
    _txCounter = 0;
  }

  /// 构造 HRV/STR 压力分数载荷，供 DBS 闭环算法作为辅助输入。
  static Uint8List buildStressPayload(DbsStressScore score) {
    final builder = BytesBuilder(copy: false)
      ..addByte(score.smoothedPercent)
      ..addByte(score.rawPercent)
      ..addByte(score.isStressed ? 1 : 0)
      ..addByte(score.engineState & 0xFF)
      ..add(_u32(score.inferCount.clamp(0, 0xFFFFFFFF)));
    return builder.toBytes();
  }

  static Uint8List buildStimFrequencyPayload(double frequencyHz) {
    return _u16(frequencyHz.round().clamp(2, 250));
  }

  static Uint8List buildStimIntensityPayload(double intensity) {
    final clamped = intensity.clamp(0.0, 25.5).toDouble();
    final data = ByteData(4)..setFloat32(0, clamped, Endian.big);
    return data.buffer.asUint8List();
  }

  static Uint8List buildStimPulseWidthPayload(double pulseWidthUs) {
    final value = pulseWidthUs.round().clamp(20, 450);
    return Uint8List.fromList([..._u16(value), ..._u16(value)]);
  }

  static Uint8List u8(int value) => Uint8List.fromList([value & 0xFF]);

  static Uint8List u16(int value) => _u16(value);

  static Uint8List _u16(int value) {
    final data = ByteData(2)..setUint16(0, value, Endian.big);
    return data.buffer.asUint8List();
  }

  static Uint8List _u32(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.big);
    return data.buffer.asUint8List();
  }

  static int _readU16(List<int> data, int offset) {
    return ByteData.sublistView(
      Uint8List.fromList(data),
      offset,
      offset + 2,
    ).getUint16(0, Endian.big);
  }

  static int _readI16(List<int> data, int offset) {
    return ByteData.sublistView(
      Uint8List.fromList(data),
      offset,
      offset + 2,
    ).getInt16(0, Endian.big);
  }

  static int _readU32(List<int> data, int offset) {
    return ByteData.sublistView(
      Uint8List.fromList(data),
      offset,
      offset + 4,
    ).getUint32(0, Endian.big);
  }

  static double _readFloat32(List<int> data, int offset) {
    return ByteData.sublistView(
      Uint8List.fromList(data),
      offset,
      offset + 4,
    ).getFloat32(0, Endian.big);
  }

  static String readUtf8(List<int> data) {
    return utf8.decode(data, allowMalformed: true).replaceAll('\u0000', '');
  }

  /// 解析设备状态 PDU。每个 opcode 对应固件上报的一个状态字段。
  static DbsDeviceStatus parseDeviceStatus(DbsFrame frame) {
    DbsDeviceStatus status = DbsDeviceStatus(receivedAt: DateTime.now());
    for (final pdu in frame.pdus) {
      final data = pdu.data;
      switch (pdu.opcode) {
        case 0x00:
          status = status.merge(
            DbsDeviceStatus(
              receivedAt: DateTime.now(),
              hardwareVersion: readUtf8(data),
            ),
          );
        case 0x01:
          status = status.merge(
            DbsDeviceStatus(
              receivedAt: DateTime.now(),
              firmwareVersion: readUtf8(data),
            ),
          );
        case 0x03:
          if (data.isNotEmpty) {
            status = status.merge(
              DbsDeviceStatus(
                receivedAt: DateTime.now(),
                batteryPercent: data[0],
              ),
            );
          }
        case 0x04:
          if (data.isNotEmpty) {
            status = status.merge(
              DbsDeviceStatus(
                receivedAt: DateTime.now(),
                chargeIndicator: data[0],
              ),
            );
          }
        case 0x05:
          if (data.length >= 2) {
            status = status.merge(
              DbsDeviceStatus(
                receivedAt: DateTime.now(),
                chargeCurrentMa: _readU16(data, 0),
              ),
            );
          }
        case 0x06:
          if (data.length >= 2) {
            status = status.merge(
              DbsDeviceStatus(
                receivedAt: DateTime.now(),
                chargeVoltageMv: _readU16(data, 0),
              ),
            );
          }
        case 0x08:
          if (data.length >= 2) {
            status = status.merge(
              DbsDeviceStatus(
                receivedAt: DateTime.now(),
                deviceTemperatureC: _readI16(data, 0) / 10.0,
              ),
            );
          }
        case 0x09:
          if (data.length >= 2) {
            status = status.merge(
              DbsDeviceStatus(
                receivedAt: DateTime.now(),
                batteryCycle: _readU16(data, 0),
              ),
            );
          }
        case 0x0A:
          if (data.isNotEmpty) {
            status = status.merge(
              DbsDeviceStatus(
                receivedAt: DateTime.now(),
                waterIngress: data[0],
              ),
            );
          }
        case 0x0D:
          if (data.isNotEmpty) {
            status = status.merge(
              DbsDeviceStatus(receivedAt: DateTime.now(), deviceType: data[0]),
            );
          }
        case 0x0E:
          if (data.isNotEmpty) {
            status = status.merge(
              DbsDeviceStatus(
                receivedAt: DateTime.now(),
                humidityPercent: data[0],
              ),
            );
          }
        case 0x0F:
          if (data.length >= 2) {
            status = status.merge(
              DbsDeviceStatus(
                receivedAt: DateTime.now(),
                batteryVoltageMv: _readU16(data, 0),
              ),
            );
          }
      }
    }
    return status;
  }

  /// 解析感测配置，LFP 采样率会影响后续波形时间轴。
  static DbsSensingConfig parseSensingConfig(DbsFrame frame) {
    int? liveMask;
    int? liveRate;
    int? lfpMask;
    int? lfpRate;
    for (final pdu in frame.pdus) {
      final data = pdu.data;
      if (data.length < 2) continue;
      switch (pdu.opcode) {
        case 0x00:
          liveMask = _readU16(data, 0);
        case 0x01:
          liveRate = _readU16(data, 0);
        case 0x04:
          lfpMask = _readU16(data, 0);
        case 0x05:
          lfpRate = _readU16(data, 0);
      }
    }
    return DbsSensingConfig(
      receivedAt: DateTime.now(),
      liveChannelMask: liveMask,
      liveSampleRate: liveRate,
      lfpChannelMask: lfpMask,
      lfpSampleRate: lfpRate,
    );
  }

  /// 解析刺激参数回读或配置反馈，用于同步控制页显示。
  static DbsStimParams parseStimParams(DbsFrame frame) {
    var group = 1;
    var method = 0;
    var frequency = 130.0;
    var intensity = 2.5;
    var pulseWidth = 60.0;
    for (final pdu in frame.pdus) {
      final data = pdu.data;
      switch (pdu.opcode) {
        case 0x00:
          if (data.isNotEmpty) group = data[0];
        case 0x01:
          if (data.isNotEmpty) method = data[0];
        case 0x02:
          if (data.length >= 2) frequency = _readU16(data, 0).toDouble();
        case 0x05:
          if (data.length >= 4) intensity = _readFloat32(data, 0);
        case 0x06:
          if (data.length >= 2) pulseWidth = _readU16(data, 0).toDouble();
      }
    }
    return DbsStimParams(
      receivedAt: DateTime.now(),
      group: group,
      method: method,
      frequencyHz: frequency,
      intensity: intensity,
      pulseWidthUs: pulseWidth,
    );
  }

  /// 解析运行开关状态。bitmask 和单独 opcode 都可能携带相同开关信息。
  static DbsRunStatus parseRunStatus(DbsFrame frame) {
    int? bitmask;
    int? activeGroup;
    bool? liveSampleOn;
    bool? stimulateOn;
    bool? impedanceOn;
    bool? lfpSampleOn;
    for (final pdu in frame.pdus) {
      final data = pdu.data;
      switch (pdu.opcode) {
        case 0x00:
          if (data.length >= 2) {
            bitmask = _readU16(data, 0);
            liveSampleOn = (bitmask & (1 << 0)) != 0;
            stimulateOn = (bitmask & (1 << 1)) != 0;
            impedanceOn = (bitmask & (1 << 2)) != 0;
            lfpSampleOn = (bitmask & (1 << 4)) != 0;
          }
        case 0x01:
          if (data.isNotEmpty) activeGroup = data[0];
        case 0x07:
          if (data.isNotEmpty) liveSampleOn = data[0] != 0;
        case 0x08:
          if (data.isNotEmpty) stimulateOn = data[0] != 0;
        case 0x09:
          if (data.isNotEmpty) impedanceOn = data[0] != 0;
        case 0x0B:
          if (data.isNotEmpty) lfpSampleOn = data[0] != 0;
      }
    }
    return DbsRunStatus(
      receivedAt: DateTime.now(),
      switchBitmask: bitmask,
      activeGroup: activeGroup,
      liveSampleOn: liveSampleOn,
      stimulateOn: stimulateOn,
      impedanceOn: impedanceOn,
      lfpSampleOn: lfpSampleOn,
    );
  }

  /// 解析 Stream Data 中的 LFP 数据块。
  ///
  /// PDU 0x00 的 data 布局为：
  /// seconds(4B) + millis(2B) + channelMask(2B) + sampleCount(1B)
  /// + 按采样点交织排列的 int16 通道样本。
  static DbsStreamData? parseStreamData(
    DbsFrame frame, {
    int sampleRate = 1000,
  }) {
    DbsPdu? pdu;
    for (final candidate in frame.pdus) {
      if (candidate.opcode == 0x00) {
        pdu = candidate;
        break;
      }
    }
    if (pdu == null || pdu.data.length < 9) return null;
    final data = pdu.data;
    final seconds = _readU32(data, 0);
    final millis = _readU16(data, 4);
    final channelMask = _readU16(data, 6);
    final sampleCount = data[8];
    final channels = <int>[
      for (var bit = 0; bit < 16; bit++)
        if ((channelMask & (1 << bit)) != 0) bit + 1,
    ];
    final expectedLength = 9 + channels.length * sampleCount * 2;
    if (data.length < expectedLength) return null;

    final channelSamples = <int, List<double>>{
      for (final channel in channels) channel: <double>[],
    };
    // 样本按 datapoint -> channel 的顺序交织，按 channelMask 拆回各通道数组。
    var offset = 9;
    for (var dp = 0; dp < sampleCount; dp++) {
      for (final channel in channels) {
        channelSamples[channel]!.add(_readI16(data, offset).toDouble());
        offset += 2;
      }
    }

    return DbsStreamData(
      receivedAt: DateTime.now(),
      sampleTimestamp: DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + millis,
      ),
      channelMask: channelMask,
      sampleCount: sampleCount,
      sampleRate: sampleRate,
      channelSamples: channelSamples,
    );
  }
}

class DbsEncryptedFrameException implements Exception {
  const DbsEncryptedFrameException();

  @override
  String toString() => 'Encrypted DBS frames are not supported in this build.';
}

class DbsUnsupportedFrameException implements Exception {
  final String message;
  const DbsUnsupportedFrameException(this.message);

  @override
  String toString() => message;
}
