# 脑心愈吾 (Naoxinyuyu)

**闭环 DBS 多模态上位机系统** — 生物医学工程竞赛项目

Flutter 可视化前端 + Python 计算后端，通过 BLE 接收 STM32 硬件采集的 ECG/EEG 数据，实现实时波形展示、HRV 分析、健康评估等功能。

---

## 系统架构

```
┌──────────────────────┐     HTTP REST      ┌──────────────────────┐
│   Flutter App (UI)   │ ◄──────────────►   │  Python 后端 (计算)   │
│                      │                     │                      │
│  DashboardPage       │  POST /api/upload   │  FastAPI Server      │
│  VisualizerPage      │  POST /api/hrv      │  scipy.io.loadmat    │
│  OfflineTestPage     │  POST /api/analyze  │  R-peak → HRV →报告  │
│  ControllerPage      │  GET  /api/health   │                      │
└──────────────────────┘                     └──────────────────────┘
```

### 目录结构

```
Naoxinyuyu_app/
├── app_pretend/            # Flutter 前端
│   ├── lib/
│   │   ├── core/
│   │   │   ├── services/   # ApiClient, BLE, 数据回放
│   │   │   ├── state/      # GlobalAppState (Provider)
│   │   │   └── theme/      # AppTheme
│   │   └── features/
│   │       ├── dashboard/  # 首页
│   │       ├── visualizer/ # 波形 + 分析 + 离线测试
│   │       └── controller/ # DBS 参数控制
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

## 快速开始

### 1. 后端启动

```bash
cd Naoxinyuyu_app

# 安装依赖
pip install fastapi uvicorn scipy numpy python-multipart

# 启动服务（默认 http://localhost:8000）
uvicorn src.main:app --reload --port 8000
```

验证后端：
```bash
curl http://localhost:8000/api/health
# → {"status":"ok","version":"1.0.0"}
```

### 2. 前端启动

```bash
cd Naoxinyuyu_app/app_pretend

# 安装依赖
flutter pub get

# 运行（Windows）
flutter run -d windows
```

确保后端已在 8000 端口运行，Flutter 启动后即可使用离线测试等功能。

---

## 功能说明

| 页面 | 功能 |
|------|------|
| **首页** | 设备连接状态、实时心率、情绪晴雨表、模式选择 |
| **实时波形** | CH1 EEG / CH2 ECG 双通道实时波形 |
| **分析报告** | 健康评分、HRV 指标、AI 解读 |
| **离线测试** | 上传 .mat 文件 → 解析 ECG 波形 → HRV 分析 |
| **控制** | DBS 刺激参数调节（强度/频率/脉宽）+ E-STOP |

### 离线测试

数据分析页 → "离线测试" 标签页：
1. 确保后端服务已启动
2. 点击"选择 .mat 文件"
3. 选取 `send_xzc/live_result/` 中的 .mat 文件
4. 自动上传 → 解析 → 绘制 ECG 波形 + 显示 HRV 指标

---

## 技术栈

- **前端**: Flutter 3.41 + Provider + CustomPainter
- **后端**: Python 3.14 + FastAPI + scipy + numpy
- **通信**: HTTP REST API (localhost)
- **硬件协议**: BLE (flutter_blue_plus)

---

## 开发计划

- [x] Flutter UI 三页布局（首页/数据/控制）
- [x] Python 后端（.mat 解析 + R 峰检测 + HRV 计算）
- [x] 离线测试功能（文件上传 → 波形绘制 → 指标展示）
- [x] ECG 波形图渲染 + R 峰标注
- [ ] BLE 硬件对接（flutter_blue_plus 实现）
- [ ] 实时数据 WebSocket 推送
- [ ] 分析报告接入后端真实数据

---

## 项目背景

本项目为**生物医学工程竞赛**参赛作品，实现闭环 DBS（深部脑刺激）多模态神经调控系统的上位机软件部分。硬件端（STM32 + DBS）负责信号采集、滤波、解码和闭环控制，上位机负责数据可视化和人机交互。
