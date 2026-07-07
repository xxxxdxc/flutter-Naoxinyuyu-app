import 'package:flutter/material.dart';

/// ECG 波形图绘制器
///
/// 绘制滤波后的 ECG 数据线 + R 峰标注点。
/// 适配 500Hz 采样率，支持最多 5000 点（10 秒）数据展示。
class EcgWaveformPainter extends CustomPainter {
  final List<double> data;
  final List<int> rPeakIndices;
  final Color waveColor;
  final Color rPeakColor;
  final bool rPeakDotsOnWave;

  EcgWaveformPainter({
    required this.data,
    this.rPeakIndices = const [],
    this.waveColor = const Color(0xFF34A853),
    this.rPeakColor = const Color(0xFFEA4335),
    this.rPeakDotsOnWave = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final pad = EdgeInsets.fromLTRB(40, 16, 16, 24);
    final chartW = size.width - pad.left - pad.right;
    final chartH = size.height - pad.top - pad.bottom;
    final midY = pad.top + chartH / 2;

    // 计算幅值范围
    double maxAbs = 0;
    for (final v in data) {
      final abs = v.abs();
      if (abs > maxAbs) maxAbs = abs;
    }
    if (maxAbs < 0.01) maxAbs = 1;
    maxAbs *= 1.2; // 20% 余量

    final yScale = chartH / (2 * maxAbs);
    final xScale = data.length > 1 ? chartW / (data.length - 1) : 0.0;

    // ---- 背景 ----
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // ---- 网格线 ----
    final gridPaint = Paint()
      ..color = const Color(0xFFE8EAED)
      ..strokeWidth = 0.5;

    // 水平网格（5 条）
    for (int i = 0; i <= 4; i++) {
      final y = pad.top + (chartH / 4) * i;
      canvas.drawLine(
        Offset(pad.left, y),
        Offset(size.width - pad.right, y),
        gridPaint,
      );
    }

    // 垂直网格（10 条）
    for (int i = 0; i <= 10; i++) {
      final x = pad.left + (chartW / 10) * i;
      canvas.drawLine(
        Offset(x, pad.top),
        Offset(x, size.height - pad.bottom),
        gridPaint,
      );
    }

    // ---- 零线 ----
    final zeroPaint = Paint()
      ..color = const Color(0xFFDADCE0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(pad.left, midY),
      Offset(size.width - pad.right, midY),
      zeroPaint,
    );

    // ---- Y 轴标签 ----
    _drawText(
      canvas,
      maxAbs.toStringAsFixed(2),
      Offset(pad.left - 6, pad.top + 2),
      const Color(0xFF999999),
      10,
      TextAlign.right,
    );
    _drawText(
      canvas,
      '0',
      Offset(pad.left - 6, midY + 3),
      const Color(0xFF999999),
      10,
      TextAlign.right,
    );

    // ---- X 轴标签 ----
    _drawText(
      canvas,
      '0s',
      Offset(pad.left, size.height - 2),
      const Color(0xFF999999),
      10,
      TextAlign.center,
    );
    _drawText(
      canvas,
      '${(data.length / 500).toStringAsFixed(1)}s',
      Offset(size.width - pad.right, size.height - 2),
      const Color(0xFF999999),
      10,
      TextAlign.center,
    );

    // ---- ECG 波形 ----
    final wavePaint = Paint()
      ..color = waveColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = pad.left + i * xScale;
      final y = midY - data[i] * yScale;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, wavePaint);

    // ---- R 峰标注 ----
    for (final idx in rPeakIndices) {
      if (idx < 0 || idx >= data.length) continue;

      final x = pad.left + idx * xScale;
      final waveY = midY - data[idx] * yScale;
      final markerY = rPeakDotsOnWave ? waveY : midY + chartH * 0.06;

      // 竖虚线
      final dashPaint = Paint()
        ..color = rPeakColor.withAlpha(80)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(x, pad.top),
        Offset(x, size.height - pad.bottom),
        dashPaint,
      );

      // 红点
      canvas.drawCircle(Offset(x, markerY), 4, Paint()..color = rPeakColor);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize,
    TextAlign align,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    tp.paint(
      canvas,
      offset -
          Offset(
            align == TextAlign.right
                ? tp.width
                : (align == TextAlign.center ? tp.width / 2 : 0),
            fontSize / 2,
          ),
    );
  }

  @override
  bool shouldRepaint(covariant EcgWaveformPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.rPeakIndices != rPeakIndices ||
        oldDelegate.rPeakDotsOnWave != rPeakDotsOnWave;
  }
}
