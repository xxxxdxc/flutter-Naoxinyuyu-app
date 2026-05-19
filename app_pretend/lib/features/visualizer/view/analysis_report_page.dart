import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/state/global_app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../components/trend_chart_painter.dart';

class AnalysisReportPage extends StatefulWidget {
  const AnalysisReportPage({super.key});

  @override
  State<AnalysisReportPage> createState() => _AnalysisReportPageState();
}

class _AnalysisReportPageState extends State<AnalysisReportPage> {
  @override
  void initState() {
    super.initState();
    // 初始化时生成分析报告
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<GlobalAppState>();
      if (state.currentAnalysis == null) {
        state.generateAnalysis();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalAppState>(
      builder: (context, state, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 时间范围选择器
              _buildTimeRangeSelector(context, state),
              const SizedBox(height: 24),

              if (state.isGeneratingReport)
                _buildLoadingState()
              else if (state.currentAnalysis != null)
                _buildReportContent(context, state)
              else
                _buildEmptyState(context),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeRangeSelector(BuildContext context, GlobalAppState state) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.divider.withAlpha((0.3 * 255).toInt())),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('时间范围', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<TimeRange>(
              segments: const [
                ButtonSegment<TimeRange>(
                  value: TimeRange.last24h,
                  label: Text('最近24小时'),
                  icon: Icon(Icons.today, size: 16),
                ),
                ButtonSegment<TimeRange>(
                  value: TimeRange.last7d,
                  label: Text('最近7天'),
                  icon: Icon(Icons.calendar_view_week, size: 16),
                ),
                ButtonSegment<TimeRange>(
                  value: TimeRange.last30d,
                  label: Text('最近30天'),
                  icon: Icon(Icons.calendar_month, size: 16),
                ),
                ButtonSegment<TimeRange>(
                  value: TimeRange.custom,
                  label: Text('自定义'),
                  icon: Icon(Icons.settings, size: 16),
                ),
              ],
              selected: {state.selectedTimeRange},
              onSelectionChanged: (Set<TimeRange> newSelection) {
                if (newSelection.isNotEmpty) {
                  state.updateTimeRange(newSelection.first);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Center(
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryMain),
              ),
              const SizedBox(height: 16),
              Text('正在生成分析报告...', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.divider.withAlpha((0.3 * 255).toInt())),
      ),
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.analytics, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text('数据采集中', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('请稍后再查看分析报告', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<GlobalAppState>().generateAnalysis();
              },
              child: const Text('生成模拟报告'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, GlobalAppState state) {
    final analysis = state.currentAnalysis!;
    final aiInterpretation = state.aiInterpretation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 健康评分卡片
        _buildHealthScoreCard(context, analysis),
        const SizedBox(height: 16),

        // 关键指标网格
        _buildMetricsGrid(context, analysis),
        const SizedBox(height: 16),

        // AI解读卡片
        _buildAiInterpretationCard(context, aiInterpretation),
        const SizedBox(height: 16),

        // 趋势图表卡片
        _buildTrendChartCard(context, analysis),
      ],
    );
  }

  Widget _buildHealthScoreCard(BuildContext context, AnalysisMetrics analysis) {
    final healthScore = analysis.healthScore;
    String statusText;
    Color statusColor;

    if (healthScore >= 80) {
      statusText = '状态极佳';
      statusColor = AppTheme.success;
    } else if (healthScore >= 60) {
      statusText = '状态良好';
      statusColor = AppTheme.info;
    } else if (healthScore >= 40) {
      statusText = '需注意';
      statusColor = AppTheme.warning;
    } else {
      statusText = '建议咨询医生';
      statusColor = AppTheme.error;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.divider.withAlpha((0.3 * 255).toInt())),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text('健康评分', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: healthScore / 100,
                    strokeWidth: 12,
                    backgroundColor: AppTheme.primaryMain.withAlpha((0.1 * 255).toInt()),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          healthScore.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontSize: 48,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '报告生成时间: ${_formatDateTime(analysis.generatedAt)}',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, AnalysisMetrics analysis) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 1 : 2;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: crossAxisCount == 1 ? 3.2 : 1.6,
      children: [
        _buildMetricItem(
          context,
          title: '平均心率',
          value: analysis.avgHeartRate.toStringAsFixed(0),
          unit: 'BPM',
          icon: Icons.favorite_border,
          trend: analysis.avgHeartRate > 72 ? '↑' : '↓',
        ),
        _buildMetricItem(
          context,
          title: 'HRV压力指数',
          value: analysis.hrvStressIndex.toStringAsFixed(0),
          unit: '点',
          icon: Icons.heart_broken,
          status: analysis.hrvStressIndex < 50 ? '放松' : '压力',
          statusColor: analysis.hrvStressIndex < 50 ? AppTheme.success : AppTheme.warning,
        ),
        _buildMetricItem(
          context,
          title: '异常脑电占比',
          value: analysis.abnormalEegPercentage.toStringAsFixed(1),
          unit: '%',
          icon: Icons.psychology,
          subtitle: 'Beta波活跃',
          isHighlight: analysis.abnormalEegPercentage > 20,
        ),
        _buildMetricItem(
          context,
          title: '总刺激时长',
          value: _formatDuration(analysis.totalStimulationTime),
          unit: '',
          icon: Icons.timer,
          subtitle: '占监测时间${(analysis.totalStimulationTime.inHours / 24 * 100).toStringAsFixed(0)}%',
        ),
      ],
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    String? trend,
    String? status,
    Color? statusColor,
    String? subtitle,
    bool isHighlight = false,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.divider.withAlpha((0.3 * 255).toInt())),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(title, style: Theme.of(context).textTheme.labelSmall),
                if (trend != null) ...[
                  const SizedBox(width: 4),
                  Text(trend, style: TextStyle(
                    color: trend == '↑' ? AppTheme.success : AppTheme.error,
                    fontSize: 12,
                  )),
                ],
                if (status != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor?.withAlpha((0.1 * 255).toInt()),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor ?? Colors.transparent, width: 1),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isHighlight ? AppTheme.primaryMain : AppTheme.textPrimary,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(unit, style: Theme.of(context).textTheme.labelSmall),
                ],
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiInterpretationCard(BuildContext context, AiInterpretation? aiInterpretation) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.primaryMain.withAlpha((0.3 * 255).toInt())),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryMain.withAlpha((0.1 * 255).toInt()),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.psychology, color: AppTheme.primaryMain, size: 20),
                ),
                const SizedBox(width: 8),
                Text('AI智能解读', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                const Icon(Icons.auto_awesome, size: 16, color: AppTheme.primaryMain),
              ],
            ),
            const SizedBox(height: 16),

            if (aiInterpretation != null) ...[
              // 总结部分
              if (aiInterpretation.summary.isNotEmpty) ...[
                Text(
                  aiInterpretation.summary,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 发现部分
              if (aiInterpretation.findings.isNotEmpty) ...[
                Text('发现:', style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                )),
                const SizedBox(height: 8),
                ...aiInterpretation.findings.map((finding) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: AppTheme.textSecondary)),
                      Expanded(
                        child: Text(finding, style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
              ],

              // 建议部分
              if (aiInterpretation.recommendations.isNotEmpty) ...[
                Text('建议:', style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                )),
                const SizedBox(height: 8),
                ...aiInterpretation.recommendations.map((recommendation) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: AppTheme.primaryMain)),
                      Expanded(
                        child: Text(recommendation, style: TextStyle(color: AppTheme.textPrimary)),
                      ),
                    ],
                  ),
                )),
              ],

              const SizedBox(height: 16),
              Text(
                'AI生成时间: ${_formatDateTime(aiInterpretation.generatedAt)}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ] else ...[
              // AI解读生成中状态
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryMain),
                    ),
                    const SizedBox(height: 16),
                    Text('AI正在生成报告中...', style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    )),
                    const SizedBox(height: 8),
                    Text(
                      '请稍候，AI正在分析您的生理数据',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChartCard(BuildContext context, AnalysisMetrics analysis) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.divider.withAlpha((0.3 * 255).toInt())),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('趋势分析', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '刺激强度与生理指标变化趋势',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            // 图表容器
            AspectRatio(
              aspectRatio: 16 / 10, // 16:10的宽高比
              child: Container(
                constraints: const BoxConstraints(minHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.divider.withAlpha((0.5 * 255).toInt())),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomPaint(
                      painter: TrendChartPainter(
                        intensityData: analysis.intensityTrend,
                        physiologicalData: analysis.physiologicalTrend,
                        intensityColor: AppTheme.primaryMain,
                        physiologicalColor: AppTheme.success,
                        xAxisTitle: '时间',
                        intensityYAxisTitle: '强度 (mA)',
                        physiologicalYAxisTitle: 'HRV',
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('刺激强度', AppTheme.primaryMain),
                const SizedBox(width: 16),
                _buildLegendItem('HRV指标', AppTheme.success),
              ],
            ),

            const SizedBox(height: 16),
            Text(
              '说明: 趋势图表显示刺激强度与HRV指标随时间变化关系，用于评估治疗效果',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              '提示: 图表已优化显示，自动调整数据点密度确保清晰可读',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}年${dateTime.month}月${dateTime.day}日 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours >= 24) {
      final days = duration.inHours ~/ 24;
      final hours = duration.inHours % 24;
      if (hours > 0) {
        return '${days}天${hours}小时';
      }
      return '${days}天';
    } else if (duration.inHours > 0) {
      final minutes = duration.inMinutes % 60;
      if (minutes > 0) {
        return '${duration.inHours}小时${minutes}分钟';
      }
      return '${duration.inHours}小时';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}分钟';
    }
    return '${duration.inSeconds}秒';
  }
}