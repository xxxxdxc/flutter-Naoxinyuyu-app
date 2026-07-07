import 'package:flutter/foundation.dart';

class SignalState extends ChangeNotifier {
  List<double> ecgWaveform = const [];
  List<double> lfpWaveform = const [];
}
