# 脑心愈郁 (Naoxinyuyu)

**闭环 DBS 多模态神经调控上位机系统** — 生物医学工程竞赛项目

Flutter 桌面端可视化前端 + Python 计算后端，通过 BLE 连接 **KT6368A HRV 胸带** 和 **DBS 设备**，实现 ECG 实时波形展示、HRV 分析、R 峰标注、情绪引擎交互、DBS 参数调控、校准流程控制与健康评估等功能。

---

## 目录

- [系统概述](#系统概述)
- [环境准备（新电脑部署）](#环境准备新电脑部署)
- [项目运行](#项目运行)
- [BLE 联调测试（HRV 胸带）](#ble-联调测试hrv-胸带)
- [DBS 设备联调](#dbs-设备联调)
- [离线测试功能](#离线测试功能)
- [项目架构](#项目架构)
- [常见问题](#常见问题)

---

## 系统概述

### 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                        上位机 PC                                  │
│                                                                  │
│  ┌────────────────────────────────────┐    REST API    ┌──────┐ │
│  │         Flutter App (UI)           │ ◄────────────► │Python│ │
│  │                                    │   localhost:    │后端  │ │
│  │  ┌─────┐ ┌──────────┐ ┌────────┐  │     8000       │      │ │
│  │  │首页 │ │数据分析  │ │ 控制   │  │                │FastAP│ │
│  │  │     │ │ 实时波形 │ │ E-STOP │  │                │I     │ │
│  │  │     │ │ 分析报告 │ │ 急停   │  │                │.mat  │ │
│  │  │     │ │ 离线测试 │ │        │  │                │解析  │ │
│  │  │     │ │ 历史记录 │ │        │  │                │HRV   │ │
│  │  └─────┘ └──────────┘ └────────┘  │                │报告  │ │
│  └──────────────┬─────────────────────┘                └──────┘ │
│                 │ BLE (universal_ble)                            │
│         ┌───────┴────────────────────┐                           │
│         │                            │                           │
│  ┌──────▼───────┐           ┌────────▼────────┐                 │
│  │KT6368A 胸带   │           │   DBS 设备       │                 │
│  │ASCII 文本协议 │           │  二进制帧协议     │                 │
│  │ECG/RPK/HRV/STR│           │  设备状态          │                 │
│  │CMD:C/S/X...   │           │  E-STOP          │                 │
│  └───────────────┘           └─────────────────┘                 │
└──────────────────────────────────────────────────────────────────┘
```

### 功能概览

| 页面 | 功能 | 依赖 |
|------|------|------|
| **首页** | BLE 连接管理、实时心率、HRV 指标、情绪引擎面板、基线校准/应激诱导控制、情绪晴雨表 | BLE 胸带 |
| **实时波形** | CH1 LFP / CH2 ECG 双通道实时波形 + 红色 R 峰标记、HRV/设备信息/压力分值面板 | BLE 胸带 + DBS |
| **分析报告** | 健康评分仪表盘、HRV 指标统计、AI 解读、趋势图表 | 后端 |
| **离线测试** | 上传 .mat 文件 → 解析 ECG 波形 → R 峰检测 → HRV 分析（不依赖 BLE） | 后端 |
| **历史记录** | 浏览历史会话记录（ECG/HRV/情绪得分） | 本地 JSONL |
| **控制页面** | DBS 参数下发、刺激开关、E-STOP 紧急停止、压力得分转发状态 | DBS 设备 |

### 通信协议

**HRV 胸带（KT6368A）：**
- BLE Notify/Write，ASCII 文本协议，START/END 边界，XOR8 CRC
- Service UUID: `0000FFF0-0000-1000-8000-00805F9B34FB`
- Notify: FFF1 / Write: FFF0
- 数据行：SYS（系统状态）、ECG（波形）、RPK（R 峰位置）、HRV（心率变异性指标）、STR（情绪引擎）、PKTCRC（CRC 校验）
- 控制命令：`CMD:C`（基线校准）、`CMD:S`（应激诱导）、`CMD:X`（取消）、`CMD:R`（重置引擎）、`CMD:E`（擦除模型）

**DBS 设备：**
- BLE 自定义二进制帧协议，当前实现以 `app_pretend/lib/core/services/dbs_frame_codec.dart` 为准
- 5 个特征值：配置写入 / 设备通知 / 流数据 / 存储数据
- 已实现：连接、初始状态查询、压力得分下发、刺激参数下发、刺激开关、DBS 状态解析、LFP 流数据解析
- 待确认：硬件端是否采用同一套 UUID、命令字、PDU 编码和未加密单包格式

---

## 环境准备（新电脑部署）

> 以下步骤适用于在一台**新的 Windows 电脑**上完整部署本项目。联调 DBS 时需要 **Python 后端** 和 **Flutter 前端** 同时运行。

### 前置条件清单

| 工具 | 版本要求 | 下载链接 |
|------|---------|---------|
| Windows | 10 / 11（64 位） | — |
| Flutter | >= 3.41 | https://docs.flutter.dev/get-started/install/windows |
| Python | >= 3.12 | https://www.python.org/downloads/ |
| Git | 任意版本 | https://git-scm.com/downloads |
| 蓝牙硬件 | 4.0+（笔记本内置 / USB 适配器） | — |

### 验证预装版本

打开 PowerShell 或 CMD，运行以下命令确认工具已就绪：

```powershell
python --version     # 应显示 Python 3.12.x
flutter --version    # 应显示 Flutter 3.41.x，Dart 3.11.x
git --version        # 应显示 git 2.x
```

### Flutter Windows 桌面端特殊配置

**开启 Windows 开发者模式**（否则 Flutter Windows 构建会失败）：

```powershell
# 方法 1：图形界面
# Win + I → 更新和安全 → 开发者选项 → 开启"开发人员模式"

# 方法 2：直接打开设置页
start ms-settings:developers
```

**启用 Flutter Windows 桌面支持：**

```powershell
flutter config --enable-windows-desktop
```

**验证 Windows 桌面端支持：**

```powershell
flutter devices
# 输出中应包含类似：Windows (desktop) • windows • windows-x64 • Microsoft Windows [版本 xx]
```

---

## 项目运行

### 第一步：克隆项目

```powershell
# 进入你想存放项目的目录
cd D:\Projects

# 克隆仓库
git clone https://github.com/xxxxdxc/flutter-Naoxinyuyu-app.git

# 进入项目根目录
cd Naoxinyuyu_app
```

### 第二步：启动 Python 后端

后端提供离线 HRV 计算和报告生成能力（BLE 实时数据不依赖后端，但离线测试功能需要）。

```powershell
# 1. 创建 Python 虚拟环境（推荐）
python -m venv .venv

# 2. 激活虚拟环境
.venv\Scripts\activate

# 3. 安装后端依赖
pip install -r src/requirements.txt

# 4. 启动后端服务（保持此终端窗口运行）
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
```

**验证后端启动成功：**

打开浏览器访问 http://localhost:8000/docs — 应显示 Swagger API 文档页面。

或在终端中运行：

```powershell
curl http://localhost:8000/api/health
# 期望返回：{"status":"ok","version":"1.0.0"}
```

> 后端终端需要**保持运行**。如果关闭终端，后端将停止。可在需要时用 `Ctrl + C` 安全停止。

### 第三步：启动 Flutter 前端（Windows 桌面端）

新开一个 PowerShell 终端窗口（之前的 Python 后端终端保持运行）。

```powershell
# 1. 进入前端项目目录
cd Naoxinyuyu_app\app_pretend

# 2. 安装 Flutter 依赖
flutter pub get

# 3. 启动 Windows 桌面应用
flutter run -d windows
```

等待构建完成，会弹出一个独立的 Windows 窗口，显示应用主界面。

> **首次构建较慢**（Flutter 需要编译 Dart 代码和原生 Windows 绑定），后续启动会快很多。

### 第四步：登录

应用首次启动会显示**登录页面**。因为是本地存储（`users.json` 文件），首次使用请点击底部 **"注册"** 切换开关：

1. 填写用户名、显示名称、密码
2. 选择角色（患者 或 医生）
3. 点击 **"注册"** — 注册成功后自动登录进入主界面

后续启动直接使用已注册的账号登录即可。

---

## BLE 联调测试（HRV 胸带）

### 硬件准备

| 项目 | 说明 |
|------|------|
| **HRV 胸带** | KT6368A，已充电并开机（长按电源键，指示灯闪烁） |
| **电脑蓝牙** | 确保 Windows 蓝牙已开启（任务栏右下角蓝牙图标 → 右键 → 打开蓝牙） |
| **距离** | 胸带与电脑距离不超过 5 米，无遮挡 |
| **后端** | 确保 Python 后端正在运行（localhost:8000 可访问） |
| **前端** | Flutter Windows 桌面应用已启动 |

### 连接步骤

1. 打开 Flutter 应用，进入 **首页**
2. 点击右下角 **蓝牙 FAB 按钮**（![蓝牙图标](https://img.icons8.com/ios/24/000000/bluetooth.png) 圆形蓝牙图标）
3. 在弹出的 **设备管理** 面板中，找到 **KT6368A 胸带** 条目
4. 点击右侧的 **"连接"** 按钮
5. 应用开始扫描并连接 BLE 设备，等待约 5-15 秒

### 连接成功后的预期现象

| 位置 | 现象 |
|------|------|
| 右下角蓝牙 FAB | 图标变为绿色 `bluetooth_connected` |
| HRV 胸带卡片 | 状态从"未连接"→"已连接"，显示电池电量百分比 |
| 情绪引擎面板 | 出现（根据胸带 STR 状态显示对应内容） |
| 实时心率 | 开始显示 BPM 数值和圆形进度指示 |
| HRV (RMSSD) | 约 60 秒后 HRV 窗口就绪，显示数值 |
| 数据分析 → 实时波形 | CH2 显示 ECG 波形 + 红色 R 峰标记 |

### 校准流程

校准是获取个性化情绪模型的标准流程，三个阶段的转换通过情绪引擎面板控制：

```
未校准 ──CMD:C──→ 基线校准中 ──自动──→ 待诱导 ──CMD:S──→ 应激诱导中 ──自动──→ 推理中（实时输出情绪得分）
  │                    │                           │                      │
  └──可随时取消         └──可随时取消                 └──可随时取消           └──显示情绪得分
```

#### 基线校准
- 点击 **"开始基线校准"** 按钮
- 面板显示 `基线校准中` + 进度条（calm_done / calm_need）
- 保持安静坐姿约 7 分钟（7 个窗口）
- 可随时点击 **"取消校准"** 中止

#### 应激诱导
- 基线校准完成后，状态变为"待诱导"
- 点击 **"开始应激诱导"** 按钮
- 面板显示 `应激诱导中` + 进度条（stress_done / stress_need）
- 按要求完成任务约 2 分钟（2 个窗口）

#### 实时情绪输出
- 完成校准后，引擎进入 `推理中` 状态
- 首页显示实时情绪评分（0-100 百分制整数）和"平静"/"应激"标签
- 数据面板同步显示压力分值

---

## DBS 设备联调（已实现功能）

> 此部分面向 DBS 硬件/嵌入式同学联调。结论先说清楚：**向 DBS 下发压力得分已实现；DBS 传入数据解析也已实现一部分，并已接入全局状态和实时波形 UI。**  
> 当前协议实现以 `app_pretend/lib/core/services/dbs_ble_service.dart`、`dbs_frame_codec.dart`、`dbs_models.dart` 为准，单元测试见 `app_pretend/test/dbs_frame_codec_test.dart`。

### 已实现功能

| 功能 | 当前状态 | 代码入口 | 联调说明 |
|------|---------|---------|---------|
| DBS BLE 扫描/连接/断开 | 已实现 | `DbsBleService.connect()` / `disconnect()` | App 按固定 Service UUID 扫描，连接后发现写入和通知特征值 |
| 初始状态查询 | 已实现 | `queryInitialState()` | 连接成功后自动查询设备状态、采样配置、刺激参数、运行状态 |
| 压力得分下发 | 已实现 | `sendStressScore()` | HRV 情绪引擎进入 `state=3` 后自动转发，也可从状态层手动调用 |
| 刺激参数下发 | 已实现 | `syncStimParams()` | 控制页在手动模式、解锁、DBS 已连接时可下发强度/频率/脉宽，并随后开启刺激 |
| 刺激停止 / E-STOP | 已实现 | `setStimulatorEnabled(false)` / `stopDbsStimulation()` | 控制页 E-STOP 按钮会发送“关闭刺激”命令 |
| LFP/流数据接收解析 | 已实现 | `parseStreamData()` | DBS 流数据会进入 `eegStream`，在数据分析页实时波形 CH1 显示第一通道 |
| 设备状态解析 | 已实现 | `parseDeviceStatus()` | 电量、温度等会显示在首页 DBS 卡片和实时波形底部信息面板 |
| 运行状态解析 | 已实现 | `parseRunStatus()` | 刺激开关状态会同步到 App 的 DBS 运行状态 |
| ACK/反馈解析 | 已实现基础版 | `DbsAckEvent` | 目前按 PDU 首字节 `0` 或空数据视为成功，详细错误码需硬件端约定 |
| 多包/加密/CRC | 未实现 | `decodeFrame()` | 目前仅支持未加密、单包帧；DBS 若启用加密或分包，App 会忽略或报错 |

### BLE UUID 要求

DBS 端必须广播或暴露以下 Service UUID，否则 App 扫描不到：

| 用途 | UUID | 方向 | 是否必需 |
|------|------|------|---------|
| DBS 主服务 | `6E400001-B5A3-F393-E0A9-E50E24DCCA9F` | - | 必需 |
| 配置写入 | `6E400002-B5A3-F393-E0A9-E50E24DCCA9F` | App -> DBS | 必需，需支持 Write 或 WriteWithoutResponse |
| 设备通知 | `6E400003-B5A3-F393-E0A9-E50E24DCCA9F` | DBS -> App | 必需，需支持 Notify |
| 流数据 | `6E400004-B5A3-F393-E0A9-E50E24DCCA9F` | DBS -> App | 可选，支持 Notify 后可显示 LFP |
| 存储数据 | `6E400005-B5A3-F393-E0A9-E50E24DCCA9F` | DBS -> App | 可选，当前只订阅并按存储数据来源处理 |

连接成功后的自动查询顺序：

1. `0x03` 设备状态查询
2. `0x06` 采样配置查询
3. `0x08` 刺激参数查询，PDU `opcode=0x00`，数据为 group `1`
4. `0x0C` 运行状态查询

### DBS 二进制帧格式

当前 App 只支持单包、未加密帧。多字节整数均为 **big-endian**。

| 字段 | 字节数 | 说明 |
|------|------:|------|
| Preamble | 1 | 固定 `0xA5` |
| Flags | 1 | bit7-4 rolling counter，bit3 encrypted，bit2 ack requested |
| Command | 1 | 命令字 |
| Seconds | 4 | Unix timestamp 秒 |
| Millis | 2 | 毫秒 |
| Total Packet | 1 | 当前仅支持 `1` |
| Current Packet | 1 | 当前仅支持 `1` |
| Data Length | 1 | PDU 区总长度，最大 `232` |
| PDU Data | N | 一个或多个 PDU |

PDU 格式：

| 字段 | 字节数 | 说明 |
|------|------:|------|
| Opcode | 1 | 子字段/子命令 |
| Length | 2 | Payload 长度，big-endian |
| Payload | N | 具体数据 |

注意：当前帧格式里 **没有 CRC 字段**。如果硬件端需要 CRC，需要同步修改 `DbsFrameCodec.encode()` / `decodeFrame()`。

### App 下发给 DBS 的命令

#### 1. 压力得分 `0x12`

压力得分来自 HRV 胸带 `STR` 行：

```text
STR:state,calm_done,calm_need,stress_done,stress_need,score_raw,score_smoothed,is_stressed,infer_count
```

自动转发条件：

- DBS 已连接；
- 情绪引擎 `state=3`，即推理中；
- `score_smoothed` 或 `is_stressed` 发生变化，或距离上次发送已超过 1 秒。

下发帧：

| 层级 | 值 |
|------|---|
| Command | `0x12` |
| PDU Opcode | `0x00` |
| PDU Length | `0x0008` |
| Payload | `score_smoothed_percent(1B) + score_raw_percent(1B) + is_stressed(1B) + engine_state(1B) + infer_count(4B)` |

Payload 字段：

| 字段 | 字节数 | 编码 |
|------|------:|------|
| `score_smoothed_percent` | 1 | `score_smoothed <= 1.0` 时乘 100，最终 clamp 到 0-100 |
| `score_raw_percent` | 1 | 同上 |
| `is_stressed` | 1 | `0` 平静，`1` 应激 |
| `engine_state` | 1 | 情绪引擎状态，推理中通常为 `3` |
| `infer_count` | 4 | 推理次数，uint32 big-endian |

示例：`score_smoothed=0.72`，`score_raw=0.68`，`is_stressed=true`，`engine_state=3`，`infer_count=35` 时，PDU 数据为：

```text
00 00 08  48 44 01 03 00 00 00 23
```

完整帧中 `Command=0x12`，第一个字节为 `0xA5`。测试文件已覆盖这个例子。

#### 2. 刺激参数 `0x09`

控制页点击“同步至设备”后会先发送刺激参数，再发送开启刺激。

| PDU Opcode | Payload | 说明 |
|------------|---------|------|
| `0x00` | `group(1B)` | 默认 `1` |
| `0x01` | `method(1B)` | 当前固定 `0` |
| `0x02` | `frequency_hz(uint16)` | 频率，big-endian，编码时 clamp 到 2-250 |
| `0x03` | `0x01` | 当前固定值 |
| `0x04` | `00 01` | 当前固定值 |
| `0x05` | `intensity(float32)` | 强度 mA，big-endian，编码时 clamp 到 0.0-25.5 |
| `0x06` | `pulse_width_1(uint16) + pulse_width_2(uint16)` | 脉宽 us，big-endian，编码时 clamp 到 20-450，两个值相同 |

#### 3. 运行配置 / 刺激开关 `0x0D`

| 用途 | PDU Opcode | Payload |
|------|------------|---------|
| 开启/关闭实时采样 | `0x07` | `1` 开启，`0` 关闭 |
| 开启/关闭刺激 | `0x08` | `1` 开启，`0` 关闭 |
| 开启/关闭 LFP 采样 | `0x0B` | `1` 开启，`0` 关闭 |

控制页 E-STOP 当前实现为发送 `Command=0x0D, PDU opcode=0x08, payload=0x00`，即关闭刺激。若硬件端要求独立急停命令字，需要在 `stopDbsStimulation()` 或 `DbsBleService` 中改成约定命令。

### DBS 回传给 App 的数据解析

已经实现的解析入口在 `DbsFrameCodec`，解析结果通过 `DbsBleService.eventStream` 进入 `GlobalAppState._onDbsEvent()`。

| Command | 解析函数 | App 使用方式 |
|---------|---------|-------------|
| `0x03` 设备状态 | `parseDeviceStatus()` | 更新 DBS 电量、温度等，首页和实时波形面板展示 |
| `0x06` 采样配置 | `parseSensingConfig()` | 更新 LFP/Live 采样率 |
| `0x08` 刺激参数查询 | `parseStimParams()` | 同步强度、频率、脉宽到全局刺激状态 |
| `0x09` 刺激参数反馈 | `DbsAckEvent` | 记录最近 ACK |
| `0x0C` 运行状态 | `parseRunStatus()` | 同步刺激是否运行 |
| `0x0D` 运行配置反馈 | `DbsAckEvent` | 记录最近 ACK |
| `0x12` 压力得分反馈 | `DbsAckEvent` | 记录最近 ACK |
| `0xC0` 流数据 | `parseStreamData()` | 第一通道写入 `eegStream`，在 CH1: EEG (LFP) 实时显示 |
| 其他命令 | `DbsAckEvent` | 作为基础 ACK/反馈处理 |

#### 设备状态 `0x03` 支持的 PDU

| Opcode | 字段 | 编码 |
|--------|------|------|
| `0x00` | hardwareVersion | UTF-8 字符串 |
| `0x01` | firmwareVersion | UTF-8 字符串 |
| `0x03` | batteryPercent | uint8，0-100 |
| `0x04` | chargeIndicator | uint8 |
| `0x05` | chargeCurrentMa | uint16 big-endian |
| `0x06` | chargeVoltageMv | uint16 big-endian |
| `0x08` | deviceTemperatureC | int16 big-endian，除以 10 |
| `0x09` | batteryCycle | uint16 big-endian |
| `0x0A` | waterIngress | uint8 |
| `0x0D` | deviceType | uint8 |
| `0x0E` | humidityPercent | uint8 |
| `0x0F` | batteryVoltageMv | uint16 big-endian |

#### 采样配置 `0x06` 支持的 PDU

| Opcode | 字段 | 编码 |
|--------|------|------|
| `0x00` | liveChannelMask | uint16 big-endian |
| `0x01` | liveSampleRate | uint16 big-endian |
| `0x04` | lfpChannelMask | uint16 big-endian |
| `0x05` | lfpSampleRate | uint16 big-endian |

#### 刺激参数查询 `0x08` 支持的 PDU

| Opcode | 字段 | 编码 |
|--------|------|------|
| `0x00` | group | uint8 |
| `0x01` | method | uint8 |
| `0x02` | frequencyHz | uint16 big-endian |
| `0x05` | intensity | float32 big-endian |
| `0x06` | pulseWidthUs | uint16 big-endian |

#### 运行状态 `0x0C` 支持的 PDU

| Opcode | 字段 | 编码 |
|--------|------|------|
| `0x00` | switchBitmask | uint16 big-endian，bit0=liveSampleOn，bit1=stimulateOn，bit2=impedanceOn，bit4=lfpSampleOn |
| `0x01` | activeGroup | uint8 |
| `0x07` | liveSampleOn | uint8，非 0 为 true |
| `0x08` | stimulateOn | uint8，非 0 为 true |
| `0x09` | impedanceOn | uint8，非 0 为 true |
| `0x0B` | lfpSampleOn | uint8，非 0 为 true |

#### 流数据 `0xC0`

流数据要求 PDU `opcode=0x00`，Payload 格式：

| 字段 | 字节数 | 编码 |
|------|------:|------|
| seconds | 4 | uint32 big-endian |
| millis | 2 | uint16 big-endian |
| channelMask | 2 | uint16 big-endian，bit0 表示通道 1 |
| sampleCount | 1 | 每通道采样点数 |
| samples | `通道数 * sampleCount * 2` | int16 big-endian，按采样点交错排列 |

交错排列示例：通道 1 + 通道 2、`sampleCount=2` 时，顺序为 `ch1_dp1, ch2_dp1, ch1_dp2, ch2_dp2`。App 当前只把最小通道号的数据作为 LFP 主波形显示。

### 联调操作流程

1. 硬件端确认 DBS 使用上述 Service/Characteristic UUID，并广播主 Service UUID。
2. 启动 Flutter Windows 桌面端：`cd app_pretend`，`flutter run -d windows`。
3. 首页点击右下角蓝牙按钮，在设备管理面板中点击 DBS 设备“连接”。
4. 连接成功后，App 会自动发起 `0x03/0x06/0x08/0x0C` 查询；硬件端先回 `0x03` 电量和 `0x0C` 运行状态，方便确认链路。
5. 若要验证压力得分下发，同时连接 KT6368A 胸带，完成基线校准和应激诱导，使 `STR state=3`。此时 App 会自动向 DBS 发送 `0x12`。
6. 若要验证 LFP 上传，DBS 通过流数据特征值发送 `0xC0` 帧，App 数据分析页 CH1 会显示第一通道波形。
7. 若要验证参数下发，进入控制页，切到手动模式、解锁、修改参数并点击同步至设备。硬件端应收到 `0x09`，随后收到 `0x0D/opcode=0x08/payload=1`。
8. 点击 E-STOP，硬件端应收到 `0x0D/opcode=0x08/payload=0`。

### 当前限制与需要硬件端确认的问题

- App 只支持 `preamble=0xA5`、单包、未加密、无 CRC 的二进制帧。
- `decodeFrame()` 不做粘包/拆包重组，建议 DBS 每次 Notify 发一个完整帧。
- `Data Length` 是 1 字节，PDU 区最大 232 字节，LFP 单帧不要超过这个限制。
- 所有多字节字段当前按 big-endian 解析。
- ACK/错误码目前只有基础处理，建议硬件端明确 ACK payload：例如 `0x00=成功`，非 0 为错误码。
- 当前 E-STOP 是“关闭刺激”运行配置命令，不是独立最高优先级急停命令。
- 当前没有把 DBS ACK、LFP、状态写入历史记录；历史记录主要记录 HRV 胸带会话数据。
- `docs/DBS所需信息.md` 是早期需求确认表，实际实现已比该文档更具体；联调时请以本 README 和代码为准。

### 常见 DBS 联调问题

| 问题 | 可能原因 | 解决办法 |
|------|---------|---------|
| 找不到 DBS 设备 | 未广播 `6E400001...` 主服务 / 距离过远 | 确认 DBS 广播 Service UUID，靠近电脑 |
| 连接失败并提示服务不完整 | 缺少写特征值或设备通知特征值 | 确认 `6E400002...` 可写，`6E400003...` 可 Notify |
| 连接后无状态 | App 已发送查询但 DBS 未按帧格式回包 | 先回最小 `0x03` 电量包验证 |
| LFP 不显示 | 未订阅流数据特征值 / `0xC0` payload 格式不匹配 | 对照“流数据 `0xC0`”格式发送完整帧 |
| 压力得分未转发 | DBS 未连接 / HRV 引擎未进入 `state=3` | 确认 DBS 连接，完成 HRV 基线校准和应激诱导 |
| App 报加密不支持 | Flags bit3 为 1 | 联调阶段关闭加密，或扩展 App 解密逻辑 |
| App 报多包不支持 | Total/Current Packet 不是 1/1 | 单帧发送，或实现分包重组 |

---

## 离线测试功能

> 不依赖 BLE 硬件，仅需 Python 后端和 Flutter 前端。

用于验证后端 HRV 计算能力或分析已有的 `.mat` 格式 ECG 数据文件。

### 操作步骤

1. 确保 Python 后端正在运行（`localhost:8000`）
2. 在 Flutter 应用中导航到 **数据分析 → 离线测试**
3. 点击 **"选择 .mat 文件"**
4. 选取包含 ECG 信号的 `.mat` 文件
5. 应用自动将文件上传到后端 → 后端解析 → 计算 HRV → 返回结果
6. 页面显示：
   - ECG 波形图（含 R 峰标记）
   - 心率 (BPM)
   - SDNN（标准差）
   - RMSSD（均方根差）
   - LF/HF 比值
   - 压力指数
   - R 峰统计

### .mat 文件格式要求

MAT 文件需包含以下变量：

| 变量名 | 类型 | 说明 |
|--------|------|------|
| `data` | float[] | ECG 信号一维数组 |
| `fs` | float | 采样率（Hz），默认 500 |

参考 `send_xzc/` 目录下的样例文件格式。

---

## 项目架构

### 目录结构

```
Naoxinyuyu_app/
├── app_pretend/                  # Flutter 跨平台前端
│   ├── lib/
│   │   ├── main.dart             # 应用入口 + AuthGate
│   │   ├── main_home_page.dart   # 底部导航（首页/数据/控制）
│   │   ├── core/
│   │   │   ├── services/
│   │   │   │   ├── ble_service.dart          # KT6368A 胸带 BLE 连接
│   │   │   │   ├── ble_parser.dart           # ASCII 文本协议解析器
│   │   │   │   ├── dbs_ble_service.dart      # DBS 设备 BLE 连接
│   │   │   │   ├── dbs_frame_codec.dart      # DBS 二进制帧编解码
│   │   │   │   ├── dbs_models.dart           # DBS 数据模型
│   │   │   │   ├── data_replay_service.dart  # ECG 离线回放
│   │   │   │   ├── api_client.dart           # HTTP REST 客户端
│   │   │   │   ├── session_history_service.dart  # 本地会话记录
│   │   │   │   └── user_database_service.dart    # 用户登录存储
│   │   │   ├── state/
│   │   │   │   └── global_app_state.dart     # 全局状态管理 (ChangeNotifier)
│   │   │   └── theme/
│   │   │       └── app_theme.dart            # 主题色彩配置
│   │   └── features/
│   │       ├── auth/       # 登录/注册
│   │       ├── dashboard/  # 首页：BLE连接/心率/情绪引擎
│   │       ├── visualizer/ # 实时波形/分析报告/离线测试/历史记录
│   │       └── controller/ # DBS 参数控制
│   ├── assets/
│   │   ├── images/          # 图片资源
│   │   └── *.json           # ECG 样例数据
│   └── pubspec.yaml
│
├── src/                       # Python FastAPI 后端
│   ├── main.py                # 入口 + 路由注册
│   ├── requirements.txt       # Python 依赖
│   ├── routers/
│   │   ├── upload.py          # POST /api/upload
│   │   ├── hrv.py             # POST /api/hrv
│   │   └── analyze.py         # POST /api/analyze
│   ├── services/
│   │   ├── mat_loader.py      # .mat 文件解析
│   │   ├── r_peak_detector.py # R 峰自适应阈值检测
│   │   └── hrv_calculator.py  # HRV 指标计算
│   └── models/
│       └── schemas.py         # Pydantic 数据模型
│
├── send_xzc/                  # 原始 .mat 实验数据
├── docs/                      # 设计文档/协议文档/需求文档
├── scripts/                   # 后端测试/数据导出脚本
└── test/                      # Flutter 单元测试
```

### 技术栈

| 层级 | 技术 | 用途 |
|------|------|------|
| 前端框架 | Flutter 3.41 | 跨平台 UI |
| 前端语言 | Dart 3.11 | 应用逻辑 |
| 状态管理 | Provider (ChangeNotifier) | 全局状态 |
| 波形渲染 | CustomPainter | ECG/EEG 实时波形 |
| BLE 通信 | universal_ble | 跨平台蓝牙 |
| 后端框架 | Python FastAPI | HTTP API |
| 后端计算 | scipy / numpy | .mat 解析 / HRV 计算 |
| 本地存储 | JSON / JSONL | 用户账户 / 会话历史 |

### 数据流

```
BLE 胸带 ──Notify──→ BleService ──BlePacket──→ GlobalAppState
                                                    │
                          ┌─────────────────────────┤
                          │          │               │
                          ▼          ▼               ▼
                     ecgStream   _lastHr/HRV    _emotionScore
                     waveform    _lastRmssd     _engineState
                          │          │               │
                          ▼          ▼               ▼
                    _WaveformPainter 数据面板     情绪引擎面板
                    (实时ECG + R峰)   (HRV/电量)   (校准/得分)

DBS 设备 ──Notify──→ DbsBleService ──DbsEvent──→ GlobalAppState
      ▲                                              │
      │                                              ├── dbsDeviceStatus / dbsRunStatus
      │                                              ├── eegStream.waveform (LFP 第一通道)
      │                                              └── lastDbsAck
      │
      └──Write── DbsFrameCodec.encode()
                ├── 0x12 压力得分
                ├── 0x09 刺激参数
                └── 0x0D 采样/刺激开关
```

---

## 常见问题

### 环境部署问题

| 问题 | 原因 | 解决办法 |
|------|------|---------|
| `flutter pub get` 失败 | 网络问题 / 依赖冲突 | 尝试 `flutter pub cache repair` 或设置镜像源 |
| `flutter run -d windows` 报错 | 开发者模式未开启 | `start ms-settings:developers` 开启 |
| 构建时提示 "symlink" 错误 | Windows 权限 | 以管理员身份运行 PowerShell |
| `pip install` 失败 | Python 版本不符 | 确认 `python --version` >= 3.12 |
| 后端端口被占用 | 其他程序占用了 8000 端口 | 修改 `--port 8001` 启动，或在 Flutter 中修改 `api_client.dart` 的 base URL |
| `universal_ble` 兼容性 | Windows BLE 栈问题 | 更新蓝牙驱动，尝试 `devcon` 工具 |

### BLE 连接问题

| 问题 | 可能原因 | 解决办法 |
|------|---------|---------|
| 连接超时（15秒） | 设备未开机或不在范围 | 检查胸带电量，靠近电脑（< 5米） |
| 搜索不到设备 | BLE 未开启 / 驱动问题 / 设备不广播 | 检查系统蓝牙设置，尝试重启蓝牙适配器 |
| 连接后无数据 | Notify 未正确订阅 | 断开重连 |
| HRV 显示"蓄积中" | HRV 窗口尚未就绪（需 60秒/300秒） | 等待即可，属于正常现象 |
| 情绪引擎一直是"未校准" | 尚未发送校准命令 | 点击"开始基线校准" |
| CRC 校验失败较多 | 蓝牙信号干扰 | 靠近设备，减少 2.4GHz 干扰源 |

### 运行提示

- Flutter 前端和 Python 后端需要**同时运行**（两个终端窗口）
- BLE 功能仅在 **Windows 桌面端** 可用，Web/Chrome 不支持 BLE
- 历史会话数据存储在 `naoxinyuyu_data/users/{userId}/sessions/` 目录下
- 用户账户数据存储在 `naoxinyuyu_data/users.json`

---

## 开发命令速查

```powershell
# 前端
cd app_pretend
flutter pub get         # 安装/同步依赖
flutter run -d windows  # 运行 Windows 桌面端
flutter analyze         # 代码静态分析
flutter test            # 运行测试

# 后端
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000   # 启动
python scripts/test_backend.py                              # 测试后端 API
```

---

## 参考文档

- `docs/BLE协议需求文档.md` — BLE 通信需求和早期字段设计
- `docs/DBS所需信息.md` — DBS 联调信息确认表（早期文档，实际实现以本 README 和代码为准）
- `docs/离线数据测试功能需求文档.md` — 离线 `.mat` 测试功能说明
- `docs/比赛文书-上位机App.md` — 项目背景和比赛文书

---

*本项目为生物医学工程竞赛参赛作品，实现闭环 DBS 多模态神经调控系统的上位机软件部分。硬件端（STM32 + DBS）负责信号采集、滤波、解码和闭环控制，上位机负责数据可视化和人机交互。*
