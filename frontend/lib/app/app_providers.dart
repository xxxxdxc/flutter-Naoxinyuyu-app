import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/state/global_app_state.dart';
import '../features/auth/state/auth_state.dart';
import '../features/demo/state/demo_state.dart';
import '../features/devices/state/device_state.dart';
import '../features/history/state/history_state.dart';
import '../features/offline_analysis/state/offline_analysis_state.dart';
import '../features/reports/state/report_state.dart';
import '../features/signals/state/signal_state.dart';
import '../features/stimulation/state/stimulation_state.dart';

List<SingleChildWidget> buildAppProviders() {
  return [
    ChangeNotifierProvider(create: (_) => GlobalAppState()),
    ChangeNotifierProvider(create: (_) => AuthState()),
    ChangeNotifierProvider(create: (_) => DeviceState()),
    ChangeNotifierProvider(create: (_) => SignalState()),
    ChangeNotifierProvider(create: (_) => StimulationControlState()),
    ChangeNotifierProvider(create: (_) => DemoState()),
    ChangeNotifierProvider(create: (_) => HistoryState()),
    ChangeNotifierProvider(create: (_) => ReportState()),
    ChangeNotifierProvider(create: (_) => OfflineAnalysisState()),
  ];
}
