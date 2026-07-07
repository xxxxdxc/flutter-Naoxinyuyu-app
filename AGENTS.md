# AGENTS.md

本文件是本项目所有智能体进行开发、修改、调试、测试和文档更新时必须优先遵守的项目级规则。

当本文件与临时任务说明冲突时，应优先满足用户在当前对话中的明确要求；当用户没有明确覆盖时，以本文件为准。

## 项目定位

本项目是“脑心愈郁 / Naoxinyuyu”生物医学工程竞赛上位机应用。

项目由两个主要部分组成：

- `backend/app/`：Python FastAPI 后端，负责离线数据解析、R 峰检测、HRV 计算和 API 服务。
- `frontend/`：Flutter 前端，负责桌面端 UI、BLE 通信、DBS 控制、实时波形、历史记录和演示流程。

项目还包含：

- `docs/`：BLE、DBS、离线测试、比赛文书、开发指南等文档。
- `scripts/`：辅助脚本和后端测试脚本。

本项目应被理解为竞赛演示与工程原型系统，不应被表述为已经认证的医疗器械或临床诊断系统。

## 核心原则

- 先理解现有结构，再进行修改。
- 优先沿用项目已有代码风格、目录结构、命名方式和状态管理方式。
- 修改应聚焦当前任务，不做无关重构。
- 不随意删除、重命名或大范围移动文件。
- 不随意修改 BLE UUID、DBS 协议、二进制帧结构、校验逻辑、HRV 算法行为或比赛展示主流程。
- 涉及硬件、协议、算法、医学含义或比赛文书时，必须先查看 `docs/` 中的相关资料。
- 保留中文文档和中文 UI 语境。除非任务明确要求，不要把已有中文内容翻译成英文。
- 编辑 Markdown、Dart、Python、YAML、JSON 等文件时应使用 UTF-8 编码。

## 目录结构说明

### 后端

- `backend/app/main.py`：FastAPI 应用入口。
- `backend/app/api/v1/`：API 路由。
- `backend/app/services/`：核心服务逻辑，例如 `.mat` 数据加载、R 峰检测、HRV 计算。
- `backend/app/models/`：请求和响应数据模型。
- `backend/requirements.txt`：后端 Python 依赖。

### 前端

- `frontend/lib/main.dart`：Flutter 应用入口。
- `frontend/lib/main_home_page.dart`：主页面框架。
- `frontend/lib/core/`：主题、全局状态、服务层。
- `frontend/lib/core/services/`：BLE、DBS、API、数据回放、历史记录、用户数据等服务。
- `frontend/lib/features/`：业务功能页面。
- `frontend/test/`：Flutter 单元测试和组件测试。
- `frontend/assets/`：演示数据和静态资源。

### 文档和脚本

- `docs/`：协议、需求、开发和比赛材料。
- `scripts/export_mat_to_json.py`：离线数据导出辅助脚本。
- `scripts/test_backend.py`：后端基础测试脚本。

## 常用命令

### 启动后端

在项目根目录执行：

```powershell
python -m venv .venv
.venv\Scripts\activate
pip install -r backend\requirements.txt
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

### 启动前端

在 `frontend/` 目录执行：

```powershell
flutter pub get
flutter run -d windows
```

### 运行测试

后端：

```powershell
python scripts\test_backend.py
```

前端：

```powershell
cd frontend
flutter test
```

DBS 编解码相关改动应重点运行：

```powershell
cd frontend
flutter test test\dbs_frame_codec_test.dart
```

## 后端开发规则

- API 路由应放在 `backend/app/api/v1/`。
- 业务计算和数据处理逻辑应放在 `backend/app/services/`。
- 请求、响应和共享数据结构应放在 `backend/app/models/schemas.py` 或同目录合适文件中。
- 不要把复杂计算逻辑直接写进路由函数。
- 文件上传接口必须检查文件类型、异常情况和错误返回。
- HRV、R 峰检测、采样率、时间单位等改动必须谨慎，避免破坏既有分析结果。
- 如果修改 API 返回结构，必须同步检查 Flutter 端 `api_client.dart` 和相关页面解析逻辑。

## 前端开发规则

- 页面代码应放在 `frontend/lib/features/.../view/`。
- 可复用组件应放在相应 feature 的 `components/` 或项目已有的合适位置。
- 全局状态、服务和跨页面逻辑应放在 `frontend/lib/core/`。
- 优先复用已有服务，不重复实现同类逻辑。
- 涉及后端请求时优先通过 `frontend/lib/core/services/api_client.dart`。
- 涉及 BLE 胸带时优先查看和复用 `ble_service.dart`、`ble_parser.dart`。
- 涉及 DBS 设备时优先查看和复用 `dbs_ble_service.dart`、`dbs_frame_codec.dart`、`dbs_models.dart`。
- 涉及历史记录时优先查看和复用 `session_history_service.dart`。
- 涉及用户数据时优先查看和复用 `user_database_service.dart`。
- 保持 Windows 桌面端可运行。不要只按 Web 或移动端假设设计。
- UI 文案应保持中文、简洁、适合竞赛演示场景。

## BLE 胸带规则

BLE 胸带相关实现涉及实时数据和硬件通信，修改前必须先阅读相关代码和文档。

重点文件：

- `frontend/lib/core/services/ble_service.dart`
- `frontend/lib/core/services/ble_parser.dart`
- `docs/BLE协议需求文档.md`

除非任务明确要求，否则不要修改：

- Service UUID
- Notify / Write 特征值
- 数据行格式
- CRC 校验方式
- `SYS`、`ECG`、`RPK`、`HRV`、`STR` 等消息含义
- 校准、诱导、取消、重置等命令语义

如果没有真实硬件，必须明确说明 BLE 行为未能进行真实设备验证。

## DBS 设备规则

DBS 通信涉及自定义二进制协议和安全相关控制逻辑，修改时必须格外谨慎。

重点文件：

- `frontend/lib/core/services/dbs_ble_service.dart`
- `frontend/lib/core/services/dbs_frame_codec.dart`
- `frontend/lib/core/services/dbs_models.dart`
- `frontend/test/dbs_frame_codec_test.dart`
- `docs/DBS所需信息.md`
- `docs/蓝牙通信协议_植入式刺激器(1).pdf`

除非任务明确要求，否则不要修改：

- DBS 帧头、命令字、长度字段和校验方式。
- E-STOP 急停语义。
- 刺激开关语义。
- 压力分数下发语义。
- 设备状态解析字段。
- LFP 流数据解析方式。

DBS 协议改动必须配套更新或新增测试。

如果没有真实 DBS 硬件，必须明确说明硬件联调未能验证。

## 离线数据和 HRV 分析规则

重点文件：

- `backend/app/services/mat_loader.py`
- `backend/app/services/r_peak_detector.py`
- `backend/app/services/hrv_calculator.py`
- `backend/app/api/v1/upload.py`
- `backend/app/api/v1/hrv.py`
- `backend/app/api/v1/analyze.py`
- `docs/离线数据测试功能需求文档.md`

开发规则：

- 保持 `.mat` 文件解析流程稳定。
- 不要随意改变 ECG 数据单位、采样率假设或返回字段名。
- R 峰检测和 HRV 计算的算法改动必须说明原因。
- 涉及前后端字段变更时，必须同时检查 Flutter 离线测试页面和报告页面。

## 文档规则

涉及以下内容时，应优先查看 `docs/`：

- BLE 协议
- DBS 协议
- 离线测试流程
- 比赛展示文案
- 上位机开发说明
- 硬件联调信息

重要文档包括：

- `docs/BLE协议需求文档.md`
- `docs/离线数据测试功能需求文档.md`
- `docs/DBS所需信息.md`
- `docs/比赛文书-上位机App.md`
- `docs/上位机开发指南(1).pdf`
- `docs/蓝牙通信协议_植入式刺激器(1).pdf`

更新文档时应保持中文表达清晰，避免过度营销化或医学诊断化表述。

## 测试和验证要求

根据改动范围运行最小必要检查。

后端改动：

```powershell
python scripts\test_backend.py
```

Flutter 改动：

```powershell
cd frontend
flutter test
```

DBS 编解码改动：

```powershell
cd frontend
flutter test test\dbs_frame_codec_test.dart
```

如果因为环境缺少 Flutter、Python 依赖、硬件或网络导致无法验证，必须在最终说明中明确写出。

## 安全和医学表述边界

- 不要声称本项目可以进行临床诊断。
- 不要声称本项目已经通过医疗器械认证。
- 不要加入未经文档支持的治疗效果、疗效保证或诊断结论。
- 可以使用“竞赛演示”“工程原型”“健康评估”“压力/情绪趋势分析”等更稳妥表述。
- 涉及 DBS 刺激、急停、刺激参数、设备状态时，要避免轻率改动和夸大说明。

## 文件编辑规则

- 不要删除 `.venv`、Flutter 平台目录、日志、临时目录或生成文件，除非用户明确要求。
- 不要随意修改 `.gitignore`、构建配置、平台工程文件，除非任务需要。
- 不要批量格式化整个项目，除非用户明确要求。
- 不要引入新的大型依赖，除非确有必要并说明原因。
- 不要把密钥、令牌、个人信息或硬件私有参数写入仓库。

## 智能体交付规则

完成任务时，应向用户说明：

- 修改了什么。
- 涉及哪些关键文件。
- 运行了哪些测试或检查。
- 哪些部分因为缺少硬件、依赖或环境没有验证。
- 如果有风险，应直接说明风险点。

如果任务涉及代码修改，应优先给出实际修改结果，而不是只给方案。

如果任务涉及硬件联调，应区分：

- 已通过代码或单元测试验证的内容。
- 只能在真实 BLE/DBS 硬件上验证的内容。

## 推荐工作流程

1. 阅读任务要求。
2. 搜索相关文件和已有实现。
3. 查看必要文档。
4. 小范围修改。
5. 运行最小必要测试。
6. 总结修改、验证结果和未验证风险。

本项目的优先目标是稳定、清晰、可演示、可解释。所有智能体都应围绕这一目标进行开发。
