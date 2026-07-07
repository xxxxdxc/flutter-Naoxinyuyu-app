import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/state/global_app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../components/ecg_waveform_painter.dart';
import 'analysis_report_page.dart';
import 'history_records_page.dart';
import 'offline_test_page.dart';

class VisualizerPage extends StatefulWidget {
  const VisualizerPage({super.key});

  @override
  State<VisualizerPage> createState() => _VisualizerPageState();
}

class _VisualizerPageState extends State<VisualizerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _timeScale = 5.0; // 5s view
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _tabController.index == 0
            ? Colors.black
            : Colors.white,
        foregroundColor: _tabController.index == 0
            ? Colors.white
            : AppTheme.textPrimary,
        title: const Text(
          '数据分析',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '实时波形'),
            Tab(text: '分析报告'),
            Tab(text: '离线测试'),
            Tab(text: '历史记录'),
          ],
          labelColor: _tabController.index == 0
              ? Colors.white
              : AppTheme.primaryMain,
          unselectedLabelColor: _tabController.index == 0
              ? Colors.white70
              : AppTheme.textSecondary,
          indicatorColor: _tabController.index == 0
              ? Colors.white
              : AppTheme.primaryMain,
          onTap: (index) {
            setState(() {}); // 强制重建以更新AppBar颜色
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 实时波形选项卡
          _buildWaveformTab(),
          // 分析报告选项卡
          const AnalysisReportPage(),
          // 离线测试选项卡
          const OfflineTestPage(),
          const HistoryRecordsPage(),
        ],
      ),
    );
  }

  Widget _buildWaveformTab() {
    return Consumer<GlobalAppState>(
      builder: (context, state, child) {
        return Container(
          color: Colors.black, // 示波器深色背景
          child: Column(
            children: [
              // EEG + ECG 双通道波形
              Expanded(
                flex: 3,
                child: _WaveformCanvas(
                  title: 'CH1: EEG (LFP)',
                  sampleRate: state.eegStream.sampleRate,
                  color: Colors.greenAccent,
                  data: state.eegStream.waveform,
                  timeScale: _timeScale,
                  isPaused: _isPaused,
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                flex: 3,
                child: state.isDemoMode
                    ? _DemoEcgCanvas(
                        data: state.ecgStream.waveform,
                        rPeakIndices: state.rPeakIndices,
                      )
                    : _WaveformCanvas(
                        title: 'CH2: ECG (HRV)',
                        sampleRate: state.ecgStream.sampleRate,
                        color: Colors.pinkAccent,
                        data: state.ecgStream.waveform,
                        timeScale: _timeScale,
                        isPaused: _isPaused,
                        rPeakIndices: state.useBleSource
                            ? state.rPeakIndices
                            : null,
                      ),
              ),
              _buildControlOverlay(),
              // BLE 实时数据面板
              if (state.useBleSource || state.isDbsConnected)
                _BleDataPanel(state: state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.black,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _isPaused ? Icons.play_arrow : Icons.pause,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isPaused = !_isPaused;
                });
              },
            ),
            const SizedBox(width: 8),
            const Text('1s', style: TextStyle(color: Colors.white70)),
            SizedBox(
              width: 150,
              child: Slider(
                value: _timeScale,
                min: 1.0,
                max: 10.0,
                activeColor: Colors.white,
                inactiveColor: Colors.white24,
                onChanged: (val) {
                  setState(() {
                    _timeScale = val;
                  });
                },
              ),
            ),
            const Text('10s', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

/// BLE 实时数据面板 — 核心状态 / HRV指标 / 压力融合 / 设备详情
class _BleDataPanel extends StatelessWidget {
  final GlobalAppState state;
  const _BleDataPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 8),
              _buildCompactStatusRow(),
              const SizedBox(height: 10),
              _sectionTitle('HRV 指标'),
              const SizedBox(height: 4),
              Row(
                children: [
                  _hrvItem(
                    '心率',
                    state.lastHr?.toStringAsFixed(1) ?? '--',
                    'BPM',
                    Icons.favorite,
                    Colors.pinkAccent,
                  ),
                  _hrvItem(
                    'RMSSD',
                    state.lastRmssd?.toStringAsFixed(1) ?? '--',
                    'ms',
                    Icons.monitor_heart_outlined,
                    Colors.orangeAccent,
                  ),
                  _hrvItem(
                    'PNN50',
                    state.lastPnn50?.toStringAsFixed(1) ?? '--',
                    '%',
                    Icons.analytics,
                    Colors.lightBlueAccent,
                  ),
                  _hrvItem(
                    'LF/HF',
                    state.lastLfHf?.toStringAsFixed(2) ?? '--',
                    '',
                    Icons.show_chart,
                    Colors.purpleAccent,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStressSection(),
              const SizedBox(height: 8),
              _buildDeviceDetailsTile(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _hrvItem(
    String label,
    String value,
    String unit,
    IconData icon,
    Color iconColor,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 10, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (unit.isNotEmpty)
                  Text(
                    ' $unit',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatusRow() {
    final hrvBattery = state.useBleSource ? '${state.batteryPct}%' : '--%';
    final dbsBattery = state.isDbsConnected
        ? '${state.dbsBatteryPercent}%'
        : '--%';
    final stimulation = state.isDbsConnected
        ? (state.isDbsStimulating ? '刺激运行' : '刺激停止')
        : '刺激未知';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        'HRV $hrvBattery · DBS $dbsBattery · $stimulation · ${_fusionStatusText(compact: true)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStressSection() {
    final engineState = state.engineState;

    // 引擎状态标签
    String engineLabel;
    Color engineColor;
    switch (engineState) {
      case 0:
        engineLabel = '未校准';
        engineColor = Colors.grey;
      case 1:
        engineLabel = '校准中';
        engineColor = Colors.orangeAccent;
      case 2:
        engineLabel = '诱导中';
        engineColor = Colors.redAccent;
      case 3:
        engineLabel = state.isStressed ? '应激' : '平静';
        engineColor = state.isStressed ? Colors.redAccent : Colors.greenAccent;
      default:
        engineLabel = '--';
        engineColor = Colors.grey;
    }

    // 始终显示压力分值（百分制整数），与设备 score_smoothed 一致
    final score = (state.emotionScore * 100).clamp(0, 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: engineColor.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: engineColor.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '压力状态',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                engineState == 3
                    ? (state.isStressed
                          ? Icons.warning_amber_rounded
                          : Icons.sentiment_satisfied_alt)
                    : Icons.info_outline,
                size: 20,
                color: engineColor,
              ),
              const SizedBox(width: 8),
              Text(
                '$score / 100',
                style: TextStyle(
                  color: engineColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                engineLabel,
                style: TextStyle(
                  color: engineColor.withAlpha(190),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _fusionInfo('HRV → DBS', _fusionStatusText()),
              _fusionInfo('最近发送', _formatTime(state.lastDbsStressSentAt)),
              _fusionInfo(
                '包序号',
                state.lastDbsStressSentAt == null
                    ? '--'
                    : '${state.lastDbsStressSeq}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fusionInfo(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12),
        children: [
          TextSpan(
            text: '$label：',
            style: const TextStyle(color: Colors.white38),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceDetailsTile() {
    return Theme(
      data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white54,
          title: const Text(
            '设备详情',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _detailItem('HRV 设备', _hrvDeviceName),
                _detailItem('DBS 设备', _dbsDeviceName),
                _detailItem('HRV 电量', _hrvBatteryText),
                _detailItem('DBS 电量', _dbsBatteryText),
                _detailItem('温度', _temperatureText),
                _detailItem('刺激状态', _stimulationText),
                _detailItem('LFP 感测', _lfpSensingText),
                _detailItem('当前模式', _modeText),
                _detailItem('CRC', '${state.crcOk}/${state.crcBad}'),
                _detailItem('HRV 连接状态', _connectionText(state.isBleConnected)),
                _detailItem('DBS 连接状态', _connectionText(state.isDbsConnected)),
                _detailItem(
                  'DBS 最近命令',
                  state.lastDbsCommandResult?.statusText ?? '未发送',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return SizedBox(
      width: 170,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fusionStatusText({bool compact = false}) {
    if (!state.isDbsConnected) {
      return compact ? '融合未启用' : '未发送';
    }
    if (state.isDbsEmergencyStopped) {
      return compact ? '急停锁定' : '急停已触发';
    }
    if (!state.isBleConnected || state.engineState != 3) {
      return compact ? 'DBS 单方刺激' : '等待 HRV 校准完成';
    }

    final result = state.lastDbsStressSendResult;
    if (result != null) {
      return result.statusText;
    }
    return compact ? '融合转发中' : '转发中';
  }

  String get _hrvDeviceName {
    if (state.isDemoMode) {
      return state.hrvConnection.deviceName ?? GlobalAppState.demoHrvDeviceName;
    }
    return state.hrvConnection.deviceName ?? '--';
  }

  String get _dbsDeviceName {
    if (state.isDemoMode) {
      return state.dbsConnection.deviceName ?? GlobalAppState.demoDbsDeviceName;
    }
    return state.dbsConnection.deviceName ?? '--';
  }

  String get _hrvBatteryText =>
      state.useBleSource ? '${state.batteryPct}%' : '--';
  String get _dbsBatteryText =>
      state.isDbsConnected ? '${state.dbsBatteryPercent}%' : '--';
  String get _temperatureText => state.dbsTemperatureC == null
      ? '--'
      : '${state.dbsTemperatureC!.toStringAsFixed(1)}°C';
  String get _stimulationText {
    if (!state.isDbsConnected) return '未知';
    return state.isDbsStimulating ? '运行' : '停止';
  }

  String get _lfpSensingText {
    if (!state.isDbsConnected) return '未知';
    final value = state.dbsRunStatus?.lfpSampleOn;
    if (value == null) return '未知';
    return value ? '开启' : '关闭';
  }

  String get _modeText {
    if (state.isDemoMode) return '演示模式';
    if (state.useBleSource || state.isDbsConnected) return '实时模式';
    return '手动模式';
  }

  String _connectionText(bool connected) => connected ? '已连接' : '未连接';

  String _formatTime(DateTime? time) {
    if (time == null) return '--';
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(time.hour)}:${twoDigits(time.minute)}:${twoDigits(time.second)}';
  }
}

class _DemoEcgCanvas extends StatelessWidget {
  final List<double> data;
  final List<int> rPeakIndices;

  const _DemoEcgCanvas({required this.data, required this.rPeakIndices});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBDBDBD)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: CustomPaint(
            size: Size.infinite,
            painter: EcgWaveformPainter(
              data: data,
              rPeakIndices: rPeakIndices,
              waveColor: const Color(0xFF34A853),
              rPeakColor: const Color(0xFFEA4335),
              rPeakDotsOnWave: false,
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveformCanvas extends StatelessWidget {
  final String title;
  final int sampleRate;
  final Color color;
  final List<double> data;
  final double timeScale;
  final bool isPaused;
  final List<int>? rPeakIndices;

  const _WaveformCanvas({
    required this.title,
    required this.sampleRate,
    required this.color,
    required this.data,
    required this.timeScale,
    required this.isPaused,
    this.rPeakIndices,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(size: Size.infinite, painter: _GridPainter()),
        CustomPaint(
          size: Size.infinite,
          painter: _WaveformPainter(
            data: data,
            color: color,
            timeScale: timeScale,
            sampleRate: sampleRate,
            rPeakOffsets: rPeakIndices,
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${sampleRate}Hz',
                style: TextStyle(color: color, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha((0.05 * 255).toInt())
      ..strokeWidth = 1.0;

    final double gridStep = 20.0;

    for (double i = 0; i < size.width; i += gridStep) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += gridStep) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WaveformPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double timeScale;
  final int sampleRate;
  final List<int>? rPeakOffsets;

  _WaveformPainter({
    required this.data,
    required this.color,
    required this.timeScale,
    required this.sampleRate,
    this.rPeakOffsets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      // 无数据时显示提示文字
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '等待数据…',
          style: TextStyle(color: Colors.white24, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();

    // 显示的最大点数 = timeScale * sampleRate
    int visiblePoints = (timeScale * sampleRate).toInt();

    // 从最新的数据开始往前画
    int startIdx = data.length > visiblePoints
        ? data.length - visiblePoints
        : 0;
    final visibleData = data.sublist(startIdx);

    double xStep = size.width / visiblePoints;
    double midY = size.height / 2;

    // 自动缩放：根据可见数据的实际范围计算
    double dataMin = visibleData[0];
    double dataMax = visibleData[0];
    for (final v in visibleData) {
      if (v < dataMin) dataMin = v;
      if (v > dataMax) dataMax = v;
    }
    final dataRange = dataMax - dataMin;
    double yScale;
    double dataMid = midY;
    if (dataRange < 1e-10) {
      // 全零或常量值，用默认缩放
      yScale = size.height / 200;
    } else {
      // 加 10% 边距防止触顶
      final adjustedRange = dataRange * 1.1;
      yScale = size.height / adjustedRange;
      dataMid = midY + ((dataMax + dataMin) / 2) * yScale;
    }

    for (int i = 0; i < visibleData.length; i++) {
      double x = i * xStep;
      double y = dataMid - visibleData[i] * yScale;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // 绘制 R 峰标记
    if (rPeakOffsets != null && rPeakOffsets!.isNotEmpty) {
      final rDotPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;
      final rLinePaint = Paint()
        ..color = Colors.red.withAlpha(80)
        ..strokeWidth = 0.5;

      for (final idx in rPeakOffsets!) {
        // idx 为 waveform 中的局部索引（0 = 第一点）
        if (idx < startIdx || idx >= data.length) continue;

        final localIdx = idx - startIdx;
        final x = localIdx * xStep;
        final y = dataMid - data[idx] * yScale;

        canvas.drawLine(Offset(x, 0), Offset(x, size.height), rLinePaint);
        canvas.drawCircle(Offset(x, y), 3.0, rDotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
