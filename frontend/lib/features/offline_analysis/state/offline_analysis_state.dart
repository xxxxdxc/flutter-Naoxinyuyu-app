import 'package:flutter/foundation.dart';

class OfflineAnalysisState extends ChangeNotifier {
  bool isUploading = false;
  String? activeFileId;
}
