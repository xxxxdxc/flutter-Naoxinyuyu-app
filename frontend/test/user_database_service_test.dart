import 'dart:io';

import 'package:naoxinyuyu_app/core/services/user_database_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late UserDatabaseService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('user_database_test_');
    service = UserDatabaseService(baseDirectoryProvider: () async => tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('registers a user and keeps it as current user', () async {
    final user = await service.register(
      username: 'PatientA',
      password: '1234',
      displayName: '患者A',
    );

    expect(user.username, 'patienta');
    expect(user.displayName, '患者A');

    final current = await service.currentUser();
    expect(current, isNotNull);
    expect(current!.id, user.id);

    final snapshot = await service.load();
    expect(snapshot.users, hasLength(1));
    expect(snapshot.currentUserId, user.id);
  });

  test('logs out and logs in again with stored credentials', () async {
    final user = await service.register(
      username: 'doctor',
      password: 'abcd',
      displayName: '医生',
      role: 'doctor',
    );

    await service.logout();
    expect(await service.currentUser(), isNull);

    final loggedIn = await service.login(username: 'doctor', password: 'abcd');
    expect(loggedIn.id, user.id);
    expect(loggedIn.role, 'doctor');

    final current = await service.currentUser();
    expect(current, isNotNull);
    expect(current!.id, user.id);
  });

  test('rejects duplicate usernames', () async {
    await service.register(
      username: 'same',
      password: '1234',
      displayName: 'A',
    );

    expect(
      () => service.register(
        username: 'SAME',
        password: '1234',
        displayName: 'B',
      ),
      throwsA(isA<UserDatabaseException>()),
    );
  });
}
