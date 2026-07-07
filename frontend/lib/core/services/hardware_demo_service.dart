import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'ble_parser.dart';
import 'dbs_frame_codec.dart';
import 'dbs_models.dart';

enum DemoCalibrationStage {
  idle,
  enteringHrvCalibration,
  connectingChestStrap,
  checkingSignalQuality,
  collectingBaseline,
  baselineDone,
  collectingStress,
  generatingModel,
  savingModel,
  monitoring,
}

class HardwareDemoService {
  static const int hrvSampleRate = 500;
  static const int lfpSampleRate = 250;
  static const int baselineSegments = 7;
  static const int stressSegments = 2;
  static const int secondsPerSegment = 60;

  final BleParser _hrvParser;
  final DbsFrameCodec _dbsCodec;
  final Random _random;

  HardwareDemoService({
    BleParser? hrvParser,
    DbsFrameCodec? dbsCodec,
    Random? random,
  }) : _hrvParser = hrvParser ?? BleParser(),
       _dbsCodec = dbsCodec ?? DbsFrameCodec(),
       _random = random ?? Random(42);

  final StreamController<BlePacket> _hrvController =
      StreamController<BlePacket>.broadcast();
  final StreamController<DbsEvent> _dbsController =
      StreamController<DbsEvent>.broadcast();

  Stream<BlePacket> get hrvPacketStream => _hrvController.stream;
  Stream<DbsEvent> get dbsEventStream => _dbsController.stream;

  Timer? _hrvTimer;
  Timer? _dbsTimer;
  Timer? _dbsStatusTimer;

  int _tick = 0;
  int _dbsTick = 0;
  DemoCalibrationStage _stage = DemoCalibrationStage.idle;
  int _stageElapsedSeconds = 0;
  int _currentSegment = 0;
  bool _stimulating = true;
  bool _modelReady = false;
  bool _modelSaved = false;
  double _scoreRaw = 0.32;
  double _scoreSmoothed = 0.35;
  double _signalQualityPercent = 0;
  double _stimIntensity = 2.5;
  double _stimFrequency = 130;
  double _stimPulseWidth = 60;

  bool get isRunning => _hrvTimer != null || _dbsTimer != null;
  DemoCalibrationStage get stage => _stage;
  int get stageElapsedSeconds => _stageElapsedSeconds;
  int get currentSegment => _currentSegment;
  int get currentSegmentRemainingSeconds {
    if (_stage != DemoCalibrationStage.collectingBaseline &&
        _stage != DemoCalibrationStage.collectingStress) {
      return 0;
    }
    return secondsPerSegment - (_stageElapsedSeconds % secondsPerSegment);
  }

  double get signalQualityPercent => _signalQualityPercent;
  bool get modelReady => _modelReady;
  bool get modelSaved => _modelSaved;

  void start() {
    if (isRunning) return;
    resetFlow();
    _hrvTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _advanceFlowByOneSecond();
      final rawPacket = buildHrvPacket(tick: _tick++);
      for (final packet in _hrvParser.feed(utf8.encode(rawPacket))) {
        _hrvController.add(packet);
      }
    });
    _dbsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_stage.index >= DemoCalibrationStage.connectingChestStrap.index) {
        _emitDbsStreamFrame();
      }
    });
    _dbsStatusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_stage.index >= DemoCalibrationStage.connectingChestStrap.index) {
        _emitDbsInitialState();
      }
    });
  }

  void resetFlow() {
    _tick = 0;
    _dbsTick = 0;
    _stage = DemoCalibrationStage.enteringHrvCalibration;
    _stageElapsedSeconds = 0;
    _currentSegment = 0;
    _scoreRaw = 0.32;
    _scoreSmoothed = 0.35;
    _signalQualityPercent = 0;
    _modelReady = false;
    _modelSaved = false;
    _stimulating = true;
    _hrvParser.clear();
    _dbsCodec.resetCounter();
  }

  Future<void> stop() async {
    _hrvTimer?.cancel();
    _dbsTimer?.cancel();
    _dbsStatusTimer?.cancel();
    _hrvTimer = null;
    _dbsTimer = null;
    _dbsStatusTimer = null;
    _hrvParser.clear();
  }

  Future<void> sendHrvCommand(String command) async {
    if (command.contains('CMD:CONNECT')) {
      _setStage(DemoCalibrationStage.connectingChestStrap);
      _emitDbsInitialState();
    } else if (command.contains('CMD:Q')) {
      _setStage(DemoCalibrationStage.checkingSignalQuality);
    } else if (command.contains('CMD:C')) {
      _setStage(DemoCalibrationStage.collectingBaseline);
    } else if (command.contains('CMD:S')) {
      _setStage(DemoCalibrationStage.collectingStress);
    } else if (command.contains('CMD:G')) {
      _setStage(DemoCalibrationStage.generatingModel);
    } else if (command.contains('CMD:V')) {
      _setStage(DemoCalibrationStage.savingModel);
    } else if (command.contains('CMD:X')) {
      _setStage(DemoCalibrationStage.idle);
    } else if (command.contains('CMD:R')) {
      resetFlow();
    } else if (command.contains('CMD:E')) {
      _setStage(DemoCalibrationStage.idle);
    }
  }

  void completeStressCollection() {
    _setStage(DemoCalibrationStage.generatingModel);
  }

  Future<void> syncStimParams({
    required double intensityMa,
    required double frequencyHz,
    required double pulseWidthUs,
  }) async {
    _stimIntensity = intensityMa;
    _stimFrequency = frequencyHz;
    _stimPulseWidth = pulseWidthUs;
    _stimulating = true;
    _emitDbsFrame(
      _dbsCodec.encode(
        command: DbsProtocol.commandStimQuery,
        pdus: [
          DbsPdu(opcode: 0x00, data: DbsFrameCodec.u8(1)),
          DbsPdu(opcode: 0x02, data: DbsFrameCodec.u16(frequencyHz.round())),
          DbsPdu(
            opcode: 0x05,
            data: DbsFrameCodec.buildStimIntensityPayload(intensityMa),
          ),
          DbsPdu(
            opcode: 0x06,
            data: DbsFrameCodec.buildStimPulseWidthPayload(pulseWidthUs),
          ),
        ],
      ),
    );
    _emitDbsRunStatus();
  }

  Future<void> setStimulatorEnabled(bool enabled) async {
    _stimulating = enabled;
    _emitDbsRunStatus();
  }

  String buildHrvPacket({int tick = 0}) {
    final samples = _buildEcgSamples(tick, hrvSampleRate);
    final rPeaks = _buildRPeaks(tick, samples.length);
    final phase = tick.toDouble();
    final stressLoad = _stage == DemoCalibrationStage.collectingStress
        ? 0.66
        : (_stage == DemoCalibrationStage.monitoring ? _scoreSmoothed : 0.35);
    final heartRate = 76.0 + stressLoad * 10 + sin(phase * 0.24) * 1.4;
    final rmssd = (72.0 - stressLoad * 34 + sin(phase * 0.18) * 2).clamp(
      18.0,
      78.0,
    );
    final pnn50 = (42.0 - stressLoad * 22 + cos(phase * 0.16) * 1.5).clamp(
      5.0,
      46.0,
    );
    final lf = 420.0 + stressLoad * 250 + sin(phase * 0.14) * 18;
    final hf = 410.0 - stressLoad * 130 + cos(phase * 0.14) * 12;
    final lfHf = (lf / max(1, hf)).clamp(0.5, 5.5);
    final isStressed = _scoreSmoothed >= 0.62 ? 1 : 0;

    final bodyLines = [
      'SYS:1,$hrvSampleRate,$hrvSampleRate,3.86,${92 - (tick ~/ 80) % 4},0',
      'ECG:${samples.map((v) => v.toStringAsFixed(4)).join(',')}',
      'RPK:${rPeaks.length}${rPeaks.isEmpty ? '' : ',${rPeaks.join(',')}'}',
      'HRV:1,${_stage == DemoCalibrationStage.monitoring ? 1 : 0},${heartRate.toStringAsFixed(1)},${rmssd.toStringAsFixed(1)},${pnn50.toStringAsFixed(1)},${lf.toStringAsFixed(1)},${hf.toStringAsFixed(1)},${lfHf.toStringAsFixed(2)}',
      'STR:$_strState,$_calmDone,$baselineSegments,$_stressDone,$stressSegments,${_scoreRaw.toStringAsFixed(3)},${_scoreSmoothed.toStringAsFixed(3)},$isStressed,$_inferCount',
    ];
    final body = '\n${bodyLines.join('\n')}\n';
    final crc = xor8(body);
    return 'START$body'
        'PKTCRC:${crc.toRadixString(16).padLeft(2, '0').toUpperCase()}\n'
        'END';
  }

  int get _strState {
    switch (_stage) {
      case DemoCalibrationStage.collectingBaseline:
        return 1;
      case DemoCalibrationStage.baselineDone:
        return 5;
      case DemoCalibrationStage.collectingStress:
        return 2;
      case DemoCalibrationStage.monitoring:
        return 3;
      case DemoCalibrationStage.idle:
        return 0;
      default:
        return 4;
    }
  }

  int get _calmDone => _stage == DemoCalibrationStage.collectingBaseline
      ? _currentSegment.clamp(0, baselineSegments)
      : (_stage.index > DemoCalibrationStage.collectingBaseline.index
            ? baselineSegments
            : 0);

  int get _stressDone => _stage == DemoCalibrationStage.collectingStress
      ? _currentSegment.clamp(0, stressSegments)
      : (_stage.index > DemoCalibrationStage.collectingStress.index
            ? stressSegments
            : 0);

  int get _inferCount => _stage == DemoCalibrationStage.monitoring
      ? max(1, _stageElapsedSeconds)
      : 0;

  Uint8List buildDbsDeviceStatusFrame() {
    return _dbsCodec.encode(
      command: DbsProtocol.commandDeviceStatus,
      pdus: [
        DbsPdu(opcode: 0x00, data: Uint8List.fromList(utf8.encode('DEMO-DBS'))),
        DbsPdu(opcode: 0x01, data: Uint8List.fromList(utf8.encode('FW-DEMO'))),
        DbsPdu(opcode: 0x03, data: DbsFrameCodec.u8(86)),
        DbsPdu(opcode: 0x08, data: DbsFrameCodec.u16(258)),
        DbsPdu(opcode: 0x0F, data: DbsFrameCodec.u16(3980)),
      ],
    );
  }

  Uint8List buildDbsStreamFrame({
    int tick = 0,
    int sampleCount = lfpSampleRate,
  }) {
    final now = DateTime.now();
    final seconds = now.millisecondsSinceEpoch ~/ 1000;
    final millis = now.millisecondsSinceEpoch % 1000;
    final payload = BytesBuilder(copy: false)
      ..add(_u32(seconds))
      ..add(_u16(millis))
      ..add(_u16(0x0001))
      ..addByte(sampleCount.clamp(0, 255).toInt());
    for (var i = 0; i < sampleCount; i++) {
      final t = (tick * sampleCount + i) / lfpSampleRate;
      final lfp =
          180 * sin(2 * pi * 12 * t) +
          70 * sin(2 * pi * 24 * t) +
          (_stimulating ? 28 * sin(2 * pi * 125 * t) : 0) +
          (_random.nextDouble() - 0.5) * 12;
      payload.add(_i16(lfp.round().clamp(-32768, 32767)));
    }
    return _dbsCodec.encode(
      command: DbsProtocol.commandStreamData,
      pdus: [DbsPdu(opcode: 0x00, data: payload.toBytes())],
    );
  }

  static int xor8(String body) {
    var crc = 0;
    for (final byte in utf8.encode(body)) {
      crc ^= byte;
    }
    return crc & 0xFF;
  }

  void _setStage(DemoCalibrationStage nextStage) {
    _stage = nextStage;
    _stageElapsedSeconds = 0;
    _currentSegment =
        nextStage == DemoCalibrationStage.collectingBaseline ||
            nextStage == DemoCalibrationStage.collectingStress
        ? 1
        : 0;
  }

  void _advanceFlowByOneSecond() {
    _stageElapsedSeconds++;
    _signalQualityPercent = _stage == DemoCalibrationStage.checkingSignalQuality
        ? 95 + sin(_stageElapsedSeconds * 0.9) * 3
        : (_signalQualityPercent == 0 ? 96 : _signalQualityPercent);

    switch (_stage) {
      case DemoCalibrationStage.enteringHrvCalibration:
        break;
      case DemoCalibrationStage.connectingChestStrap:
        break;
      case DemoCalibrationStage.checkingSignalQuality:
        if (_stageElapsedSeconds >= 5) {
          _setStage(DemoCalibrationStage.collectingBaseline);
        }
      case DemoCalibrationStage.collectingBaseline:
        _currentSegment = min(
          baselineSegments,
          ((_stageElapsedSeconds - 1) ~/ secondsPerSegment) + 1,
        );
        _scoreRaw = 0.30 + sin(_stageElapsedSeconds * 0.05) * 0.04;
        _scoreSmoothed = _scoreSmoothed * 0.92 + _scoreRaw * 0.08;
        if (_stageElapsedSeconds >= baselineSegments * secondsPerSegment) {
          _setStage(DemoCalibrationStage.baselineDone);
        }
      case DemoCalibrationStage.baselineDone:
        break;
      case DemoCalibrationStage.collectingStress:
        _currentSegment = min(
          stressSegments,
          ((_stageElapsedSeconds - 1) ~/ secondsPerSegment) + 1,
        );
        _scoreRaw = 0.62 + sin(_stageElapsedSeconds * 0.06) * 0.08;
        _scoreSmoothed = _scoreSmoothed * 0.9 + _scoreRaw * 0.1;
        if (_stageElapsedSeconds >= stressSegments * secondsPerSegment) {
          _setStage(DemoCalibrationStage.generatingModel);
        }
      case DemoCalibrationStage.generatingModel:
        if (_stageElapsedSeconds >= 3) {
          _modelReady = true;
          _setStage(DemoCalibrationStage.savingModel);
        }
      case DemoCalibrationStage.savingModel:
        if (_stageElapsedSeconds >= 1) {
          _modelReady = true;
          _modelSaved = true;
          _setStage(DemoCalibrationStage.monitoring);
        }
      case DemoCalibrationStage.monitoring:
        _scoreRaw = 0.48 + sin(_stageElapsedSeconds * 0.12) * 0.14;
        _scoreSmoothed = (_scoreSmoothed * 0.9 + _scoreRaw * 0.1).clamp(
          0.25,
          0.82,
        );
      case DemoCalibrationStage.idle:
        break;
    }
  }

  List<double> _buildEcgSamples(int tick, int count) {
    final start = tick * count;
    return List.generate(count, (i) {
      final sampleIndex = start + i;
      final seconds = sampleIndex / hrvSampleRate;
      const rr = 370;
      final beat = sampleIndex % rr;
      final pWave = 0.055 * exp(-pow((beat - 318) / 18.0, 2));
      final qWave = -0.075 * exp(-pow((beat - 2) / 4.0, 2));
      final rWave = 0.58 * exp(-pow((beat - 8) / 2.3, 2));
      final sWave = -0.14 * exp(-pow((beat - 22) / 8.0, 2));
      final tWave = 0.095 * exp(-pow((beat - 115) / 24.0, 2));
      final base =
          0.018 * sin(2 * pi * 0.35 * seconds) +
          0.012 * sin(2 * pi * 7.5 * seconds) +
          0.006 * sin(2 * pi * 19 * seconds);
      final noise = (_random.nextDouble() - 0.5) * 0.012;
      return base + pWave + qWave + rWave + sWave + tWave + noise;
    });
  }

  List<int> _buildRPeaks(int tick, int count) {
    final start = tick * count;
    final peaks = <int>[];
    for (var i = 0; i < count; i++) {
      if ((start + i) % 370 == 8) {
        peaks.add(i);
      }
    }
    return peaks;
  }

  void _emitDbsInitialState() {
    _emitDbsFrame(buildDbsDeviceStatusFrame());
    _emitDbsFrame(
      _dbsCodec.encode(
        command: DbsProtocol.commandSensingConfig,
        pdus: [
          DbsPdu(opcode: 0x04, data: DbsFrameCodec.u16(0x0001)),
          DbsPdu(opcode: 0x05, data: DbsFrameCodec.u16(lfpSampleRate)),
        ],
      ),
    );
    unawaited(
      syncStimParams(
        intensityMa: _stimIntensity,
        frequencyHz: _stimFrequency,
        pulseWidthUs: _stimPulseWidth,
      ),
    );
  }

  void _emitDbsRunStatus() {
    final bitmask = (_stimulating ? (1 << 1) : 0) | (1 << 4);
    _emitDbsFrame(
      _dbsCodec.encode(
        command: DbsProtocol.commandRunStatus,
        pdus: [
          DbsPdu(opcode: 0x00, data: DbsFrameCodec.u16(bitmask)),
          DbsPdu(opcode: 0x01, data: DbsFrameCodec.u8(1)),
        ],
      ),
    );
  }

  void _emitDbsStreamFrame() {
    _emitDbsFrame(buildDbsStreamFrame(tick: _dbsTick++));
  }

  void _emitDbsFrame(Uint8List bytes) {
    final frame = _dbsCodec.decodeFrame(bytes);
    if (frame == null) return;
    switch (frame.command) {
      case DbsProtocol.commandDeviceStatus:
        _dbsController.add(DbsFrameCodec.parseDeviceStatus(frame));
      case DbsProtocol.commandSensingConfig:
        _dbsController.add(DbsFrameCodec.parseSensingConfig(frame));
      case DbsProtocol.commandStimQuery:
      case DbsProtocol.commandStimConfig:
        _dbsController.add(DbsFrameCodec.parseStimParams(frame));
      case DbsProtocol.commandRunStatus:
      case DbsProtocol.commandRunConfig:
        _dbsController.add(DbsFrameCodec.parseRunStatus(frame));
      case DbsProtocol.commandStreamData:
        final stream = DbsFrameCodec.parseStreamData(
          frame,
          sampleRate: lfpSampleRate,
        );
        if (stream != null) _dbsController.add(stream);
      default:
        for (final pdu in frame.pdus) {
          _dbsController.add(
            DbsAckEvent(
              command: frame.command,
              receivedAt: DateTime.now(),
              opcode: pdu.opcode,
              data: pdu.data,
            ),
          );
        }
    }
  }

  static Uint8List _u16(int value) {
    final data = ByteData(2)..setUint16(0, value, Endian.big);
    return data.buffer.asUint8List();
  }

  static Uint8List _i16(int value) {
    final data = ByteData(2)..setInt16(0, value, Endian.big);
    return data.buffer.asUint8List();
  }

  static Uint8List _u32(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.big);
    return data.buffer.asUint8List();
  }

  void dispose() {
    unawaited(stop());
    _hrvController.close();
    _dbsController.close();
  }
}
