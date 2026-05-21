import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/state/global_app_state.dart';
import '../../../core/services/ble_service.dart';
import '../../../core/theme/app_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('脑心愈郁', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.brandPurple)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {},
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DeviceCardsRow(),
            const SizedBox(height: 16),
            const _HeartRateCard(),
            const SizedBox(height: 16),
            Consumer<GlobalAppState>(
              builder: (context, state, _) {
                if (!state.useBleSource && !state.isReplaying) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    const _MoodBarometerCard(),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            const _EngineStateCard(),
            const SizedBox(height: 16),
            const _MetricsGrid(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDevicePanel(context),
        backgroundColor: AppTheme.primaryLight.withAlpha((0.2 * 255).toInt()),
        elevation: 0,
        child: Consumer<GlobalAppState>(
          builder: (context, state, _) => Icon(
            state.isBleConnected
                ? Icons.bluetooth_connected
                : Icons.bluetooth,
            color: state.isBleConnected
                ? Colors.green
                : AppTheme.primaryDark,
          ),
        ),
      ),
    );
  }

  void _showDevicePanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _DevicePanelContent();
      },
    );
  }
}

/// 设备管理面板内容（带连接状态反馈）
class _DevicePanelContent extends StatefulWidget {
  @override
  State<_DevicePanelContent> createState() => _DevicePanelContentState();
}

class _DevicePanelContentState extends State<_DevicePanelContent> {
  bool _isConnecting = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalAppState>(
      builder: (context, state, child) {
        // 同步本地连接中状态与全局状态
        if (!_isConnecting && state.isBleConnected) {
          // 已连接，正常显示
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('设备管理', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              // HRV 胸带
              ListTile(
                leading: const Icon(Icons.watch, color: AppTheme.deviceHrv),
                title: const Text('KT6368A 胸带 (BLE)'),
                subtitle: Text(_getHrvSubtitle(state)),
                trailing: _buildHrvTrailing(state),
              ),
              const Divider(),
              // DBS 设备（预留）
              ListTile(
                leading: Icon(Icons.psychology, color: Colors.grey[400]),
                title: Text('DBS 设备', style: TextStyle(color: Colors.grey[400])),
                subtitle: Text('预留', style: TextStyle(color: Colors.grey[500])),
                trailing: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.grey[500],
                  ),
                  child: const Text('连接'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _getHrvSubtitle(GlobalAppState state) {
    if (_isConnecting) return '连接中...';
    if (state.isBleConnected) return '已连接 (电量 ${state.batteryPct}%)';
    return '未连接';
  }

  Widget _buildHrvTrailing(GlobalAppState state) {
    if (_isConnecting) {
      return const SizedBox(
        width: 24, height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return ElevatedButton(
      onPressed: () => _handleHrvToggle(state),
      child: Text(state.isBleConnected ? '断开' : '连接'),
    );
  }

  Future<void> _handleHrvToggle(GlobalAppState state) async {
    if (state.isBleConnected) {
      await state.disconnectBle();
      return;
    }

    setState(() => _isConnecting = true);

    try {
      final ok = await state.startBleConnection();
      if (mounted) {
        setState(() => _isConnecting = false);
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('连接失败：设备不支持数据通知')),
          );
        }
      }
    } on BleConnectException catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接异常: $e')),
        );
      }
    }
  }
}

class _DeviceCardsRow extends StatelessWidget {
  const _DeviceCardsRow();

  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalAppState>(
      builder: (context, state, child) {
        return Row(
          children: [
            Expanded(
              child: _DeviceCard(
                title: 'HRV 胸带',
                icon: Icons.watch,
                color: AppTheme.deviceHrv,
                isConnected: state.hrvConnection.status == ConnectionStatus.connected,
                battery: state.hrvConnection.batteryLevel ?? 0,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _DeviceCard(
                title: 'DBS 设备',
                icon: Icons.psychology,
                color: Colors.grey,
                isConnected: false,
                battery: 0,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isConnected;
  final int battery;

  const _DeviceCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.isConnected,
    required this.battery,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.divider.withAlpha((0.3 * 255).toInt())),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha((0.1 * 255).toInt()),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.battery_charging_full, size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 2),
                      Text('$battery%', style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isConnected ? AppTheme.connected : AppTheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartRateCard extends StatelessWidget {
  const _HeartRateCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalAppState>(
      builder: (context, state, child) {
        final hr = state.currentHeartRate ?? 0;
        final displayHr = hr > 0 ? hr.toStringAsFixed(0) : '--';
        final progress = hr > 0 ? (hr / 120).clamp(0.0, 1.0) : 0.0;
        // 模拟最高/最低（实际应从历史数据取）
        final maxHr = hr > 0 ? (hr + 8).toStringAsFixed(0) : '--';
        final minHr = hr > 0 ? (hr - 5).toStringAsFixed(0) : '--';

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
                Text('实时心率监控', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 24),
                SizedBox(
                  height: 160,
                  width: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: AppTheme.primaryMain.withAlpha((0.1 * 255).toInt()),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryMain),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(displayHr, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 48, color: AppTheme.primaryMain)),
                            Text('BPM', style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text('最高', style: Theme.of(context).textTheme.labelSmall),
                        Text(maxHr, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('最低', style: Theme.of(context).textTheme.labelSmall),
                        Text(minHr, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid();

  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalAppState>(
      builder: (context, state, child) {
        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            _MetricItem(
              title: 'HRV (RMSSD)',
              value: state.lastRmssd != null
                  ? state.lastRmssd!.toStringAsFixed(1)
                  : (state.useBleSource ? '蓄积中' : '--'),
              unit: state.lastRmssd != null ? 'ms' : '',
              icon: Icons.favorite_border,
            ),
            _MetricItem(
              title: '心率',
              value: state.currentHeartRate != null
                  ? state.currentHeartRate!.toStringAsFixed(1)
                  : '--',
              unit: state.currentHeartRate != null ? 'BPM' : '',
              icon: Icons.monitor_heart_outlined,
            ),
            const _ModeCard(),
            _MetricItem(
              title: 'LF/HF',
              value: state.lastLfHf != null
                  ? state.lastLfHf!.toStringAsFixed(2)
                  : (state.useBleSource ? '蓄积中' : '--'),
              unit: '',
              icon: Icons.show_chart,
            ),
          ],
        );
      },
    );
  }
}

class _EngineStateCard extends StatelessWidget {
  const _EngineStateCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalAppState>(
      builder: (context, state, child) {
        if (!state.useBleSource && !state.isReplaying) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: AppTheme.divider.withAlpha((0.3 * 255).toInt())),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, size: 20, color: AppTheme.brandPurple),
                    const SizedBox(width: 8),
                    Text('情绪引擎',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                    const Spacer(),
                    if (state.useBleSource)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('BLE',
                            style:
                                TextStyle(fontSize: 11, color: Colors.green)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildEngineContent(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEngineContent(BuildContext context, GlobalAppState state) {
    switch (state.engineState) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusChip('未校准', Colors.grey),
            const SizedBox(height: 12),
            if (state.useBleSource)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => state.sendBleCommand('CMD:C\n'),
                  icon: const Icon(Icons.track_changes, size: 18),
                  label: const Text('开始基线校准'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusChip('基线校准中', Colors.orange),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: state.calmNeed > 0
                  ? state.calmDone / state.calmNeed
                  : 0,
            ),
            const SizedBox(height: 4),
            Text('${state.calmDone} / ${state.calmNeed}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (state.useBleSource)
              TextButton.icon(
                onPressed: () => state.sendBleCommand('CMD:X\n'),
                icon: const Icon(Icons.cancel, size: 16, color: Colors.red),
                label: const Text('取消校准',
                    style: TextStyle(color: Colors.red)),
              ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusChip('应激诱导中', Colors.red),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: state.stressNeed > 0
                  ? state.stressDone / state.stressNeed
                  : 0,
              color: Colors.red,
            ),
            const SizedBox(height: 4),
            Text('${state.stressDone} / ${state.stressNeed}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (state.useBleSource)
              TextButton.icon(
                onPressed: () => state.sendBleCommand('CMD:X\n'),
                icon: const Icon(Icons.cancel, size: 16, color: Colors.red),
                label: const Text('取消校准',
                    style: TextStyle(color: Colors.red)),
              ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusChip(
                    state.isStressed ? '应激' : '平静',
                    state.isStressed ? Colors.red : Colors.green),
                const SizedBox(width: 8),
                Text('推理 #${state.inferCount}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              (state.emotionScore * 100).toStringAsFixed(0),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: state.isStressed
                        ? Colors.red
                        : AppTheme.brandPurple,
                  ),
            ),
            Text('情绪得分',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;

  const _MetricItem({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(unit, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalAppState>(
      builder: (context, state, child) {
        final modeDesc = state.currentModeDescription;

        return GestureDetector(
          onTap: () => _showModeSelector(context),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: modeDesc.color.withAlpha((0.3 * 255).toInt()),
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // 模式图标
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: modeDesc.color.withAlpha((0.1 * 255).toInt()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(modeDesc.icon, color: modeDesc.color, size: 24),
                  ),
                  const SizedBox(width: 12),

                  // 模式信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前模式',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                modeDesc.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: modeDesc.color,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 状态指示灯
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: state.stimulation.status == StimStatus.running
                                    ? AppTheme.error
                                    : AppTheme.connected,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 切换箭头
                  Icon(
                    Icons.arrow_forward_ios,
                    color: AppTheme.textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showModeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => _ModeSelectorBottomSheet(),
    );
  }
}

class _ModeSelectorBottomSheet extends StatelessWidget {
  const _ModeSelectorBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalAppState>(
      builder: (context, state, child) {
        final allModes = state.getAllModeDescriptions();
        final currentMode = state.currentModeDescription;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SafeArea(child: ListView(
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            children: [
              // 标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '选择治疗模式',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '当前模式: ${currentMode.name}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),

              // 模式列表
              ...allModes.map((modeDesc) => _ModeOptionTile(
                modeDesc: modeDesc,
                isSelected: modeDesc.mode == state.stimulation.mode,
                onTap: () => _handleModeSelection(context, state, modeDesc.mode),
              )),

              const SizedBox(height: 16),
            ],
          )),
        );
      },
    );
  }

  Future<void> _handleModeSelection(
    BuildContext context,
    GlobalAppState state,
    TreatmentMode newMode,
  ) async {
    // 尝试切换模式
    final success = await state.changeTreatmentMode(newMode);

    if (!success) {
      // 需要确认（设备正在运行）
      final confirmed = await _showConfirmationDialog(context, state, newMode);
      if (confirmed) {
        // 强制切换模式
        await state.changeTreatmentMode(newMode, force: true);
        Navigator.pop(context); // 关闭底部面板
        _showSuccessSnackbar(context, '模式已切换，刺激已停止');
      }
    } else {
      // 直接切换成功
      Navigator.pop(context); // 关闭底部面板
      _showSuccessSnackbar(context, '模式已切换');
    }
  }

  Future<bool> _showConfirmationDialog(
    BuildContext context,
    GlobalAppState state,
    TreatmentMode newMode,
  ) async {
    final newModeDesc = state.getAllModeDescriptions()
        .firstWhere((desc) => desc.mode == newMode);

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认切换模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('设备正在运行刺激，切换模式将停止当前刺激。'),
            const SizedBox(height: 16),
            const Text('当前刺激参数:'),
            Text('• 强度: ${state.stimulation.intensity} mA'),
            Text('• 频率: ${state.stimulation.frequency} Hz'),
            Text('• 脉宽: ${state.stimulation.pulseWidth} μs'),
            const SizedBox(height: 16),
            Text('切换到: ${newModeDesc.name}'),
            Text('模式特点: ${newModeDesc.description}'),
            const SizedBox(height: 16),
            const Text('确定要切换吗？', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('停止并切换'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ModeOptionTile extends StatelessWidget {
  final ModeDescription modeDesc;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOptionTile({
    required this.modeDesc,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? modeDesc.color : AppTheme.divider.withAlpha((0.3 * 255).toInt()),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // 模式图标
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: modeDesc.color.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(modeDesc.icon, color: modeDesc.color, size: 20),
              ),
              const SizedBox(width: 12),

              // 模式信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modeDesc.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: modeDesc.color,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      modeDesc.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 信息图标和选择标记
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 信息图标
                  GestureDetector(
                    onTap: () => _showModeDetails(context, modeDesc),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 选择标记
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: modeDesc.color,
                      size: 24,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showModeDetails(BuildContext context, ModeDescription modeDesc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(modeDesc.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: modeDesc.color.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(modeDesc.icon, color: modeDesc.color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  '模式详情',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(modeDesc.description),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              '适用场景:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _getModeUsageTips(modeDesc.mode),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _getModeUsageTips(TreatmentMode mode) {
    switch (mode) {
      case TreatmentMode.manual:
        return const Text('• 临床测试和调试\n• 参数优化实验\n• 紧急手动干预');
      case TreatmentMode.hrvResponse:
        return const Text('• 焦虑抑郁治疗\n• 自主神经功能调节\n• 压力管理');
      case TreatmentMode.eegResponse:
        return const Text('• 神经振荡异常治疗\n• 认知功能改善\n• 睡眠障碍治疗');
      case TreatmentMode.hybrid:
        return const Text('• 复杂症状治疗\n• 多模态生物反馈\n• 个性化治疗方案');
    }
  }
}

class _MoodBarometerCard extends StatefulWidget {
  const _MoodBarometerCard();

  @override
  State<_MoodBarometerCard> createState() => _MoodBarometerCardState();
}

class _MoodBarometerCardState extends State<_MoodBarometerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _sliderController;
  late Animation<double> _sliderAnimation;
  double? _previousMoodValue;

  @override
  void initState() {
    super.initState();
    _sliderController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _sliderAnimation = CurvedAnimation(
      parent: _sliderController,
      curve: Curves.easeInOut,
    );
    // 初始启动动画
    _sliderController.forward();
  }

  @override
  void dispose() {
    _sliderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalAppState>(
      builder: (context, state, child) {
        debugPrint('MoodBarometerCard building, moodState: ${state.moodState.level} ${state.moodState.value}');
        final moodState = state.moodState;

        // 检查情绪值是否变化，如果变化则重新启动动画
        if (_previousMoodValue != null && _previousMoodValue != moodState.value) {
          _sliderController.reset();
          _sliderController.forward();
        }
        _previousMoodValue = moodState.value;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.divider.withAlpha((0.3 * 255).toInt())),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '情绪晴雨表',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Icon(
                      _getDynamicMoodIcon(moodState.value),
                      color: _getMoodColor(moodState.level),
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 主要内容：三列布局
                _buildContentLayout(context, moodState),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentLayout(BuildContext context, MoodState moodState) {
    // 响应式布局：小屏幕垂直，大屏幕水平
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    if (isSmallScreen) {
      return Column(
        children: [
          // 情绪状态
          _buildMoodStatus(context, moodState),
          const SizedBox(height: 16),
          // 渐变进度条
          _buildGradientProgressBar(context, moodState.value),
          const SizedBox(height: 16),
          // 行动建议按钮
          _buildActionButton(context, moodState.suggestion),
        ],
      );
    } else {
      return Row(
        children: [
          // 左侧：情绪状态 (2/7比例)
          Expanded(
            flex: 2,
            child: _buildMoodStatus(context, moodState),
          ),
          // 中间：渐变进度条 (3/7比例)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildGradientProgressBar(context, moodState.value),
            ),
          ),
          // 右侧：行动建议按钮 (2/7比例)
          Expanded(
            flex: 2,
            child: _buildActionButton(context, moodState.suggestion),
          ),
        ],
      );
    }
  }

  Widget _buildMoodStatus(BuildContext context, MoodState moodState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${moodState.value.toInt()}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _getMoodColor(moodState.level),
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          moodState.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildGradientProgressBar(BuildContext context, double value) {
    return Column(
      children: [
        // 使用LayoutBuilder获取实际宽度
        LayoutBuilder(
          builder: (context, constraints) {
            final progressBarWidth = constraints.maxWidth;

            return SizedBox(
              height: 24, // 包含滑块的高度
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // 渐变条背景
                  Container(
                    height: 8,
                    width: progressBarWidth,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppTheme.primaryLight,
                          AppTheme.primaryDark,
                        ],
                      ),
                    ),
                  ),

                  // 进度填充
                  AnimatedBuilder(
                    animation: _sliderAnimation,
                    builder: (context, child) {
                      return Container(
                        height: 8,
                        width: progressBarWidth *
                            (value / 100) *
                            _sliderAnimation.value,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.white.withAlpha((0.3 * 255).toInt()),
                        ),
                      );
                    },
                  ),

                  // 滑块
                  AnimatedBuilder(
                    animation: _sliderAnimation,
                    builder: (context, child) {
                      final sliderPosition = progressBarWidth *
                          (value / 100) *
                          _sliderAnimation.value;

                      return Positioned(
                        left: sliderPosition - 12, // 滑块宽度24，中心对齐
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha((0.1 * 255).toInt()),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.circle,
                            size: 8,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),

        // 刻度标签
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('低落', style: Theme.of(context).textTheme.labelSmall),
            Text('中性', style: Theme.of(context).textTheme.labelSmall),
            Text('良好', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String suggestion) {
    return ElevatedButton(
      onPressed: () {
        _showSuggestionDialog(context, suggestion);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryMain,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: const Text('行动建议'),
    );
  }

  void _showSuggestionDialog(BuildContext context, String suggestion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('情绪调节建议'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('根据您当前的情绪状态，建议：'),
            const SizedBox(height: 16),
            Text(suggestion),
            const SizedBox(height: 16),
            const Text(
              '提示：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('• 建议每天进行10-15分钟的放松练习'),
            const Text('• 保持规律的作息时间'),
            const Text('• 如有需要，及时咨询专业人员'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 获取动态情绪图标（7档表情映射）
  IconData _getDynamicMoodIcon(double value) {
    if (value < 10) return Icons.sentiment_very_dissatisfied;     // 0-10: 😢
    if (value < 25) return Icons.sentiment_dissatisfied;          // 10-25: 😞
    if (value < 35) return Icons.sentiment_neutral;               // 25-35: 😐
    if (value < 50) return Icons.sentiment_satisfied_alt;         // 35-50: 🙂
    if (value < 65) return Icons.sentiment_satisfied;             // 50-65: 😊
    if (value < 85) return Icons.sentiment_very_satisfied;        // 65-85: 😄
    return Icons.emoji_emotions;                                 // 85-100: 😁
  }

  // 获取情绪颜色
  Color _getMoodColor(MoodLevel level) {
    switch (level) {
      case MoodLevel.veryLow:
        return AppTheme.error; // 红色
      case MoodLevel.low:
        return AppTheme.warning; // 橙色
      case MoodLevel.neutral:
        return AppTheme.textSecondary; // 灰色
      case MoodLevel.good:
        return AppTheme.connected; // 绿色
      case MoodLevel.excellent:
        return AppTheme.primaryMain; // 蓝色
    }
    // 永远不会执行到这里，但为了编译安全
    return AppTheme.textSecondary;
  }

}
