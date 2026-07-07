import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// 后端 API 响应模型
class UploadResult {
  final String fileId;
  final String fileName;
  final int sampleRate;
  final int numSamples;
  final double durationSec;
  final List<double> filteredData;
  final List<double> rawData;

  UploadResult.fromJson(Map<String, dynamic> json)
    : fileId = json['file_id'] as String,
      fileName = json['file_name'] as String,
      sampleRate = json['sample_rate'] as int,
      numSamples = json['num_samples'] as int,
      durationSec = (json['duration_sec'] as num).toDouble(),
      filteredData = (json['filtered_data'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      rawData = (json['raw_data'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
}

class HrvResult {
  final double heartRate;
  final double sdnnMs;
  final double rmssdMs;
  final double lfHfRatio;
  final double stressIndex;
  final int rPeakCount;
  final List<int> rPeakIndices;
  final List<double> rrIntervalsMs;
  final double meanRrMs;

  HrvResult.fromJson(Map<String, dynamic> json)
    : heartRate = (json['heart_rate'] as num).toDouble(),
      sdnnMs = (json['sdnn_ms'] as num).toDouble(),
      rmssdMs = (json['rmssd_ms'] as num).toDouble(),
      lfHfRatio = (json['lf_hf_ratio'] as num).toDouble(),
      stressIndex = (json['stress_index'] as num).toDouble(),
      rPeakCount = json['r_peak_count'] as int,
      rPeakIndices = (json['r_peak_indices'] as List<dynamic>).cast<int>(),
      rrIntervalsMs = (json['rr_intervals_ms'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      meanRrMs = (json['mean_rr_ms'] as num).toDouble();
}

class AnalyzeResult {
  final String? reportId;
  final double healthScore;
  final double avgHeartRate;
  final double hrvStressIndex;
  final Interpretation interpretation;

  AnalyzeResult.fromJson(Map<String, dynamic> json)
    : reportId = json['report_id'] as String?,
      healthScore = (json['health_score'] as num).toDouble(),
      avgHeartRate = (json['avg_heart_rate'] as num).toDouble(),
      hrvStressIndex = (json['hrv_stress_index'] as num).toDouble(),
      interpretation = Interpretation.fromJson(
        json['interpretation'] as Map<String, dynamic>,
      );
}

class Interpretation {
  final String summary;
  final List<String> findings;
  final List<String> recommendations;

  Interpretation.fromJson(Map<String, dynamic> json)
    : summary = json['summary'] as String,
      findings = (json['findings'] as List<dynamic>).cast<String>(),
      recommendations = (json['recommendations'] as List<dynamic>)
          .cast<String>();
}

/// Naoxinyuyu 后端 API 客户端
///
/// 封装所有与 Python 后端的 HTTP 通信。
/// 后端默认地址: http://localhost:8000
class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({this.baseUrl = 'http://localhost:8000'}) : _client = http.Client();

  /// 健康检查
  Future<bool> healthCheck() async {
    try {
      final resp = await _client
          .get(Uri.parse('$baseUrl/api/v1/health'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['status'] == 'ok';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 上传 .mat 文件并解析（支持 Web 和原生）
  /// - [bytes]: 文件字节（Web 用）
  /// - [fileName]: 文件名
  /// - [filePath]: 本地路径（原生用，可选）
  Future<UploadResult> uploadMatFile({
    String? filePath,
    List<int>? bytes,
    String? fileName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/files/mat'),
    );

    if (bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName ?? 'upload.mat',
        ),
      );
    } else if (filePath != null) {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('文件不存在: $filePath');
      }
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    } else {
      throw Exception('必须提供 bytes 或 filePath');
    }

    final streamedResp = await request.send().timeout(
      const Duration(seconds: 30),
    );
    final resp = await http.Response.fromStream(streamedResp);

    if (resp.statusCode != 200) {
      throw Exception('上传失败 (${resp.statusCode}): ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return UploadResult.fromJson(json);
  }

  /// 计算 HRV 指标
  /// [fileId] upload 接口返回的文件 ID
  Future<HrvResult> computeHrv(String fileId) async {
    final resp = await _client
        .post(
          Uri.parse('$baseUrl/api/v1/analysis/hrv'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'file_id': fileId}),
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw Exception('HRV 计算失败 (${resp.statusCode}): ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return HrvResult.fromJson(json);
  }

  /// 生成分析报告
  /// [fileId] upload 接口返回的文件 ID
  Future<AnalyzeResult> analyze(String fileId) async {
    final resp = await _client
        .post(
          Uri.parse('$baseUrl/api/v1/analysis/report'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'file_id': fileId}),
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw Exception('分析失败 (${resp.statusCode}): ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return AnalyzeResult.fromJson(json);
  }

  /// 释放资源
  void dispose() {
    _client.close();
  }
}
