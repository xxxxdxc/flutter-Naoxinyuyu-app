/// BLE 数据包解析器框架
///
/// 将硬件 BLE 字节流解析为结构化数据。
/// 当前为接口定义，具体解析逻辑需根据硬件协议文档填充。
///
/// 预期数据包结构（以硬件文档为准）:
///   [帧头2B][包类型1B][数据长度1B][数据区N B][校验和1B]
class BleParser {
  /// 解析硬件发来的指标数据包
  /// [bytes] BLE Notify 收到的原始字节
  /// 返回结构化指标，解析失败返回 null
  HardwareMetricsPacket? parse(List<int> bytes) {
    // TODO: 根据实际协议文档实现解析
    // 1. 校验帧头
    // 2. 校验校验和
    // 3. 根据包类型分流解析
    // 4. 提取各字段值
    return null;
  }

  /// 解析 ECG 波形数据
  List<double> _parseEcgWaveform(List<int> payload) {
    // TODO: 按协议转换字节为浮点采样值
    // 考虑因素：大小端、有无符号、缩放因子
    return [];
  }

  /// 解析 HRV 指标
  HrvMetricsPacket? _parseHrvMetrics(List<int> payload) {
    // TODO: 按协议提取心率、SDNN、RMSSD、LF/HF等
    return null;
  }

  /// 解析 EEG 频带能量
  EegBandPacket? _parseEegBands(List<int> payload) {
    // TODO: 按协议提取 Delta/Theta/Alpha/Beta
    return null;
  }

  /// 解析设备状态
  DeviceStatusPacket? _parseDeviceStatus(List<int> payload) {
    // TODO: 按协议提取电量、运行状态、当前模式
    return null;
  }
}

/// 硬件数据的完整指标集合
/// 根据硬件协议文档填充
class HardwareMetricsPacket {
  final List<double>? ecgWaveform;
  final List<double>? eegWaveform;
  final int ecgSampleRate;
  final int eegSampleRate;

  // HRV
  final double? heartRate;
  final double? sdnn;
  final double? rmssd;
  final double? lfHfRatio;
  final double? hrvStressIndex;

  // EEG 频带
  final double? deltaPower;
  final double? thetaPower;
  final double? alphaPower;
  final double? betaPower;

  // 综合评估
  final double? moodScore;
  final double? stressLevel;

  // 设备状态
  final bool? dbsRunning;
  final int? dbsBattery;
  final int? hrvBattery;
  final int? currentMode;

  const HardwareMetricsPacket({
    this.ecgWaveform,
    this.eegWaveform,
    this.ecgSampleRate = 500,
    this.eegSampleRate = 250,
    this.heartRate,
    this.sdnn,
    this.rmssd,
    this.lfHfRatio,
    this.hrvStressIndex,
    this.deltaPower,
    this.thetaPower,
    this.alphaPower,
    this.betaPower,
    this.moodScore,
    this.stressLevel,
    this.dbsRunning,
    this.dbsBattery,
    this.hrvBattery,
    this.currentMode,
  });
}

class HrvMetricsPacket {
  final double heartRate;
  final double sdnn;
  final double rmssd;
  final double lfHfRatio;
  final double stressIndex;

  const HrvMetricsPacket({
    required this.heartRate,
    required this.sdnn,
    required this.rmssd,
    required this.lfHfRatio,
    required this.stressIndex,
  });
}

class EegBandPacket {
  final double delta;
  final double theta;
  final double alpha;
  final double beta;
  const EegBandPacket({
    required this.delta,
    required this.theta,
    required this.alpha,
    required this.beta,
  });
}

class DeviceStatusPacket {
  final int battery;
  final bool dbsRunning;
  final int currentMode;
  const DeviceStatusPacket({
    required this.battery,
    required this.dbsRunning,
    required this.currentMode,
  });
}
