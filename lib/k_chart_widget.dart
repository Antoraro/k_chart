import 'dart:async';

import 'package:flutter/material.dart';
import 'package:k_chart/chart_translations.dart';
import 'package:k_chart/extension/map_ext.dart';
import 'package:k_chart/flutter_k_chart.dart';

enum MainState { MA, BOLL, NONE }
enum SecondaryState { MACD, KDJ, RSI, WR, CCI, NONE }

class TimeFormat {
  static const List<String> YEAR_MONTH_DAY = [yyyy, '-', mm, '-', dd];
  static const List<String> YEAR_MONTH_DAY_WITH_HOUR = [
    yyyy,
    '-',
    mm,
    '-',
    dd,
    ' ',
    HH,
    ':',
    nn
  ];
}

class KChartWidget extends StatefulWidget {
  final List<KLineEntity>? datas;
  final MainState mainState;
  final bool volHidden;
  final SecondaryState secondaryState;
  final Function()? onSecondaryTap;
  final String Function(double) priceFormatter;
  final bool isLine;
  final bool hideGrid;
  @Deprecated('Use `translations` instead.')
  final bool isChinese;
  final bool showNowPrice;
  final bool showInfoDialog;
  final Map<String, ChartTranslations> translations;
  final List<String> timeFormat;

  //当屏幕滚动到尽头会调用，真为拉到屏幕右侧尽头，假为拉到屏幕左侧尽头
  final Function(bool)? onLoadMore;

  @Deprecated('Use `chartColors` instead.')
  final List<Color>? bgColor;
  final int fixedLength;
  final List<int> maDayList;
  final int flingTime;
  final double flingRatio;
  final Curve flingCurve;
  final Function(bool)? isOnDrag;
  final ChartColors chartColors;
  final ChartStyle chartStyle;

  KChartWidget(
    this.datas,
    this.chartStyle,
    this.chartColors, {
    this.mainState = MainState.MA,
    this.secondaryState = SecondaryState.MACD,
    this.onSecondaryTap,
    this.volHidden = false,
    this.isLine = false,
    this.hideGrid = false,
    @Deprecated('Use `translations` instead.') this.isChinese = false,
    this.showNowPrice = true,
    this.showInfoDialog = true,
    this.translations = kChartTranslations,
    @Deprecated('Use ChartStyle.timeFormat instead.')
        this.timeFormat = TimeFormat.YEAR_MONTH_DAY,
    this.onLoadMore,
    this.priceFormatter = defaultPriceFormatter,
    @Deprecated('Use `chartColors` instead.') this.bgColor,
    @Deprecated('Use priceFormatter() instead.') this.fixedLength = 2,
    this.maDayList = const [5, 10, 20],
    this.flingTime = 600,
    this.flingRatio = 0.5,
    this.flingCurve = Curves.decelerate,
    this.isOnDrag,
  });

  static String defaultPriceFormatter(double value) => value.toStringAsFixed(2);

  @override
  _KChartWidgetState createState() => _KChartWidgetState();
}

class _KChartWidgetState extends State<KChartWidget>
    with TickerProviderStateMixin {
  double mScaleX = 1.0, mScrollX = 0.0, mSelectX = 0.0;
  StreamController<InfoWindowEntity?>? mInfoWindowStream;
  double mHeight = 0, mWidth = 0;
  AnimationController? _controller;
  Animation<double>? aniX;

  double getMinScrollX() {
    return mScaleX;
  }

  double _lastScale = 1.0;
  bool isScale = false, isDrag = false, isLongPress = false;

  @override
  void initState() {
    super.initState();
    mInfoWindowStream = StreamController<InfoWindowEntity?>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    mInfoWindowStream?.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.datas != null && widget.datas!.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }
    final _painter = ChartPainter(
      widget.chartStyle,
      widget.chartColors,
      priceFormatter: widget.priceFormatter,
      datas: widget.datas,
      scaleX: mScaleX,
      scrollX: mScrollX,
      selectX: mSelectX,
      isLongPass: isLongPress,
      mainState: widget.mainState,
      volHidden: widget.volHidden,
      secondaryState: widget.secondaryState,
      isLine: widget.isLine,
      hideGrid: widget.hideGrid,
      showNowPrice: widget.showNowPrice,
      sink: mInfoWindowStream?.sink,
      bgColor: widget.bgColor,
      maDayList: widget.maDayList,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        mHeight = constraints.maxHeight;
        mWidth = constraints.maxWidth;

        return GestureDetector(
          onTapUp: (details) {
            if (widget.onSecondaryTap != null &&
                _painter.isInSecondaryRect(details.localPosition)) {
              widget.onSecondaryTap!();
            }
          },
          onHorizontalDragDown: (details) {
            _stopAnimation();
            _onDragChanged(true);
          },
          onHorizontalDragUpdate: (details) {
            if (isScale || isLongPress) return;
            mScrollX = ((details.primaryDelta ?? 0) / mScaleX + mScrollX)
                .clamp(0.0, ChartPainter.maxScrollX)
                .toDouble();
            notifyChanged();
          },
          onHorizontalDragEnd: (DragEndDetails details) {
            var velocity = details.velocity.pixelsPerSecond.dx;
            _onFling(velocity);
          },
          onHorizontalDragCancel: () => _onDragChanged(false),
          onScaleStart: (_) {
            isScale = true;
          },
          onScaleUpdate: (details) {
            if (isDrag || isLongPress) return;
            mScaleX = (_lastScale * details.scale).clamp(0.5, 2.2);
            notifyChanged();
          },
          onScaleEnd: (_) {
            isScale = false;
            _lastScale = mScaleX;
          },
          onLongPressStart: (details) {
            isLongPress = true;
            if (mSelectX != details.globalPosition.dx) {
              mSelectX = details.globalPosition.dx;
              notifyChanged();
            }
          },
          onLongPressMoveUpdate: (details) {
            if (mSelectX != details.globalPosition.dx) {
              mSelectX = details.globalPosition.dx;
              notifyChanged();
            }
          },
          onLongPressEnd: (details) {
            isLongPress = false;
            mInfoWindowStream?.sink.add(null);
            notifyChanged();
          },
          child: Stack(
            children: <Widget>[
              CustomPaint(
                size: Size(double.infinity, double.infinity),
                painter: _painter,
              ),
              if (widget.showInfoDialog)
                _InfoDialog(
                  width: mWidth,
                  infoWindowStream: mInfoWindowStream,
                  isLongPress: isLongPress,
                  widget: widget,
                )
            ],
          ),
        );
      },
    );
  }

  void _stopAnimation({bool needNotify = true}) {
    if (_controller != null && _controller!.isAnimating) {
      _controller!.stop();
      _onDragChanged(false);
      if (needNotify) {
        notifyChanged();
      }
    }
  }

  void _onDragChanged(bool isOnDrag) {
    isDrag = isOnDrag;
    if (widget.isOnDrag != null) {
      widget.isOnDrag!(isDrag);
    }
  }

  void _onFling(double x) {
    _controller = AnimationController(
        duration: Duration(milliseconds: widget.flingTime), vsync: this);
    aniX = null;
    aniX = Tween<double>(begin: mScrollX, end: x * widget.flingRatio + mScrollX)
        .animate(CurvedAnimation(
            parent: _controller!.view, curve: widget.flingCurve));
    aniX!.addListener(() {
      mScrollX = aniX!.value;
      if (mScrollX <= 0) {
        mScrollX = 0;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(true);
        }
        _stopAnimation();
      } else if (mScrollX >= ChartPainter.maxScrollX) {
        mScrollX = ChartPainter.maxScrollX;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(false);
        }
        _stopAnimation();
      }
      notifyChanged();
    });
    aniX!.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _onDragChanged(false);
        notifyChanged();
      }
    });
    _controller!.forward();
  }

  void notifyChanged() => setState(() {});
}

class _InfoDialog extends StatelessWidget {
  const _InfoDialog({
    Key? key,
    required this.width,
    required this.widget,
    required this.isLongPress,
    required this.infoWindowStream,
  }) : super(key: key);
  final double width;
  final bool isLongPress;
  final KChartWidget widget;
  final StreamController<InfoWindowEntity?>? infoWindowStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<InfoWindowEntity?>(
      stream: infoWindowStream?.stream,
      builder: (context, snapshot) {
        if (!isLongPress ||
            widget.isLine == true ||
            !snapshot.hasData ||
            snapshot.data?.kLineEntity == null) return Container();
        KLineEntity entity = snapshot.data!.kLineEntity;
        double upDown = entity.change ?? entity.close - entity.open;
        double upDownPercent = entity.ratio ?? (upDown / entity.open) * 100;
        final List<String> infoList = [
          getDate(entity.time),
          widget.priceFormatter.call(entity.open),
          widget.priceFormatter.call(entity.high),
          widget.priceFormatter.call(entity.low),
          widget.priceFormatter.call(entity.close),
          "${upDown > 0 ? "+" : ""}${widget.priceFormatter.call(upDown)}",
          "${upDownPercent > 0 ? "+" : ''}${widget.priceFormatter.call(upDownPercent)}%",
          entity.amount.toInt().toString()
        ];
        return Container(
          margin: EdgeInsets.only(
              left: snapshot.data!.isLeft ? 4 : width - width / 3 - 4, top: 25),
          width: width / 3,
          decoration: BoxDecoration(
              color: widget.chartColors.selectFillColor,
              border: Border.all(
                  color: widget.chartColors.selectBorderColor, width: 0.5)),
          child: ListView.builder(
            padding: EdgeInsets.all(4),
            itemCount: infoList.length,
            itemExtent: 14.0,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final translations = widget.isChinese
                  ? kChartTranslations['zh_CN']!
                  : widget.translations.of(context);

              return _InfoItem(
                info: infoList[index],
                infoName: translations.byIndex(index),
                infoColor: getInfoColor(infoList[index]),
                infoNameColor: widget.chartColors.infoWindowTitleColor,
              );
            },
          ),
        );
      },
    );
  }

  String getDate(int? date) => dateFormat(
        DateTime.fromMillisecondsSinceEpoch(
          date ?? DateTime.now().millisecondsSinceEpoch,
        ),
        [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn],
      );

  Color getInfoColor(String info) {
    Color color = widget.chartColors.infoWindowNormalColor;
    if (info.startsWith("+"))
      color = widget.chartColors.infoWindowUpColor;
    else if (info.startsWith("-")) color = widget.chartColors.infoWindowDnColor;

    return color;
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    Key? key,
    required this.info,
    required this.infoName,
    required this.infoColor,
    required this.infoNameColor,
  }) : super(key: key);
  final String info, infoName;
  final Color infoColor, infoNameColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            "$infoName",
            style: TextStyle(
              color: infoNameColor,
              fontSize: 10.0,
            ),
          ),
        ),
        Text(
          info,
          style: TextStyle(
            color: infoColor,
            fontSize: 10.0,
          ),
        ),
      ],
    );
  }
}
