import 'dart:convert';

/// BLE ASCII 文本协议解析器
///
/// 协议格式（START/END 边界，XOR8 CRC）：
/// ```
/// START
/// SYS:mode,source_fs,process_fs,batt_v,batt_pct,charge
/// DBG:DCRC,ok,bad,no_crc
/// ECG:v1,v2,v3,...,vN
/// RPK:num,idx1,idx2,...,idxN
/// HRV:rdy60,rdy300,hr,rmssd,pnn50,lf,hf,lf_hf
/// STR:state,calm_done,calm_need,stress_done,stress_need,score_raw,score_smoothed,is_stressed,infer_count
/// PKTCRC:XX
/// END
/// ```
class BleParser {
  final List<int> _buffer = [];
  static const int maxBufferSize = 102400; // 100KB

  /// 输入 BLE 原始字节，尝试提取 0~N 个完整数据包
  List<BlePacket> feed(List<int> chunk) {
    _buffer.addAll(chunk);

    // 防内存溢出
    if (_buffer.length > maxBufferSize) {
      _buffer.clear();
      return [];
    }

    final packets = <BlePacket>[];
    final text = utf8.decode(_buffer, allowMalformed: true);

    int searchStart = 0;
    while (true) {
      final startIdx = text.indexOf('START', searchStart);
      if (startIdx < 0) break;

      final endIdx = text.indexOf('END', startIdx + 5);
      if (endIdx < 0) break;

      // 提取 START ~ END 之间的完整文本
      final packetText = text.substring(startIdx, endIdx + 3);

      final packet = _parsePacket(packetText);
      if (packet != null) {
        packets.add(packet);
      }

      searchStart = endIdx + 3;
    }

    // 清理已处理的字节
    if (searchStart > 0) {
      final consumed = utf8.encode(text.substring(0, searchStart)).length;
      if (consumed > 0 && consumed <= _buffer.length) {
        _buffer.removeRange(0, consumed);
      }
    }

    return packets;
  }

  BlePacket? _parsePacket(String text) {
    // 提取包体（START 之后、PKTCRC 之前的内容用于 CRC 计算）
    final bodyEnd = text.lastIndexOf('PKTCRC:');
    if (bodyEnd < 0) return null;

    final crcLineEnd = text.indexOf('\n', bodyEnd);
    final crcLine = (crcLineEnd > bodyEnd)
        ? text.substring(bodyEnd, crcLineEnd).trim()
        : text.substring(bodyEnd).trim();

    // 校验 CRC
    final expectedCrc = _parseHexCrc(crcLine);
    if (expectedCrc == null) return null;

    // CRC 计算范围：START 之后、PKTCRC 行之前的所有字节
    final crcBody = text.substring(5, bodyEnd); // 跳过 "START"
    if (!_verifyCrc(crcBody, expectedCrc)) return null;

    // 按行解析
    final lines = _parseLines(text);
    if (lines.isEmpty) return null;

    try {
      // SYS
      final sysParts = _splitLine(lines['SYS']);
      final mode = sysParts.isNotEmpty ? int.tryParse(sysParts[0]) ?? 0 : 0;
      final sourceFs = sysParts.length > 1 ? _parseDouble(sysParts[1]) ?? 500.0 : 500.0;
      final processFs = sysParts.length > 2 ? _parseDouble(sysParts[2]) ?? 500.0 : 500.0;
      final battV = sysParts.length > 3 ? _parseDouble(sysParts[3]) ?? 0.0 : 0.0;
      final battPct = sysParts.length > 4 ? int.tryParse(sysParts[4]) ?? 0 : 0;
      final charge = sysParts.length > 5 ? int.tryParse(sysParts[5]) ?? 0 : 0;

      // ECG
      final ecgWaveform = _parseEcgLine(lines['ECG']);

      // RPK
      final (rPeakCount, rPeakIndices) = _parseRpkLine(lines['RPK']);

      // HRV (optional)
      int? rdy60;
      int? rdy300;
      double? hr;
      double? rmssd;
      double? pnn50;
      double? lf;
      double? hf;
      double? lfHf;

      if (lines.containsKey('HRV')) {
        final hrvParts = _splitLine(lines['HRV']);
        if (hrvParts.length >= 8) {
          rdy60 = int.tryParse(hrvParts[0]);
          rdy300 = int.tryParse(hrvParts[1]);
          hr = _parseDouble(hrvParts[2]);
          rmssd = _parseDouble(hrvParts[3]);
          pnn50 = _parseDouble(hrvParts[4]);
          lf = _parseDouble(hrvParts[5]);
          hf = _parseDouble(hrvParts[6]);
          lfHf = _parseDouble(hrvParts[7]);
        }
      }

      // STR
      final strParts = _splitLine(lines['STR']);
      final strState = strParts.isNotEmpty ? int.tryParse(strParts[0]) ?? 0 : 0;
      final calmDone = strParts.length > 1 ? int.tryParse(strParts[1]) ?? 0 : 0;
      final calmNeed = strParts.length > 2 ? int.tryParse(strParts[2]) ?? 7 : 7;
      final stressDone = strParts.length > 3 ? int.tryParse(strParts[3]) ?? 0 : 0;
      final stressNeed = strParts.length > 4 ? int.tryParse(strParts[4]) ?? 2 : 2;
      final scoreRaw = strParts.length > 5 ? _parseDouble(strParts[5]) ?? 0.0 : 0.0;
      final scoreSmoothed = strParts.length > 6 ? _parseDouble(strParts[6]) ?? 0.0 : 0.0;
      final isStressed = strParts.length > 7 ? int.tryParse(strParts[7]) ?? 0 : 0;
      final inferCount = strParts.length > 8 ? int.tryParse(strParts[8]) ?? 0 : 0;

      // DBG:DCRC（可选）
      int? dbgCrcOk;
      int? dbgCrcBad;
      int? dbgNoCrc;
      if (lines.containsKey('DBG')) {
        final dbgLine = lines['DBG']!;
        if (dbgLine.startsWith('DCRC,')) {
          final dbgParts = _splitLine(dbgLine.substring(5));
          dbgCrcOk = dbgParts.isNotEmpty ? int.tryParse(dbgParts[0]) : null;
          dbgCrcBad = dbgParts.length > 1 ? int.tryParse(dbgParts[1]) : null;
          dbgNoCrc = dbgParts.length > 2 ? int.tryParse(dbgParts[2]) : null;
        }
      }

      return BlePacket(
        mode: mode,
        sourceFs: sourceFs,
        processFs: processFs,
        battV: battV,
        battPct: battPct,
        charge: charge,
        ecgWaveform: ecgWaveform,
        rPeakCount: rPeakCount,
        rPeakIndices: rPeakIndices,
        rdy60: rdy60,
        rdy300: rdy300,
        hr: hr,
        rmssd: rmssd,
        pnn50: pnn50,
        lf: lf,
        hf: hf,
        lfHf: lfHf,
        strState: strState,
        calmDone: calmDone,
        calmNeed: calmNeed,
        stressDone: stressDone,
        stressNeed: stressNeed,
        scoreRaw: scoreRaw,
        scoreSmoothed: scoreSmoothed,
        isStressed: isStressed,
        inferCount: inferCount,
        dbgCrcOk: dbgCrcOk,
        dbgCrcBad: dbgCrcBad,
        dbgNoCrc: dbgNoCrc,
      );
    } catch (_) {
      return null;
    }
  }

  /// XOR8 校验
  bool _verifyCrc(String body, int expectedCrc) {
    final bytes = utf8.encode(body);
    int crc = 0;
    for (final byte in bytes) {
      crc ^= byte;
    }
    return crc == expectedCrc;
  }

  /// 解析 PKTCRC:XX 行，返回十六进制值
  int? _parseHexCrc(String line) {
    final colonIdx = line.indexOf(':');
    if (colonIdx < 0) return null;
    final hexStr = line.substring(colonIdx + 1).trim();
    if (hexStr.isEmpty) return null;
    return int.tryParse(hexStr, radix: 16);
  }

  /// 将文本分割为行，返回 key-value 映射
  Map<String, String> _parseLines(String text) {
    final lines = text.split('\n');
    final map = <String, String>{};

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed == 'START' || trimmed == 'END') continue;
      if (trimmed.startsWith('PKTCRC:')) continue;

      final colonIdx = trimmed.indexOf(':');
      if (colonIdx < 0) continue;

      // 处理 DBG:DCRC 这种带冒号的 key
      // 如果第二个字符是 ':' 或 key 以 DBG 开头
      String key;
      String value;
      if (trimmed.startsWith('DBG:')) {
        key = 'DBG';
        value = trimmed.substring(4);
      } else {
        key = trimmed.substring(0, colonIdx);
        value = trimmed.substring(colonIdx + 1);
      }

      map[key] = value;
    }

    return map;
  }

  /// 解析 ECG 行：逗号分隔的浮点数列表
  List<double> _parseEcgLine(String? value) {
    if (value == null || value.isEmpty) return [];
    final parts = value.split(',');
    final result = <double>[];
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final num = _parseDouble(trimmed);
      if (num != null) {
        result.add(num);
      }
    }
    return result;
  }

  /// 解析 RPK 行：首字段为计数，后续为索引
  (int, List<int>) _parseRpkLine(String? value) {
    if (value == null || value.isEmpty) return (0, []);
    final parts = value.split(',');
    if (parts.isEmpty) return (0, []);
    final count = int.tryParse(parts[0].trim()) ?? 0;
    final indices = <int>[];
    for (int i = 1; i < parts.length; i++) {
      final idx = int.tryParse(parts[i].trim());
      if (idx != null) indices.add(idx);
    }
    return (count, indices);
  }

  List<String> _splitLine(String? value) {
    if (value == null || value.isEmpty) return [];
    return value.split(',').map((s) => s.trim()).toList();
  }

  double? _parseDouble(String s) {
    return double.tryParse(s.trim());
  }

  void clear() {
    _buffer.clear();
  }
}

/// 一个完整的 BLE 数据包，包含所有解析后的字段
class BlePacket {
  // SYS
  final int mode;
  final double sourceFs;
  final double processFs;
  final double battV;
  final int battPct;
  final int charge;

  // ECG
  final List<double> ecgWaveform;

  // RPK
  final int rPeakCount;
  final List<int> rPeakIndices;

  // HRV (可能为 null — HRV 行不是每个包都有)
  final int? rdy60;
  final int? rdy300;
  final double? hr;
  final double? rmssd;
  final double? pnn50;
  final double? lf;
  final double? hf;
  final double? lfHf;

  // STR
  final int strState;
  final int calmDone;
  final int calmNeed;
  final int stressDone;
  final int stressNeed;
  final double scoreRaw;
  final double scoreSmoothed;
  final int isStressed;
  final int inferCount;

  // DBG（可选）
  final int? dbgCrcOk;
  final int? dbgCrcBad;
  final int? dbgNoCrc;

  const BlePacket({
    this.mode = 0,
    this.sourceFs = 500,
    this.processFs = 500,
    this.battV = 0.0,
    this.battPct = 0,
    this.charge = 0,
    this.ecgWaveform = const [],
    this.rPeakCount = 0,
    this.rPeakIndices = const [],
    this.rdy60,
    this.rdy300,
    this.hr,
    this.rmssd,
    this.pnn50,
    this.lf,
    this.hf,
    this.lfHf,
    this.strState = 0,
    this.calmDone = 0,
    this.calmNeed = 7,
    this.stressDone = 0,
    this.stressNeed = 2,
    this.scoreRaw = 0.0,
    this.scoreSmoothed = 0.0,
    this.isStressed = 0,
    this.inferCount = 0,
    this.dbgCrcOk,
    this.dbgCrcBad,
    this.dbgNoCrc,
  });

  /// HRV 行是否在此包中存在
  bool get hasHrv => rdy60 != null;
}

/// 硬件数据的完整指标集合（保留以兼容旧代码）
class HardwareMetricsPacket {
  final List<double>? ecgWaveform;
  final List<double>? eegWaveform;
  final int ecgSampleRate;
  final int eegSampleRate;

  // HRV
  final double? heartRate;
  final double? sdnn;
  final double? rmssd;
  final double? lfHfRatio;
  final double? hrvStressIndex;

  // EEG 频带
  final double? deltaPower;
  final double? thetaPower;
  final double? alphaPower;
  final double? betaPower;

  // 综合评估
  final double? moodScore;
  final double? stressLevel;

  // 设备状态
  final bool? dbsRunning;
  final int? dbsBattery;
  final int? hrvBattery;
  final int? currentMode;

  const HardwareMetricsPacket({
    this.ecgWaveform,
    this.eegWaveform,
    this.ecgSampleRate = 500,
    this.eegSampleRate = 250,
    this.heartRate,
    this.sdnn,
    this.rmssd,
    this.lfHfRatio,
    this.hrvStressIndex,
    this.deltaPower,
    this.thetaPower,
    this.alphaPower,
    this.betaPower,
    this.moodScore,
    this.stressLevel,
    this.dbsRunning,
    this.dbsBattery,
    this.hrvBattery,
    this.currentMode,
  });
}

class HrvMetricsPacket {
  final double heartRate;
  final double sdnn;
  final double rmssd;
  final double lfHfRatio;
  final double stressIndex;

  const HrvMetricsPacket({
    required this.heartRate,
    required this.sdnn,
    required this.rmssd,
    required this.lfHfRatio,
    required this.stressIndex,
  });
}

class EegBandPacket {
  final double delta;
  final double theta;
  final double alpha;
  final double beta;
  const EegBandPacket({
    required this.delta,
    required this.theta,
    required this.alpha,
    required this.beta,
  });
}

class DeviceStatusPacket {
  final int battery;
  final bool dbsRunning;
  final int currentMode;
  const DeviceStatusPacket({
    required this.battery,
    required this.dbsRunning,
    required this.currentMode,
  });
}
