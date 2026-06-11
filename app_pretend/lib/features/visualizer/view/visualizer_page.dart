import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/state/global_app_state.dart';
import '../../../core/theme/app_theme.dart';
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
                child: _WaveformCanvas(
                  title: 'CH2: ECG (HRV)',
                  sampleRate: state.ecgStream.sampleRate,
                  color: Colors.pinkAccent,
                  data: state.ecgStream.waveform,
                  timeScale: _timeScale,
                  isPaused: _isPaused,
                  rPeakIndices: state.useBleSource ? state.rPeakIndices : null,
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

/// BLE 实时数据面板 — HRV指标 / 设备信息 / 压力分值
class _BleDataPanel extends StatelessWidget {
  final GlobalAppState state;
  const _BleDataPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),
          // === 板块一：HRV 指标 ===
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
          // === 板块二：设备信息 ===
          _sectionTitle('设备信息'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (state.useBleSource)
                _infoItem(
                  Icons.monitor_heart_outlined,
                  '胸环',
                  '${state.batteryPct}%',
                  state.batteryPct,
                ),
              if (state.isDbsConnected)
                _infoItem(
                  Icons.psychology,
                  'DBS',
                  '${state.dbsBatteryPercent}%',
                  state.dbsBatteryPercent,
                ),
              if (state.isDbsConnected)
                _plainInfoItem(
                  Icons.thermostat,
                  '温度',
                  state.dbsTemperatureC == null
                      ? '--'
                      : '${state.dbsTemperatureC!.toStringAsFixed(1)}°C',
                ),
              if (state.isDbsConnected)
                _plainInfoItem(
                  Icons.bolt,
                  '刺激',
                  state.isDbsStimulating ? '运行' : '停止',
                ),
            ],
          ),
          const SizedBox(height: 12),
          // === 板块三：压力分值 ===
          _sectionTitle('压力分值'),
          const SizedBox(height: 4),
          _buildStressSection(),
        ],
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

  Widget _infoItem(IconData icon, String label, String value, int batteryPct) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: batteryPct > 20 ? Colors.greenAccent : Colors.redAccent,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _plainInfoItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.lightBlueAccent),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: engineColor.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: engineColor.withAlpha(80)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
                '$score',
                style: TextStyle(
                  color: engineColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                engineLabel,
                style: TextStyle(
                  color: engineColor.withAlpha(180),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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
