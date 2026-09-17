import 'package:flutter/material.dart';

import 'data/hydrology.dart';

const _navy = Color(0xFF0B2748);
const _water = Color(0xFF2D7FA8);
const _muted = Color(0xFF5C6B74);
const _ink = Color(0xFF162632);
const _line = Color(0xFFE1E6E9);

/// Gráfico da série real de nível do Rio Itajaí-Açu.
///
/// Regras que este gráfico segue:
///
/// - desenha **apenas medições reais** da estação telemétrica; nunca interpola
///   um ponto que não existe nem completa buracos da série;
/// - mostra escala, unidade e horários, para que a linha possa ser lida como
///   número e não como impressão;
/// - marca as cotas oficiais da Defesa Civil, que são o único critério válido
///   para dizer se um nível é preocupante;
/// - a escala vertical inclui a próxima cota acima do observado, para que a
///   distância até ela seja visível — um gráfico ajustado só aos dados faria
///   uma variação de 10 cm parecer uma cheia.
class RiverChart extends StatelessWidget {
  const RiverChart({
    required this.readings,
    this.height = 168,
    super.key,
  });

  final List<RiverReading> readings;
  final double height;

  /// Mínimo de pontos para que uma linha signifique alguma coisa.
  static const minimumPoints = 3;

  @override
  Widget build(BuildContext context) {
    if (readings.length < minimumPoints) {
      return Container(
        height: 72,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Série insuficiente para desenhar o gráfico. '
          'São necessárias ao menos 3 leituras.',
          style: TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
        ),
      );
    }

    final ordered = [...readings]..sort((a, b) => a.at.compareTo(b.at));
    final values = ordered.map((r) => r.meters).toList();
    final observedMin = values.reduce((a, b) => a < b ? a : b);
    final observedMax = values.reduce((a, b) => a > b ? a : b);

    // Inclui a próxima cota acima do observado: a distância até ela é a
    // informação que importa para decidir.
    final nextStage = RiverStage.values.firstWhere(
      (stage) => stage.minMeters > observedMax,
      orElse: () => RiverStage.maximumAlert,
    );
    final ceiling =
        nextStage.minMeters.isFinite ? nextStage.minMeters : observedMax + 1;

    var top = ceiling > observedMax ? ceiling : observedMax;
    var bottom = observedMin;
    // Margem para a linha não colar nas bordas.
    final span = (top - bottom).abs();
    final padding = span < 0.2 ? 0.15 : span * 0.12;
    top += padding;
    bottom -= padding;
    if (bottom < 0) bottom = 0;

    final stages = RiverStage.values
        .where((stage) =>
            stage.minMeters > bottom &&
            stage.minMeters < top &&
            stage.minMeters > 0)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _RiverChartPainter(
              readings: ordered,
              minMeters: bottom,
              maxMeters: top,
              stages: stages,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(width: 14, height: 2, color: _water),
            const SizedBox(width: 6),
            Text(
              'Nível medido (m) · ${ordered.length} leituras · '
              '${_range(ordered)}',
              style: const TextStyle(color: _muted, fontSize: 10.5),
            ),
          ],
        ),
        if (stages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 2,
                  child: CustomPaint(painter: _DashLegendPainter()),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Cota oficial: ${stages.map((s) => '${s.label} '
                        '${s.minMeters.toStringAsFixed(0)} m').join(' · ')}',
                    style: const TextStyle(color: _muted, fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _range(List<RiverReading> ordered) {
    String at(DateTime t) =>
        '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}h';
    return '${at(ordered.first.at)} a ${at(ordered.last.at)}';
  }
}

class _RiverChartPainter extends CustomPainter {
  const _RiverChartPainter({
    required this.readings,
    required this.minMeters,
    required this.maxMeters,
    required this.stages,
  });

  final List<RiverReading> readings;
  final double minMeters;
  final double maxMeters;
  final List<RiverStage> stages;

  static const _leftAxis = 34.0;
  static const _bottomAxis = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width - _leftAxis;
    final plotHeight = size.height - _bottomAxis;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    final range =
        (maxMeters - minMeters).abs() < 0.001 ? 1.0 : maxMeters - minMeters;

    double yFor(double meters) =>
        plotHeight - ((meters - minMeters) / range) * plotHeight;

    double xFor(int index) => readings.length == 1
        ? _leftAxis
        : _leftAxis + (index / (readings.length - 1)) * plotWidth;

    // Moldura do gráfico.
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _line;
    canvas.drawLine(
        const Offset(_leftAxis, 0), Offset(_leftAxis, plotHeight), frame);
    canvas.drawLine(
        Offset(_leftAxis, plotHeight), Offset(size.width, plotHeight), frame);

    // Escala vertical, em metros: três marcas legíveis.
    for (var i = 0; i <= 2; i++) {
      final meters = minMeters + range * (i / 2);
      final y = yFor(meters);
      canvas.drawLine(
        Offset(_leftAxis, y),
        Offset(size.width, y),
        Paint()
          ..strokeWidth = 1
          ..color = _line.withValues(alpha: .6),
      );
      _label(
        canvas,
        meters.toStringAsFixed(1).replaceAll('.', ','),
        Offset(0, y - 6),
        _muted,
        9.5,
      );
    }

    // Cotas oficiais: linha tracejada com o nome.
    for (final stage in stages) {
      final y = yFor(stage.minMeters);
      if (y < 0 || y > plotHeight) continue;
      final dash = Paint()
        ..strokeWidth = 1.2
        ..color = _stageColor(stage).withValues(alpha: .75);
      const dashWidth = 5.0;
      var x = _leftAxis;
      while (x < _leftAxis + plotWidth) {
        canvas.drawLine(Offset(x, y),
            Offset((x + dashWidth).clamp(0, size.width), y), dash);
        x += dashWidth * 2;
      }
      _label(
        canvas,
        stage.label,
        Offset(_leftAxis + 4, y - 12),
        _stageColor(stage),
        9,
        bold: true,
      );
    }

    // A linha da série real.
    final path = Path();
    for (var i = 0; i < readings.length; i++) {
      final point = Offset(xFor(i), yFor(readings[i].meters));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _water,
    );

    // Último ponto destacado: é a leitura mais recente.
    final last = Offset(xFor(readings.length - 1), yFor(readings.last.meters));
    canvas.drawCircle(last, 3.5, Paint()..color = _water);
    canvas.drawCircle(
      last,
      3.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white,
    );

    // Horários nas extremidades.
    _label(canvas, _hour(readings.first.at), Offset(_leftAxis, plotHeight + 4),
        _muted, 9.5);
    _label(canvas, _hour(readings.last.at),
        Offset(size.width - 30, plotHeight + 4), _muted, 9.5);
  }

  static String _hour(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  static Color _stageColor(RiverStage stage) => switch (stage) {
        RiverStage.normality => _navy,
        RiverStage.observation => _water,
        RiverStage.attention => const Color(0xFF8A6D1F),
        RiverStage.alert || RiverStage.maximumAlert => const Color(0xFFC92B35),
      };

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    Color color,
    double size, {
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_RiverChartPainter old) =>
      old.readings != readings ||
      old.minMeters != minMeters ||
      old.maxMeters != maxMeters;
}

class _DashLegendPainter extends CustomPainter {
  const _DashLegendPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..color = _ink.withValues(alpha: .5);
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, size.height / 2), Offset(x + 3, size.height / 2), paint);
      x += 6;
    }
  }

  @override
  bool shouldRepaint(_DashLegendPainter oldDelegate) => false;
}
