import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemSound, SystemSoundType, HapticFeedback;

/// 投稿確定時の「確定演出」（バックログ「Lottieアニメーション・効果音」対応）。
///
/// 【方針】このセッションはpub.devへのネットワークアクセスが無く、`lottie`パッケージの追加
/// （`pub get`が通るかの確認含む）や効果音アセット（音声ファイルが実機で正しく再生されるか）を
/// 検証する手段が無い。そのため、外部パッケージ・バイナリアセットを追加する代わりに、
/// Flutter標準機能（`AnimationController` + `CustomPainter` + `SystemSound` + `HapticFeedback`）
/// のみで「波紋の広がり→円のスケールイン→チェックマークのストローク描画」という多段の演出＋
/// 効果音・触覚フィードバックを実装した。パッケージ追加なしで確実に動作する分、Lottieほどの
/// 表現力・デザイン自由度は無い。将来的にデザインアセット（.lottie/.json）が用意でき、
/// ローカル環境で`pub get`・実機確認ができる段階になったら`lottie`パッケージへの置き換えを検討する。
class CheckmarkBurstAnimation extends StatefulWidget {
  const CheckmarkBurstAnimation({super.key, required this.color, this.size = 96});

  final Color color;
  final double size;

  @override
  State<CheckmarkBurstAnimation> createState() => _CheckmarkBurstAnimationState();
}

class _CheckmarkBurstAnimationState extends State<CheckmarkBurstAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    // 演出開始（＝確定完了画面が表示された瞬間）に効果音・触覚フィードバックを鳴らす。
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _CheckmarkBurstPainter(progress: _controller.value, color: widget.color),
        ),
      ),
    );
  }
}

class _CheckmarkBurstPainter extends CustomPainter {
  _CheckmarkBurstPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. 波紋: 0.0〜0.6の区間で外側へ広がりながらフェードアウト
    final burstProgress = Curves.easeOut.transform((progress / 0.6).clamp(0.0, 1.0));
    if (burstProgress > 0) {
      final burstPaint = Paint()
        ..color = color.withValues(alpha: (1 - burstProgress) * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, radius * (0.6 + burstProgress * 0.5), burstPaint);
    }

    // 2. 円の塗りつぶし: 0.0〜0.5でスケールイン（elasticOutで少し弾む）
    final circleProgress = Curves.elasticOut.transform((progress / 0.5).clamp(0.0, 1.0));
    canvas.drawCircle(center, radius * 0.85 * circleProgress, Paint()..color = color);

    // 3. チェックマークのストローク描画: 0.35〜1.0でパスを徐々に描く
    final checkProgress = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    if (checkProgress > 0) {
      final path = Path()
        ..moveTo(radius * 0.55, radius * 1.02)
        ..lineTo(radius * 0.85, radius * 1.32)
        ..lineTo(radius * 1.45, radius * 0.68);
      final metric = path.computeMetrics().first;
      final extracted = metric.extractPath(0, metric.length * checkProgress);
      final checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.08
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(extracted, checkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkBurstPainter oldDelegate) => oldDelegate.progress != progress;
}
