import 'dart:typed_data';

import 'package:naoxinyuyu_app/core/services/dbs_frame_codec.dart';
import 'package:naoxinyuyu_app/core/services/dbs_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'encodes DBS frame with command, PDU length, and big-endian payload',
    () {
      final codec = DbsFrameCodec();
      final frame = codec.encode(
        command: DbsProtocol.commandStressScore,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000123),
        pdus: [
          DbsPdu(
            opcode: 0x00,
            data: DbsFrameCodec.buildStressPayload(
              const DbsStressScore(
                scoreSmoothed: 0.72,
                scoreRaw: 0.68,
                isStressed: true,
                engineState: 3,
                inferCount: 35,
              ),
            ),
          ),
        ],
      );

      expect(frame[0], DbsFrameCodec.preamble);
      expect(frame[1], 0x04); // RC=0, encryption=0, ack=1
      expect(frame[2], DbsProtocol.commandStressScore);
      expect(frame[9], 1);
      expect(frame[10], 1);
      expect(frame[11], 11);
      expect(frame.sublist(12, 15), [0x00, 0x00, 0x08]);
      expect(frame.sublist(15), [72, 68, 1, 3, 0, 0, 0, 35]);
    },
  );

  test('decodes device status fields', () {
    final codec = DbsFrameCodec();
    final bytes = codec.encode(
      command: DbsProtocol.commandDeviceStatus,
      pdus: [
        DbsPdu(opcode: 0x03, data: Uint8List.fromList([85])),
        DbsPdu(opcode: 0x08, data: Uint8List.fromList([0x00, 0xFA])),
      ],
    );

    final frame = codec.decodeFrame(bytes)!;
    final status = DbsFrameCodec.parseDeviceStatus(frame);

    expect(status.batteryPercent, 85);
    expect(status.deviceTemperatureC, 25.0);
  });

  test('decodes interleaved stream samples by active channel', () {
    final codec = DbsFrameCodec();
    final payload = Uint8List.fromList([
      0x65, 0x53, 0xF1, 0x00, // seconds
      0x00, 0x7B, // millis
      0x00, 0x03, // ch1 + ch2
      0x02, // datapoints
      0x00, 0x64, // ch1 dp1 = 100
      0xFF, 0x9C, // ch2 dp1 = -100
      0x00, 0xC8, // ch1 dp2 = 200
      0xFF, 0x38, // ch2 dp2 = -200
    ]);
    final bytes = codec.encode(
      command: DbsProtocol.commandStreamData,
      pdus: [DbsPdu(opcode: 0x00, data: payload)],
    );

    final frame = codec.decodeFrame(bytes)!;
    final stream = DbsFrameCodec.parseStreamData(frame, sampleRate: 500)!;

    expect(stream.channelMask, 0x0003);
    expect(stream.sampleCount, 2);
    expect(stream.sampleRate, 500);
    expect(stream.channelSamples[1], [100, 200]);
    expect(stream.channelSamples[2], [-100, -200]);
    expect(stream.firstChannelSamples, [100, 200]);
  });

  test('encodes E-STOP as run config stimulate off command', () {
    final codec = DbsFrameCodec();
    final frame = codec.encode(
      command: DbsProtocol.commandRunConfig,
      pdus: [DbsPdu(opcode: 0x08, data: DbsFrameCodec.u8(0))],
    );

    expect(frame[2], DbsProtocol.commandRunConfig);
    expect(frame[9], 1);
    expect(frame[10], 0x09);
    expect(frame[11], 4);
    expect(frame.sublist(12, 15), [0x00, 0x00, 0x01]);
    expect(frame[15], 0);
  });

  test('maps DBS ACK status and treats payload echo as success', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    final echoedPayloadAck = DbsAckEvent(
      command: DbsProtocol.commandStressScore,
      receivedAt: now,
      opcode: 0x00,
      data: Uint8List.fromList([72, 68, 1, 3, 0, 0, 0, 35]),
    );
    final errorAck = DbsAckEvent(
      command: DbsProtocol.commandRunConfig,
      receivedAt: now,
      opcode: 0x08,
      data: Uint8List.fromList([DbsAckStatus.stateError]),
    );

    expect(echoedPayloadAck.isSuccess, isTrue);
    expect(DbsCommandResult.fromAck(echoedPayloadAck).isSuccess, isTrue);
    expect(errorAck.isSuccess, isFalse);
    expect(DbsCommandResult.fromAck(errorAck).statusText, '状态错误');
  });
}
