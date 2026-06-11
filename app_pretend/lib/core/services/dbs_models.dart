import 'dart:typed_data';

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

class DbsPdu {
  final int opcode;
  final Uint8List data;

  const DbsPdu({required this.opcode, required this.data});

  int get length => data.length;
}

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

abstract class DbsEvent {
  final int command;
  final DateTime receivedAt;

  const DbsEvent({required this.command, required this.receivedAt});
}

class DbsAckEvent extends DbsEvent {
  final int opcode;
  final Uint8List data;

  const DbsAckEvent({
    required super.command,
    required super.receivedAt,
    required this.opcode,
    required this.data,
  });

  bool get isSuccess => data.isEmpty || data.first == 0;
}

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
