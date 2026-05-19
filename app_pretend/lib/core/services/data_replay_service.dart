import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

/// 离线数据回放服务
/// 加载预录的 JSON 格式 ECG 数据，按 500Hz 真实采样率逐点发射，
/// 模拟 STM32 BLE 实时数据流。在硬件未就绪时用于开发调试。
class DataReplayService {
  DataReplayService() {
    _ecgController = StreamController<double>.broadcast();
    _heartRateController = StreamController<double>.broadcast();
  }

  late StreamController<double> _ecgController;
  late StreamController<double> _heartRateController;
  Timer? _timer;
  List<double>? _data;
  int _currentIndex = 0;
  int _sampleRate = 500;

  // R波检测相关
  double _rThreshold = 0.3;
  int _lastRPeakIndex = -1;
  static const int _refractoryPeriod = 150; // 不应期 150 采样点 (300ms)
  final List<double> _recentRR = []; // 最近5个RR间期

  /// ECG采样点数据流（每2ms发射一个）
  Stream<double> get ecgStream => _ecgController.stream;

  /// 瞬时心率数据流（BPM，R波检测后更新）
  Stream<double> get heartRateStream => _heartRateController.stream;

  /// 是否正在回放
  bool get isPlaying => _timer != null;

  /// 数据总长度
  int get totalSamples => _data?.length ?? 0;

  /// 当前播放进度（采样点索引）
  int get currentIndex => _currentIndex;

  /// 启动回放
  /// [assetPath] JSON 数据文件路径，如 'assets/ecg_sample.json'
  Future<void> start({String assetPath = 'assets/ecg_short_sample.json'}) async {
    await stop();

    // 加载 JSON 数据
    final jsonStr = await rootBundle.loadString(assetPath);
    final Map<String, dynamic> json = jsonDecode(jsonStr);
    _data = (json['filtered_data'] as List<dynamic>).cast<double>();
    _sampleRate = json['fs'] as int? ?? 500;
    _currentIndex = 0;
    _lastRPeakIndex = -1;
    _recentRR.clear();

    final intervalMs = (1000 / _sampleRate).round(); // 500Hz → 2ms
    _rThreshold = _calculateInitialThreshold();

    _timer = Timer.periodic(Duration(milliseconds: intervalMs), _onTick);
  }

  /// 停止回放
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _currentIndex = 0;
  }

  /// 暂停/恢复
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (_data == null || _data!.isEmpty) return;
    if (_timer != null) return; // 已在运行
    final intervalMs = (1000 / _sampleRate).round();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), _onTick);
  }

  void _onTick(Timer timer) {
    if (_data == null || _currentIndex >= _data!.length) {
      // 数据播完，循环
      _currentIndex = 0;
      _lastRPeakIndex = -1;
      _recentRR.clear();
      return;
    }

    final sample = _data![_currentIndex];
    _ecgController.add(sample);

    // R波检测
    _detectRPeak(sample);

    _currentIndex++;
  }

  /// 自适应阈值R波检测
  void _detectRPeak(double value) {
    // 更新自适应阈值
    _rThreshold = _rThreshold * 0.95 + (value.abs() * 0.05);
    final effectiveThreshold = _rThreshold * 1.5;

    // 检查是否超过阈值且在不应期外
    if (value > effectiveThreshold &&
        (_lastRPeakIndex < 0 || (_currentIndex - _lastRPeakIndex) > _refractoryPeriod)) {
      // 确认是局部最大值（检查前后3个点）
      final startIdx = max(0, _currentIndex - 3);
      final endIdx = min(_data!.length - 1, _currentIndex + 3);
      bool isLocalMax = true;
      for (int j = startIdx; j <= endIdx; j++) {
        if (_data![j] > value) {
          isLocalMax = false;
          break;
        }
      }

      if (isLocalMax) {
        if (_lastRPeakIndex > 0) {
          final rrInterval = (_currentIndex - _lastRPeakIndex) * 1000 ~/ _sampleRate;
          _recentRR.add(rrInterval.toDouble());
          if (_recentRR.length > 5) {
            _recentRR.removeAt(0);
          }
          // 计算瞬时心率
          if (_recentRR.isNotEmpty) {
            final avgRR = _recentRR.reduce((a, b) => a + b) / _recentRR.length;
            if (avgRR > 0) {
              final hr = 60000.0 / avgRR;
              _heartRateController.add(hr);
            }
          }
        }
        _lastRPeakIndex = _currentIndex;
      }
    }
  }

  double _calculateInitialThreshold() {
    if (_data == null || _data!.isEmpty) return 0.3;
    // 取前1000个点的标准差估算阈值
    final n = min(1000, _data!.length);
    double sum = 0, sumSq = 0;
    for (int i = 0; i < n; i++) {
      sum += _data![i].abs();
      sumSq += _data![i] * _data![i];
    }
    final mean = sum / n;
    final std = sqrt(sumSq / n - mean * mean);
    return max(0.1, std * 2.5);
  }

  /// 释放资源
  void dispose() {
    _timer?.cancel();
    _ecgController.close();
    _heartRateController.close();
  }
}
