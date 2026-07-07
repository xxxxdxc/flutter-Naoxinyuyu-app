import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/session_history_service.dart';
import '../../../core/state/global_app_state.dart';
import '../../../core/theme/app_theme.dart';

class HistoryRecordsPage extends StatelessWidget {
  const HistoryRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalAppState>(
      builder: (context, state, child) {
        return RefreshIndicator(
          onRefresh: state.loadHistorySessions,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(context, state),
              const SizedBox(height: 16),
              if (state.isLoadingHistory)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.historySessions.isEmpty)
                _buildEmptyState(context)
              else
                ...state.historySessions.map(
                  (session) => _SessionSummaryCard(session: session),
                ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, GlobalAppState state) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryMain.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.folder_copy_outlined,
            color: AppTheme.primaryMain,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '历史记录',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                '${state.activeUserName} · ${state.historySessions.length} 条记录${state.isDemoMode ? ' · 演示中' : ''}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '刷新',
          onPressed: () => state.loadHistorySessions(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        children: [
          Icon(Icons.history, size: 56, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text('暂无历史记录', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '连接 BLE 并接收数据后，会自动保存到这里。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  final SessionSummary session;

  const _SessionSummaryCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final isDemoLog =
        session.recordType == historyRecordTypeDemoOperation;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.divider.withAlpha(80)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HistorySessionDetailPage(session: session),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDateTime(session.startedAt),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StatusPill(isComplete: session.isComplete),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isDemoLog) ...[
                Text(
                  '演示模式操作日志',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.primaryMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  _MetricChip(
                    icon: Icons.timer_outlined,
                    label: '时长',
                    value: _formatDuration(session.duration),
                  ),
                  _MetricChip(
                    icon: isDemoLog
                        ? Icons.science_outlined
                        : Icons.show_chart,
                    label: isDemoLog ? '类型' : '样本',
                    value: isDemoLog ? '演示' : '${session.ecgSampleCount}',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _MetricChip(
                    icon: Icons.favorite_border,
                    label: '平均心率',
                    value: _formatNumber(
                      session.averageHeartRate,
                      suffix: ' BPM',
                    ),
                  ),
                  _MetricChip(
                    icon: Icons.monitor_heart_outlined,
                    label: 'RMSSD',
                    value: _formatNumber(session.averageRmssd, suffix: ' ms'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _MetricChip(
                    icon: Icons.warning_amber_outlined,
                    label: '平均压力',
                    value: _formatNumber(session.averageStressScore),
                  ),
                  _MetricChip(
                    icon: Icons.battery_std,
                    label: '设备',
                    value: session.deviceName,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistorySessionDetailPage extends StatelessWidget {
  final SessionSummary session;

  const HistorySessionDetailPage({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('采集详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOverview(context),
          const SizedBox(height: 16),
          _buildMetricGrid(context),
          const SizedBox(height: 16),
          _buildStorageInfo(context),
        ],
      ),
    );
  }

  Widget _buildOverview(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.divider.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.assignment_outlined,
                  color: AppTheme.primaryMain,
                ),
                const SizedBox(width: 8),
                Text(
                  '会话摘要',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _StatusPill(isComplete: session.isComplete),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(label: '用户', value: session.userName),
            _DetailRow(
              label: session.recordType == historyRecordTypeDemoOperation
                  ? '日志'
                  : '设备',
              value: session.recordType == historyRecordTypeDemoOperation
                  ? '演示模式操作日志'
                  : session.deviceName,
            ),
            if (session.recordType == historyRecordTypeDemoOperation)
              _DetailRow(label: '演示设备', value: session.deviceName),
            _DetailRow(
              label: '开始时间',
              value: _formatDateTime(session.startedAt),
            ),
            _DetailRow(
              label: '结束时间',
              value: session.endedAt == null
                  ? '采集中'
                  : _formatDateTime(session.endedAt!),
            ),
            _DetailRow(label: '采集时长', value: _formatDuration(session.duration)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricGrid(BuildContext context) {
    final isDemoLog =
        session.recordType == historyRecordTypeDemoOperation;
    final items = isDemoLog
        ? [
            const _DetailMetric('记录类型', '演示日志', Icons.science_outlined),
            _DetailMetric(
              '最终心率',
              _formatNumber(session.averageHeartRate, suffix: ' BPM'),
              Icons.favorite_border,
            ),
            _DetailMetric(
              '最终 RMSSD',
              _formatNumber(session.averageRmssd, suffix: ' ms'),
              Icons.analytics_outlined,
            ),
            _DetailMetric(
              '最终压力',
              _formatNumber(session.averageStressScore),
              Icons.psychology_outlined,
            ),
            _DetailMetric(
              '信号质量',
              _formatNumber(session.maxStressScore, suffix: '%'),
              Icons.fact_check_outlined,
            ),
          ]
        : [
            _DetailMetric('ECG 样本', '${session.ecgSampleCount}', Icons.show_chart),
            _DetailMetric('采样率', '${session.sampleRate} Hz', Icons.speed),
            _DetailMetric(
              'HRV 记录',
              '${session.hrvRecordCount}',
              Icons.monitor_heart_outlined,
            ),
            _DetailMetric(
              '压力记录',
              '${session.stressRecordCount}',
              Icons.warning_amber_outlined,
            ),
            _DetailMetric(
              '平均心率',
              _formatNumber(session.averageHeartRate, suffix: ' BPM'),
              Icons.favorite_border,
            ),
            _DetailMetric(
              '平均 RMSSD',
              _formatNumber(session.averageRmssd, suffix: ' ms'),
              Icons.analytics_outlined,
            ),
            _DetailMetric(
              '平均压力',
              _formatNumber(session.averageStressScore),
              Icons.psychology_outlined,
            ),
            _DetailMetric(
              '最高压力',
              _formatNumber(session.maxStressScore),
              Icons.trending_up,
            ),
          ];

    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      children: items.map((item) => _DetailMetricCard(item: item)).toList(),
    );
  }

  Widget _buildStorageInfo(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.divider.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本地文件',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(
              session.sessionPath,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            '$label ',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isComplete;

  const _StatusPill({required this.isComplete});

  @override
  Widget build(BuildContext context) {
    final color = isComplete ? AppTheme.success : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        isComplete ? '已完成' : '采集中',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _DetailMetric {
  final String label;
  final String value;
  final IconData icon;

  const _DetailMetric(this.label, this.value, this.icon);
}

class _DetailMetricCard extends StatelessWidget {
  final _DetailMetric item;

  const _DetailMetricCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.divider.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 18, color: AppTheme.primaryMain),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              item.value,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)} '
      '${two(dateTime.hour)}:${two(dateTime.minute)}';
}

String _formatDuration(Duration duration) {
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60);
    return minutes == 0
        ? '${duration.inHours} 小时'
        : '${duration.inHours}小时$minutes分钟';
  }
  if (duration.inMinutes > 0) {
    final seconds = duration.inSeconds.remainder(60);
    return seconds == 0
        ? '${duration.inMinutes} 分钟'
        : '${duration.inMinutes}分$seconds秒';
  }
  return '${duration.inSeconds} 秒';
}

String _formatNumber(double? value, {String suffix = ''}) {
  if (value == null) return '--';
  return '${value.toStringAsFixed(1)}$suffix';
}
