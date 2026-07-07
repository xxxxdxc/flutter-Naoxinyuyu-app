import 'package:flutter/foundation.dart';

class AuthState extends ChangeNotifier {
  bool isLoading = false;
  String? errorMessage;
}
