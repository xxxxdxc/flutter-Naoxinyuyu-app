# 脑心愈郁（Naoxinyuyu）

“脑心愈郁 / Naoxinyuyu”是生物医学工程竞赛上位机应用项目，用于演示多模态生理信号采集、HRV 分析、DBS 设备控制、历史记录和报告生成等流程。

本项目定位为竞赛演示与工程原型系统，不是已认证医疗器械，也不用于临床诊断。

## 项目结构

```text
Naoxinyuyu_app/
  backend/                  # Python FastAPI 后端
    app/
      main.py               # FastAPI 应用入口
      api/v1/               # /api/v1 接口路由
      core/                 # 配置、SQLite 初始化、运行时目录
      domains/              # 后端业务域
      services/             # ECG/HRV 算法与 .mat 解析逻辑
    requirements.txt        # 后端依赖

  frontend/                 # Flutter 桌面端前端
    lib/
      app/                  # Provider 注册、应用框架
      core/
        network/            # 后端 API 客户端
        hardware/           # BLE/DBS 底层通信与协议
        services/           # 兼容旧路径的服务导出与本地服务
        state/              # 旧 GlobalAppState 兼容门面
        theme/              # 全局主题
      features/             # 前端业务功能模块
    assets/                 # 演示数据和静态资源
    test/                   # Flutter 测试

  docs/                     # 协议、需求、比赛材料和架构文档
    architecture/           # 当前重构后的架构说明

  scripts/                  # 辅助脚本
    test_backend.py         # 后端接口测试脚本
```

## 功能模块

### 后端 `backend/`

- 提供 `/api/v1` REST API。
- 解析上传的 `.mat` 离线 ECG 数据。
- 执行 R 峰检测、RR 间期计算和 HRV 指标计算。
- 生成健康评估报告文本。
- 使用本地 SQLite 保存用户、会话、文件和报告元数据。
- 运行时数据默认写入 `backend/runtime/data/`，该目录不会提交到仓库。

主要接口：

```text
GET  /api/v1/health
POST /api/v1/files/mat
POST /api/v1/analysis/hrv
POST /api/v1/analysis/report
POST /api/v1/users
POST /api/v1/auth/login
POST /api/v1/sessions
GET  /api/v1/users/{user_id}/sessions
GET  /api/v1/reports/{report_id}
```

### 前端 `frontend/`

- Flutter Windows 桌面端 UI。
- 负责首页、实时波形、离线分析、历史记录、报告和 DBS 控制页面。
- 通过 `core/network/api_client.dart` 调用后端。
- 通过 `core/hardware/ble/` 管理 BLE 胸带连接和 ECG/HRV 数据解析。
- 通过 `core/hardware/dbs/` 管理 DBS 蓝牙连接、帧编解码、刺激参数和急停控制。
- 当前仍保留 `GlobalAppState` 作为兼容门面，新的业务域 State 已按模块放入 `features/*/state/`。

### 文档 `docs/`

- BLE 协议、DBS 协议、离线测试需求、比赛文书等项目资料。
- `docs/architecture/` 说明当前前后端分离后的模块边界、API v1 和迁移检查清单。

## 环境要求

### 后端

- Python 3.11+ 推荐
- FastAPI
- Uvicorn
- NumPy / SciPy

### 前端

- Flutter SDK
- Windows 桌面开发环境
- 项目主要面向 Windows 桌面端运行

## 部署与运行

以下命令默认在项目根目录 `Naoxinyuyu_app/` 下执行。

### 1. 创建并安装后端环境

```powershell
python -m venv .venv
.venv\Scripts\activate
pip install -r backend\requirements.txt
```

### 2. 启动后端

```powershell
uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000
```

后端接口文档：

```text
http://localhost:8000/docs
```

健康检查：

```powershell
curl http://localhost:8000/api/v1/health
```

### 3. 安装前端依赖

打开新的 PowerShell 窗口：

```powershell
cd frontend
flutter pub get
```

### 4. 启动前端

```powershell
flutter run -d windows
```

前端默认访问后端：

```text
http://localhost:8000
```

## 测试

### 后端基础检查

先启动后端，再执行：

```powershell
python scripts\test_backend.py
```

### 后端语法检查

```powershell
python -m compileall backend\app
```

### Flutter 测试

```powershell
cd frontend
flutter test
```

DBS 帧编解码相关改动应重点运行：

```powershell
cd frontend
flutter test test\dbs_frame_codec_test.dart
```

## 开发约定

- 后端新增 API 放在 `backend/app/api/v1/`。
- 后端业务逻辑优先放入 `backend/app/domains/`。
- HRV、R 峰检测和 `.mat` 解析算法放在 `backend/app/services/`，不要随意改变算法行为。
- 前端页面放在 `frontend/lib/features/.../view/`。
- 前端可复用组件放在对应 feature 的 `widgets/` 或现有合适目录。
- BLE/DBS 协议底层实现放在 `frontend/lib/core/hardware/`。
- 不要随意修改 BLE UUID、DBS 帧结构、校验逻辑、急停语义和刺激控制语义。
- UI 和文档保持中文语境，表述应符合竞赛演示和工程原型定位。

## 常见问题

### 后端启动后访问不到接口

确认后端启动命令是否使用了新入口：

```powershell
uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000
```

然后访问：

```text
http://localhost:8000/api/v1/health
```

### Flutter 找不到包或导入报错

在 `frontend/` 下重新拉取依赖：

```powershell
flutter pub get
```

### 无真实 BLE/DBS 硬件时如何验证

可以运行代码级测试和演示模式，但不能声称完成真实硬件联调。BLE 胸带和 DBS 设备的连接、通知、写入、急停和刺激控制仍需在真实设备上验证。
