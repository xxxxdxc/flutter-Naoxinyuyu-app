import 'dart:async';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import '../services/data_replay_service.dart';
import '../services/ble_service.dart';
import '../services/ble_parser.dart';

// 设备连接状态
enum ConnectionStatus { disconnected, connecting, connected, error }

class DeviceConnectionState {
  final ConnectionStatus status;
  final String? deviceId;
  final String? deviceName;
  final int? batteryLevel; // 0-100
  final int? signalStrength; // dBm
  final DateTime? connectedAt; // 连接时间

  DeviceConnectionState({
    required this.status,
    this.deviceId,
    this.deviceName,
    this.batteryLevel,
    this.signalStrength,
    this.connectedAt,
  });

  DeviceConnectionState copyWith({
    ConnectionStatus? status,
    String? deviceId,
    String? deviceName,
    int? batteryLevel,
    int? signalStrength,
    DateTime? connectedAt,
  }) {
    return DeviceConnectionState(
      status: status ?? this.status,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      signalStrength: signalStrength ?? this.signalStrength,
      connectedAt: connectedAt ?? this.connectedAt,
    );
  }
}

// 数据流状态
enum StreamStatus { idle, streaming, paused, error }

class DataStreamState {
  final StreamStatus status;
  final Duration duration; // 采集时长
  final int sampleRate; // 采样率
  final List<double> waveform; // 波形数据

  DataStreamState({
    required this.status,
    this.duration = Duration.zero,
    this.sampleRate = 250,
    this.waveform = const [],
  });

  DataStreamState copyWith({
    StreamStatus? status,
    Duration? duration,
    int? sampleRate,
    List<double>? waveform,
  }) {
    return DataStreamState(
      status: status ?? this.status,
      duration: duration ?? this.duration,
      sampleRate: sampleRate ?? this.sampleRate,
      waveform: waveform ?? this.waveform,
    );
  }
}

// 刺激器状态
enum StimStatus { off, configuring, running, error }

// 治疗模式枚举
enum TreatmentMode {
  manual,      // 手动模式
  hrvResponse, // 心率变异性响应模式
  eegResponse, // 脑电响应模式
  hybrid,      // 混合模式
}

// 模式描述信息
class ModeDescription {
  final TreatmentMode mode;
  final String name;
  final String description;
  final Color color;
  final IconData icon;

  ModeDescription({
    required this.mode,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
  });
}

class StimulationState {
  final StimStatus status;
  final double frequency; // Hz (1-130)
  final double intensity; // mA (0-10)
  final double pulseWidth; // μs (60-500)
  final TreatmentMode mode; // 治疗模式
  final Duration duration; // 刺激时长

  StimulationState({
    required this.status,
    this.frequency = 130.0,
    this.intensity = 2.5,
    this.pulseWidth = 60.0,
    this.mode = TreatmentMode.manual,
    this.duration = Duration.zero,
  });

  StimulationState copyWith({
    StimStatus? status,
    double? frequency,
    double? intensity,
    double? pulseWidth,
    TreatmentMode? mode,
    Duration? duration,
  }) {
    return StimulationState(
      status: status ?? this.status,
      frequency: frequency ?? this.frequency,
      intensity: intensity ?? this.intensity,
      pulseWidth: pulseWidth ?? this.pulseWidth,
      mode: mode ?? this.mode,
      duration: duration ?? this.duration,
    );
  }
}

// 错误状态
enum ErrorLevel { info, warning, error, critical }

class ErrorState {
  final ErrorLevel level;
  final String code;
  final String message;
  final String? solution;

  ErrorState({
    required this.level,
    required this.code,
    required this.message,
    this.solution,
  });
}

class UserSettings {
  final bool isAutoMode;
  UserSettings({this.isAutoMode = false});
}

// 安全上限配置
class SafetyLimits {
  final double maxIntensity;    // mA (0.0-10.0)
  final double maxFrequency;    // Hz (1.0-150.0)
  final double maxPulseWidth;   // μs (60-500)

  const SafetyLimits({
    required this.maxIntensity,
    required this.maxFrequency,
    required this.maxPulseWidth,
  });
}

// ========== 数据分析相关模型 ==========

// 时间范围枚举
enum TimeRange { last24h, last7d, last30d, custom }

// ========== 情绪状态模型 ==========

// 情绪等级枚举
enum MoodLevel { veryLow, low, neutral, good, excellent }

// 情绪状态数据类
class MoodState {
  final MoodLevel level;
  final double value; // 0-100
  final String description;
  final String suggestion;
  final DateTime timestamp;

  MoodState({
    required this.level,
    required this.value,
    required this.description,
    required this.suggestion,
    required this.timestamp,
  });

  MoodState copyWith({
    MoodLevel? level,
    double? value,
    String? description,
    String? suggestion,
    DateTime? timestamp,
  }) {
    return MoodState(
      level: level ?? this.level,
      value: value ?? this.value,
      description: description ?? this.description,
      suggestion: suggestion ?? this.suggestion,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

// 分析指标数据类
class AnalysisMetrics {
  final double healthScore;           // 健康评分 0-100
  final double avgHeartRate;          // 平均心率 BPM
  final double hrvStressIndex;        // HRV压力指数 0-100
  final double abnormalEegPercentage; // 异常脑电占比 0-100%
  final Duration totalStimulationTime; // 总刺激时长
  final List<double> intensityTrend;  // 刺激强度趋势数据
  final List<double> physiologicalTrend; // 生理指标趋势数据
  final DateTime generatedAt;         // 报告生成时间

  AnalysisMetrics({
    required this.healthScore,
    required this.avgHeartRate,
    required this.hrvStressIndex,
    required this.abnormalEegPercentage,
    required this.totalStimulationTime,
    required this.intensityTrend,
    required this.physiologicalTrend,
    required this.generatedAt,
  });

  AnalysisMetrics copyWith({
    double? healthScore,
    double? avgHeartRate,
    double? hrvStressIndex,
    double? abnormalEegPercentage,
    Duration? totalStimulationTime,
    List<double>? intensityTrend,
    List<double>? physiologicalTrend,
    DateTime? generatedAt,
  }) {
    return AnalysisMetrics(
      healthScore: healthScore ?? this.healthScore,
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
      hrvStressIndex: hrvStressIndex ?? this.hrvStressIndex,
      abnormalEegPercentage: abnormalEegPercentage ?? this.abnormalEegPercentage,
      totalStimulationTime: totalStimulationTime ?? this.totalStimulationTime,
      intensityTrend: intensityTrend ?? this.intensityTrend,
      physiologicalTrend: physiologicalTrend ?? this.physiologicalTrend,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}

// AI解读数据类（预留接口）
class AiInterpretation {
  final String summary;               // 总结
  final List<String> findings;        // 发现列表
  final List<String> recommendations; // 建议列表
  final DateTime generatedAt;         // 生成时间

  AiInterpretation({
    required this.summary,
    required this.findings,
    required this.recommendations,
    required this.generatedAt,
  });

  AiInterpretation copyWith({
    String? summary,
    List<String>? findings,
    List<String>? recommendations,
    DateTime? generatedAt,
  }) {
    return AiInterpretation(
      summary: summary ?? this.summary,
      findings: findings ?? this.findings,
      recommendations: recommendations ?? this.recommendations,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}

class GlobalAppState extends ChangeNotifier {
  // ========== 设备连接状态 ==========
  DeviceConnectionState dbsConnection = DeviceConnectionState(status: ConnectionStatus.disconnected);
  DeviceConnectionState hrvConnection = DeviceConnectionState(status: ConnectionStatus.disconnected);

  // ========== 数据采集状态 ==========
  DataStreamState eegStream = DataStreamState(status: StreamStatus.idle, sampleRate: 250);
  DataStreamState ecgStream = DataStreamState(status: StreamStatus.idle, sampleRate: 500);

  // ========== 刺激器状态 ==========
  StimulationState stimulation = StimulationState(status: StimStatus.off);

  // ========== 异常状态 ==========
  ErrorState? error; // 当前错误（null表示无错误）

  // ========== 用户设置 ==========
  UserSettings settings = UserSettings();

  // ========== 情绪状态 ==========
  MoodState _moodState = _createRandomMoodState();

  // 创建随机情绪状态（30-70范围内）
  static MoodState _createRandomMoodState() {
    final random = Random();
    final value = 30.0 + random.nextDouble() * 40.0; // 30-70范围内随机
    final level = _calculateMoodLevelStatic(value);
    return MoodState(
      level: level,
      value: value,
      description: _getMoodDescriptionStatic(level),
      suggestion: _getMoodSuggestionStatic(level),
      timestamp: DateTime.now(),
    );
  }

  // 静态方法用于计算情绪等级
  static MoodLevel _calculateMoodLevelStatic(double value) {
    if (value < 20) return MoodLevel.veryLow;
    if (value < 40) return MoodLevel.low;
    if (value < 60) return MoodLevel.neutral;
    if (value < 80) return MoodLevel.good;
    return MoodLevel.excellent;
  }

  // 静态方法用于获取情绪描述
  static String _getMoodDescriptionStatic(MoodLevel level) {
    switch (level) {
      case MoodLevel.veryLow:
        return '情绪低落，需要关注';
      case MoodLevel.low:
        return '情绪偏低，建议调整';
      case MoodLevel.neutral:
        return '情绪稳定，状态正常';
      case MoodLevel.good:
        return '情绪良好，状态积极';
      case MoodLevel.excellent:
        return '情绪极佳，状态优秀';
    }
  }

  // 静态方法用于获取情绪建议
  static String _getMoodSuggestionStatic(MoodLevel level) {
    switch (level) {
      case MoodLevel.veryLow:
        return '建议进行深度放松练习，咨询专业人员';
      case MoodLevel.low:
        return '尝试呼吸练习和轻度运动，调整心态';
      case MoodLevel.neutral:
        return '保持当前状态，适当休息和放松';
      case MoodLevel.good:
        return '继续保持积极状态，适度社交和运动';
      case MoodLevel.excellent:
        return '状态优秀，保持良好习惯，帮助他人';
    }
  }

  MoodState get moodState => _moodState;

  // ========== 数据分析状态 ==========
  TimeRange _selectedTimeRange = TimeRange.last24h;
  AnalysisMetrics? _currentAnalysis;
  AiInterpretation? _aiInterpretation;
  bool _isGeneratingReport = false;

  // Getters for analysis state
  TimeRange get selectedTimeRange => _selectedTimeRange;
  AnalysisMetrics? get currentAnalysis => _currentAnalysis;
  AiInterpretation? get aiInterpretation => _aiInterpretation;
  bool get isGeneratingReport => _isGeneratingReport;

  // ========== 模式安全上限配置 ==========
  final Map<TreatmentMode, SafetyLimits> _modeSafetyLimits = {
    TreatmentMode.manual: const SafetyLimits(
      maxIntensity: 10.0,
      maxFrequency: 150.0,
      maxPulseWidth: 500.0,
    ),
    TreatmentMode.hrvResponse: const SafetyLimits(
      maxIntensity: 8.0,
      maxFrequency: 130.0,
      maxPulseWidth: 300.0,
    ),
    TreatmentMode.eegResponse: const SafetyLimits(
      maxIntensity: 6.0,
      maxFrequency: 100.0,
      maxPulseWidth: 200.0,
    ),
    TreatmentMode.hybrid: const SafetyLimits(
      maxIntensity: 7.0,
      maxFrequency: 120.0,
      maxPulseWidth: 250.0,
    ),
  };

  SafetyLimits getCurrentSafetyLimits() {
    return _modeSafetyLimits[stimulation.mode] ?? _modeSafetyLimits[TreatmentMode.manual]!;
  }

  // 可选：添加安全上限更新方法
  void updateSafetyLimitForMode(TreatmentMode mode, SafetyLimits newLimits) {
    _modeSafetyLimits[mode] = newLimits;
    notifyListeners();
  }

  // ========== 数据回放（替代模拟） ==========
  final DataReplayService _replayService = DataReplayService();
  StreamSubscription<double>? _ecgSub;
  StreamSubscription<double>? _hrSub;
  Timer? _batchFlushTimer;
  int _totalEcgSamples = 0;

  bool get isReplaying => _replayService.isPlaying;

  // 存储最近的心率值用于计算平均心率
  final List<double> _recentHeartRates = [];

  // ========== BLE 数据源 ==========
  final BleService _bleService = BleService();
  bool _useBleSource = false;
  StreamSubscription<BlePacket>? _blePacketSub;
  StreamSubscription<bool>? _bleConnSub;

  // BLE 设备信息
  bool get useBleSource => _useBleSource;
  bool get isBleConnected => _bleService.isConnected;

  // STR 引擎状态
  int _engineState = 0;
  int _calmDone = 0;
  int _calmNeed = 7;
  int _stressDone = 0;
  int _stressNeed = 2;
  double _emotionScore = 0.0;
  double _emotionScoreRaw = 0.0;
  bool _isStressed = false;
  int _inferCount = 0;

  int get engineState => _engineState;
  int get calmDone => _calmDone;
  int get calmNeed => _calmNeed;
  int get stressDone => _stressDone;
  int get stressNeed => _stressNeed;
  double get emotionScore => _emotionScore;
  double get emotionScoreRaw => _emotionScoreRaw;
  bool get isStressed => _isStressed;
  int get inferCount => _inferCount;

  // HRV 就绪状态（来自 BLE 协议）
  int _hrvRdy60 = 0;
  int _hrvRdy300 = 0;
  double? _lastHr;
  double? _lastRmssd;
  double? _lastPnn50;
  double? _lastLf;
  double? _lastHf;
  double? _lastLfHf;

  int get hrvRdy60 => _hrvRdy60;
  int get hrvRdy300 => _hrvRdy300;
  double? get lastHr => _lastHr;
  double? get lastRmssd => _lastRmssd;
  double? get lastPnn50 => _lastPnn50;
  double? get lastLf => _lastLf;
  double? get lastHf => _lastHf;
  double? get lastLfHf => _lastLfHf;

  // SYS 设备信息
  int _batteryPct = 0;
  double _battV = 0.0;
  int _chargeState = 0;
  int _deviceMode = 0;
  double _sourceFs = 500;
  double _processFs = 500;

  int get batteryPct => _batteryPct;
  double get battV => _battV;
  int get chargeState => _chargeState;
  int get deviceMode => _deviceMode;
  double get sourceFs => _sourceFs;
  double get processFs => _processFs;

  // R 峰索引（用于波形标注）
  List<int> _rPeakIndices = [];
  List<int> get rPeakIndices => _rPeakIndices;

  // CRC 统计
  int _crcOk = 0;
  int _crcBad = 0;
  int get crcOk => _crcOk;
  int get crcBad => _crcBad;

  /// 初始化数据回放
  void startDataReplay({String assetPath = 'assets/ecg_short_sample.json'}) async {
    // 设置连接状态
    dbsConnection = DeviceConnectionState(
      status: ConnectionStatus.connected,
      deviceId: 'DBS-001',
      deviceName: 'DBS 设备',
      batteryLevel: 85,
      signalStrength: -60,
      connectedAt: DateTime.now(),
    );
    hrvConnection = DeviceConnectionState(
      status: ConnectionStatus.connected,
      deviceId: 'HRV-001',
      deviceName: 'HRV 手环',
      batteryLevel: 92,
      signalStrength: -40,
      connectedAt: DateTime.now(),
    );
    notifyListeners();

    // 取消旧订阅
    _ecgSub?.cancel();
    _hrSub?.cancel();

    // 重置数据流
    eegStream = eegStream.copyWith(status: StreamStatus.streaming, sampleRate: 250, waveform: []);
    ecgStream = ecgStream.copyWith(status: StreamStatus.streaming, sampleRate: 500, waveform: []);
    _totalEcgSamples = 0;
    _recentHeartRates.clear();
    notifyListeners();

    // 监听ECG数据流 — 使用批量缓冲，避免500次/秒的UI更新
    final List<double> batchBuffer = [];

    _ecgSub = _replayService.ecgStream.listen((sample) {
      batchBuffer.add(sample);
      _totalEcgSamples++;
    });

    // 每50ms批量刷新一次UI（20fps，约25个采样点/批）
    _batchFlushTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (batchBuffer.isEmpty) return;

      final newWave = List<double>.from(ecgStream.waveform)..addAll(batchBuffer);
      batchBuffer.clear();

      // 保留最近 10 秒数据
      if (newWave.length > ecgStream.sampleRate * 10) {
        newWave.removeRange(0, newWave.length - ecgStream.sampleRate * 10);
      }
      ecgStream = ecgStream.copyWith(
        waveform: newWave,
        duration: Duration(milliseconds: (_totalEcgSamples * 1000 ~/ ecgStream.sampleRate)),
      );
      notifyListeners();
    });

    // 监听心率数据流
    _hrSub = _replayService.heartRateStream.listen((hr) {
      _recentHeartRates.add(hr);
      if (_recentHeartRates.length > 50) {
        _recentHeartRates.removeAt(0);
      }
    });

    await _replayService.start(assetPath: assetPath);
  }

  /// 停止数据回放
  void stopDataReplay() {
    _replayService.stop();
    _batchFlushTimer?.cancel();
    _batchFlushTimer = null;
    _ecgSub?.cancel();
    _hrSub?.cancel();
    dbsConnection = DeviceConnectionState(status: ConnectionStatus.disconnected);
    hrvConnection = DeviceConnectionState(status: ConnectionStatus.disconnected);
    eegStream = eegStream.copyWith(status: StreamStatus.idle, waveform: []);
    ecgStream = ecgStream.copyWith(status: StreamStatus.idle, waveform: []);
    notifyListeners();
  }

  // ========== BLE 连接管理 ==========

  /// 启动 BLE 连接
  Future<bool> startBleConnection() async {
    if (_replayService.isPlaying) {
      stopDataReplay();
    }

    _bleConnSub = _bleService.connectionStateStream.listen((connected) {
      if (connected) {
        hrvConnection = DeviceConnectionState(
          status: ConnectionStatus.connected,
          deviceId: 'HRV-BLE',
          deviceName: 'KT6368A 胸带',
          batteryLevel: _batteryPct,
          connectedAt: DateTime.now(),
        );
      } else {
        hrvConnection = DeviceConnectionState(
          status: ConnectionStatus.disconnected,
        );
        _useBleSource = false;
      }
      notifyListeners();
    });

    try {
      final ok = await _bleService.connect();

      if (ok) {
        _useBleSource = true;
        _blePacketSub = _bleService.packetStream.listen(_onBlePacket);
        ecgStream = ecgStream.copyWith(
          status: StreamStatus.streaming,
          sampleRate: 500,
          waveform: [],
        );
        _totalEcgSamples = 0;
        _recentHeartRates.clear();
        _startBleBatchTimer();
      }

      notifyListeners();
      return ok;
    } catch (e) {
      // 连接失败，清理已注册的订阅
      await _bleConnSub?.cancel();
      _bleConnSub = null;
      hrvConnection = DeviceConnectionState(
        status: ConnectionStatus.disconnected,
      );
      notifyListeners();
      rethrow;
    }
  }

  /// 断开 BLE 连接
  Future<void> disconnectBle() async {
    _batchFlushTimer?.cancel();
    _batchFlushTimer = null;
    await _blePacketSub?.cancel();
    _blePacketSub = null;
    await _bleConnSub?.cancel();
    _bleConnSub = null;
    await _bleService.disconnect();
    _useBleSource = false;
    hrvConnection = DeviceConnectionState(status: ConnectionStatus.disconnected);
    ecgStream = ecgStream.copyWith(status: StreamStatus.idle, waveform: []);
    notifyListeners();
  }

  /// 发送 BLE 控制命令
  Future<void> sendBleCommand(String cmd) async {
    await _bleService.sendCommand(cmd);
  }

  /// BLE 数据包处理
  void _onBlePacket(BlePacket packet) {
    // 1. SYS
    _batteryPct = packet.battPct;
    _battV = packet.battV;
    _chargeState = packet.charge;
    _deviceMode = packet.mode;
    _sourceFs = packet.sourceFs;
    _processFs = packet.processFs;
    hrvConnection = hrvConnection.copyWith(batteryLevel: _batteryPct);

    // 2. ECG 波形缓冲（_batchFlushTimer 批量刷新）
    if (packet.ecgWaveform.isNotEmpty) {
      _bleEcgBuffer.addAll(packet.ecgWaveform);
      _totalEcgSamples += packet.ecgWaveform.length;
    }

    // 3. R 峰索引（存储为距波形末尾的负偏移，buffer 裁剪后仍有效）
    if (packet.rPeakIndices.isNotEmpty && packet.ecgWaveform.isNotEmpty) {
      final pktLen = packet.ecgWaveform.length;
      _rPeakIndices = packet.rPeakIndices
          .map((idx) => idx - pktLen)
          .toList();
    } else {
      _rPeakIndices = [];
    }

    // 4. HRV（仅当此行存在时）
    if (packet.hasHrv) {
      _hrvRdy60 = packet.rdy60 ?? 0;
      _hrvRdy300 = packet.rdy300 ?? 0;
      _lastHr = packet.hr;
      _lastRmssd = packet.rmssd;
      _lastPnn50 = packet.pnn50;
      _lastLf = packet.lf;
      _lastHf = packet.hf;
      _lastLfHf = packet.lfHf;

      if (packet.hr != null) {
        _recentHeartRates.add(packet.hr!);
        if (_recentHeartRates.length > 50) {
          _recentHeartRates.removeAt(0);
        }
      }

      if (packet.rmssd != null) {
        _updateMoodFromHrv(packet.rmssd!, packet.lfHf);
      }
    }

    // 5. STR 引擎
    _engineState = packet.strState;
    _calmDone = packet.calmDone;
    _calmNeed = packet.calmNeed;
    _stressDone = packet.stressDone;
    _stressNeed = packet.stressNeed;
    _emotionScoreRaw = packet.scoreRaw;
    _emotionScore = packet.scoreSmoothed;
    _isStressed = packet.isStressed == 1;
    _inferCount = packet.inferCount;

    if (_engineState == 3) {
      final moodValue = (_emotionScore * 100).clamp(0.0, 100.0);
      updateMoodState(moodValue);
    }

    notifyListeners();
  }

  void _updateMoodFromHrv(double rmssd, double? lfHf) {
    double moodValue;
    if (rmssd < 20) {
      moodValue = 25;
    } else if (rmssd < 40) {
      moodValue = 50;
    } else if (rmssd < 60) {
      moodValue = 70;
    } else {
      moodValue = 85;
    }
    if (lfHf != null && lfHf > 2.0) {
      moodValue -= 15;
    }
    updateMoodState(moodValue.clamp(0.0, 100.0));
  }

  // BLE ECG 波形缓冲
  final List<double> _bleEcgBuffer = [];

  void _startBleBatchTimer() {
    _batchFlushTimer?.cancel();
    _batchFlushTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_bleEcgBuffer.isEmpty || !_useBleSource) return;

      final newWave = List<double>.from(ecgStream.waveform)
        ..addAll(_bleEcgBuffer);
      _bleEcgBuffer.clear();

      final maxSamples = (ecgStream.sampleRate * 10).toInt();
      if (newWave.length > maxSamples) {
        newWave.removeRange(0, newWave.length - maxSamples);
      }
      ecgStream = ecgStream.copyWith(
        waveform: newWave,
        duration: Duration(
          milliseconds: (_totalEcgSamples * 1000 ~/ ecgStream.sampleRate),
        ),
      );
      notifyListeners();
    });
  }

  /// 获取瞬时心率（最近一次值）
  double? get currentHeartRate {
    if (_recentHeartRates.isEmpty) return null;
    return _recentHeartRates.last;
  }

  /// 获取平均心率
  double? get averageHeartRate {
    if (_recentHeartRates.isEmpty) return null;
    return _recentHeartRates.reduce((a, b) => a + b) / _recentHeartRates.length;
  }

  @override
  void dispose() {
    _replayService.dispose();
    _batchFlushTimer?.cancel();
    _ecgSub?.cancel();
    _hrSub?.cancel();
    _blePacketSub?.cancel();
    _bleConnSub?.cancel();
    _bleService.dispose();
    super.dispose();
  }

  // ========== 模式管理方法 ==========

  // 获取当前模式描述
  ModeDescription get currentModeDescription => _getModeDescription(stimulation.mode);

  // 切换治疗模式
  Future<bool> changeTreatmentMode(TreatmentMode newMode, {bool force = false}) async {
    // 安全检查：如果设备正在运行且不是强制切换，需要确认
    if (stimulation.status == StimStatus.running && !force) {
      return false; // 需要二次确认
    }

    // 如果设备正在运行且是强制切换，先停止刺激
    if (stimulation.status == StimStatus.running && force) {
      updateStimulation(stimulation.copyWith(status: StimStatus.off));
    }

    // 更新模式
    updateStimulation(stimulation.copyWith(mode: newMode));
    return true;
  }

  // 获取所有模式描述
  List<ModeDescription> getAllModeDescriptions() {
    return [
      ModeDescription(
        mode: TreatmentMode.manual,
        name: '手动模式',
        description: '完全手动控制刺激参数，适用于临床测试和调试。',
        color: const Color(0xFF4FC3F7), // 浅蓝色
        icon: Icons.touch_app,
      ),
      ModeDescription(
        mode: TreatmentMode.hrvResponse,
        name: '心率变异性响应模式',
        description: '根据心率变异性自动调整刺激参数，优化自主神经功能。',
        color: const Color(0xFFFF9800), // 橙色
        icon: Icons.favorite,
      ),
      ModeDescription(
        mode: TreatmentMode.eegResponse,
        name: '脑电响应模式',
        description: '根据脑电信号特征自动调整刺激，针对神经振荡异常。',
        color: const Color(0xFF1976D2), // 深蓝色
        icon: Icons.psychology,
      ),
      ModeDescription(
        mode: TreatmentMode.hybrid,
        name: '混合模式',
        description: '结合HRV和EEG信号进行多模态闭环控制。',
        color: const Color(0xFF4CAF50), // 绿色
        icon: Icons.merge,
      ),
    ];
  }

  // 获取单个模式描述
  ModeDescription _getModeDescription(TreatmentMode mode) {
    return getAllModeDescriptions().firstWhere((desc) => desc.mode == mode);
  }

  void updateStimulation(StimulationState newState) {
    stimulation = newState;
    notifyListeners();
  }

  // ========== 数据分析方法 ==========

  // 更新时间范围并重新生成分析
  void updateTimeRange(TimeRange range) {
    _selectedTimeRange = range;
    _generateAnalysis();
    notifyListeners();
  }

  // 手动触发分析生成
  Future<void> generateAnalysis() async {
    await _generateAnalysis();
  }

  // 内部方法：生成分析报告
  Future<void> _generateAnalysis() async {
    _isGeneratingReport = true;
    notifyListeners();

    try {
      // 模拟延迟，模拟分析过程
      await Future.delayed(const Duration(milliseconds: 800));

      // 生成模拟分析数据
      final metrics = _generateMockAnalysisMetrics();
      _currentAnalysis = metrics;

      // 生成模拟AI解读
      _aiInterpretation = _generateMockAiInterpretation(metrics);

      _isGeneratingReport = false;
      notifyListeners();
    } catch (e) {
      _isGeneratingReport = false;
      notifyListeners();
      rethrow;
    }
  }

  // 生成模拟分析指标
  AnalysisMetrics _generateMockAnalysisMetrics() {
    final random = Random();

    // 健康评分：70-95之间随机
    final healthScore = 70.0 + random.nextDouble() * 25.0;

    // 平均心率：60-85 BPM之间随机
    final avgHeartRate = 60.0 + random.nextDouble() * 25.0;

    // HRV压力指数：30-70之间随机
    final hrvStressIndex = 30.0 + random.nextDouble() * 40.0;

    // 异常脑电占比：5-25%之间随机
    final abnormalEegPercentage = 5.0 + random.nextDouble() * 20.0;

    // 总刺激时长：根据时间范围模拟
    Duration totalStimulationTime;
    switch (_selectedTimeRange) {
      case TimeRange.last24h:
        totalStimulationTime = Duration(hours: 2 + random.nextInt(4));
      case TimeRange.last7d:
        totalStimulationTime = Duration(hours: 10 + random.nextInt(20));
      case TimeRange.last30d:
        totalStimulationTime = Duration(hours: 40 + random.nextInt(50));
      case TimeRange.custom:
        totalStimulationTime = Duration(hours: 1 + random.nextInt(5));
    }

    // 根据时间范围确定数据点数量
    final int dataPointCount;
    switch (_selectedTimeRange) {
      case TimeRange.last24h:
        dataPointCount = 12; // 24小时内12个点（2小时间隔）
        break;
      case TimeRange.last7d:
        dataPointCount = 14; // 7天内14个点（每天2个点）
        break;
      case TimeRange.last30d:
        dataPointCount = 15; // 30天内15个点（每2天1个点）
        break;
      case TimeRange.custom:
        dataPointCount = 10; // 自定义范围10个点
        break;
    }

    // 生成趋势数据
    final intensityTrend = List.generate(dataPointCount, (i) => 1.0 + random.nextDouble() * 3.0);
    final physiologicalTrend = List.generate(dataPointCount, (i) => 50.0 + random.nextDouble() * 30.0);

    return AnalysisMetrics(
      healthScore: healthScore,
      avgHeartRate: avgHeartRate,
      hrvStressIndex: hrvStressIndex,
      abnormalEegPercentage: abnormalEegPercentage,
      totalStimulationTime: totalStimulationTime,
      intensityTrend: intensityTrend,
      physiologicalTrend: physiologicalTrend,
      generatedAt: DateTime.now(),
    );
  }

  // 生成模拟AI解读
  AiInterpretation _generateMockAiInterpretation(AnalysisMetrics metrics) {
    String summary;
    final List<String> findings = [];
    final List<String> recommendations = [];

    // 根据健康评分生成不同的解读
    if (metrics.healthScore >= 80) {
      summary = '整体状态极佳，生理指标表现优秀。';
      findings.add('健康评分达到${metrics.healthScore.toStringAsFixed(0)}分，处于优秀水平');
      findings.add('HRV压力指数良好，自主神经功能稳定');
      recommendations.add('继续保持当前的治疗方案');
      recommendations.add('维持规律的作息和运动');
    } else if (metrics.healthScore >= 60) {
      summary = '状态良好，部分指标有提升空间。';
      findings.add('健康评分${metrics.healthScore.toStringAsFixed(0)}分，处于良好水平');
      findings.add('检测到轻微的压力波动，建议关注');
      recommendations.add('适当增加放松训练');
      recommendations.add('保持当前刺激参数，定期复查');
    } else {
      summary = '需关注健康状态，建议及时调整。';
      findings.add('健康评分${metrics.healthScore.toStringAsFixed(0)}分，需要关注');
      findings.add('压力指数偏高，建议进行压力管理');
      recommendations.add('咨询医生调整治疗方案');
      recommendations.add('增加休息时间，避免过度劳累');
    }

    // 根据异常脑电占比添加发现
    if (metrics.abnormalEegPercentage > 20) {
      findings.add('异常脑电活动占比较高（${metrics.abnormalEegPercentage.toStringAsFixed(1)}%）');
      recommendations.add('关注脑电信号变化，必要时调整刺激参数');
    }

    // 根据刺激时长添加建议
    final hours = metrics.totalStimulationTime.inHours;
    if (hours > 8) {
      recommendations.add('刺激时间较长，注意设备电池和皮肤状况');
    }

    return AiInterpretation(
      summary: summary,
      findings: findings,
      recommendations: recommendations,
      generatedAt: DateTime.now(),
    );
  }

  // ========== 情绪状态管理方法 ==========

  // 更新情绪状态
  void updateMoodState(double newValue) {
    final newLevel = _calculateMoodLevel(newValue);
    final newDescription = _getMoodDescription(newLevel);
    final newSuggestion = _getMoodSuggestion(newLevel);

    _moodState = MoodState(
      level: newLevel,
      value: newValue,
      description: newDescription,
      suggestion: newSuggestion,
      timestamp: DateTime.now(),
    );

    notifyListeners();
  }

  // 根据数值计算情绪等级
  MoodLevel _calculateMoodLevel(double value) {
    if (value < 20) return MoodLevel.veryLow;
    if (value < 40) return MoodLevel.low;
    if (value < 60) return MoodLevel.neutral;
    if (value < 80) return MoodLevel.good;
    return MoodLevel.excellent;
  }

  // 获取情绪描述
  String _getMoodDescription(MoodLevel level) {
    switch (level) {
      case MoodLevel.veryLow:
        return '情绪低落，需要关注';
      case MoodLevel.low:
        return '情绪偏低，建议调整';
      case MoodLevel.neutral:
        return '情绪稳定，状态正常';
      case MoodLevel.good:
        return '情绪良好，状态积极';
      case MoodLevel.excellent:
        return '情绪极佳，状态优秀';
    }
  }

  // 获取情绪建议
  String _getMoodSuggestion(MoodLevel level) {
    switch (level) {
      case MoodLevel.veryLow:
        return '建议进行深度放松练习，咨询专业人员';
      case MoodLevel.low:
        return '尝试呼吸练习和轻度运动，调整心态';
      case MoodLevel.neutral:
        return '保持当前状态，适当休息和放松';
      case MoodLevel.good:
        return '继续保持积极状态，适度社交和运动';
      case MoodLevel.excellent:
        return '状态优秀，保持良好习惯，帮助他人';
    }
  }

}
