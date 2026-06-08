import 'dart:convert';
import 'dart:io';

import 'package:flutter_application_1/core/services/ble_parser.dart';
import 'package:flutter_application_1/core/services/session_history_service.dart';
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

    expect(meta.existsSync(), isTrue);
    expect(ecg.existsSync(), isTrue);
    expect(hrv.existsSync(), isTrue);
    expect(stress.existsSync(), isTrue);

    final ecgLine =
        jsonDecode(ecg.readAsLinesSync().single) as Map<String, dynamic>;
    expect(ecgLine['samples'], [0.1, 0.2, 0.3]);

    final stressLine =
        jsonDecode(stress.readAsLinesSync().single) as Map<String, dynamic>;
    expect(stressLine['scorePercent'], 50);
    expect(stressLine['isStressed'], isTrue);
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
}
