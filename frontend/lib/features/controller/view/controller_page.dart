import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/dbs_models.dart';
import '../../../core/state/global_app_state.dart';
import '../../../core/theme/app_theme.dart';

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key});

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  bool _isLocked = true;
  bool _isDirty = false;

  double _intensity = 2.5;
  double _frequency = 130.0;
  double _pulseWidth = 60.0;

  // 新增状态变量
  TreatmentMode? _currentMode;
  bool _isManualMode = false; // 初始设为false，直到获取到真实模式

  // 安全上限状态变量
  double _maxIntensity = 10.0; // 最大强度上限
  double _maxFrequency = 150.0; // 最大频率上限
  double _maxPulseWidth = 500.0; // 最大脉宽上限

  @override
  void initState() {
    super.initState();
    // 初始读取状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final globalState = context.read<GlobalAppState>();
      final stimulation = globalState.stimulation;

      setState(() {
        _intensity = stimulation.intensity;
        _frequency = stimulation.frequency;
        _pulseWidth = stimulation.pulseWidth;
        _currentMode = stimulation.mode;
        _isManualMode = _currentMode == TreatmentMode.manual;
        _updateSafetyLimits(globalState);
        _clampParametersToLimits(); // 确保初始参数在安全范围内
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 监听模式变化
    final state = context.read<GlobalAppState>();
    if (_currentMode != state.stimulation.mode) {
      setState(() {
        _currentMode = state.stimulation.mode;
        _isManualMode = _currentMode == TreatmentMode.manual;
        _updateSafetyLimits(state);
        _clampParametersToLimits(); // 确保参数在安全范围内
      });
    }
  }

  void _updateSafetyLimits(GlobalAppState state) {
    // 从全局状态获取当前模式的安全上限
    final limits = state.getCurrentSafetyLimits();
    setState(() {
      _maxIntensity = limits.maxIntensity;
      _maxFrequency = limits.maxFrequency;
      _maxPulseWidth = limits.maxPulseWidth;
    });
  }

  void _clampParametersToLimits() {
    if (!_isManualMode) {
      setState(() {
        _intensity = _intensity.clamp(0.0, _maxIntensity);
        _frequency = _frequency.clamp(0.0, _maxFrequency);
        _pulseWidth = _pulseWidth.clamp(0.0, _maxPulseWidth);
      });
    }
  }

  void _markDirty() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  Widget _buildModeInfoCard(BuildContext context) {
    return Consumer<GlobalAppState>(
      builder: (context, state, child) {
        final modeDesc = state.currentModeDescription;
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: modeDesc.color.withAlpha(76),
            ), // 0.3 opacity
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(modeDesc.icon, color: modeDesc.color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前模式: ${modeDesc.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isManualMode
                            ? '手动控制 - 参数将下发至 DBS'
                            : '自动模式 - HRV 校准完成后才向 DBS 转发压力得分',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDemoStatusCard(BuildContext context, GlobalAppState state) {
    if (!state.isDemoMode) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.brandPurple.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, color: AppTheme.brandPurple),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '演示模式：参数下发和 E-STOP 由本地演示设备反馈；不向真实 DBS 发送压力分数。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Text(
              state.isDbsStimulating ? '刺激运行' : '刺激停止',
              style: TextStyle(
                color: state.isDbsStimulating
                    ? AppTheme.success
                    : AppTheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDbsDebugCard(BuildContext context, GlobalAppState state) {
    final gatt = state.dbsGattDiagnostic;
    final stressResult = state.lastDbsStressSendResult;
    final canSendStress = state.canSendHrvStressToDbs;
    final disabledReason = _manualStressDisabledReason(state);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.deviceDbs.withAlpha(76)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: const Text('DBS 联调测试'),
        subtitle: Text(
          state.isDbsEmergencyStopped
              ? '急停已触发，断开并重新连接 DBS 后解除'
              : '连接、ACK、LFP 感测与压力分数发送状态',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          if (state.isDbsEmergencyStopped)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withAlpha(24),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.error.withAlpha(90)),
              ),
              child: const Text(
                '急停锁定中：参数同步、开启刺激和压力分数发送已禁用。',
                style: TextStyle(
                  color: AppTheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _debugLine('Service', _boolText(gatt.serviceFound)),
              _debugLine('Write', _boolText(gatt.writeFound)),
              _debugLine('Notify', _boolText(gatt.deviceNotifyFound)),
              _debugLine('Stream', _boolText(gatt.streamDataFound)),
              _debugLine('Storage', _boolText(gatt.storageDataFound)),
              _debugLine('MTU', gatt.mtuStatus),
              _debugLine('连接阶段', gatt.connectionStage),
              _debugLine('最近错误', gatt.lastError ?? '--'),
              _debugLine(
                'LFP 感测',
                _commandResultText(state.lastDbsSensingResult),
              ),
              _debugLine(
                '最近命令',
                _commandResultText(state.lastDbsCommandResult),
              ),
              _debugLine('压力发送', stressResult?.statusText ?? '未发送'),
              _debugLine(
                '压力序号',
                state.lastDbsStressSentAt == null
                    ? '--'
                    : '${state.lastDbsStressSeq}',
              ),
              _debugLine(
                '压力分数',
                state.lastDbsStressScore == null
                    ? '--'
                    : '${state.lastDbsStressScore}',
              ),
              _debugLine('HRV 状态', state.engineState == 3 ? '正式监测' : '等待校准'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.send_outlined),
                  label: Text(
                    canSendStress ? '发送当前 HRV 压力分数' : disabledReason,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: canSendStress
                      ? () => _sendCurrentStressScore(context)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _debugLine(String label, String value) {
    return SizedBox(
      width: 170,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _boolText(bool value) => value ? '已找到' : '未找到';

  String _commandResultText(DbsCommandResult? result) {
    if (result == null) return '未发送';
    return result.statusText;
  }

  String _manualStressDisabledReason(GlobalAppState state) {
    if (state.isDemoMode) return '演示模式禁用';
    if (state.isDbsEmergencyStopped) return '急停锁定';
    if (!state.isDbsConnected) return '等待 DBS 连接';
    if (!state.isBleConnected || state.engineState != 3) {
      return '等待 HRV 校准完成';
    }
    return '不可发送';
  }

  Future<void> _sendCurrentStressScore(BuildContext context) async {
    final state = context.read<GlobalAppState>();
    final result = await state.sendCurrentHrvStressScoreToDbs();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('压力分数发送结果: ${result.statusText}')));
  }

  Future<void> _confirmEmergencyStop(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认紧急停止'),
        content: const Text(
          '将立即向 DBS 下发 E-STOP 指令并进入本地急停锁定。锁定后需断开并重新连接 DBS 才能恢复参数下发。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              '取消',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认急停'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final state = context.read<GlobalAppState>();
    final result = await state.triggerDbsEmergencyStop();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('DBS 急停结果: ${result.statusText}')));
  }

  Widget _buildSafetyLimitsSection(BuildContext context) {
    if (_isManualMode) return const SizedBox(); // 手动模式不显示安全上限

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.warning.withAlpha(76)), // 0.3 opacity
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: AppTheme.warning),
                const SizedBox(width: 8),
                Text('安全上限设置', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '当前为自动模式，算法控制实时参数。您可以设置参数安全上限:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 32),

            // 最大强度设置
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('最大强度'),
                Text(
                  '${_maxIntensity.toStringAsFixed(1)} mA',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: _maxIntensity,
              min: 0.0,
              max: 10.0,
              divisions: 100,
              label: _maxIntensity.toStringAsFixed(1),
              onChanged: (val) {
                setState(() => _maxIntensity = val);
                _clampParametersToLimits();
              },
            ),

            const SizedBox(height: 24),

            // 最大频率设置
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('最大频率'),
                Text(
                  '${_maxFrequency.toStringAsFixed(1)} Hz',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: _maxFrequency,
              min: 0.0,
              max: 150.0,
              divisions: 150,
              label: _maxFrequency.toStringAsFixed(1),
              onChanged: (val) {
                setState(() => _maxFrequency = val);
                _clampParametersToLimits();
              },
            ),

            const SizedBox(height: 24),

            // 最大脉宽设置
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('最大脉宽'),
                Text(
                  '${_maxPulseWidth.toStringAsFixed(0)} μs',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: _maxPulseWidth,
              min: 0.0,
              max: 500.0,
              divisions: 100,
              label: _maxPulseWidth.toStringAsFixed(0),
              onChanged: (val) {
                setState(() => _maxPulseWidth = val);
                _clampParametersToLimits();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _syncParams(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认同步参数'),
        content: Text(
          '将下发新参数:\n强度: $_intensity mA\n频率: $_frequency Hz\n脉宽: $_pulseWidth μs\n\n确定执行吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '取消',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final state = context.read<GlobalAppState>();
              try {
                await state.syncDbsStimParams(
                  intensityMa: _intensity,
                  frequencyHz: _frequency,
                  pulseWidthUs: _pulseWidth,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('DBS 参数下发成功')));
                setState(() {
                  _isDirty = false;
                  _isLocked = true;
                });
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('DBS 参数下发失败: $e')));
              }
            },
            child: const Text('确认下发'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 确保状态同步
    final globalState = context.watch<GlobalAppState>();
    final isDbsConnected = globalState.isDbsConnected;
    final currentStimulation = globalState.stimulation;

    // 如果本地状态未初始化或与全局状态不同步，更新它
    if (_currentMode == null || _currentMode != currentStimulation.mode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentMode = currentStimulation.mode;
            _isManualMode = _currentMode == TreatmentMode.manual;
            _updateSafetyLimits(globalState);
            _clampParametersToLimits();
          });
        }
      });
    }

    // 计算安全频率值
    final safeFrequency = _frequency.clamp(
      0.0,
      _isManualMode ? 150.0 : _maxFrequency,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '参数控制',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(
              _isLocked ? Icons.lock : Icons.lock_open,
              color: _isManualMode
                  ? (_isLocked ? AppTheme.textSecondary : AppTheme.primaryMain)
                  : AppTheme.textSecondary,
            ),
            label: Text(
              _isManualMode ? (_isLocked ? '解锁编辑' : '已解锁') : '自动模式锁定',
              style: TextStyle(
                color: _isManualMode
                    ? (_isLocked
                          ? AppTheme.textSecondary
                          : AppTheme.primaryMain)
                    : AppTheme.textSecondary,
              ),
            ),
            onPressed: _isManualMode
                ? () {
                    setState(() {
                      _isLocked = !_isLocked;
                    });
                  }
                : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModeInfoCard(context),
            _buildDemoStatusCard(context, globalState),
            _buildDbsDebugCard(context, globalState),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppTheme.divider.withAlpha((0.3 * 255).toInt()),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('刺激参数', style: Theme.of(context).textTheme.titleLarge),
                    const Divider(height: 32),

                    // Intensity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('强度 (Intensity)'),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${_intensity.toStringAsFixed(1)} mA',
                              style: TextStyle(
                                fontSize: 20,
                                color: _isDirty
                                    ? AppTheme.primaryMain
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!_isManualMode)
                              Text(
                                '算法实时控制',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _intensity,
                      min: 0.0,
                      max: _isManualMode ? 10.0 : _maxIntensity, // 动态最大值
                      divisions: 100,
                      label: _intensity.toStringAsFixed(1),
                      onChanged: _isManualMode && !_isLocked
                          ? (val) {
                              setState(() => _intensity = val);
                              _markDirty();
                            }
                          : null,
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '0 mA',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '10.0 mA',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Frequency
                    const Text('频率 (Frequency) - Hz'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.divider),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: DropdownButton<double>(
                          value: safeFrequency,
                          isExpanded: true,
                          underline: const SizedBox(), // 移除默认下划线
                          items: () {
                            final maxFreq = _isManualMode
                                ? 150.0
                                : _maxFrequency;
                            // 使用安全频率值，确保不超过上限
                            final currentFreq = safeFrequency;

                            // 使用Set确保选项唯一性
                            final optionSet = <double>{};

                            // 添加预设选项中不超过上限的值
                            for (final freq in [60.0, 100.0, 130.0, 150.0]) {
                              if (freq <= maxFreq) {
                                optionSet.add(freq);
                              }
                            }

                            // 总是添加当前安全频率值（确保下拉菜单有匹配项）
                            optionSet.add(currentFreq);

                            // 确保至少有一个选项
                            if (optionSet.isEmpty) {
                              optionSet.add(maxFreq > 0 ? maxFreq : 60.0);
                            }

                            // 转换为排序列表
                            final options = optionSet.toList()..sort();

                            return options.map((f) {
                              return DropdownMenuItem<double>(
                                value: f,
                                child: Text(
                                  '$f Hz ${f == 130.0 ? '(Default)' : ''}',
                                ),
                              );
                            }).toList();
                          }(),
                          onChanged: _isManualMode && !_isLocked
                              ? (val) {
                                  if (val != null) {
                                    setState(() => _frequency = val);
                                    _markDirty();
                                  }
                                }
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pulse Width
                    const Text('脉宽 (Pulse Width) - μs'),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _pulseWidth.toStringAsFixed(0),
                      enabled: _isManualMode && !_isLocked,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        hintText: _isManualMode ? '' : '算法控制',
                      ),
                      onChanged: _isManualMode && !_isLocked
                          ? (val) {
                              final parsed = double.tryParse(val);
                              if (parsed != null) {
                                setState(
                                  () => _pulseWidth = parsed.clamp(
                                    0.0,
                                    _isManualMode ? 500.0 : _maxPulseWidth,
                                  ),
                                );
                                _markDirty();
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 安全上限设置部分
            _buildSafetyLimitsSection(context),
            const SizedBox(height: 32),

            // Sync Button
            ElevatedButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('同步至设备'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isDirty &&
                        _isManualMode &&
                        isDbsConnected &&
                        !globalState.isDbsEmergencyStopped
                    ? AppTheme.primaryMain
                    : AppTheme.divider.withAlpha((0.5 * 255).toInt()),
                foregroundColor:
                    _isDirty &&
                        _isManualMode &&
                        isDbsConnected &&
                        !globalState.isDbsEmergencyStopped
                    ? Colors.white
                    : AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed:
                  _isManualMode &&
                      _isDirty &&
                      !_isLocked &&
                      isDbsConnected &&
                      !globalState.isDbsEmergencyStopped
                  ? () => _syncParams(context)
                  : null,
            ),
            const SizedBox(height: 16),

            // E-STOP Button
            Consumer<GlobalAppState>(
              builder: (context, state, _) {
                final bool canEstop =
                    state.isDbsConnected && !state.isDbsEmergencyStopped;
                return ElevatedButton.icon(
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('紧急停止 (E-STOP)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canEstop
                        ? AppTheme.error
                        : Colors.grey[350],
                    foregroundColor: canEstop ? Colors.white : Colors.grey[500],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: canEstop
                      ? () => _confirmEmergencyStop(context)
                      : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
