import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/global_app_state.dart';
import '../../../core/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isRegisterMode = false;
  String _role = 'patient';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.divider.withAlpha(80)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Consumer<GlobalAppState>(
                builder: (context, state, child) {
                  return Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.account_circle_outlined,
                          size: 56,
                          color: AppTheme.primaryMain,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isRegisterMode ? '创建用户档案' : '用户登录',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '历史记录将按登录用户分别保存',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if ((value ?? '').trim().length < 2) {
                              return '请输入至少 2 个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: '密码',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          obscureText: true,
                          textInputAction: _isRegisterMode
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(state),
                          validator: (value) {
                            if ((value ?? '').length < 4) {
                              return '请输入至少 4 个字符';
                            }
                            return null;
                          },
                        ),
                        if (_isRegisterMode) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _displayNameController,
                            decoration: const InputDecoration(
                              labelText: '显示名称',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(state),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'patient',
                                label: Text('患者'),
                                icon: Icon(Icons.favorite_border),
                              ),
                              ButtonSegment(
                                value: 'doctor',
                                label: Text('医生'),
                                icon: Icon(Icons.medical_services_outlined),
                              ),
                            ],
                            selected: {_role},
                            onSelectionChanged: (selection) {
                              setState(() => _role = selection.first);
                            },
                          ),
                        ],
                        if (state.authError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            state.authError!,
                            style: const TextStyle(color: AppTheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: state.isAuthLoading
                              ? null
                              : () => _submit(state),
                          icon: state.isAuthLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _isRegisterMode
                                      ? Icons.person_add_alt
                                      : Icons.login,
                                ),
                          label: Text(_isRegisterMode ? '创建并登录' : '登录'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: state.isAuthLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isRegisterMode = !_isRegisterMode;
                                  });
                                },
                          child: Text(
                            _isRegisterMode ? '已有用户？返回登录' : '没有用户？创建档案',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(GlobalAppState state) async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text;
    final password = _passwordController.text;
    if (_isRegisterMode) {
      await state.registerUser(
        username: username,
        password: password,
        displayName: _displayNameController.text,
        role: _role,
      );
    } else {
      await state.login(username: username, password: password);
    }
  }
}
