# 架构迁移检查清单

## 已建立的目标

- 顶层目录使用 `backend/` 和 `frontend/`。
- 后端主入口使用 `backend.app.main:app`。
- 后端 API 使用 `/api/v1`。
- 后端运行时数据进入 `backend/runtime/data/`。
- Flutter package 名称使用 `naoxinyuyu_app`。
- 前端新增业务域 State 骨架。

## 后续迁移顺序

1. 将 `frontend/lib/core/services/api_client.dart` 移到 `frontend/lib/core/network/`。
2. 将 BLE 文件移到 `frontend/lib/core/hardware/ble/`，保留临时导出文件直到页面迁移完成。
3. 将 DBS 文件移到 `frontend/lib/core/hardware/dbs/`，每次移动后运行 DBS codec 测试。
4. 从 `GlobalAppState` 抽出 auth、history、demo、devices、signals、stimulation、reports、offline_analysis 状态。
5. 将页面从读取 `GlobalAppState` 改为读取对应 feature state。
6. 将历史记录和用户数据从前端本地 JSON 服务迁移为后端 API 服务。
7. 拆分 `dashboard_page.dart`、`controller_page.dart`、`visualizer_page.dart` 等大文件。
8. 删除旧的兼容门面和旧路径导出文件。

## 每阶段必须验证

```powershell
python -m compileall backend\app
cd frontend
flutter test test\dbs_frame_codec_test.dart
flutter test
```

没有真实 BLE/DBS 硬件时，只能说明已完成代码和单元测试验证，不能声称硬件联调通过。
