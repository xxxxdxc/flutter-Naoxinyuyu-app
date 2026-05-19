import 'dart:math';
import 'package:flutter/material.dart';

/// 趋势图表绘制器 - 显示刺激强度与生理指标的双折线图
class TrendChartPainter extends CustomPainter {
  final List<double> intensityData;    // 刺激强度数据
  final List<double> physiologicalData; // 生理指标数据
  final Color intensityColor;          // 刺激强度线条颜色
  final Color physiologicalColor;      // 生理指标线条颜色
  final String xAxisTitle;             // X轴标题
  final String intensityYAxisTitle;    // 左Y轴标题
  final String physiologicalYAxisTitle; // 右Y轴标题
  final bool showGrid;                 // 是否显示网格
  final Color gridColor;               // 网格颜色
  final Color axisColor;               // 坐标轴颜色
  final TextStyle? axisTextStyle;      // 坐标轴文字样式
  final double? leftMargin;            // 左侧边距（像素或null时使用百分比）
  final double? rightMargin;           // 右侧边距
  final double? topMargin;             // 顶部边距
  final double? bottomMargin;          // 底部边距

  TrendChartPainter({
    required this.intensityData,
    required this.physiologicalData,
    this.intensityColor = const Color(0xFF1976D2), // 主色调蓝色
    this.physiologicalColor = const Color(0xFF4CAF50), // 绿色
    this.xAxisTitle = '时间',
    this.intensityYAxisTitle = '强度 (mA)',
    this.physiologicalYAxisTitle = 'HRV',
    this.showGrid = true,
    this.gridColor = const Color(0xFFE0E0E0),
    this.axisColor = const Color(0xFF757575),
    this.axisTextStyle,
    this.leftMargin,
    this.rightMargin,
    this.topMargin,
    this.bottomMargin,
  });

  // 动态计算边距
  double _effectiveLeftMargin(Size size) => leftMargin ?? size.width * 0.12;
  double _effectiveRightMargin(Size size) => rightMargin ?? size.width * 0.12;
  double _effectiveTopMargin(Size size) => topMargin ?? size.height * 0.1;
  double _effectiveBottomMargin(Size size) => bottomMargin ?? size.height * 0.15;

  // 计算可用绘图区域
  double _chartWidth(Size size) => size.width - _effectiveLeftMargin(size) - _effectiveRightMargin(size);
  double _chartHeight(Size size) => size.height - _effectiveTopMargin(size) - _effectiveBottomMargin(size);

  // 数据采样方法：当数据点过多时进行采样
  List<double> _sampleData(List<double> originalData, int targetCount) {
    if (targetCount >= originalData.length) return originalData;

    final sampled = <double>[];
    final step = originalData.length / targetCount;

    for (int i = 0; i < targetCount; i++) {
      final index = (i * step).floor();
      sampled.add(originalData[index]);
    }

    return sampled;
  }

  // 计算最佳X轴标签数量
  int _optimalXTickCount(double chartWidth) {
    const double minLabelWidth = 50.0; // 最小标签宽度
    final int maxTicks = (chartWidth / minLabelWidth).floor();

    // 考虑数据点数量，但标签数不超过数据点数量
    final int dataPointCount = max(intensityData.length, physiologicalData.length);
    return max(3, min(maxTicks, min(dataPointCount, 8))); // 最少3个，最多8个标签
  }

  // 生成X轴标签文本
  String _generateXLabel(int index, int totalTicks) {
    if (index == 0) return '开始';
    if (index == totalTicks) return '现在';

    // 根据总刻度数生成有意义的时间标签
    if (totalTicks <= 4) {
      return '${index * 6}h'; // 少量刻度时使用6小时间隔
    } else if (totalTicks <= 6) {
      return '${index * 4}h'; // 中等刻度时使用4小时间隔
    } else {
      return '${index * 2}h'; // 较多刻度时使用2小时间隔
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawGrid(canvas, size);
    _drawAxes(canvas, size);
    _drawChartLines(canvas, size);
    _drawLegends(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _drawGrid(Canvas canvas, Size size) {
    if (!showGrid) return;

    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final leftMargin = _effectiveLeftMargin(size);
    final rightMargin = _effectiveRightMargin(size);
    final topMargin = _effectiveTopMargin(size);
    final bottomMargin = _effectiveBottomMargin(size);

    final chartWidth = _chartWidth(size);
    final chartHeight = _chartHeight(size);

    const int verticalLines = 6;
    const int horizontalLines = 5;

    // 绘制垂直网格线（在绘图区域内）
    for (int i = 1; i < verticalLines; i++) {
      final x = leftMargin + chartWidth * i / verticalLines;
      canvas.drawLine(Offset(x, topMargin), Offset(x, size.height - bottomMargin), paint);
    }

    // 绘制水平网格线（在绘图区域内）
    for (int i = 1; i < horizontalLines; i++) {
      final y = topMargin + chartHeight * i / horizontalLines;
      canvas.drawLine(Offset(leftMargin, y), Offset(size.width - rightMargin, y), paint);
    }
  }

  void _drawAxes(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final leftMargin = _effectiveLeftMargin(size);
    final rightMargin = _effectiveRightMargin(size);
    final topMargin = _effectiveTopMargin(size);
    final bottomMargin = _effectiveBottomMargin(size);

    // X轴
    canvas.drawLine(
      Offset(leftMargin, size.height - bottomMargin),
      Offset(size.width - rightMargin, size.height - bottomMargin),
      axisPaint,
    );

    // Y轴（左）
    canvas.drawLine(
      Offset(leftMargin, topMargin),
      Offset(leftMargin, size.height - bottomMargin),
      axisPaint,
    );

    // Y轴（右）
    canvas.drawLine(
      Offset(size.width - rightMargin, topMargin),
      Offset(size.width - rightMargin, size.height - bottomMargin),
      axisPaint,
    );

    // 绘制轴标题
    _drawAxisLabels(canvas, size);
  }

  void _drawAxisLabels(Canvas canvas, Size size) {
    final textStyle = axisTextStyle ?? TextStyle(
      color: axisColor,
      fontSize: 10,
    );

    final leftMargin = _effectiveLeftMargin(size);
    final rightMargin = _effectiveRightMargin(size);
    final bottomMargin = _effectiveBottomMargin(size);
    final chartWidth = _chartWidth(size);
    final chartHeight = _chartHeight(size);

    // X轴标题
    _drawTextCentered(
      canvas,
      xAxisTitle,
      Offset(size.width / 2, size.height - bottomMargin / 2),
      textStyle,
    );

    // 左Y轴标题（旋转-90度）
    _drawTextVertical(
      canvas,
      intensityYAxisTitle,
      Offset(leftMargin / 2, size.height / 2),
      textStyle,
    );

    // 右Y轴标题（旋转90度）
    _drawTextVertical(
      canvas,
      physiologicalYAxisTitle,
      Offset(size.width - rightMargin / 2, size.height / 2),
      textStyle,
      clockwise: true,
    );

    // X轴刻度标签 - 使用动态计算的最佳刻度数
    final int xTicks = _optimalXTickCount(chartWidth);
    for (int i = 0; i <= xTicks; i++) {
      final x = leftMargin + chartWidth * i / xTicks;
      final label = _generateXLabel(i, xTicks);
      _drawTextCentered(
        canvas,
        label,
        Offset(x, size.height - bottomMargin / 3),
        textStyle,
      );
    }

    // 左Y轴刻度标签（刺激强度）
    const int leftYTicks = 5;
    for (int i = 0; i <= leftYTicks; i++) {
      final y = size.height - bottomMargin - chartHeight * i / leftYTicks;
      final value = i * 2.5; // 0-10 mA
      _drawTextRightAligned(
        canvas,
        value.toStringAsFixed(1),
        Offset(leftMargin * 0.8, y),
        textStyle,
      );
    }

    // 右Y轴刻度标签（生理指标）
    const int rightYTicks = 5;
    for (int i = 0; i <= rightYTicks; i++) {
      final y = size.height - bottomMargin - chartHeight * i / rightYTicks;
      final value = i * 20; // 0-100
      _drawTextLeftAligned(
        canvas,
        value.toStringAsFixed(0),
        Offset(size.width - rightMargin * 0.8, y),
        textStyle,
      );
    }
  }

  void _drawChartLines(Canvas canvas, Size size) {
    if (intensityData.isEmpty && physiologicalData.isEmpty) return;

    // 计算数据范围
    final maxIntensity = intensityData.isNotEmpty
        ? intensityData.reduce((a, b) => a > b ? a : b)
        : 10.0;
    final maxPhysiological = physiologicalData.isNotEmpty
        ? physiologicalData.reduce((a, b) => a > b ? a : b)
        : 100.0;

    // 绘制刺激强度折线
    if (intensityData.isNotEmpty) {
      _drawLine(
        canvas,
        size,
        intensityData,
        intensityColor,
        maxIntensity,
        false, // isRightAxis: false
      );
    }

    // 绘制生理指标折线
    if (physiologicalData.isNotEmpty) {
      _drawLine(
        canvas,
        size,
        physiologicalData,
        physiologicalColor,
        maxPhysiological,
        true, // isRightAxis: true
      );
    }
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    List<double> data,
    Color color,
    double maxValue,
    bool isRightAxis,
  ) {
    if (data.isEmpty) return;

    final leftMargin = _effectiveLeftMargin(size);
    final bottomMargin = _effectiveBottomMargin(size);
    final chartWidth = _chartWidth(size);
    final chartHeight = _chartHeight(size);

    // 检查数据点间距，避免过密
    final double minXSpacing = 8.0; // 最小X轴间距（像素）
    final double actualXSpacing = chartWidth / (data.length - 1);
    List<double> effectiveData = data;

    // 如果数据点过密，进行采样
    if (actualXSpacing < minXSpacing && data.length > 8) {
      final targetCount = (chartWidth / minXSpacing).floor();
      effectiveData = _sampleData(data, targetCount.clamp(6, 16)); // 最少6个，最多16个点
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    final xStep = chartWidth / (effectiveData.length - 1);

    for (int i = 0; i < effectiveData.length; i++) {
      final x = leftMargin + i * xStep;
      final normalizedValue = effectiveData[i] / maxValue;
      final y = size.height - bottomMargin - normalizedValue * chartHeight;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // 只在数据点较少时显示数据点标记
      if (effectiveData.length <= 12) {
        final pointPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), 3, pointPaint);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawLegends(Canvas canvas, Size size) {
    const legendSpacing = 80.0;
    final legendStartX = size.width / 2 - legendSpacing;

    // 刺激强度图例
    _drawLegendItem(
      canvas,
      '刺激强度',
      intensityColor,
      Offset(legendStartX, 10),
    );

    // 生理指标图例
    _drawLegendItem(
      canvas,
      '生理指标',
      physiologicalColor,
      Offset(legendStartX + legendSpacing, 10),
    );
  }

  void _drawLegendItem(Canvas canvas, String label, Color color, Offset position) {
    // 图例颜色标记
    final markerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(position.dx + 8, position.dy + 8), 4, markerPaint);

    // 图例文本
    final textStyle = axisTextStyle ?? TextStyle(
      color: axisColor,
      fontSize: 10,
    );

    _drawTextLeftAligned(
      canvas,
      label,
      Offset(position.dx + 20, position.dy + 4),
      textStyle,
    );
  }

  void _drawTextCentered(Canvas canvas, String text, Offset position, TextStyle style) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy - textPainter.height / 2),
    );
  }

  void _drawTextRightAligned(Canvas canvas, String text, Offset position, TextStyle style) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width, position.dy - textPainter.height / 2),
    );
  }

  void _drawTextLeftAligned(Canvas canvas, String text, Offset position, TextStyle style) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, position);
  }

  void _drawTextVertical(
    Canvas canvas,
    String text,
    Offset position,
    TextStyle style, {
    bool clockwise = false,
  }) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(clockwise ? pi / 2 : -pi / 2);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter oldDelegate) {
    return intensityData != oldDelegate.intensityData ||
        physiologicalData != oldDelegate.physiologicalData ||
        intensityColor != oldDelegate.intensityColor ||
        physiologicalColor != oldDelegate.physiologicalColor ||
        showGrid != oldDelegate.showGrid ||
        leftMargin != oldDelegate.leftMargin ||
        rightMargin != oldDelegate.rightMargin ||
        topMargin != oldDelegate.topMargin ||
        bottomMargin != oldDelegate.bottomMargin;
  }
}