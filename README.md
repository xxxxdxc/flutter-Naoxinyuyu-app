# 脑心愈郁 (Naoxinyuyu)

**闭环 DBS 多模态上位机系统** — 生物医学工程竞赛项目

Flutter 可视化前端 + Python 计算后端，通过 BLE 接收实时 ECG 数据，实现波形展示、HRV 分析、情绪引擎交互、健康评估等功能。

---

## 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                       上位机 PC                              │
│                                                             │
│  ┌──────────────────────┐     HTTP REST     ┌─────────────┐ │
│  │   Flutter App (UI)   │ ◄──────────────►  │ Python 后端  │ │
│  │                      │                   │             │ │
│  │  DashboardPage       │ POST /api/upload   │ FastAPI     │ │
│  │  VisualizerPage      │ POST /api/hrv      │ .mat 解析   │ │
│  │  OfflineTestPage     │ POST /api/analyze  │ HRV 计算    │ │
│  │  ControllerPage      │ GET  /api/health   │ 报告生成    │ │
│  └──────┬───────────────┘                   └─────────────┘ │
│         │ BLE (flutter_blue_plus)                            │
│         ▼                                                    │
│  ┌──────────────────────────────────────────────────────┐    │
│  │              KT6368A HRV 胸带                         │    │
│  │  ─ ASCII 文本协议 (START/END/XOR8 CRC)               │    │
│  │  ─ SYS/ECG/RPK/HRV/STR 数据行                        │    │
│  │  ─ CMD 控制命令 (校准/诱导/重置)                      │    │
│  └──────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 目录结构

```
Naoxinyuyu_app/
├── app_pretend/            # Flutter 前端
│   ├── lib/
│   │   ├── core/
│   │   │   ├── services/   # ApiClient, BleService, BleParser
│   │   │   ├── state/      # GlobalAppState (Provider)
│   │   │   └── theme/      # AppTheme
│   │   └── features/
│   │       ├── dashboard/  # 首页：HRV指标/情绪引擎/校准控制
│   │       ├── visualizer/ # 实时波形 + R峰标注 + 离线测试
│   │       └── controller/ # DBS 参数控制（预留）
│   ├── assets/             # ECG 样例数据
│   └── pubspec.yaml
│
├── src/                    # Python 后端
│   ├── main.py             # FastAPI 入口
│   ├── routers/            # API 路由 (upload/hrv/analyze)
│   ├── services/           # 计算引擎 (mat解析/R峰检测/HRV)
│   └── models/             # Pydantic 数据模型
│
├── send_xzc/               # 原始 .mat 数据
├── docs/                   # 需求文档
└── scripts/                # 工具脚本
```

---

## 环境准备

### 前置条件

| 工具 | 版本要求 | 验证命令 |
|------|---------|---------|
| Python | >= 3.12 | `python --version` |
| Flutter | >= 3.41 | `flutter --version` |
| Dart SDK | >= 3.11（随 Flutter 捆绑） | `dart --version` |
| Windows | 10 / 11 | `winver` |

### Windows 蓝牙环境要求

- PC 需具备蓝牙 4.0+ 硬件（笔记本一般内置，台式机需 USB 蓝牙适配器）
- BLE 功能仅在 **Windows 桌面端** (`flutter run -d windows`) 可用，Web/Chrome 不支持

---

## 运行项目

> 先启动 **Python 后端**，再启动 **Flutter 前端**。联调时两端都需要保持运行。

---

### 第一步：启动 Python 后端

后端运行在 `http://localhost:8000`，提供离线 HRV 计算和报告生成能力（BLE 数据解析不依赖后端，但离线测试功能需要）。

```bash
# 进入项目根目录
cd Naoxinyuyu_app

# （推荐）创建虚拟环境
python -m venv .venv
.venv\Scripts\activate      # Windows

# 安装依赖
pip install -r src/requirements.txt

# 启动后端（热重载模式）
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
```

**验证后端：**

```bash
curl http://localhost:8000/api/health
# 期望返回：{"status":"ok","version":"1.0.0"}
```

或打开浏览器访问 http://localhost:8000/docs 查看 Swagger API 文档。

---

### 第二步：启动 Flutter 前端（Windows 桌面端）

> ⚠️ **Windows 开发者模式要求**：Flutter Windows 桌面端构建需要系统开启开发人员模式。
>
> **开启方法**: `Win + I` → 更新和安全 → 开发者选项 → 开启"开发人员模式"
>
> 或直接运行：`start ms-settings:developers`

```bash
# 保持后端运行，新开一个终端

# 启用 Windows 桌面端支持（仅首次）
flutter config --enable-windows-desktop

# 进入前端项目
cd Naoxinyuyu_app/app_pretend

# 安装 Dart 依赖
flutter pub get

# 启动应用（Windows 桌面端）
flutter run -d windows
```

应用启动后，会弹出独立窗口。如果启动失败提示 "symlink support"，请检查开发者模式是否已开启。

---

## BLE 联调测试流程

确保后端和前端都已启动运行后，按以下步骤进行 BLE 联调。

### 准备工作

| 项目 | 说明 |
|------|------|
| **硬件** | KT6368A HRV 胸带，已充电并开机 |
| **PC 蓝牙** | 确保系统蓝牙已开启（任务栏右下角蓝牙图标） |
| **距离** | 胸带与 PC 距离不超过 5 米，中间无遮挡 |
| **后端** | `http://localhost:8000` 健康检查通过 |
| **前端** | Flutter Windows 桌面端已启动 |

### 连接步骤

1. **打开前端应用**，进入**首页**
2. 点击右下角 **蓝牙 FAB 按钮**（圆形蓝牙图标）
3. 在弹出的**设备管理**面板中，点击 **KT6368A 胸带** 条目右侧的 **"连接"** 按钮
4. 应用开始扫描 BLE 设备，等待连接

### 连接成功后的预期现象

连接成功后，你会在界面上看到以下变化：

| 位置 | 现象 |
|------|------|
| 右下角蓝牙 FAB | 图标变为绿色 `bluetooth_connected` |
| **HRV 胸带** 卡片 | 状态从"未连接"变为"已连接"，显示电池电量百分比 |
| **情绪引擎** 面板 | 出现（根据胸带 STR 状态显示对应内容） |
| **实时心率监控** | 开始显示 BPM 数值和圆形进度 |
| **HRV (RMSSD)** | 当 HRV 窗口就绪后，显示数值 |
| 数据分析 → **实时波形** | CH2 显示 ECG 波形 + 红色 R 峰标记 |

### 校准流程测试

校准是获取个性化情绪模型的标准流程，分三个阶段。所有操作通过首页的**情绪引擎**面板完成：

```
未校准 ──CMD:C──→ 基线校准中 ──自动完成──→ 待诱导 ──CMD:S──→ 应激诱导中 ──自动完成──→ 推理中（实时输出情绪得分）
  │                    │                              │                      │
  └──可随时取消         └──可随时取消                    └──可随时取消           └──显示情绪得分
```

#### 步骤 1：开始基线校准

- 状态为"未校准"时，点击情绪引擎面板中的 **"开始基线校准"** 按钮
- 面板显示 `基线校准中` + 进度条（calm_done/calm_need）
- 需要保持安静坐姿约 7 分钟（7 个窗口）
- 可随时点击 **"取消校准"** 中止

#### 步骤 2：开始应激诱导

- 基线校准完成后，状态变为"待诱导"
- 点击 **"开始应激诱导"** 按钮
- 面板显示 `应激诱导中` + 进度条（stress_done/stress_need）
- 按照实验要求完成任务约 2 分钟（2 个窗口）
- 可随时点击 **"取消校准"** 中止

#### 步骤 3：实时情绪输出

- 完成校准流程后，引擎进入 `推理中` 状态
- 首页显示实时情绪评分（0-100）和"平静"/"应激"标签
- 情绪晴雨表同步更新

### 常见连接问题

| 问题 | 可能原因 | 解决办法 |
|------|---------|---------|
| 连接超时（15秒） | 设备未开机或不在范围内 | 检查胸带电量，靠近 PC |
| 搜索不到设备 | BLE 未开启或驱动问题 | 检查系统蓝牙设置，重试扫描 |
| 连接后无数据 | Notify 未正确订阅 | 断开重连 |
| HRV 显示"蓄积中" | HRV 窗口尚未就绪（需 60秒/300秒） | 等待即可，属于正常现象 |
| 情绪引擎一直是"未校准" | 尚未发送校准命令 | 点击"开始基线校准" |
| CRC 校验失败 | 蓝牙信号干扰 | 靠近设备，减少干扰源 |

---

### 第三步：离线测试功能（可选，不依赖 BLE）

作为 BLE 实时模式的补充，离线测试功能可以从 `.mat` 文件分析 ECG 数据：

1. 应用内导航到 **数据分析 → 离线测试**
2. 点击 **"选择 .mat 文件"**
3. 选取包含 ECG 信号的 `.mat` 文件
4. 自动上传 → 后端计算 HRV → 返回结果
5. 页面显示 ECG 波形图、心率、SDNN、RMSSD、R 峰计数

> 参考 [send_xzc/](send_xzc/) 目录下的样例文件格式：MAT 文件需包含 `data`（ECG 信号数组）和 `fs`（采样率）变量。

---

## 功能说明

| 页面 | 功能 |
|------|------|
| **首页** | BLE 连接管理、实时心率、HRV 指标、情绪引擎面板、校准控制 |
| **实时波形** | CH1 EEG / CH2 ECG 双通道实时波形 + R 峰红色标注 |
| **分析报告** | 健康评分、HRV 指标、AI 解读（开发中） |
| **离线测试** | 上传 .mat 文件 → 解析 ECG 波形 → HRV 分析（不依赖 BLE） |
| **控制** | DBS 刺激参数调节（强度/频率/脉宽）+ E-STOP（预留） |

---

## BLE 通信协议

与 KT6368A 胸带的通信基于 ASCII 文本协议，通过 BLE Notify/Write 传输。

**关键参数：**

| 参数 | 值 |
|------|-----|
| 设备名称 | KT6368A-BLE-2.1 |
| Service UUID | `0000FFF0-0000-1000-8000-00805F9B34FB` |
| Notify 特征值 | FFF1（下位机→上位机数据） |
| Write 特征值 | FFF0（上位机→下位机命令） |

**数据行格式：** SYS / ECG / RPK / HRV / STR / PKTCRC，START/END 边界，XOR8 CRC。

**控制命令：** `CMD:C`（基线校准）、`CMD:S`（应激诱导）、`CMD:X`（取消）、`CMD:R`（重置引擎）、`CMD:E`（擦除模型）。

完整协议文档见 `docs/通信数据协议.md`。

---

## 技术栈

- **前端**: Flutter 3.41 + Provider + CustomPainter
- **后端**: Python 3.12+ + FastAPI + scipy + numpy
- **通信**: BLE (flutter_blue_plus) + HTTP REST API
- **硬件协议**: KT6368A BLE 2.1 自定义 ASCII 文本协议

---

## 开发计划

- [x] Flutter UI 三页布局（首页/数据/控制）
- [x] Python 后端（.mat 解析 + R 峰检测 + HRV 计算）
- [x] 离线测试功能（文件上传 → 波形绘制 → 指标展示）
- [x] ECG 波形图渲染 + R 峰标注
- [x] BLE 硬件对接（flutter_blue_plus 实现）
- [x] BLE 数据解析引擎（ASCII 协议 / CRC 校验 / 拼包）
- [x] 校准流程控制（基线校准 / 应激诱导 / 实时情绪）
- [o] 实时数据 WebSocket 推送
- [o] 分析报告接入后端真实数据

---

## 项目背景

本项目为**生物医学工程竞赛**参赛作品，实现闭环 DBS（深部脑刺激）多模态神经调控系统的上位机软件部分。硬件端（STM32 + DBS）负责信号采集、滤波、解码和闭环控制，上位机负责数据可视化和人机交互。
