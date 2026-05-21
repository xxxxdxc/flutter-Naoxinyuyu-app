import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/state/global_app_state.dart';
import '../../../core/theme/app_theme.dart';
import 'analysis_report_page.dart';
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
    _tabController = TabController(length: 3, vsync: this);
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
        backgroundColor: _tabController.index == 0 ? Colors.black : Colors.white,
        foregroundColor: _tabController.index == 0 ? Colors.white : AppTheme.textPrimary,
        title: const Text('数据分析', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '实时波形'),
            Tab(text: '分析报告'),
            Tab(text: '离线测试'),
          ],
          labelColor: _tabController.index == 0 ? Colors.white : AppTheme.primaryMain,
          unselectedLabelColor: _tabController.index == 0 ? Colors.white70 : AppTheme.textSecondary,
          indicatorColor: _tabController.index == 0 ? Colors.white : AppTheme.primaryMain,
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
              Expanded(
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
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
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
        CustomPaint(
          size: Size.infinite,
          painter: _GridPainter(),
        ),
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
              Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('${sampleRate}Hz', style: TextStyle(color: color, fontSize: 12)),
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
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // 显示的最大点数 = timeScale * sampleRate
    int visiblePoints = (timeScale * sampleRate).toInt();
    
    // 从最新的数据开始往前画
    int startIdx = data.length > visiblePoints ? data.length - visiblePoints : 0;
    
    double xStep = size.width / visiblePoints;
    double midY = size.height / 2;
    
    // 假设数据范围在 -100 到 100 之间，进行缩放
    double yScale = size.height / 200;

    for (int i = 0; i < data.length - startIdx; i++) {
      double x = i * xStep;
      double y = midY - (data[startIdx + i] * yScale);
      
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

      for (final offset in rPeakOffsets!) {
        final globalIdx = data.length + offset; // offset 为负
        if (globalIdx < startIdx || globalIdx >= data.length) continue;

        final localIdx = globalIdx - startIdx;
        final x = localIdx * xStep;
        final y = midY - (data[globalIdx] * yScale);

        canvas.drawLine(Offset(x, 0), Offset(x, size.height), rLinePaint);
        canvas.drawCircle(Offset(x, y), 3.0, rDotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
