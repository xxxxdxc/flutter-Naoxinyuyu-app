import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../visualizer/components/ecg_waveform_painter.dart';

// 辅助颜色常量
const Color _successBg = Color(0xFFE8F5E9);
const Color _successMain = Color(0xFF4CAF50);
const Color _textHint = Color(0xFFBDBDBD);
const Color _warningMain = Color(0xFFFF9800);
const Color _errorMain = Color(0xFFF44336);

/// 离线数据测试页面
///
/// 接入 Python 后端：选文件 → 上传 → HRV 计算 → 波形渲染 + 指标显示
class OfflineTestPage extends StatefulWidget {
  const OfflineTestPage({super.key});

  @override
  State<OfflineTestPage> createState() => _OfflineTestPageState();
}

class _OfflineTestPageState extends State<OfflineTestPage> {
  final ApiClient _api = ApiClient();

  // 文件状态
  String? _fileName;
  bool _isBackendOnline = false;
  bool _isProcessing = false;

  // 解析结果
  UploadResult? _uploadResult;
  HrvResult? _hrvResult;

  @override
  void initState() {
    super.initState();
    _checkBackend();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _checkBackend() async {
    final ok = await _api.healthCheck();
    if (mounted) {
      setState(() => _isBackendOnline = ok);
    }
  }

  Future<void> _pickAndProcessFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mat'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      setState(() {
        _fileName = file.name;
        _isProcessing = true;
        _uploadResult = null;
        _hrvResult = null;
      });

      // 1. 上传 .mat 文件并解析
      final upload = await _api.uploadMatFile(file.path!);

      // 2. 计算 HRV 指标
      final hrv = await _api.computeHrv(upload.fileId);

      if (mounted) {
        setState(() {
          _uploadResult = upload;
          _hrvResult = hrv;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('处理失败: $e'),
            backgroundColor: _errorMain,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBackendStatus(),
            const SizedBox(height: 12),
            _buildFileInfo(),
            const SizedBox(height: 16),
            _buildWaveformArea(),
            const SizedBox(height: 16),
            _buildMetricSection(),
            const SizedBox(height: 20),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackendStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isBackendOnline ? _successBg : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isBackendOnline ? _successMain : _warningMain,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: _isBackendOnline ? _successMain : _warningMain,
          ),
          const SizedBox(width: 6),
          Text(
            _isBackendOnline ? '后端服务已连接' : '后端未连接',
            style: TextStyle(
              fontSize: 12,
              color: _isBackendOnline ? _successMain : _warningMain,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _checkBackend,
            child: const Icon(Icons.refresh, size: 14, color: _textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfo() {
    final hasFile = _fileName != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: hasFile ? _successBg : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasFile ? _successMain : AppTheme.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasFile ? Icons.description : Icons.folder_open,
            color: hasFile ? _successMain : AppTheme.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFile ? _fileName! : '未选择文件',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: hasFile ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
                if (_uploadResult != null)
                  Text(
                    '${_uploadResult!.numSamples} 采样点 · '
                    '${_uploadResult!.durationSec.toStringAsFixed(1)} 秒 · '
                    '${_uploadResult!.sampleRate}Hz',
                    style: const TextStyle(fontSize: 12, color: _textHint),
                  )
                else if (!hasFile)
                  const Text(
                    '请选择一个 .mat 数据文件',
                    style: TextStyle(fontSize: 12, color: _textHint),
                  ),
              ],
            ),
          ),
          if (_isProcessing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_hrvResult != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _successBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '分析完成',
                style: TextStyle(
                  fontSize: 12,
                  color: _successMain,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWaveformArea() {
    if (_uploadResult != null && _hrvResult != null) {
      final data = _uploadResult!.filteredData;
      // 最多显示 5000 点（10 秒），截取最后部分
      final displayData = data.length > 5000
          ? data.sublist(data.length - 5000)
          : data;

      return Container(
        width: double.infinity,
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: CustomPaint(
            size: const Size(double.infinity, 260),
            painter: EcgWaveformPainter(
              data: displayData,
              rPeakIndices: _hrvResult!.rPeakIndices,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 56, color: _textHint.withAlpha(100)),
          const SizedBox(height: 12),
          const Text('ECG 波形图区域',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _textHint)),
          const SizedBox(height: 4),
          const Text('选择 .mat 文件后将在此显示波形',
              style: TextStyle(fontSize: 13, color: _textHint)),
        ],
      ),
    );
  }

  Widget _buildMetricSection() {
    final metrics = _buildMetricList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final (label, value, unit, icon, color) = metrics[index];
        return _buildMetricCard(label, value, unit, icon, color);
      },
    );
  }

  List<(String, String, String, IconData, Color)> _buildMetricList() {
    if (_hrvResult != null) {
      return [
        ('心率', _hrvResult!.heartRate.toStringAsFixed(1), 'BPM',
            Icons.favorite, _errorMain),
        ('SDNN', _hrvResult!.sdnnMs.toStringAsFixed(1), 'ms',
            Icons.timeline, AppTheme.primaryMain),
        ('RMSSD', _hrvResult!.rmssdMs.toStringAsFixed(1), 'ms',
            Icons.show_chart, _successMain),
        ('R峰数', '${_hrvResult!.rPeakCount}', '个',
            Icons.trip_origin, _warningMain),
      ];
    }
    return [
      ('心率', '--', 'BPM', Icons.favorite, _errorMain),
      ('SDNN', '--', 'ms', Icons.timeline, AppTheme.primaryMain),
      ('RMSSD', '--', 'ms', Icons.show_chart, _successMain),
      ('R峰数', '--', '个', Icons.trip_origin, _warningMain),
    ];
  }

  Widget _buildMetricCard(
      String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 10, color: _textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : _pickAndProcessFile,
        icon: Icon(_isProcessing ? Icons.hourglass_top : Icons.folder_open),
        label: Text(
          _isProcessing ? '正在分析...' : '选择 .mat 文件',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryMain,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.primaryMain.withAlpha(100),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
