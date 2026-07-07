import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'ble_parser.dart';

const String defaultHistoryUserId = 'default_user';
const String defaultHistoryUserName = '默认用户';
const String historyRecordTypeAcquisition = 'acquisition';
const String historyRecordTypeDemoOperation = 'demoOperation';

class SessionSummary {
  final String sessionId;
  final String recordType;
  final String userId;
  final String userName;
  final String deviceName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int sampleRate;
  final int ecgSampleCount;
  final int hrvRecordCount;
  final int stressRecordCount;
  final double? averageHeartRate;
  final double? averageRmssd;
  final double? averageStressScore;
  final double? maxStressScore;
  final bool isComplete;
  final String sessionPath;

  const SessionSummary({
    required this.sessionId,
    this.recordType = historyRecordTypeAcquisition,
    required this.userId,
    required this.userName,
    required this.deviceName,
    required this.startedAt,
    required this.endedAt,
    required this.sampleRate,
    required this.ecgSampleCount,
    required this.hrvRecordCount,
    required this.stressRecordCount,
    required this.averageHeartRate,
    required this.averageRmssd,
    required this.averageStressScore,
    required this.maxStressScore,
    required this.isComplete,
    required this.sessionPath,
  });

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'recordType': recordType,
      'userId': userId,
      'userName': userName,
      'deviceName': deviceName,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'sampleRate': sampleRate,
      'ecgSampleCount': ecgSampleCount,
      'hrvRecordCount': hrvRecordCount,
      'stressRecordCount': stressRecordCount,
      'averageHeartRate': averageHeartRate,
      'averageRmssd': averageRmssd,
      'averageStressScore': averageStressScore,
      'maxStressScore': maxStressScore,
      'isComplete': isComplete,
    };
  }

  factory SessionSummary.fromJson(
    Map<String, dynamic> json, {
    required String sessionPath,
  }) {
    final recordType =
        json['recordType'] as String? ?? historyRecordTypeAcquisition;
    final endedAt = json['endedAt'] == null
        ? null
        : DateTime.parse(json['endedAt'] as String);
    final isDemoOperation = recordType == historyRecordTypeDemoOperation;
    final storedComplete = json['isComplete'] as bool? ?? false;

    return SessionSummary(
      sessionId: json['sessionId'] as String,
      recordType: recordType,
      userId: json['userId'] as String? ?? defaultHistoryUserId,
      userName: json['userName'] as String? ?? defaultHistoryUserName,
      deviceName: json['deviceName'] as String? ?? '--',
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: endedAt,
      sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 500,
      ecgSampleCount: (json['ecgSampleCount'] as num?)?.toInt() ?? 0,
      hrvRecordCount: (json['hrvRecordCount'] as num?)?.toInt() ?? 0,
      stressRecordCount: (json['stressRecordCount'] as num?)?.toInt() ?? 0,
      averageHeartRate: (json['averageHeartRate'] as num?)?.toDouble(),
      averageRmssd: (json['averageRmssd'] as num?)?.toDouble(),
      averageStressScore: (json['averageStressScore'] as num?)?.toDouble(),
      maxStressScore: (json['maxStressScore'] as num?)?.toDouble(),
      isComplete: storedComplete || (isDemoOperation && endedAt != null),
      sessionPath: sessionPath,
    );
  }
}

class SessionHistoryService {
  static const int _ecgFlushSampleThreshold = 500;
  static const Duration _ecgFlushInterval = Duration(seconds: 1);

  final Uuid _uuid;
  final Future<Directory> Function()? _baseDirectoryProvider;

  Directory? _sessionDir;
  IOSink? _ecgSink;
  IOSink? _hrvSink;
  IOSink? _stressSink;
  IOSink? _dbsSink;
  Timer? _flushTimer;

  String? _activeSessionId;
  String _activeUserId = defaultHistoryUserId;
  String _activeUserName = defaultHistoryUserName;
  String _activeDeviceName = '--';
  DateTime? _startedAt;
  int _sampleRate = 500;
  int _ecgSampleCount = 0;
  int _hrvRecordCount = 0;
  int _stressRecordCount = 0;
  double _heartRateSum = 0;
  int _heartRateCount = 0;
  double _rmssdSum = 0;
  int _rmssdCount = 0;
  double _stressScoreSum = 0;
  int _stressScoreCount = 0;
  double? _maxStressScore;
  final List<double> _pendingEcgSamples = [];

  SessionHistoryService({
    Uuid? uuid,
    Future<Directory> Function()? baseDirectoryProvider,
  }) : _uuid = uuid ?? const Uuid(),
       _baseDirectoryProvider = baseDirectoryProvider;

  bool get hasActiveSession => _activeSessionId != null;

  Future<void> startSession({
    String userId = defaultHistoryUserId,
    String userName = defaultHistoryUserName,
    String deviceName = '--',
    int sampleRate = 500,
  }) async {
    if (hasActiveSession) {
      await finishSession();
    }

    try {
      _activeSessionId = _uuid.v4();
      _activeUserId = userId;
      _activeUserName = userName;
      _activeDeviceName = deviceName;
      _startedAt = DateTime.now();
      _sampleRate = sampleRate;
      _ecgSampleCount = 0;
      _hrvRecordCount = 0;
      _stressRecordCount = 0;
      _heartRateSum = 0;
      _heartRateCount = 0;
      _rmssdSum = 0;
      _rmssdCount = 0;
      _stressScoreSum = 0;
      _stressScoreCount = 0;
      _maxStressScore = null;
      _pendingEcgSamples.clear();

      _sessionDir = Directory(
        '${(await _sessionsDirectory(userId: userId)).path}${Platform.pathSeparator}$_activeSessionId',
      );
      await _sessionDir!.create(recursive: true);

      _ecgSink = File(
        '${_sessionDir!.path}${Platform.pathSeparator}ecg.jsonl',
      ).openWrite(mode: FileMode.append);
      _hrvSink = File(
        '${_sessionDir!.path}${Platform.pathSeparator}hrv.jsonl',
      ).openWrite(mode: FileMode.append);
      _stressSink = File(
        '${_sessionDir!.path}${Platform.pathSeparator}stress.jsonl',
      ).openWrite(mode: FileMode.append);
      _dbsSink = File(
        '${_sessionDir!.path}${Platform.pathSeparator}dbs.jsonl',
      ).openWrite(mode: FileMode.append);

      await _writeMeta(isComplete: false);
      _flushTimer = Timer.periodic(_ecgFlushInterval, (_) {
        unawaited(_flushEcgSamples());
      });
    } catch (e) {
      debugPrint('[History] startSession failed: $e');
      await _resetActiveSession(closeSinks: true);
    }
  }

  Future<SessionSummary?> recordDemoOperation({
    String userId = defaultHistoryUserId,
    String userName = defaultHistoryUserName,
    required String deviceName,
    required DateTime startedAt,
    required DateTime endedAt,
    required bool modelSaved,
    required String finalStage,
    double? finalHeartRate,
    double? finalRmssd,
    double? finalStressScore,
    double? averageSignalQuality,
  }) async {
    try {
      final sessionId = _uuid.v4();
      final sessionDir = Directory(
        '${(await _sessionsDirectory(userId: userId)).path}${Platform.pathSeparator}$sessionId',
      );
      await sessionDir.create(recursive: true);

      final summary = SessionSummary(
        sessionId: sessionId,
        recordType: historyRecordTypeDemoOperation,
        userId: userId,
        userName: userName,
        deviceName: deviceName,
        startedAt: startedAt,
        endedAt: endedAt,
        sampleRate: 500,
        ecgSampleCount: 0,
        hrvRecordCount: 0,
        stressRecordCount: 0,
        averageHeartRate: finalHeartRate,
        averageRmssd: finalRmssd,
        averageStressScore: finalStressScore,
        maxStressScore: averageSignalQuality,
        isComplete: true,
        sessionPath: sessionDir.path,
      );

      final meta = summary.toJson()
        ..addAll({
          'finalStage': finalStage,
          'modelSaved': modelSaved,
          'averageSignalQuality': averageSignalQuality,
        });
      final metaFile = File(
        '${sessionDir.path}${Platform.pathSeparator}meta.json',
      );
      await metaFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(meta),
        flush: true,
      );
      return summary;
    } catch (e) {
      debugPrint('[History] recordDemoOperation failed: $e');
      return null;
    }
  }

  Future<void> recordPacket(BlePacket packet) async {
    if (!hasActiveSession) return;

    try {
      if (packet.ecgWaveform.isNotEmpty) {
        _pendingEcgSamples.addAll(packet.ecgWaveform);
        _ecgSampleCount += packet.ecgWaveform.length;
        if (_pendingEcgSamples.length >= _ecgFlushSampleThreshold) {
          await _flushEcgSamples();
        }
      }

      if (packet.hasHrv) {
        _hrvRecordCount++;
        if (packet.hr != null) {
          _heartRateSum += packet.hr!;
          _heartRateCount++;
        }
        if (packet.rmssd != null) {
          _rmssdSum += packet.rmssd!;
          _rmssdCount++;
        }
        _hrvSink?.writeln(
          jsonEncode({
            'timestamp': DateTime.now().toIso8601String(),
            'rdy60': packet.rdy60,
            'rdy300': packet.rdy300,
            'hr': packet.hr,
            'rmssd': packet.rmssd,
            'pnn50': packet.pnn50,
            'lf': packet.lf,
            'hf': packet.hf,
            'lfHf': packet.lfHf,
          }),
        );
      }

      _stressRecordCount++;
      final stressScore = (packet.scoreSmoothed * 100).clamp(0.0, 100.0);
      _stressScoreSum += stressScore;
      _stressScoreCount++;
      _maxStressScore = _maxStressScore == null
          ? stressScore
          : (_maxStressScore! > stressScore ? _maxStressScore : stressScore);
      _stressSink?.writeln(
        jsonEncode({
          'timestamp': DateTime.now().toIso8601String(),
          'state': packet.strState,
          'calmDone': packet.calmDone,
          'calmNeed': packet.calmNeed,
          'stressDone': packet.stressDone,
          'stressNeed': packet.stressNeed,
          'scoreRaw': packet.scoreRaw,
          'scoreSmoothed': packet.scoreSmoothed,
          'scorePercent': stressScore,
          'isStressed': packet.isStressed == 1,
          'inferCount': packet.inferCount,
        }),
      );
    } catch (e) {
      debugPrint('[History] recordPacket failed: $e');
    }
  }

  Future<void> recordDbsEvent(
    String eventType, {
    Map<String, dynamic> data = const {},
  }) async {
    if (!hasActiveSession) return;

    try {
      _dbsSink?.writeln(
        jsonEncode({
          'timestamp': DateTime.now().toIso8601String(),
          'eventType': eventType,
          ...data,
        }),
      );
      await _dbsSink?.flush();
    } catch (e) {
      debugPrint('[History] recordDbsEvent failed: $e');
    }
  }

  Future<SessionSummary?> finishSession() async {
    if (!hasActiveSession) return null;

    try {
      _flushTimer?.cancel();
      _flushTimer = null;
      await _flushEcgSamples();
      await _ecgSink?.flush();
      await _hrvSink?.flush();
      await _stressSink?.flush();
      await _dbsSink?.flush();
      final summary = await _writeMeta(
        endedAt: DateTime.now(),
        isComplete: true,
      );
      await _resetActiveSession(closeSinks: true);
      return summary;
    } catch (e) {
      debugPrint('[History] finishSession failed: $e');
      await _resetActiveSession(closeSinks: true);
      return null;
    }
  }

  Future<List<SessionSummary>> loadSessions({
    String userId = defaultHistoryUserId,
  }) async {
    try {
      final sessionsDir = await _sessionsDirectory(userId: userId);
      if (!sessionsDir.existsSync()) return [];

      final summaries = <SessionSummary>[];
      final entries = sessionsDir.listSync().whereType<Directory>();
      for (final dir in entries) {
        final metaFile = File('${dir.path}${Platform.pathSeparator}meta.json');
        if (!metaFile.existsSync()) continue;
        try {
          final json =
              jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
          summaries.add(SessionSummary.fromJson(json, sessionPath: dir.path));
        } catch (e) {
          debugPrint('[History] load meta failed (${dir.path}): $e');
        }
      }
      summaries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return summaries;
    } catch (e) {
      debugPrint('[History] loadSessions failed: $e');
      return [];
    }
  }

  Future<void> _flushEcgSamples() async {
    if (_pendingEcgSamples.isEmpty || _ecgSink == null) return;

    final samples = List<double>.from(_pendingEcgSamples);
    _pendingEcgSamples.clear();
    _ecgSink?.writeln(
      jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'sampleRate': _sampleRate,
        'startSample': _ecgSampleCount - samples.length,
        'samples': samples,
      }),
    );
    await _ecgSink?.flush();
  }

  Future<SessionSummary> _writeMeta({
    DateTime? endedAt,
    required bool isComplete,
  }) async {
    final sessionDir = _sessionDir;
    final sessionId = _activeSessionId;
    final startedAt = _startedAt;
    if (sessionDir == null || sessionId == null || startedAt == null) {
      throw StateError('No active session metadata to write.');
    }

    final summary = SessionSummary(
      sessionId: sessionId,
      recordType: historyRecordTypeAcquisition,
      userId: _activeUserId,
      userName: _activeUserName,
      deviceName: _activeDeviceName,
      startedAt: startedAt,
      endedAt: endedAt,
      sampleRate: _sampleRate,
      ecgSampleCount: _ecgSampleCount,
      hrvRecordCount: _hrvRecordCount,
      stressRecordCount: _stressRecordCount,
      averageHeartRate: _heartRateCount == 0
          ? null
          : _heartRateSum / _heartRateCount,
      averageRmssd: _rmssdCount == 0 ? null : _rmssdSum / _rmssdCount,
      averageStressScore: _stressScoreCount == 0
          ? null
          : _stressScoreSum / _stressScoreCount,
      maxStressScore: _maxStressScore,
      isComplete: isComplete,
      sessionPath: sessionDir.path,
    );

    final metaFile = File(
      '${sessionDir.path}${Platform.pathSeparator}meta.json',
    );
    await metaFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(summary.toJson()),
      flush: true,
    );
    return summary;
  }

  Future<Directory> _sessionsDirectory({required String userId}) async {
    final provider = _baseDirectoryProvider;
    final base = provider == null
        ? await getApplicationSupportDirectory()
        : await provider();
    return Directory(
      '${base.path}${Platform.pathSeparator}naoxinyuyu_data'
      '${Platform.pathSeparator}users'
      '${Platform.pathSeparator}$userId'
      '${Platform.pathSeparator}sessions',
    )..createSync(recursive: true);
  }

  Future<void> _resetActiveSession({required bool closeSinks}) async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (closeSinks) {
      await _ecgSink?.close();
      await _hrvSink?.close();
      await _stressSink?.close();
      await _dbsSink?.close();
    }
    _ecgSink = null;
    _hrvSink = null;
    _stressSink = null;
    _dbsSink = null;
    _sessionDir = null;
    _activeSessionId = null;
    _startedAt = null;
    _pendingEcgSamples.clear();
  }
}
