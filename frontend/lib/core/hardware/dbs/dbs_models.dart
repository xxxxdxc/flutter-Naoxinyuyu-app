import 'dart:typed_data';

/// DBS 固件约定的业务命令字。
///
/// 这些值会直接进入二进制帧的 command 字段，联调时必须和固件协议保持一致。
class DbsProtocol {
  static const int commandDeviceStatus = 0x03;
  static const int commandSensingConfig = 0x06;
  static const int commandStimQuery = 0x08;
  static const int commandStimConfig = 0x09;
  static const int commandRunStatus = 0x0C;
  static const int commandRunConfig = 0x0D;
  static const int commandStressScore = 0x12;
  static const int commandStreamData = 0xC0;
  static const int commandStorageData = 0xE0;
}

/// 一条 DBS 帧内的参数单元：opcode 表示字段含义，data 存放该字段的原始字节。
class DbsPdu {
  final int opcode;
  final Uint8List data;

  const DbsPdu({required this.opcode, required this.data});

  int get length => data.length;
}

/// 编解码层使用的完整 DBS 帧模型。
///
/// 上层业务一般不直接拼接这个对象，而是通过 [DbsFrameCodec] 在二进制帧和事件之间转换。
class DbsFrame {
  final int command;
  final int rollingCounter;
  final bool encrypted;
  final bool ackRequested;
  final DateTime timestamp;
  final List<DbsPdu> pdus;
  final Uint8List rawData;

  const DbsFrame({
    required this.command,
    required this.rollingCounter,
    required this.encrypted,
    required this.ackRequested,
    required this.timestamp,
    required this.pdus,
    required this.rawData,
  });
}

/// DBS 上行数据在 App 内统一转成事件流。
///
/// 连接层只负责解析和分发事件，页面状态由 GlobalAppState 订阅这些事件后更新。
abstract class DbsEvent {
  final int command;
  final DateTime receivedAt;

  const DbsEvent({required this.command, required this.receivedAt});
}

/// 固件对某个 command/opcode 的确认或错误反馈。
class DbsAckEvent extends DbsEvent {
  final int opcode;
  final Uint8List data;

  const DbsAckEvent({
    required super.command,
    required super.receivedAt,
    required this.opcode,
    required this.data,
  });

  bool get isSuccess => data.isEmpty || !DbsAckStatus.isErrorCode(data.first);
  int get statusCode => data.isEmpty ? DbsAckStatus.success : data.first;
  String get statusLabel => isSuccess
      ? DbsAckStatus.labelFor(DbsAckStatus.success)
      : DbsAckStatus.labelFor(statusCode);
}

/// ACK 首字节的状态码映射。0x80 以上按错误码处理。
class DbsAckStatus {
  static const int success = 0x00;
  static const int formatError = 0x80;
  static const int flashError = 0x81;
  static const int stateError = 0x82;

  static bool isErrorCode(int code) => code >= 0x80;

  static String labelFor(int code) {
    switch (code) {
      case success:
        return '成功';
      case formatError:
        return '格式错误';
      case flashError:
        return '存储错误';
      case stateError:
        return '状态错误';
      default:
        return '未知错误 0x${code.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    }
  }
}

enum DbsCommandResultType { idle, sending, success, failed, timeout }

/// App 下发 DBS 命令后的用户可读结果。
///
/// 这个对象用于控制页提示、历史记录和超时排查，不参与底层协议编码。
class DbsCommandResult {
  final int command;
  final int opcode;
  final DbsCommandResultType type;
  final int? statusCode;
  final String message;
  final DateTime sentAt;
  final DateTime? receivedAt;

  const DbsCommandResult({
    required this.command,
    required this.opcode,
    required this.type,
    required this.message,
    required this.sentAt,
    this.statusCode,
    this.receivedAt,
  });

  bool get isSuccess => type == DbsCommandResultType.success;
  bool get isPending => type == DbsCommandResultType.sending;

  String get statusText {
    switch (type) {
      case DbsCommandResultType.idle:
        return '未发送';
      case DbsCommandResultType.sending:
        return '发送中';
      case DbsCommandResultType.success:
        return message;
      case DbsCommandResultType.failed:
        return message;
      case DbsCommandResultType.timeout:
        return '发送超时';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'command': command,
      'opcode': opcode,
      'type': type.name,
      'statusCode': statusCode,
      'message': message,
      'sentAt': sentAt.toIso8601String(),
      'receivedAt': receivedAt?.toIso8601String(),
    };
  }

  static DbsCommandResult sending({
    required int command,
    required int opcode,
    required DateTime sentAt,
    String message = '发送中',
  }) {
    return DbsCommandResult(
      command: command,
      opcode: opcode,
      type: DbsCommandResultType.sending,
      message: message,
      sentAt: sentAt,
    );
  }

  static DbsCommandResult fromAck(DbsAckEvent ack, {DateTime? sentAt}) {
    final code = ack.statusCode;
    final ok = ack.isSuccess;
    return DbsCommandResult(
      command: ack.command,
      opcode: ack.opcode,
      type: ok ? DbsCommandResultType.success : DbsCommandResultType.failed,
      statusCode: code,
      message: ok ? 'DBS 已接收' : DbsAckStatus.labelFor(code),
      sentAt: sentAt ?? ack.receivedAt,
      receivedAt: ack.receivedAt,
    );
  }

  static DbsCommandResult timeout({
    required int command,
    required int opcode,
    required DateTime sentAt,
  }) {
    return DbsCommandResult(
      command: command,
      opcode: opcode,
      type: DbsCommandResultType.timeout,
      message: '发送超时',
      sentAt: sentAt,
    );
  }

  static DbsCommandResult failure({
    required int command,
    required int opcode,
    required DateTime sentAt,
    required String message,
  }) {
    return DbsCommandResult(
      command: command,
      opcode: opcode,
      type: DbsCommandResultType.failed,
      message: message,
      sentAt: sentAt,
    );
  }
}

/// GATT 发现和连接阶段的诊断快照。
///
/// 如果 DBS 连接失败，先看这里能否找到 Service、Write、Notify 和 Stream 特征。
class DbsGattDiagnostic {
  final bool serviceFound;
  final bool writeFound;
  final bool deviceNotifyFound;
  final bool streamDataFound;
  final bool storageDataFound;
  final String mtuStatus;
  final String connectionStage;
  final String? lastError;
  final String? scanSource;
  final String? deviceName;
  final int? rssi;
  final bool? paired;
  final String failureKind;
  final String currentStep;
  final int systemDeviceCount;
  final int scanSeenCount;
  final int scanMatchedCount;
  final String? lastCandidateSummary;
  final List<String> advertisedServices;
  final List<String> manufacturerData;

  const DbsGattDiagnostic({
    this.serviceFound = false,
    this.writeFound = false,
    this.deviceNotifyFound = false,
    this.streamDataFound = false,
    this.storageDataFound = false,
    this.mtuStatus = 'MTU 未协商/插件不支持',
    this.connectionStage = '未开始',
    this.lastError,
    this.scanSource,
    this.deviceName,
    this.rssi,
    this.paired,
    this.failureKind = 'none',
    this.currentStep = 'idle',
    this.systemDeviceCount = 0,
    this.scanSeenCount = 0,
    this.scanMatchedCount = 0,
    this.lastCandidateSummary,
    this.advertisedServices = const [],
    this.manufacturerData = const [],
  });

  DbsGattDiagnostic copyWith({
    bool? serviceFound,
    bool? writeFound,
    bool? deviceNotifyFound,
    bool? streamDataFound,
    bool? storageDataFound,
    String? mtuStatus,
    String? connectionStage,
    String? lastError,
    String? scanSource,
    String? deviceName,
    int? rssi,
    bool? paired,
    String? failureKind,
    String? currentStep,
    int? systemDeviceCount,
    int? scanSeenCount,
    int? scanMatchedCount,
    String? lastCandidateSummary,
    List<String>? advertisedServices,
    List<String>? manufacturerData,
    bool clearLastError = false,
  }) {
    return DbsGattDiagnostic(
      serviceFound: serviceFound ?? this.serviceFound,
      writeFound: writeFound ?? this.writeFound,
      deviceNotifyFound: deviceNotifyFound ?? this.deviceNotifyFound,
      streamDataFound: streamDataFound ?? this.streamDataFound,
      storageDataFound: storageDataFound ?? this.storageDataFound,
      mtuStatus: mtuStatus ?? this.mtuStatus,
      connectionStage: connectionStage ?? this.connectionStage,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      scanSource: scanSource ?? this.scanSource,
      deviceName: deviceName ?? this.deviceName,
      rssi: rssi ?? this.rssi,
      paired: paired ?? this.paired,
      failureKind: failureKind ?? this.failureKind,
      currentStep: currentStep ?? this.currentStep,
      systemDeviceCount: systemDeviceCount ?? this.systemDeviceCount,
      scanSeenCount: scanSeenCount ?? this.scanSeenCount,
      scanMatchedCount: scanMatchedCount ?? this.scanMatchedCount,
      lastCandidateSummary: lastCandidateSummary ?? this.lastCandidateSummary,
      advertisedServices: advertisedServices ?? this.advertisedServices,
      manufacturerData: manufacturerData ?? this.manufacturerData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serviceFound': serviceFound,
      'writeFound': writeFound,
      'deviceNotifyFound': deviceNotifyFound,
      'streamDataFound': streamDataFound,
      'storageDataFound': storageDataFound,
      'mtuStatus': mtuStatus,
      'connectionStage': connectionStage,
      'lastError': lastError,
      'scanSource': scanSource,
      'deviceName': deviceName,
      'rssi': rssi,
      'paired': paired,
      'failureKind': failureKind,
      'currentStep': currentStep,
      'systemDeviceCount': systemDeviceCount,
      'scanSeenCount': scanSeenCount,
      'scanMatchedCount': scanMatchedCount,
      'lastCandidateSummary': lastCandidateSummary,
      'advertisedServices': advertisedServices,
      'manufacturerData': manufacturerData,
    };
  }
}

/// DBS 设备本机状态，例如电量、温度、硬件/固件版本。
class DbsDeviceStatus extends DbsEvent {
  final String? hardwareVersion;
  final String? firmwareVersion;
  final int? batteryPercent;
  final int? chargeIndicator;
  final int? chargeCurrentMa;
  final int? chargeVoltageMv;
  final double? deviceTemperatureC;
  final int? batteryCycle;
  final int? waterIngress;
  final int? deviceType;
  final int? humidityPercent;
  final int? batteryVoltageMv;

  const DbsDeviceStatus({
    required super.receivedAt,
    this.hardwareVersion,
    this.firmwareVersion,
    this.batteryPercent,
    this.chargeIndicator,
    this.chargeCurrentMa,
    this.chargeVoltageMv,
    this.deviceTemperatureC,
    this.batteryCycle,
    this.waterIngress,
    this.deviceType,
    this.humidityPercent,
    this.batteryVoltageMv,
  }) : super(command: DbsProtocol.commandDeviceStatus);

  DbsDeviceStatus merge(DbsDeviceStatus other) {
    return DbsDeviceStatus(
      receivedAt: other.receivedAt,
      hardwareVersion: other.hardwareVersion ?? hardwareVersion,
      firmwareVersion: other.firmwareVersion ?? firmwareVersion,
      batteryPercent: other.batteryPercent ?? batteryPercent,
      chargeIndicator: other.chargeIndicator ?? chargeIndicator,
      chargeCurrentMa: other.chargeCurrentMa ?? chargeCurrentMa,
      chargeVoltageMv: other.chargeVoltageMv ?? chargeVoltageMv,
      deviceTemperatureC: other.deviceTemperatureC ?? deviceTemperatureC,
      batteryCycle: other.batteryCycle ?? batteryCycle,
      waterIngress: other.waterIngress ?? waterIngress,
      deviceType: other.deviceType ?? deviceType,
      humidityPercent: other.humidityPercent ?? humidityPercent,
      batteryVoltageMv: other.batteryVoltageMv ?? batteryVoltageMv,
    );
  }
}

/// DBS 感测配置，包含实时感测和 LFP 感测的通道掩码与采样率。
class DbsSensingConfig extends DbsEvent {
  final int? liveChannelMask;
  final int? liveSampleRate;
  final int? lfpChannelMask;
  final int? lfpSampleRate;

  const DbsSensingConfig({
    required super.receivedAt,
    this.liveChannelMask,
    this.liveSampleRate,
    this.lfpChannelMask,
    this.lfpSampleRate,
  }) : super(command: DbsProtocol.commandSensingConfig);
}

/// DBS 当前刺激参数或参数回读结果。
class DbsStimParams extends DbsEvent {
  final int group;
  final int method;
  final double frequencyHz;
  final double intensity;
  final double pulseWidthUs;

  const DbsStimParams({
    required super.receivedAt,
    this.group = 1,
    this.method = 0,
    this.frequencyHz = 130,
    this.intensity = 2.5,
    this.pulseWidthUs = 60,
  }) : super(command: DbsProtocol.commandStimQuery);
}

/// DBS 运行状态开关集合，包含刺激、阻抗检测和 LFP 采样等状态。
class DbsRunStatus extends DbsEvent {
  final int? switchBitmask;
  final int? activeGroup;
  final bool? liveSampleOn;
  final bool? stimulateOn;
  final bool? impedanceOn;
  final bool? lfpSampleOn;

  const DbsRunStatus({
    required super.receivedAt,
    this.switchBitmask,
    this.activeGroup,
    this.liveSampleOn,
    this.stimulateOn,
    this.impedanceOn,
    this.lfpSampleOn,
  }) : super(command: DbsProtocol.commandRunStatus);
}

/// DBS Stream Data 解码后的 LFP 采样块。
///
/// channelSamples 按通道号保存样本；实时波形页会按实际通道数分别绘制多路 LFP。
class DbsStreamData extends DbsEvent {
  final DateTime sampleTimestamp;
  final int channelMask;
  final int sampleCount;
  final int sampleRate;
  final Map<int, List<double>> channelSamples;

  const DbsStreamData({
    required super.receivedAt,
    required this.sampleTimestamp,
    required this.channelMask,
    required this.sampleCount,
    required this.sampleRate,
    required this.channelSamples,
  }) : super(command: DbsProtocol.commandStreamData);

  List<double> get firstChannelSamples {
    if (channelSamples.isEmpty) return const [];
    final firstKey = channelSamples.keys.reduce((a, b) => a < b ? a : b);
    return channelSamples[firstKey] ?? const [];
  }
}

/// 从 HRV/STR 引擎转发给 DBS 的压力分数输入。
class DbsStressScore {
  final double scoreSmoothed;
  final double scoreRaw;
  final bool isStressed;
  final int engineState;
  final int inferCount;

  const DbsStressScore({
    required this.scoreSmoothed,
    required this.scoreRaw,
    required this.isStressed,
    required this.engineState,
    required this.inferCount,
  });

  int get smoothedPercent => _toPercent(scoreSmoothed);
  int get rawPercent => _toPercent(scoreRaw);

  static int _toPercent(double value) {
    final normalized = value <= 1.0 ? value * 100 : value;
    return normalized.round().clamp(0, 100);
  }
}
