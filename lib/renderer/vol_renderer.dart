import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:k_chart/flutter_k_chart.dart';

class VolRenderer extends BaseChartRenderer<VolumeEntity> {
  late double mVolWidth;
  final double priceSpacerWidth;
  final ChartStyle chartStyle;
  final ChartColors chartColors;

  VolRenderer(
    Rect chartRect,
    double maxValue,
    double minValue,
    double topPadding,
    int fixedLength,
    this.priceSpacerWidth,
    this.chartStyle,
    this.chartColors,
  ) : super(
          chartRect: chartRect,
          maxValue: maxValue,
          minValue: minValue,
          topPadding: topPadding,
          fixedLength: fixedLength,
          gridColor: chartColors.gridColor,
        ) {
    mVolWidth = this.chartStyle.volWidth;
  }

  @override
  void drawChart(VolumeEntity lastPoint, VolumeEntity curPoint, double lastX,
      double curX, Size size, Canvas canvas) {
    double r = mVolWidth / 2;
    double top = getVolY(curPoint.vol);
    double bottom = chartRect.bottom;
    if (curPoint.vol != 0) {
      canvas.drawRect(
          Rect.fromLTRB(curX - r, top, curX + r, bottom),
          chartPaint
            ..color = curPoint.close > curPoint.open
                ? this.chartColors.upColor
                : this.chartColors.dnColor);
    }

    if (lastPoint.MA5Volume != 0) {
      drawLine(lastPoint.MA5Volume, curPoint.MA5Volume, canvas, lastX, curX,
          this.chartColors.ma5Color);
    }

    if (lastPoint.MA10Volume != 0) {
      drawLine(lastPoint.MA10Volume, curPoint.MA10Volume, canvas, lastX, curX,
          this.chartColors.ma10Color);
    }
  }

  double getVolY(double value) =>
      (maxValue - value) * (chartRect.height / maxValue) + chartRect.top;

  @override
  void drawText(Canvas canvas, VolumeEntity data, double x) {
    TextSpan span = TextSpan(
      children: [
        TextSpan(
            text: "VOL:${NumberUtil.format(data.vol)}    ",
            style: getTextStyle(this.chartColors.volColor)),
        if (data.MA5Volume.notNullOrZero)
          TextSpan(
              text: "MA5:${NumberUtil.format(data.MA5Volume!)}    ",
              style: getTextStyle(this.chartColors.ma5Color)),
        if (data.MA10Volume.notNullOrZero)
          TextSpan(
              text: "MA10:${NumberUtil.format(data.MA10Volume!)}    ",
              style: getTextStyle(this.chartColors.ma10Color)),
      ],
    );
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(x, chartRect.top - topPadding));
  }

  @override
  void drawRightText(canvas, textStyle, int gridRows) {
    TextSpan span = TextSpan(
      text: "${NumberUtil.format(maxValue)}",
      style: textStyle,
    );
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();

    double shift = chartStyle.enablePriceSpacer
        ? priceSpacerWidth - chartStyle.priceLabelPadding
        : 0.0;
    double offsetX = chartStyle.alignPriceRight
        ? chartRect.width - tp.width + shift
        : (chartStyle.enablePriceSpacer
            ? chartStyle.priceLabelPadding
            : chartRect.width - tp.width);

    tp.paint(canvas, Offset(offsetX, chartRect.top - topPadding));
  }

  @override
  void drawGrid(Canvas canvas, int gridRows, int gridColumns) {
    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      gridPaint,
    );
    double columnSpace = chartRect.width / gridColumns;
    double shiftX = chartStyle.alignPriceRight ? 0.0 : priceSpacerWidth;
    for (int i = 0; i <= gridColumns; i++) {
      canvas.drawLine(
        Offset(columnSpace * i + shiftX, topPadding / 3),
        Offset(columnSpace * i + shiftX, chartRect.bottom),
        gridPaint,
      );
    }
  }
}
