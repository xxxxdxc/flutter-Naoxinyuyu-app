import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const String defaultUserId = 'default_user';
const String defaultUserName = '默认用户';

class AppUser {
  final String id;
  final String username;
  final String displayName;
  final String role;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.createdAt,
    required this.lastLoginAt,
  });

  AppUser copyWith({String? displayName, String? role, DateTime? lastLoginAt}) {
    return AppUser(
      id: id,
      username: username,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String? ?? json['username'] as String,
      role: json['role'] as String? ?? 'patient',
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: DateTime.parse(json['lastLoginAt'] as String),
    );
  }
}

class UserDatabaseService {
  final Uuid _uuid;
  final Future<Directory> Function()? _baseDirectoryProvider;

  UserDatabaseService({
    Uuid? uuid,
    Future<Directory> Function()? baseDirectoryProvider,
  }) : _uuid = uuid ?? const Uuid(),
       _baseDirectoryProvider = baseDirectoryProvider;

  Future<UserDatabaseSnapshot> load() async {
    final file = await _databaseFile();
    if (!file.existsSync()) {
      final snapshot = UserDatabaseSnapshot(
        users: const [],
        credentials: const {},
        currentUserId: null,
      );
      await _save(snapshot);
      return snapshot;
    }

    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return UserDatabaseSnapshot.fromJson(json);
    } catch (e) {
      debugPrint('[UserDB] load failed, recreating database: $e');
      final backup = File(
        '${file.path}.broken-${DateTime.now().millisecondsSinceEpoch}',
      );
      try {
        await file.rename(backup.path);
      } catch (_) {}
      final snapshot = UserDatabaseSnapshot(
        users: const [],
        credentials: const {},
        currentUserId: null,
      );
      await _save(snapshot);
      return snapshot;
    }
  }

  Future<AppUser> register({
    required String username,
    required String password,
    required String displayName,
    String role = 'patient',
  }) async {
    final normalized = _normalizeUsername(username);
    final snapshot = await load();
    if (snapshot.users.any((u) => u.username == normalized)) {
      throw UserDatabaseException('该用户名已存在');
    }

    final now = DateTime.now();
    final user = AppUser(
      id: _uuid.v4(),
      username: normalized,
      displayName: displayName.trim().isEmpty ? normalized : displayName.trim(),
      role: role,
      createdAt: now,
      lastLoginAt: now,
    );

    final updated = snapshot.copyWith(
      users: [...snapshot.users, user],
      credentials: {
        ...snapshot.credentials,
        user.id: _passwordHash(normalized, password),
      },
      currentUserId: user.id,
    );
    await _save(updated);
    return user;
  }

  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    final normalized = _normalizeUsername(username);
    final snapshot = await load();
    final index = snapshot.users.indexWhere((u) => u.username == normalized);
    if (index < 0) {
      throw UserDatabaseException('用户不存在');
    }

    final user = snapshot.users[index];
    final expected = snapshot.credentials[user.id];
    if (expected != _passwordHash(normalized, password)) {
      throw UserDatabaseException('密码不正确');
    }

    final updatedUser = user.copyWith(lastLoginAt: DateTime.now());
    final users = [...snapshot.users]..[index] = updatedUser;
    await _save(snapshot.copyWith(users: users, currentUserId: updatedUser.id));
    return updatedUser;
  }

  Future<void> logout() async {
    final snapshot = await load();
    await _save(snapshot.copyWith(currentUserId: null));
  }

  Future<AppUser?> currentUser() async {
    final snapshot = await load();
    final id = snapshot.currentUserId;
    if (id == null) return null;
    for (final user in snapshot.users) {
      if (user.id == id) return user;
    }
    return null;
  }

  Future<void> _save(UserDatabaseSnapshot snapshot) async {
    final file = await _databaseFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
      flush: true,
    );
  }

  Future<File> _databaseFile() async {
    final provider = _baseDirectoryProvider;
    final base = provider == null
        ? await getApplicationSupportDirectory()
        : await provider();
    return File(
      '${base.path}${Platform.pathSeparator}naoxinyuyu_data'
      '${Platform.pathSeparator}users.json',
    );
  }

  String _normalizeUsername(String username) {
    final normalized = username.trim().toLowerCase();
    if (normalized.length < 2) {
      throw UserDatabaseException('用户名至少需要 2 个字符');
    }
    return normalized;
  }

  String _passwordHash(String username, String password) {
    if (password.length < 4) {
      throw UserDatabaseException('密码至少需要 4 个字符');
    }
    var hash = 0x811c9dc5;
    final input = '$username::$password::naoxinyuyu';
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class UserDatabaseSnapshot {
  final List<AppUser> users;
  final Map<String, String> credentials;
  final String? currentUserId;

  const UserDatabaseSnapshot({
    required this.users,
    required this.credentials,
    required this.currentUserId,
  });

  UserDatabaseSnapshot copyWith({
    List<AppUser>? users,
    Map<String, String>? credentials,
    Object? currentUserId = _noCurrentUserChange,
  }) {
    return UserDatabaseSnapshot(
      users: users ?? this.users,
      credentials: credentials ?? this.credentials,
      currentUserId: identical(currentUserId, _noCurrentUserChange)
          ? this.currentUserId
          : currentUserId as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'users': users.map((u) => u.toJson()).toList(),
      'credentials': credentials,
      'currentUserId': currentUserId,
    };
  }

  factory UserDatabaseSnapshot.fromJson(Map<String, dynamic> json) {
    return UserDatabaseSnapshot(
      users: (json['users'] as List<dynamic>? ?? [])
          .map((u) => AppUser.fromJson(u as Map<String, dynamic>))
          .toList(),
      credentials: (json['credentials'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, value as String),
      ),
      currentUserId: json['currentUserId'] as String?,
    );
  }
}

const Object _noCurrentUserChange = Object();

class UserDatabaseException implements Exception {
  final String message;

  const UserDatabaseException(this.message);

  @override
  String toString() => message;
}
