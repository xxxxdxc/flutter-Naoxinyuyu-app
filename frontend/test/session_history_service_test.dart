import 'dart:convert';
import 'dart:io';

import 'package:naoxinyuyu_app/core/services/ble_parser.dart';
import 'package:naoxinyuyu_app/core/services/session_history_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late SessionHistoryService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_history_test_');
    service = SessionHistoryService(baseDirectoryProvider: () async => tempDir);
  });

  tearDown(() async {
    await service.finishSession();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('stores ECG, HRV and stress data for a completed BLE session', () async {
    await service.startSession(deviceName: 'Test Device', sampleRate: 500);

    await service.recordPacket(
      const BlePacket(
        ecgWaveform: [0.1, 0.2, 0.3],
        rdy60: 1,
        rdy300: 0,
        hr: 72,
        rmssd: 38,
        pnn50: 12,
        lf: 20,
        hf: 10,
        lfHf: 2,
        strState: 3,
        scoreRaw: 0.4,
        scoreSmoothed: 0.5,
        isStressed: 1,
        inferCount: 2,
      ),
    );

    final summary = await service.finishSession();
    expect(summary, isNotNull);
    expect(summary!.ecgSampleCount, 3);
    expect(summary.hrvRecordCount, 1);
    expect(summary.stressRecordCount, 1);
    expect(summary.averageHeartRate, 72);
    expect(summary.averageRmssd, 38);
    expect(summary.averageStressScore, 50);
    expect(summary.isComplete, isTrue);

    final sessions = await service.loadSessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.sessionId, summary.sessionId);

    final sessionDir = Directory(sessions.single.sessionPath);
    final meta = File('${sessionDir.path}${Platform.pathSeparator}meta.json');
    final ecg = File('${sessionDir.path}${Platform.pathSeparator}ecg.jsonl');
    final hrv = File('${sessionDir.path}${Platform.pathSeparator}hrv.jsonl');
    final stress = File(
      '${sessionDir.path}${Platform.pathSeparator}stress.jsonl',
    );
    final dbs = File('${sessionDir.path}${Platform.pathSeparator}dbs.jsonl');

    expect(meta.existsSync(), isTrue);
    expect(ecg.existsSync(), isTrue);
    expect(hrv.existsSync(), isTrue);
    expect(stress.existsSync(), isTrue);
    expect(dbs.existsSync(), isTrue);

    final ecgLine =
        jsonDecode(ecg.readAsLinesSync().single) as Map<String, dynamic>;
    expect(ecgLine['samples'], [0.1, 0.2, 0.3]);

    final stressLine =
        jsonDecode(stress.readAsLinesSync().single) as Map<String, dynamic>;
    expect(stressLine['scorePercent'], 50);
    expect(stressLine['isStressed'], isTrue);
  });

  test('stores DBS event logs for hardware linkage', () async {
    await service.startSession(deviceName: 'DBS 设备', sampleRate: 1000);

    await service.recordDbsEvent(
      'stress_score_send',
      data: {'seq': 1, 'scoreSmoothedPercent': 50, 'statusText': 'DBS 已接收'},
    );

    final summary = await service.finishSession();
    expect(summary, isNotNull);

    final sessionDir = Directory(summary!.sessionPath);
    final dbs = File('${sessionDir.path}${Platform.pathSeparator}dbs.jsonl');

    expect(dbs.existsSync(), isTrue);
    final line =
        jsonDecode(dbs.readAsLinesSync().single) as Map<String, dynamic>;
    expect(line['eventType'], 'stress_score_send');
    expect(line['seq'], 1);
    expect(line['scoreSmoothedPercent'], 50);
    expect(line['statusText'], 'DBS 已接收');
  });

  test('records packets without HRV fields without failing', () async {
    await service.startSession(deviceName: 'Test Device', sampleRate: 500);

    await service.recordPacket(
      const BlePacket(
        ecgWaveform: [1, 2],
        strState: 0,
        scoreRaw: 0,
        scoreSmoothed: 0,
      ),
    );

    final summary = await service.finishSession();
    expect(summary, isNotNull);
    expect(summary!.ecgSampleCount, 2);
    expect(summary.hrvRecordCount, 0);
    expect(summary.averageHeartRate, isNull);
    expect(summary.stressRecordCount, 1);
  });

  test('stores demo operation as a meta-only history record', () async {
    final startedAt = DateTime(2026, 7, 5, 10);
    final endedAt = startedAt.add(const Duration(minutes: 9, seconds: 12));

    final summary = await service.recordDemoOperation(
      deviceName: '演示设备 - HRV 胸带 + 演示设备 - DBS',
      startedAt: startedAt,
      endedAt: endedAt,
      modelSaved: true,
      finalStage: '正式监测',
      finalHeartRate: 82,
      finalRmssd: 42,
      finalStressScore: 58,
      averageSignalQuality: 96,
    );

    expect(summary, isNotNull);
    expect(summary!.recordType, historyRecordTypeDemoOperation);
    expect(summary.deviceName, contains('演示设备'));
    expect(summary.ecgSampleCount, 0);
    expect(summary.hrvRecordCount, 0);
    expect(summary.stressRecordCount, 0);
    expect(summary.isComplete, isTrue);
    expect(summary.averageHeartRate, 82);
    expect(summary.averageRmssd, 42);
    expect(summary.averageStressScore, 58);
    expect(summary.maxStressScore, 96);

    final sessions = await service.loadSessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.recordType, historyRecordTypeDemoOperation);

    final sessionDir = Directory(sessions.single.sessionPath);
    expect(
      File('${sessionDir.path}${Platform.pathSeparator}meta.json').existsSync(),
      isTrue,
    );
    expect(
      File('${sessionDir.path}${Platform.pathSeparator}ecg.jsonl').existsSync(),
      isFalse,
    );
    expect(
      File('${sessionDir.path}${Platform.pathSeparator}hrv.jsonl').existsSync(),
      isFalse,
    );
    expect(
      File(
        '${sessionDir.path}${Platform.pathSeparator}stress.jsonl',
      ).existsSync(),
      isFalse,
    );
  });

  test('marks exited demo operation complete even when model was not saved', () async {
    final startedAt = DateTime(2026, 7, 5, 11);
    final endedAt = startedAt.add(const Duration(minutes: 2));

    final summary = await service.recordDemoOperation(
      deviceName: '演示设备 - HRV 胸带 + 演示设备 - DBS',
      startedAt: startedAt,
      endedAt: endedAt,
      modelSaved: false,
      finalStage: '信号质量检查',
      finalHeartRate: null,
      finalRmssd: null,
      finalStressScore: null,
      averageSignalQuality: 88,
    );

    expect(summary, isNotNull);
    expect(summary!.recordType, historyRecordTypeDemoOperation);
    expect(summary.isComplete, isTrue);

    final sessions = await service.loadSessions();
    expect(sessions.single.isComplete, isTrue);
  });

  test('loads legacy exited demo operation as complete', () async {
    final userDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}naoxinyuyu_data'
      '${Platform.pathSeparator}users'
      '${Platform.pathSeparator}$defaultHistoryUserId'
      '${Platform.pathSeparator}sessions'
      '${Platform.pathSeparator}legacy-demo',
    );
    await userDir.create(recursive: true);

    final startedAt = DateTime(2026, 7, 5, 12);
    final endedAt = startedAt.add(const Duration(minutes: 1));
    final meta = {
      'sessionId': 'legacy-demo',
      'recordType': historyRecordTypeDemoOperation,
      'userId': defaultHistoryUserId,
      'userName': defaultHistoryUserName,
      'deviceName': '演示设备 - HRV 胸带 + 演示设备 - DBS',
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'sampleRate': 500,
      'ecgSampleCount': 0,
      'hrvRecordCount': 0,
      'stressRecordCount': 0,
      'averageHeartRate': null,
      'averageRmssd': null,
      'averageStressScore': null,
      'maxStressScore': null,
      'isComplete': false,
      'modelSaved': false,
    };
    await File(
      '${userDir.path}${Platform.pathSeparator}meta.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(meta));

    final sessions = await service.loadSessions();

    expect(sessions, hasLength(1));
    expect(sessions.single.recordType, historyRecordTypeDemoOperation);
    expect(sessions.single.isComplete, isTrue);
  });
}
