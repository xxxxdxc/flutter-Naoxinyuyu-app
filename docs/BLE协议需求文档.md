# BLE 蓝牙通信协议需求文档

## 一、概述

本文档列出 Flutter 上位机（脑心愈郁 App）与硬件设备（ECG/EEG 采集器 + DBS 刺激器）通过 BLE 通信所需的技术参数，请硬件团队据此提供具体的协议细节。

---

## 二、硬件设备信息

需要确认连接哪 **两台设备**（或同一台设备的不同 Service）：

| 设备 | 角色 | 说明 |
|------|------|------|
| ECG/EEG 采集器（STM32端） | **发送数据** | 采集心电/脑电信号，处理后通过 BLE Notify 发送 |
| DBS 刺激器 | **接收指令**（可选） | 如不涉及指令下发则无需通信 |

### 2.1 需要提供的参数

| 参数 | 示例值 | 说明 |
|------|--------|------|
| 设备广播名 (Device Name) | `ECG-MONITOR-01` | Flutter 据此扫描过滤 |
| 广播名或 Service UUID | `0000180D-0000-1000-8000-00805F9B34FB` | 用于设备发现 |
| Service UUID | `XXXX-XXXX-...` | BLE 服务 UUID |
| Notify Characteristic UUID | `XXXX-XXXX-...` | 数据发送的特征值（Flutter 订阅 Notify） |
| Write Characteristic UUID（如需） | `XXXX-XXXX-...` | 指令下发的特征值 |

> 如 ECG 采集器和 DBS 是同一个设备，只需一套 Service/Characteristic。
> 如是两个独立设备，需要两套参数。

---

## 三、数据包格式（ECG/EEG 上行数据）

STM32 → Flutter App（通过 Notify 发送）

### 3.1 通用包结构（建议）

| 字节偏移 | 长度 | 内容 | 说明 |
|---------|------|------|------|
| 0 | 2 | **帧头 (Header)** | 固定标识，如 `0xAA55` |
| 2 | 1 | **包类型 (Type)** | 标识数据类型（见下方） |
| 3 | 1 | **数据长度 (Length)** | 后续数据区的字节数 N |
| 4 | N | **数据区 (Payload)** | 具体数据内容 |
| 4+N | 1 | **校验和 (Checksum)** | XOR 或 CRC8 校验 |

### 3.2 包类型定义（建议）

| Type 值 | 数据类型 | 说明 |
|---------|---------|------|
| `0x01` | ECG 波形采样 | 滤波后 ECG 数据点 |
| `0x02` | EEG 波形采样 | 滤波后 EEG/LFP 数据点 |
| `0x03` | HRV 指标 | 心率、SDNN、RMSSD、LF/HF 等 |
| `0x04` | EEG 频带能量 | Delta/Theta/Alpha/Beta 波段能量 |
| `0x05` | 设备状态 | 电量、连接状态、运行模式等 |
| `0x06` | 综合评估 | 情绪评分、压力指数等融合结果 |

### 3.3 每种数据包的具体格式

#### 3.3.1 ECG 波形包 (Type=0x01)

| 字段 | 长度 | 说明 |
|------|------|------|
| 包类型 | 1B | `0x01` |
| 采样点数 | 1B | 本次包含的采样点个数 M |
| 采样点 1 | 2B | int16 或 float16，需确认是否带符号、缩放因子 |
| 采样点 2 | 2B | ... |
| ... | ... | ... |
| 采样点 M | 2B | ... |
| 校验和 | 1B | 可选 |

**需要确认**：
- 每个包包含 M=____ 个采样点（建议 10~50 个）
- 数据格式：□ int16 有符号  □ uint16 无符号  □ float32
- 字节序：□ 小端 (Little Endian)  □ 大端 (Big Endian)
- 缩放因子：ADC原始值 × ____ = 实际幅值(mV)
- 采样率：____ Hz（mat数据为500Hz，请确认最终值）

#### 3.3.2 HRV 指标包 (Type=0x03)

| 字段 | 长度 | 说明 |
|------|------|------|
| 包类型 | 1B | `0x03` |
| 心率 | 2B | BPM，int16，如 `75` |
| SDNN | 2B | ms，uint16 |
| RMSSD | 2B | ms，uint16 |
| LF/HF 比值 | 2B | float16 或 int16×100 |
| 压力指数 | 1B | 0-100 |
| 校验和 | 1B | 可选 |

**需要确认**：
- 哪些指标硬件端已算好？（建议硬件端完成全部 HRV 计算）
- 各指标的数值范围和精度

#### 3.3.3 EEG 频带能量包 (Type=0x04)

| 字段 | 长度 | 说明 |
|------|------|------|
| 包类型 | 1B | `0x04` |
| Delta 能量 | 2B | float16 或归一化值 |
| Theta 能量 | 2B | |
| Alpha 能量 | 2B | |
| Beta 能量 | 2B | |
| 校验和 | 1B | 可选 |

**需要确认**：
- EEG 采样率
- EEG 是否包含原始波形数据、还是仅频带能量
- 频带划分范围（Delta通常0.5-4Hz, Theta 4-8Hz, Alpha 8-13Hz, Beta 13-30Hz）



#### 3.3.4 综合评估包 (Type=0x06)

| 字段 | 长度 | 说明 |
|------|------|------|
| 包类型 | 1B | `0x06` |
| 情绪评分 | 1B | 0-100，硬件端融合 HRV+EEG 的评估结果 |
| 压力等级 | 1B | 0-100 |
| 建议操作码 | 1B | `0x00`=无操作, `0x01`=建议刺激, `0x02`=建议停止 |
| 校验和 | 1B | 可选 |

**需要确认**：
- 情绪评分和压力等级是否由硬件端计算？
- 是否需要 Flutter 端做额外的融合计算？

---

## 四、时序与性能要求

| 参数 | 要求 |
|------|------|
| ECG 采样率 | ____ Hz（建议 500Hz） |
| EEG 采样率 | ____ Hz（待确认） |
| BLE Notify 间隔 | 实时，每收到一个完整包即 Notify |
| 单次 Notify 最大字节 | 20 bytes（经典 BLE 限制）或 MTU 协商后更大 |
| 丢包处理 | □ 不处理（允许丢少量） □ 带序列号 |
| 数据缓存策略 | STM32 端是否缓存断连期间的数据 |

---

## 五、联调前 checklist

请硬件团队确认以下项后，Flutter 端即可开始开发：

- [ ] ECG 采集器 BLE 广播名 / Service UUID
- [ ] ECG 数据包格式（帧头、包类型、数据排列、校验方式）
- [ ] ECG 采样率（____Hz）和缩放因子
- [ ] EEG 是否包含、格式、采样率
- [ ] HRV 指标是否硬件端计算（如是，各指标数据格式）
- [ ] 设备状态包格式
- [ ] 综合评估包是否需要
- [ ] DBS 是否有 BLE 接口（如是，指令集定义）
- [ ] 字节序（大端/小端）
- [ ] MTU size（默认23字节还是可协商更大）

---

## 六、附件

Flutter 端数据模型（接收解析后的目标结构）：

```dart
class HardwareMetricsPacket {
  // ECG
  List<double>? ecgWaveform;
  int ecgSampleRate = 500;

  // EEG
  List<double>? eegWaveform;
  int eegSampleRate;

  // HRV
  double? heartRate;        // BPM
  double? sdnn;             // ms
  double? rmssd;            // ms
  double? lfHfRatio;
  double? hrvStressIndex;   // 0-100

  // EEG频带
  double? deltaPower;
  double? thetaPower;
  double? alphaPower;
  double? betaPower;

  // 综合评估
  double? moodScore;        // 0-100
  double? stressLevel;      // 0-100

  // 设备状态
  bool? dbsRunning;
  int? dbsBattery;
  int? hrvBattery;
  int? currentMode;         // 0=manual, 1=HRV, 2=EEG, 3=hybrid
}
```
