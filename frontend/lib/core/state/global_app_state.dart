import 'dart:async';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import '../services/data_replay_service.dart';
import '../services/ble_service.dart';
import '../services/ble_parser.dart';
import '../services/dbs_ble_service.dart';
import '../services/dbs_models.dart';
import '../services/hardware_demo_service.dart';
import '../services/session_history_service.dart';
import '../services/user_database_service.dart';

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
  manual, // 手动模式
  hrvResponse, // 心率变异性响应模式
  eegResponse, // 脑电响应模式
  hybrid, // 混合模式
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
  final double maxIntensity; // mA (0.0-10.0)
  final double maxFrequency; // Hz (1.0-150.0)
  final double maxPulseWidth; // μs (60-500)

  const SafetyLimits({
    required this.maxIntensity,
    required this.maxFrequency,
    required this.maxPulseWidth,
  });
}

// ========== 数据分析相关模型 ==========

// 时间范围枚举
enum TimeRange { last24h, last7d, last30d, custom }

// ========== 校准阶段枚举 ==========

enum CalibrationPhase {
  idle,
  enteringHrvCalibration,
  connectingChestStrap,
  checkingSignalQuality,
  calibratingBaseline,
  baselineDone,
  inducingStress,
  generatingModel,
  savingModel,
  running,
}

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
  final double healthScore; // 健康评分 0-100
  final double avgHeartRate; // 平均心率 BPM
  final double hrvStressIndex; // HRV压力指数 0-100
  final double abnormalEegPercentage; // 异常脑电占比 0-100%
  final Duration totalStimulationTime; // 总刺激时长
  final List<double> intensityTrend; // 刺激强度趋势数据
  final List<double> physiologicalTrend; // 生理指标趋势数据
  final DateTime generatedAt; // 报告生成时间

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
      abnormalEegPercentage:
          abnormalEegPercentage ?? this.abnormalEegPercentage,
      totalStimulationTime: totalStimulationTime ?? this.totalStimulationTime,
      intensityTrend: intensityTrend ?? this.intensityTrend,
      physiologicalTrend: physiologicalTrend ?? this.physiologicalTrend,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}

// AI解读数据类（预留接口）
class AiInterpretation {
  final String summary; // 总结
  final List<String> findings; // 发现列表
  final List<String> recommendations; // 建议列表
  final DateTime generatedAt; // 生成时间

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
  static const String demoHrvDeviceName = '演示设备 - HRV 胸带';
  static const String demoDbsDeviceName = '演示设备 - DBS';

  GlobalAppState() {
    unawaited(initializeApp());
  }

  // ========== 设备连接状态 ==========
  DeviceConnectionState dbsConnection = DeviceConnectionState(
    status: ConnectionStatus.disconnected,
  );
  DeviceConnectionState hrvConnection = DeviceConnectionState(
    status: ConnectionStatus.disconnected,
  );

  // ========== 数据采集状态 ==========
  DataStreamState eegStream = DataStreamState(
    status: StreamStatus.idle,
    sampleRate: 250,
  );
  DataStreamState ecgStream = DataStreamState(
    status: StreamStatus.idle,
    sampleRate: 500,
  );

  // ========== 刺激器状态 ==========
  StimulationState stimulation = StimulationState(status: StimStatus.off);

  // ========== 异常状态 ==========
  ErrorState? error; // 当前错误（null表示无错误）

  // ========== 用户设置 ==========
  UserSettings settings = UserSettings();

  // ========== 用户登录与本地数据库 ==========
  final UserDatabaseService _userDatabaseService = UserDatabaseService();
  List<AppUser> _users = [];
  AppUser? _currentUser;
  bool _isAuthLoading = true;
  String? _authError;

  List<AppUser> get users => _users;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAuthLoading => _isAuthLoading;
  String? get authError => _authError;

  String get activeUserId => _currentUser?.id ?? defaultHistoryUserId;
  String get activeUserName =>
      _currentUser?.displayName ?? defaultHistoryUserName;

  Future<void> initializeApp() async {
    _isAuthLoading = true;
    _authError = null;
    notifyListeners();
    try {
      final snapshot = await _userDatabaseService.load();
      _users = snapshot.users;
      _currentUser = await _userDatabaseService.currentUser();
      await loadHistorySessions();
    } catch (e) {
      _authError = e.toString();
    } finally {
      _isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isAuthLoading = true;
    _authError = null;
    notifyListeners();
    try {
      _currentUser = await _userDatabaseService.login(
        username: username,
        password: password,
      );
      final snapshot = await _userDatabaseService.load();
      _users = snapshot.users;
      await loadHistorySessions();
      return true;
    } catch (e) {
      _authError = e.toString();
      return false;
    } finally {
      _isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerUser({
    required String username,
    required String password,
    required String displayName,
    String role = 'patient',
  }) async {
    _isAuthLoading = true;
    _authError = null;
    notifyListeners();
    try {
      _currentUser = await _userDatabaseService.register(
        username: username,
        password: password,
        displayName: displayName,
        role: role,
      );
      final snapshot = await _userDatabaseService.load();
      _users = snapshot.users;
      await loadHistorySessions();
      return true;
    } catch (e) {
      _authError = e.toString();
      return false;
    } finally {
      _isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (_bleService.isConnected) {
      await disconnectBle();
    }
    if (_dbsService.isConnected) {
      await disconnectDbs();
    }
    await _userDatabaseService.logout();
    _currentUser = null;
    _historySessions = [];
    notifyListeners();
  }

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
    return _modeSafetyLimits[stimulation.mode] ??
        _modeSafetyLimits[TreatmentMode.manual]!;
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
  final DbsBleService _dbsService = DbsBleService();
  final HardwareDemoService _demoService = HardwareDemoService();
  bool _useBleSource = false;
  bool _isDemoMode = false;
  bool _isShuttingDownForClose = false;
  bool _shutdownCompleted = false;
  DateTime? _demoStartedAt;
  bool _dbsOnlyHistorySession = false;
  StreamSubscription<BlePacket>? _blePacketSub;
  StreamSubscription<bool>? _bleConnSub;
  StreamSubscription<DbsEvent>? _dbsEventSub;
  StreamSubscription<bool>? _dbsConnSub;
  StreamSubscription<DbsGattDiagnostic>? _dbsDiagnosticSub;
  StreamSubscription<BlePacket>? _demoHrvSub;
  StreamSubscription<DbsEvent>? _demoDbsSub;
  final SessionHistoryService _historyService = SessionHistoryService();
  List<SessionSummary> _historySessions = [];
  bool _isLoadingHistory = false;

  // BLE 设备信息
  bool get useBleSource => _useBleSource;
  bool get isDemoMode => _isDemoMode;
  bool get isBleConnected =>
      hrvConnection.status == ConnectionStatus.connected ||
      _bleService.isConnected;
  bool get isDbsConnected =>
      dbsConnection.status == ConnectionStatus.connected ||
      _dbsService.isConnected;
  List<SessionSummary> get historySessions => _historySessions;
  bool get isLoadingHistory => _isLoadingHistory;

  // ========== DBS 设备状态与联调结果 ==========
  // 这些字段由 DbsBleService 的事件流驱动，用于设备卡片、控制页和历史记录。
  DbsDeviceStatus? _dbsDeviceStatus;
  DbsSensingConfig? _dbsSensingConfig;
  DbsStimParams? _dbsStimParams;
  DbsRunStatus? _dbsRunStatus;
  DbsAckEvent? _lastDbsAck;
  DbsCommandResult? _lastDbsCommandResult;
  DbsCommandResult? _lastDbsStressSendResult;
  DbsCommandResult? _lastDbsSensingResult;
  DbsCommandResult? _lastDbsEmergencyStopResult;
  bool _isDbsEmergencyStopped = false;
  int _dbsStressSeq = 0;
  DateTime? _lastDbsStressSentAt;
  int? _lastDbsStressScore;
  bool? _lastDbsStressState;
  int _dbsLfpSamples = 0;
  DateTime? _lastDbsStreamLogAt;
  Timer? _dbsLfpFlushTimer;
  // DBS Stream Data 先按通道进入缓冲区，再由定时器批量刷新到多通道波形。
  final Map<int, List<double>> _dbsLfpBuffers = {};
  Map<int, List<double>> _dbsLfpWaveforms = {};

  DbsDeviceStatus? get dbsDeviceStatus => _dbsDeviceStatus;
  DbsSensingConfig? get dbsSensingConfig => _dbsSensingConfig;
  DbsStimParams? get dbsStimParams => _dbsStimParams;
  DbsRunStatus? get dbsRunStatus => _dbsRunStatus;
  DbsAckEvent? get lastDbsAck => _lastDbsAck;
  DbsCommandResult? get lastDbsCommandResult => _lastDbsCommandResult;
  DbsCommandResult? get lastDbsStressSendResult => _lastDbsStressSendResult;
  DbsCommandResult? get lastDbsSensingResult => _lastDbsSensingResult;
  DbsCommandResult? get lastDbsEmergencyStopResult =>
      _lastDbsEmergencyStopResult;
  DbsGattDiagnostic get dbsGattDiagnostic => _dbsService.gattDiagnostic;
  bool get isDbsEmergencyStopped => _isDbsEmergencyStopped;
  bool get canSendHrvStressToDbs =>
      isDbsConnected &&
      isBleConnected &&
      _engineState == 3 &&
      !_isDemoMode &&
      !_isDbsEmergencyStopped;
  int get lastDbsStressSeq => _dbsStressSeq;
  DateTime? get lastDbsStressSentAt => _lastDbsStressSentAt;
  int? get lastDbsStressScore => _lastDbsStressScore;
  bool? get lastDbsStressState => _lastDbsStressState;
  int get dbsBatteryPercent =>
      _dbsDeviceStatus?.batteryPercent ?? dbsConnection.batteryLevel ?? 0;
  double? get dbsTemperatureC => _dbsDeviceStatus?.deviceTemperatureC;
  bool get isDbsStimulating =>
      _dbsRunStatus?.stimulateOn ?? stimulation.status == StimStatus.running;
  bool get hasDbsLfpData =>
      _dbsLfpWaveforms.values.any((waveform) => waveform.isNotEmpty) &&
      isDbsConnected;
  Map<int, List<double>> get dbsLfpChannelWaveforms => {
    for (final entry in _dbsLfpWaveforms.entries)
      entry.key: List<double>.unmodifiable(entry.value),
  };
  List<int> get dbsLfpActiveChannels {
    final channels = <int>{
      ..._dbsLfpWaveforms.keys,
      ..._dbsLfpBuffers.keys,
    }.toList()..sort();
    return channels;
  }

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
  double _signalQualityPercent = 0;
  int _currentSegmentRemainingSeconds = 0;
  bool _modelReady = false;
  bool _modelSaved = false;

  // 校准阶段
  CalibrationPhase _calPhase = CalibrationPhase.idle;

  CalibrationPhase get calPhase => _calPhase;

  int get engineState => _engineState;
  int get calmDone => _calmDone;
  int get calmNeed => _calmNeed;
  int get stressDone => _stressDone;
  int get stressNeed => _stressNeed;
  double get emotionScore => _emotionScore;
  double get emotionScoreRaw => _emotionScoreRaw;
  bool get isStressed => _isStressed;
  int get inferCount => _inferCount;
  double get signalQualityPercent => _signalQualityPercent;
  int get currentSegmentRemainingSeconds => _currentSegmentRemainingSeconds;
  bool get modelReady => _modelReady;
  bool get modelSaved => _modelSaved;

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
  final List<int> _rPeakAbsoluteIndices = []; // 累积的绝对位置索引
  List<int> get rPeakIndices => _rPeakIndices;

  // CRC 统计（委托给 BLE 解析器）
  int get crcOk => _bleService.crcOk;
  int get crcBad => _bleService.crcBad;
  int get crcMissing => _bleService.crcMissing;

  /// 初始化数据回放
  void startDataReplay({
    String assetPath = 'assets/ecg_short_sample.json',
  }) async {
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
    eegStream = eegStream.copyWith(
      status: StreamStatus.streaming,
      sampleRate: 250,
      waveform: [],
    );
    ecgStream = ecgStream.copyWith(
      status: StreamStatus.streaming,
      sampleRate: 500,
      waveform: [],
    );
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

      final newWave = List<double>.from(ecgStream.waveform)
        ..addAll(batchBuffer);
      batchBuffer.clear();

      // 保留最近 10 秒数据
      if (newWave.length > ecgStream.sampleRate * 10) {
        newWave.removeRange(0, newWave.length - ecgStream.sampleRate * 10);
      }
      ecgStream = ecgStream.copyWith(
        waveform: newWave,
        duration: Duration(
          milliseconds: (_totalEcgSamples * 1000 ~/ ecgStream.sampleRate),
        ),
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
    dbsConnection = DeviceConnectionState(
      status: ConnectionStatus.disconnected,
    );
    hrvConnection = DeviceConnectionState(
      status: ConnectionStatus.disconnected,
    );
    eegStream = eegStream.copyWith(status: StreamStatus.idle, waveform: []);
    ecgStream = ecgStream.copyWith(status: StreamStatus.idle, waveform: []);
    notifyListeners();
  }

  Future<void> startHardwareDemo() async {
    if (_isDemoMode) return;
    if (_replayService.isPlaying) {
      stopDataReplay();
    }
    if (_bleService.isConnected) {
      await disconnectBle();
    }
    if (_dbsService.isConnected) {
      await disconnectDbs();
    }

    await _demoHrvSub?.cancel();
    await _demoDbsSub?.cancel();
    _demoHrvSub = _demoService.hrvPacketStream.listen(_onBlePacket);
    _demoDbsSub = _demoService.dbsEventStream.listen(_onDbsEvent);

    _isDemoMode = true;
    _useBleSource = true;
    _demoStartedAt = DateTime.now();
    _resetLiveDataState();
    _calPhase = CalibrationPhase.enteringHrvCalibration;

    hrvConnection = DeviceConnectionState(
      status: ConnectionStatus.disconnected,
      deviceId: 'DEMO-HRV-KT6368A',
      deviceName: demoHrvDeviceName,
      batteryLevel: null,
      signalStrength: -42,
    );
    dbsConnection = DeviceConnectionState(
      status: ConnectionStatus.disconnected,
      deviceId: 'DEMO-DBS-001',
      deviceName: demoDbsDeviceName,
      batteryLevel: null,
      signalStrength: -55,
    );
    ecgStream = ecgStream.copyWith(
      status: StreamStatus.idle,
      sampleRate: 500,
      waveform: [],
    );
    eegStream = eegStream.copyWith(
      status: StreamStatus.idle,
      sampleRate: HardwareDemoService.lfpSampleRate,
      waveform: [],
    );
    _startBleBatchTimer();
    _startDbsLfpFlushTimer();
    _demoService.start();
    notifyListeners();
  }

  Future<void> stopHardwareDemo() async {
    if (!_isDemoMode) return;

    await _demoService.stop();
    await _demoHrvSub?.cancel();
    await _demoDbsSub?.cancel();
    _demoHrvSub = null;
    _demoDbsSub = null;
    _batchFlushTimer?.cancel();
    _batchFlushTimer = null;
    _dbsLfpFlushTimer?.cancel();
    _dbsLfpFlushTimer = null;
    _bleEcgBuffer.clear();
    _clearDbsLfpData();
    _rPeakAbsoluteIndices.clear();
    _rPeakIndices = [];
    _lastDbsStressSentAt = null;
    _lastDbsStressScore = null;
    _lastDbsStressState = null;
    _lastDbsCommandResult = null;
    _lastDbsStressSendResult = null;
    _lastDbsSensingResult = null;
    _lastDbsEmergencyStopResult = null;
    _isDbsEmergencyStopped = false;
    _dbsStressSeq = 0;
    _lastDbsStreamLogAt = null;
    await _recordDemoOperationLog();
    _resetLiveDataState();
    _isDemoMode = false;
    _useBleSource = false;
    _demoStartedAt = null;
    _historySessions = await _historyService.loadSessions(userId: activeUserId);
    notifyListeners();
  }

  Future<void> shutdownForAppClose() async {
    if (_isShuttingDownForClose) return;
    _isShuttingDownForClose = true;

    try {
      if (_isDemoMode) {
        await stopHardwareDemo();
      }
      await _historyService.finishSession();
      _shutdownCompleted = true;
    } finally {
      _isShuttingDownForClose = false;
    }
  }

  Future<void> _recordDemoOperationLog() async {
    final startedAt = _demoStartedAt;
    if (startedAt == null) return;
    final finalStage = _calibrationPhaseLabel(_calPhase);
    final finalScore = _emotionScore > 0 ? _emotionScore * 100 : null;
    await _historyService.recordDemoOperation(
      userId: activeUserId,
      userName: activeUserName,
      deviceName: '$demoHrvDeviceName + $demoDbsDeviceName',
      startedAt: startedAt,
      endedAt: DateTime.now(),
      modelSaved: _modelSaved,
      finalStage: finalStage,
      finalHeartRate: currentHeartRate,
      finalRmssd: _lastRmssd,
      finalStressScore: finalScore,
      averageSignalQuality: _signalQualityPercent > 0
          ? _signalQualityPercent
          : null,
    );
  }

  void _resetLiveDataState() {
    hrvConnection = DeviceConnectionState(
      status: ConnectionStatus.disconnected,
    );
    dbsConnection = DeviceConnectionState(
      status: ConnectionStatus.disconnected,
    );
    ecgStream = DataStreamState(status: StreamStatus.idle, sampleRate: 500);
    eegStream = DataStreamState(
      status: StreamStatus.idle,
      sampleRate: HardwareDemoService.lfpSampleRate,
    );
    stimulation = StimulationState(status: StimStatus.off);
    _dbsDeviceStatus = null;
    _dbsSensingConfig = null;
    _dbsStimParams = null;
    _dbsRunStatus = null;
    _lastDbsAck = null;
    _lastDbsCommandResult = null;
    _lastDbsStressSendResult = null;
    _lastDbsSensingResult = null;
    _lastDbsEmergencyStopResult = null;
    _isDbsEmergencyStopped = false;
    _dbsStressSeq = 0;
    _lastDbsStreamLogAt = null;
    _lastDbsStressSentAt = null;
    _lastDbsStressScore = null;
    _lastDbsStressState = null;
    _dbsLfpSamples = 0;
    _bleEcgBuffer.clear();
    _clearDbsLfpData();
    _totalEcgSamples = 0;
    _rPeakAbsoluteIndices.clear();
    _rPeakIndices = [];
    _recentHeartRates.clear();
    _engineState = 0;
    _calmDone = 0;
    _calmNeed = 7;
    _stressDone = 0;
    _stressNeed = 2;
    _emotionScore = 0;
    _emotionScoreRaw = 0;
    _isStressed = false;
    _inferCount = 0;
    _signalQualityPercent = 0;
    _currentSegmentRemainingSeconds = 0;
    _modelReady = false;
    _modelSaved = false;
    _hrvRdy60 = 0;
    _hrvRdy300 = 0;
    _lastHr = null;
    _lastRmssd = null;
    _lastPnn50 = null;
    _lastLf = null;
    _lastHf = null;
    _lastLfHf = null;
    _batteryPct = 0;
    _battV = 0;
    _chargeState = 0;
    _deviceMode = 0;
    _sourceFs = 500;
    _processFs = 500;
    _calPhase = CalibrationPhase.idle;
  }

  String _calibrationPhaseLabel(CalibrationPhase phase) {
    switch (phase) {
      case CalibrationPhase.enteringHrvCalibration:
        return '进入 HRV 校准';
      case CalibrationPhase.connectingChestStrap:
        return '连接胸带';
      case CalibrationPhase.checkingSignalQuality:
        return '信号质量检查';
      case CalibrationPhase.calibratingBaseline:
        return '静息基线采集';
      case CalibrationPhase.baselineDone:
        return '静息基线完成';
      case CalibrationPhase.inducingStress:
        return '应激诱导采集';
      case CalibrationPhase.generatingModel:
        return '生成个体化模型';
      case CalibrationPhase.savingModel:
        return '保存模型';
      case CalibrationPhase.running:
        return '正式监测';
      case CalibrationPhase.idle:
        return '未校准';
    }
  }

  // ========== BLE 连接管理 ==========

  /// 启动 BLE 连接
  Future<bool> startBleConnection() async {
    if (_isDemoMode) {
      await stopHardwareDemo();
    }
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
        unawaited(_finishHistorySessionAndReload());
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
        _rPeakAbsoluteIndices.clear();
        _rPeakIndices = [];
        _recentHeartRates.clear();
        _dbsOnlyHistorySession = false;
        await _historyService.startSession(
          userId: activeUserId,
          userName: activeUserName,
          deviceName: 'KT6368A 胸带',
          sampleRate: ecgStream.sampleRate,
        );
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
    if (_isDemoMode) {
      await stopHardwareDemo();
      return;
    }
    _rPeakAbsoluteIndices.clear();
    _rPeakIndices = [];

    _batchFlushTimer?.cancel();
    _batchFlushTimer = null;
    await _blePacketSub?.cancel();
    _blePacketSub = null;
    await _bleConnSub?.cancel();
    _bleConnSub = null;
    await _bleService.disconnect();
    await _finishHistorySessionAndReload();
    _useBleSource = false;
    hrvConnection = DeviceConnectionState(
      status: ConnectionStatus.disconnected,
    );
    ecgStream = ecgStream.copyWith(status: StreamStatus.idle, waveform: []);
    notifyListeners();
  }

  /// 启动 DBS BLE 连接
  Future<bool> startDbsConnection() async {
    if (_isDemoMode) {
      await stopHardwareDemo();
    }
    dbsConnection = DeviceConnectionState(status: ConnectionStatus.connecting);
    notifyListeners();

    // DBS 服务只输出结构化事件；这里负责把事件落到全局状态和历史记录。
    _dbsEventSub ??= _dbsService.eventStream.listen(
      _onDbsEvent,
      onError: _onDbsError,
    );
    _dbsDiagnosticSub ??= _dbsService.diagnosticStream.listen((_) {
      notifyListeners();
    });
    _dbsConnSub ??= _dbsService.connectionStateStream.listen((connected) {
      if (connected) {
        dbsConnection = DeviceConnectionState(
          status: ConnectionStatus.connected,
          deviceId: 'DBS-BLE',
          deviceName: _dbsService.deviceName ?? 'DBS 设备',
          batteryLevel: dbsBatteryPercent,
          connectedAt: DateTime.now(),
        );
      } else {
        dbsConnection = DeviceConnectionState(
          status: ConnectionStatus.disconnected,
        );
        _dbsLfpFlushTimer?.cancel();
        _dbsLfpFlushTimer = null;
        _clearDbsLfpData();
      }
      notifyListeners();
    });

    try {
      final ok = await _dbsService.connect();
      if (ok) {
        _isDbsEmergencyStopped = false;
        _lastDbsCommandResult = null;
        _lastDbsStressSendResult = null;
        _lastDbsEmergencyStopResult = null;
        if (!_historyService.hasActiveSession) {
          _dbsOnlyHistorySession = true;
          await _historyService.startSession(
            userId: activeUserId,
            userName: activeUserName,
            deviceName: _dbsService.deviceName ?? 'DBS 设备',
            sampleRate: _dbsSensingConfig?.lfpSampleRate ?? 1000,
          );
        }
        unawaited(
          _historyService.recordDbsEvent(
            'connect',
            data: {
              'deviceName': _dbsService.deviceName ?? 'DBS 设备',
              'gatt': _dbsService.gattDiagnostic.toJson(),
            },
          ),
        );
        _clearDbsLfpData();
        // 连接后立即开始 LFP 波形刷新，真正的数据由 _onDbsEvent 写入缓冲区。
        _startDbsLfpFlushTimer();
        eegStream = eegStream.copyWith(
          status: StreamStatus.streaming,
          sampleRate: _dbsSensingConfig?.lfpSampleRate ?? 1000,
          waveform: [],
        );
        _dbsLfpSamples = 0;
        try {
          // 初始查询用于补齐电量、采样配置、刺激参数和运行状态。
          await _dbsService.queryInitialState();
        } catch (e) {
          final result = DbsCommandResult.failure(
            command: 0,
            opcode: 0,
            sentAt: DateTime.now(),
            message: '初始查询失败: $e',
          );
          _lastDbsCommandResult = result;
          unawaited(_recordDbsCommandResult('initial_query', result));
          error = ErrorState(
            level: ErrorLevel.warning,
            code: 'DBS_INITIAL_QUERY',
            message: result.statusText,
          );
        }
        _lastDbsSensingResult = DbsCommandResult.sending(
          command: DbsProtocol.commandRunConfig,
          opcode: 0x07,
          sentAt: DateTime.now(),
          message: '开启 LFP 感测中',
        );
        notifyListeners();
        // 联调默认打开实时感测和 LFP 感测，固件是否真正开始上传以 ACK 和 Stream 为准。
        final sensingResult = await _dbsService.setSensingEnabledAndWaitAck(
          liveEnabled: true,
          lfpEnabled: true,
        );
        _lastDbsSensingResult = sensingResult;
        _lastDbsCommandResult = sensingResult;
        unawaited(
          _recordDbsCommandResult(
            'sensing_enable',
            sensingResult,
            data: {'liveEnabled': true, 'lfpEnabled': true},
          ),
        );
        if (!sensingResult.isSuccess) {
          error = ErrorState(
            level: ErrorLevel.warning,
            code: 'DBS_SENSING',
            message: 'DBS 实时/LFP 感测开启失败: ${sensingResult.statusText}',
          );
        }
      }
      notifyListeners();
      return ok;
    } catch (e) {
      await _dbsEventSub?.cancel();
      _dbsEventSub = null;
      await _dbsConnSub?.cancel();
      _dbsConnSub = null;
      await _dbsDiagnosticSub?.cancel();
      _dbsDiagnosticSub = null;
      dbsConnection = DeviceConnectionState(status: ConnectionStatus.error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disconnectDbs() async {
    if (_isDemoMode) {
      await stopHardwareDemo();
      return;
    }
    _dbsLfpFlushTimer?.cancel();
    _dbsLfpFlushTimer = null;
    _clearDbsLfpData();
    await _dbsEventSub?.cancel();
    _dbsEventSub = null;
    await _dbsConnSub?.cancel();
    _dbsConnSub = null;
    await _dbsDiagnosticSub?.cancel();
    _dbsDiagnosticSub = null;
    await _historyService.recordDbsEvent(
      'disconnect',
      data: {'deviceName': dbsConnection.deviceName ?? 'DBS 设备'},
    );
    await _dbsService.disconnect();
    _lastDbsCommandResult = null;
    _lastDbsStressSendResult = null;
    _lastDbsSensingResult = null;
    _lastDbsEmergencyStopResult = null;
    _isDbsEmergencyStopped = false;
    _lastDbsStressSentAt = null;
    _lastDbsStressScore = null;
    _lastDbsStressState = null;
    dbsConnection = DeviceConnectionState(
      status: ConnectionStatus.disconnected,
    );
    eegStream = eegStream.copyWith(status: StreamStatus.idle, waveform: []);
    if (_dbsOnlyHistorySession) {
      _dbsOnlyHistorySession = false;
      await _finishHistorySessionAndReload();
      return;
    }
    notifyListeners();
  }

  DbsStressScore _currentStressScorePacket() {
    return DbsStressScore(
      scoreSmoothed: _emotionScore,
      scoreRaw: _emotionScoreRaw,
      isStressed: _isStressed,
      engineState: _engineState,
      inferCount: _inferCount,
    );
  }

  Future<void> _recordDbsCommandResult(
    String eventType,
    DbsCommandResult result, {
    Map<String, dynamic> data = const {},
  }) {
    return _historyService.recordDbsEvent(
      eventType,
      data: {
        ...data,
        'result': result.toJson(),
        'statusText': result.statusText,
      },
    );
  }

  Future<DbsCommandResult> sendCurrentHrvStressScoreToDbs() async {
    final now = DateTime.now();
    DbsCommandResult blocked(String message) {
      final result = DbsCommandResult.failure(
        command: DbsProtocol.commandStressScore,
        opcode: 0x00,
        sentAt: now,
        message: message,
      );
      _lastDbsStressSendResult = result;
      _lastDbsCommandResult = result;
      unawaited(_recordDbsCommandResult('stress_score_blocked', result));
      notifyListeners();
      return result;
    }

    if (_isDemoMode) return blocked('演示模式不发送真实 DBS 指令');
    if (_isDbsEmergencyStopped) return blocked('急停已触发');
    if (!isDbsConnected) return blocked('DBS 未连接');
    if (!isBleConnected || _engineState != 3) {
      return blocked('等待 HRV 校准完成');
    }

    final score = (_emotionScore * 100).round().clamp(0, 100);
    // 每次正式下发都记录序号和分数，便于和 DBS 固件日志对齐。
    _dbsStressSeq += 1;
    _lastDbsStressSentAt = now;
    _lastDbsStressScore = score;
    _lastDbsStressState = _isStressed;
    _lastDbsStressSendResult = DbsCommandResult.sending(
      command: DbsProtocol.commandStressScore,
      opcode: 0x00,
      sentAt: now,
      message: '压力分数发送中',
    );
    _lastDbsCommandResult = _lastDbsStressSendResult;
    notifyListeners();

    final result = await _dbsService.sendStressScoreAndWaitAck(
      _currentStressScorePacket(),
    );
    _lastDbsStressSendResult = result;
    _lastDbsCommandResult = result;
    unawaited(
      _recordDbsCommandResult(
        'stress_score_send',
        result,
        data: {
          'seq': _dbsStressSeq,
          'scoreSmoothedPercent': score,
          'scoreRawPercent': (_emotionScoreRaw * 100).round().clamp(0, 100),
          'isStressed': _isStressed,
          'engineState': _engineState,
          'inferCount': _inferCount,
        },
      ),
    );
    notifyListeners();
    return result;
  }

  Future<void> sendDbsStressScore() async {
    await sendCurrentHrvStressScoreToDbs();
  }

  Future<void> syncDbsStimParams({
    required double intensityMa,
    required double frequencyHz,
    required double pulseWidthUs,
  }) async {
    if (_isDemoMode) {
      await _demoService.syncStimParams(
        intensityMa: intensityMa,
        frequencyHz: frequencyHz,
        pulseWidthUs: pulseWidthUs,
      );
      stimulation = StimulationState(
        status: StimStatus.running,
        intensity: intensityMa,
        frequency: frequencyHz,
        pulseWidth: pulseWidthUs,
        mode: stimulation.mode,
      );
      notifyListeners();
      return;
    }
    if (_isDbsEmergencyStopped) {
      throw StateError('急停已触发，请断开并重新连接 DBS 后再下发参数');
    }
    // 参数同步先等参数配置 ACK，再单独发送启动刺激命令。
    final syncResult = await _dbsService.syncStimParamsAndWaitAck(
      intensityMa: intensityMa,
      frequencyHz: frequencyHz,
      pulseWidthUs: pulseWidthUs,
    );
    _lastDbsCommandResult = syncResult;
    unawaited(
      _recordDbsCommandResult(
        'stim_params_sync',
        syncResult,
        data: {
          'intensityMa': intensityMa,
          'frequencyHz': frequencyHz,
          'pulseWidthUs': pulseWidthUs,
        },
      ),
    );
    if (!syncResult.isSuccess) {
      notifyListeners();
      throw StateError(syncResult.statusText);
    }
    final startResult = await _dbsService.setStimulatorEnabledAndWaitAck(true);
    _lastDbsCommandResult = startResult;
    unawaited(
      _recordDbsCommandResult(
        'stim_start',
        startResult,
        data: {
          'intensityMa': intensityMa,
          'frequencyHz': frequencyHz,
          'pulseWidthUs': pulseWidthUs,
        },
      ),
    );
    if (!startResult.isSuccess) {
      notifyListeners();
      throw StateError(startResult.statusText);
    }
    stimulation = StimulationState(
      status: StimStatus.running,
      intensity: intensityMa,
      frequency: frequencyHz,
      pulseWidth: pulseWidthUs,
      mode: stimulation.mode,
    );
    notifyListeners();
  }

  Future<void> stopDbsStimulation() async {
    if (_isDemoMode) {
      await _demoService.setStimulatorEnabled(false);
      stimulation = stimulation.copyWith(status: StimStatus.off);
      notifyListeners();
      return;
    }
    final result = await _dbsService.setStimulatorEnabledAndWaitAck(false);
    _lastDbsCommandResult = result;
    unawaited(_recordDbsCommandResult('stim_stop', result));
    if (!result.isSuccess) {
      notifyListeners();
      throw StateError(result.statusText);
    }
    stimulation = stimulation.copyWith(status: StimStatus.off);
    notifyListeners();
  }

  Future<DbsCommandResult> triggerDbsEmergencyStop() async {
    final now = DateTime.now();
    if (_isDemoMode) {
      await _demoService.setStimulatorEnabled(false);
      final result = DbsCommandResult(
        command: DbsProtocol.commandRunConfig,
        opcode: 0x08,
        type: DbsCommandResultType.success,
        statusCode: DbsAckStatus.success,
        message: '急停已触发',
        sentAt: now,
        receivedAt: DateTime.now(),
      );
      _isDbsEmergencyStopped = true;
      _lastDbsEmergencyStopResult = result;
      _lastDbsCommandResult = result;
      stimulation = stimulation.copyWith(status: StimStatus.off);
      notifyListeners();
      return result;
    }
    if (!isDbsConnected) {
      final result = DbsCommandResult.failure(
        command: DbsProtocol.commandRunConfig,
        opcode: 0x08,
        sentAt: now,
        message: 'DBS 未连接',
      );
      _lastDbsEmergencyStopResult = result;
      _lastDbsCommandResult = result;
      unawaited(_recordDbsCommandResult('emergency_stop', result));
      notifyListeners();
      return result;
    }
    _lastDbsEmergencyStopResult = DbsCommandResult.sending(
      command: DbsProtocol.commandRunConfig,
      opcode: 0x08,
      sentAt: now,
      message: '急停发送中',
    );
    _lastDbsCommandResult = _lastDbsEmergencyStopResult;
    notifyListeners();

    // 当前急停实现复用“关闭刺激”命令，最终锁定/恢复规则仍以 DBS 固件为准。
    final ackResult = await _dbsService.emergencyStopAndWaitAck();
    final result = ackResult.isSuccess
        ? DbsCommandResult(
            command: ackResult.command,
            opcode: ackResult.opcode,
            type: DbsCommandResultType.success,
            statusCode: ackResult.statusCode,
            message: '急停已触发',
            sentAt: ackResult.sentAt,
            receivedAt: ackResult.receivedAt,
          )
        : ackResult;
    _lastDbsEmergencyStopResult = result;
    _lastDbsCommandResult = result;
    unawaited(_recordDbsCommandResult('emergency_stop', result));
    if (result.isSuccess) {
      _isDbsEmergencyStopped = true;
      stimulation = stimulation.copyWith(status: StimStatus.off);
    }
    notifyListeners();
    return result;
  }

  Future<void> setDbsSensingEnabled({
    required bool liveEnabled,
    required bool lfpEnabled,
  }) async {
    if (_isDemoMode) return;
    final result = await _dbsService.setSensingEnabledAndWaitAck(
      liveEnabled: liveEnabled,
      lfpEnabled: lfpEnabled,
    );
    _lastDbsSensingResult = result;
    _lastDbsCommandResult = result;
    unawaited(
      _recordDbsCommandResult(
        'sensing_set',
        result,
        data: {'liveEnabled': liveEnabled, 'lfpEnabled': lfpEnabled},
      ),
    );
    notifyListeners();
  }

  /// 发送 BLE 控制命令
  Future<void> sendBleCommand(String cmd) async {
    if (_isDemoMode) {
      await _demoService.sendHrvCommand(cmd);
      return;
    }
    await _bleService.sendCommand(cmd);
  }

  // ========== 校准控制方法 ==========

  /// 开始基线校准（发送 CMD:C）
  Future<void> startBaselineCalibration() async {
    if (_isDemoMode) {
      _calPhase = CalibrationPhase.calibratingBaseline;
      notifyListeners();
      await _demoService.sendHrvCommand('CMD:C\n');
      return;
    }
    _calPhase = CalibrationPhase.calibratingBaseline;
    notifyListeners();
    await sendBleCommand('CMD:C\n');
  }

  Future<void> connectDemoChestStrap() async {
    if (!_isDemoMode) return;
    _calPhase = CalibrationPhase.connectingChestStrap;
    hrvConnection = DeviceConnectionState(
      status: ConnectionStatus.connected,
      deviceId: 'DEMO-HRV-KT6368A',
      deviceName: demoHrvDeviceName,
      batteryLevel: 92,
      signalStrength: -42,
      connectedAt: DateTime.now(),
    );
    dbsConnection = DeviceConnectionState(
      status: ConnectionStatus.connected,
      deviceId: 'DEMO-DBS-001',
      deviceName: demoDbsDeviceName,
      batteryLevel: 86,
      signalStrength: -55,
      connectedAt: DateTime.now(),
    );
    ecgStream = ecgStream.copyWith(
      status: StreamStatus.streaming,
      sampleRate: 500,
      waveform: [],
    );
    eegStream = eegStream.copyWith(
      status: StreamStatus.streaming,
      sampleRate: HardwareDemoService.lfpSampleRate,
      waveform: [],
    );
    stimulation = stimulation.copyWith(status: StimStatus.running);
    notifyListeners();
    await _demoService.sendHrvCommand('CMD:CONNECT\n');
  }

  Future<void> startDemoSignalQualityCheck() async {
    if (!_isDemoMode) return;
    _calPhase = CalibrationPhase.checkingSignalQuality;
    notifyListeners();
    await _demoService.sendHrvCommand('CMD:Q\n');
  }

  /// 取消当前校准/诱导（发送 CMD:X）
  Future<void> cancelCalibration() async {
    if (_isDemoMode) {
      _calPhase = CalibrationPhase.enteringHrvCalibration;
      _signalQualityPercent = 0;
      _currentSegmentRemainingSeconds = 0;
      _modelReady = false;
      _modelSaved = false;
      _calmDone = 0;
      _stressDone = 0;
      notifyListeners();
      await _demoService.sendHrvCommand('CMD:R\n');
      return;
    }
    _calPhase = CalibrationPhase.idle;
    notifyListeners();
    await sendBleCommand('CMD:X\n');
  }

  /// 开始应激诱导（发送 CMD:S）
  Future<void> startStressInduction() async {
    if (_isDemoMode) {
      _calPhase = CalibrationPhase.inducingStress;
      notifyListeners();
      await _demoService.sendHrvCommand('CMD:S\n');
      return;
    }
    _calPhase = CalibrationPhase.inducingStress;
    notifyListeners();
    await sendBleCommand('CMD:S\n');
  }

  /// 用户确认压力活动完成
  void confirmStressDone() {
    if (_isDemoMode) {
      _demoService.completeStressCollection();
      _calPhase = CalibrationPhase.generatingModel;
    }
    // 只是本地标记状态，实际由设备 STR state 同步决定何时切换
    notifyListeners();
  }

  /// BLE 数据包处理
  void _onBlePacket(BlePacket packet) {
    if (!_isDemoMode) {
      unawaited(_historyService.recordPacket(packet));
    } else {
      _syncDemoFlowState();
    }

    // 1. SYS
    debugPrint(
      '[State] _onBlePacket: battPct=${packet.battPct}, ecgLen=${packet.ecgWaveform.length}, hasHrv=${packet.hasHrv}',
    );
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

    // 3. R 峰索引 — 累积为绝对位置（基于 _totalEcgSamples）
    if (packet.rPeakIndices.isNotEmpty && packet.ecgWaveform.isNotEmpty) {
      final pktLen = packet.ecgWaveform.length;
      final baseIdx = _totalEcgSamples - pktLen;
      for (final idx in packet.rPeakIndices) {
        _rPeakAbsoluteIndices.add(baseIdx + idx);
      }
      // 防内存无限增长：最多保留 10000 个
      if (_rPeakAbsoluteIndices.length > 10000) {
        _rPeakAbsoluteIndices.removeRange(
          0,
          _rPeakAbsoluteIndices.length - 5000,
        );
      }
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
    debugPrint(
      '[State] engineState=${packet.strState}, scoreRaw=${packet.scoreRaw}, scoreSmoothed=${packet.scoreSmoothed}, isStressed=${packet.isStressed}',
    );
    _engineState = packet.strState;
    _calmDone = packet.calmDone;
    _calmNeed = packet.calmNeed;
    _stressDone = packet.stressDone;
    _stressNeed = packet.stressNeed;
    _emotionScoreRaw = packet.scoreRaw;
    _emotionScore = packet.scoreSmoothed;
    _isStressed = packet.isStressed == 1;
    _inferCount = packet.inferCount;

    // 根据设备上报的 STR state 自动同步校准阶段
    if (!_isDemoMode) {
      switch (packet.strState) {
        case 1:
          _calPhase = CalibrationPhase.calibratingBaseline;
        case 5:
          _calPhase = CalibrationPhase.baselineDone;
        case 2:
          _calPhase = CalibrationPhase.inducingStress;
        case 3:
          _calPhase = CalibrationPhase.running;
        case 0:
        case 4:
          _calPhase = CalibrationPhase.idle;
      }
    }

    if (_engineState == 3) {
      final moodValue = (_emotionScore * 100).clamp(0.0, 100.0);
      updateMoodState(moodValue);
    }

    _maybeForwardStressScoreToDbs();

    notifyListeners();
  }

  void _syncDemoFlowState() {
    _signalQualityPercent = _demoService.signalQualityPercent;
    _currentSegmentRemainingSeconds =
        _demoService.currentSegmentRemainingSeconds;
    _modelReady = _demoService.modelReady;
    _modelSaved = _demoService.modelSaved;
    switch (_demoService.stage) {
      case DemoCalibrationStage.enteringHrvCalibration:
        _calPhase = CalibrationPhase.enteringHrvCalibration;
      case DemoCalibrationStage.connectingChestStrap:
        _calPhase = CalibrationPhase.connectingChestStrap;
      case DemoCalibrationStage.checkingSignalQuality:
        _calPhase = CalibrationPhase.checkingSignalQuality;
      case DemoCalibrationStage.collectingBaseline:
        _calPhase = CalibrationPhase.calibratingBaseline;
      case DemoCalibrationStage.baselineDone:
        _calPhase = CalibrationPhase.baselineDone;
      case DemoCalibrationStage.collectingStress:
        _calPhase = CalibrationPhase.inducingStress;
      case DemoCalibrationStage.generatingModel:
        _calPhase = CalibrationPhase.generatingModel;
      case DemoCalibrationStage.savingModel:
        _calPhase = CalibrationPhase.savingModel;
      case DemoCalibrationStage.monitoring:
        _calPhase = CalibrationPhase.running;
      case DemoCalibrationStage.idle:
        _calPhase = CalibrationPhase.idle;
    }
  }

  void _maybeForwardStressScoreToDbs() {
    if (!canSendHrvStressToDbs) return;
    if (_lastDbsStressSendResult?.isPending == true) return;

    final now = DateTime.now();
    final score = (_emotionScore * 100).round().clamp(0, 100);
    final changed =
        _lastDbsStressScore != score || _lastDbsStressState != _isStressed;
    final heartbeatDue =
        _lastDbsStressSentAt == null ||
        now.difference(_lastDbsStressSentAt!) >= const Duration(seconds: 1);

    if (!changed && !heartbeatDue) return;

    unawaited(sendCurrentHrvStressScoreToDbs());
  }

  void _onDbsEvent(DbsEvent event) {
    // DBS 事件是连接服务到 UI 状态的唯一入口：状态、ACK、LFP 流都在这里分流。
    if (event is DbsDeviceStatus) {
      _dbsDeviceStatus = _dbsDeviceStatus == null
          ? event
          : _dbsDeviceStatus!.merge(event);
      dbsConnection = dbsConnection.copyWith(
        status: ConnectionStatus.connected,
        batteryLevel: dbsBatteryPercent,
      );
      unawaited(
        _historyService.recordDbsEvent(
          'device_status',
          data: {
            'batteryPercent': event.batteryPercent,
            'temperatureC': event.deviceTemperatureC,
            'hardwareVersion': event.hardwareVersion,
            'firmwareVersion': event.firmwareVersion,
          },
        ),
      );
    } else if (event is DbsSensingConfig) {
      _dbsSensingConfig = event;
      final rate = event.lfpSampleRate ?? event.liveSampleRate;
      if (rate != null) {
        eegStream = eegStream.copyWith(sampleRate: rate);
      }
      unawaited(
        _historyService.recordDbsEvent(
          'sensing_config',
          data: {
            'liveChannelMask': event.liveChannelMask,
            'liveSampleRate': event.liveSampleRate,
            'lfpChannelMask': event.lfpChannelMask,
            'lfpSampleRate': event.lfpSampleRate,
          },
        ),
      );
    } else if (event is DbsStimParams) {
      _dbsStimParams = event;
      stimulation = stimulation.copyWith(
        intensity: event.intensity,
        frequency: event.frequencyHz,
        pulseWidth: event.pulseWidthUs,
      );
      unawaited(
        _historyService.recordDbsEvent(
          'stim_params_feedback',
          data: {
            'group': event.group,
            'method': event.method,
            'intensityMa': event.intensity,
            'frequencyHz': event.frequencyHz,
            'pulseWidthUs': event.pulseWidthUs,
          },
        ),
      );
    } else if (event is DbsRunStatus) {
      _dbsRunStatus = event;
      if (event.stimulateOn != null) {
        stimulation = stimulation.copyWith(
          status: event.stimulateOn! ? StimStatus.running : StimStatus.off,
        );
      }
      unawaited(
        _historyService.recordDbsEvent(
          'run_status',
          data: {
            'stimulateOn': event.stimulateOn,
            'liveSampleOn': event.liveSampleOn,
            'lfpSampleOn': event.lfpSampleOn,
            'impedanceOn': event.impedanceOn,
            'activeGroup': event.activeGroup,
            'switchBitmask': event.switchBitmask,
          },
        ),
      );
    } else if (event is DbsStreamData) {
      if (event.channelSamples.isNotEmpty) {
        for (final entry in event.channelSamples.entries) {
          if (entry.value.isEmpty) continue;
          _dbsLfpBuffers
              .putIfAbsent(entry.key, () => <double>[])
              .addAll(entry.value);
        }
        _dbsLfpSamples += event.sampleCount;
        if (eegStream.sampleRate != event.sampleRate) {
          eegStream = eegStream.copyWith(sampleRate: event.sampleRate);
        }
        final now = DateTime.now();
        if (_lastDbsStreamLogAt == null ||
            now.difference(_lastDbsStreamLogAt!) >=
                const Duration(seconds: 1)) {
          _lastDbsStreamLogAt = now;
          unawaited(
            // LFP 数据量很大，历史记录只写每秒摘要，避免 dbs.jsonl 快速膨胀。
            _historyService.recordDbsEvent(
              'lfp_stream_summary',
              data: {
                'sampleTimestamp': event.sampleTimestamp.toIso8601String(),
                'channelMask': event.channelMask,
                'channels': event.channelSamples.keys.toList()..sort(),
                'sampleCount': event.sampleCount,
                'sampleRate': event.sampleRate,
                'totalLfpSamples': _dbsLfpSamples,
              },
            ),
          );
        }
      }
    } else if (event is DbsAckEvent) {
      _lastDbsAck = event;
      final result = DbsCommandResult.fromAck(event);
      _lastDbsCommandResult = result;
      unawaited(_recordDbsCommandResult('ack', result));
      if (event.command == DbsProtocol.commandStressScore) {
        _lastDbsStressSendResult = result;
      } else if (event.command == DbsProtocol.commandRunConfig &&
          (event.opcode == 0x07 || event.opcode == 0x0B)) {
        _lastDbsSensingResult = result;
      } else if (event.command == DbsProtocol.commandRunConfig &&
          event.opcode == 0x08 &&
          _lastDbsEmergencyStopResult?.isPending == true) {
        _lastDbsEmergencyStopResult = result;
      }
    }
    notifyListeners();
  }

  void _onDbsError(Object errorObject) {
    error = ErrorState(
      level: ErrorLevel.warning,
      code: 'DBS_BLE',
      message: errorObject.toString(),
    );
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
    final interval = _isDemoMode
        ? const Duration(seconds: 1)
        : const Duration(milliseconds: 50);
    _batchFlushTimer = Timer.periodic(interval, (_) {
      if (_bleEcgBuffer.isEmpty || !_useBleSource) {
        if (_bleEcgBuffer.isEmpty && _useBleSource) {
          debugPrint('[State] batchFlush: 缓冲区为空，跳过');
        }
        return;
      }

      final newWave = List<double>.from(ecgStream.waveform)
        ..addAll(_bleEcgBuffer);
      if (_bleEcgBuffer.isNotEmpty) {
        final min = _bleEcgBuffer.reduce((a, b) => a < b ? a : b);
        final max = _bleEcgBuffer.reduce((a, b) => a > b ? a : b);
        debugPrint(
          '[State] batchFlush: ${_bleEcgBuffer.length}点 -> waveform=${newWave.length}点, 范围=[$min, $max]',
        );
      }
      _bleEcgBuffer.clear();

      final maxSamples = (ecgStream.sampleRate * 10).toInt();
      if (newWave.length > maxSamples) {
        newWave.removeRange(0, newWave.length - maxSamples);
      }

      // 将绝对 RPK 索引转换为当前 waveform 的局部索引
      final currentWfLen = newWave.length;
      final trimmedTotal = _totalEcgSamples - currentWfLen;
      if (trimmedTotal >= 0) {
        _rPeakAbsoluteIndices.removeWhere(
          (i) => i < trimmedTotal || i >= _totalEcgSamples,
        );
        _rPeakIndices = _rPeakAbsoluteIndices
            .map((i) => i - trimmedTotal)
            .toList();
      } else {
        _rPeakIndices = [];
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

  void _startDbsLfpFlushTimer() {
    _dbsLfpFlushTimer?.cancel();
    final interval = _isDemoMode
        ? const Duration(seconds: 1)
        : const Duration(milliseconds: 50);
    _dbsLfpFlushTimer = Timer.periodic(interval, (_) {
      final hasBufferedData = _dbsLfpBuffers.values.any(
        (buffer) => buffer.isNotEmpty,
      );
      if (!hasBufferedData || !isDbsConnected) return;

      // 将每个 DBS LFP 通道缓冲追加到对应波形，并保留最近 10 秒用于滚动显示。
      final nextWaveforms = <int, List<double>>{
        for (final entry in _dbsLfpWaveforms.entries)
          entry.key: List<double>.from(entry.value),
      };
      final maxSamples = (eegStream.sampleRate * 10).toInt();
      for (final entry in _dbsLfpBuffers.entries) {
        if (entry.value.isEmpty) continue;
        final waveform = nextWaveforms.putIfAbsent(entry.key, () => <double>[])
          ..addAll(entry.value);
        entry.value.clear();
        if (waveform.length > maxSamples) {
          waveform.removeRange(0, waveform.length - maxSamples);
        }
      }
      _dbsLfpWaveforms = nextWaveforms;

      final firstChannel = dbsLfpActiveChannels.isEmpty
          ? null
          : dbsLfpActiveChannels.first;
      final firstChannelWaveform = firstChannel == null
          ? const <double>[]
          : _dbsLfpWaveforms[firstChannel] ?? const <double>[];

      eegStream = eegStream.copyWith(
        status: StreamStatus.streaming,
        waveform: List<double>.from(firstChannelWaveform),
        duration: Duration(
          milliseconds: (_dbsLfpSamples * 1000 ~/ eegStream.sampleRate),
        ),
      );
      notifyListeners();
    });
  }

  void _clearDbsLfpData() {
    _dbsLfpBuffers.clear();
    _dbsLfpWaveforms = {};
    _dbsLfpSamples = 0;
    eegStream = eegStream.copyWith(waveform: []);
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

  Future<void> loadHistorySessions() async {
    _isLoadingHistory = true;
    notifyListeners();
    _historySessions = await _historyService.loadSessions(userId: activeUserId);
    _isLoadingHistory = false;
    notifyListeners();
  }

  Future<void> _finishHistorySessionAndReload() async {
    await _historyService.finishSession();
    _historySessions = await _historyService.loadSessions(userId: activeUserId);
    notifyListeners();
  }

  @override
  void dispose() {
    _replayService.dispose();
    if (!_shutdownCompleted) {
      unawaited(_historyService.finishSession());
    }
    _batchFlushTimer?.cancel();
    _dbsLfpFlushTimer?.cancel();
    _ecgSub?.cancel();
    _hrSub?.cancel();
    _blePacketSub?.cancel();
    _bleConnSub?.cancel();
    _dbsEventSub?.cancel();
    _dbsConnSub?.cancel();
    _dbsDiagnosticSub?.cancel();
    _demoHrvSub?.cancel();
    _demoDbsSub?.cancel();
    _bleService.dispose();
    _dbsService.dispose();
    _demoService.dispose();
    super.dispose();
  }

  // ========== 模式管理方法 ==========

  // 获取当前模式描述
  ModeDescription get currentModeDescription =>
      _getModeDescription(stimulation.mode);

  // 切换治疗模式
  Future<bool> changeTreatmentMode(
    TreatmentMode newMode, {
    bool force = false,
  }) async {
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
    final intensityTrend = List.generate(
      dataPointCount,
      (i) => 1.0 + random.nextDouble() * 3.0,
    );
    final physiologicalTrend = List.generate(
      dataPointCount,
      (i) => 50.0 + random.nextDouble() * 30.0,
    );

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
      findings.add(
        '异常脑电活动占比较高（${metrics.abnormalEegPercentage.toStringAsFixed(1)}%）',
      );
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
