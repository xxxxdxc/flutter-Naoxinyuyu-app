# 前端模块边界

前端顶层目录为 `frontend/`，仍然是 Flutter Windows 桌面应用。

## 目录职责

- `lib/app/`：应用入口、Provider 注册、登录门禁、主页面框架。
- `lib/core/theme/`：全局主题和视觉规范。
- `lib/core/network/`：后端 HTTP 客户端、错误处理和 API DTO。
- `lib/core/hardware/ble/`：BLE 胸带连接、数据解析、命令发送。
- `lib/core/hardware/dbs/`：DBS 蓝牙连接、帧编解码、协议模型。
- `lib/features/auth/`：登录、注册、当前用户状态。
- `lib/features/devices/`：BLE/DBS 连接状态、设备诊断。
- `lib/features/signals/`：ECG/LFP/HRV 实时信号展示和缓冲状态。
- `lib/features/stimulation/`：DBS 刺激参数、安全上限、急停、压力分数下发。
- `lib/features/demo/`：竞赛硬件演示模式和模拟数据流。
- `lib/features/history/`：历史会话列表和详情。
- `lib/features/reports/`：分析报告展示。
- `lib/features/offline_analysis/`：`.mat` 上传、HRV 计算、离线分析。

## 状态管理规则

继续使用 Provider/ChangeNotifier，但不得继续扩大 `GlobalAppState`。

迁移期间 `GlobalAppState` 作为兼容门面保留；新增功能必须进入对应 feature state。

目标状态拆分：

- `AuthState`
- `DeviceState`
- `SignalState`
- `StimulationControlState`
- `DemoState`
- `HistoryState`
- `ReportState`
- `OfflineAnalysisState`

## 依赖方向

页面只能依赖本 feature 的 state/service/model，必要时读取相邻 feature 的只读状态。

页面不得直接调用 BLE/DBS 底层服务；硬件服务必须由 `devices`、`signals` 或 `stimulation` 的状态层协调。

所有后端请求必须经过统一 API client，不在页面中直接使用 `http`。
