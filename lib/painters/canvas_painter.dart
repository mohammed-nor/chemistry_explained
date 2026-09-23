import 'dart:math';
import 'package:flutter/material.dart';
import '../models/molecule_model.dart';
import '../models/retrosynthesis.dart';

class RetrosynthesisBreakMarker {
  final Offset point;
  final Color color;
  final double confidence;

  const RetrosynthesisBreakMarker({
    required this.point,
    required this.color,
    required this.confidence,
  });
}

// ─── Canvas Painter ───────────────────────────────────────────────────────────

class MoleculeCanvasPainter extends CustomPainter {
  final List<Atom> atoms;
  final List<Bond> bonds;
  final String? selectedAtomId;
  final String? hoveredAtomId;
  final Offset? previewLineEnd;
  final bool isDarkTheme;
  final List<RetrosynthesisBreakMarker> retrosynthesisBreakMarkers;
  final List<FunctionalGroupMarker> functionalGroupMarkers;

  MoleculeCanvasPainter({
    required this.atoms,
    required this.bonds,
    this.selectedAtomId,
    this.hoveredAtomId,
    this.previewLineEnd,
    this.isDarkTheme = true,
    this.retrosynthesisBreakMarkers = const [],
    this.functionalGroupMarkers = const [],
  });

  Atom? _atomById(String id) {
    try {
      return atoms.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Count total bond order attached to an atom.
  int _bondOrderFor(String atomId) {
    int total = 0;
    for (final b in bonds) {
      if (b.fromId == atomId || b.toId == atomId) {
        switch (b.type) {
          case BondType.single:
            total += 1;
          case BondType.double:
            total += 2;
          case BondType.triple:
            total += 3;
        }
      }
    }
    return total;
  }

  void _drawBond(
    Canvas canvas,
    Offset a,
    Offset b,
    BondType type,
    Paint paint,
  ) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final nx = -dy / len;
    final ny = dx / len;
    const offset = 3.5;

    switch (type) {
      case BondType.single:
        canvas.drawLine(a, b, paint);
        break;
      case BondType.double:
        canvas.drawLine(
          Offset(a.dx + nx * offset, a.dy + ny * offset),
          Offset(b.dx + nx * offset, b.dy + ny * offset),
          paint,
        );
        canvas.drawLine(
          Offset(a.dx - nx * offset, a.dy - ny * offset),
          Offset(b.dx - nx * offset, b.dy - ny * offset),
          paint,
        );
        break;
      case BondType.triple:
        canvas.drawLine(a, b, paint);
        canvas.drawLine(
          Offset(a.dx + nx * offset * 1.8, a.dy + ny * offset * 1.8),
          Offset(b.dx + nx * offset * 1.8, b.dy + ny * offset * 1.8),
          paint,
        );
        canvas.drawLine(
          Offset(a.dx - nx * offset * 1.8, a.dy - ny * offset * 1.8),
          Offset(b.dx - nx * offset * 1.8, b.dy - ny * offset * 1.8),
          paint,
        );
        break;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bondPaint = Paint()
      ..color = isDarkTheme ? const Color(0xFFCCCCCC) : const Color(0xFF48566A)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw bonds
    for (final bond in bonds) {
      final from = _atomById(bond.fromId);
      final to = _atomById(bond.toId);
      if (from == null || to == null) continue;
      _drawBond(canvas, from.position, to.position, bond.type, bondPaint);
    }

    // Preview bond line
    if (selectedAtomId != null && previewLineEnd != null) {
      final sel = _atomById(selectedAtomId!);
      if (sel != null) {
        final previewPaint = Paint()
          ..color = const Color(0xFF00C8FF).withValues(alpha: 0.5)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(sel.position, previewLineEnd!, previewPaint);
      }
    }

    for (final marker in retrosynthesisBreakMarkers) {
      final ringRadius = 11.0 + marker.confidence * 9.0;
      final alpha = (marker.confidence * 120 + 40).round();
      final ringPaint = Paint()
        ..color = marker.color.withAlpha(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawCircle(marker.point, ringRadius, ringPaint);

      final fillPaint = Paint()
        ..color = marker.color.withAlpha(0)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(marker.point, ringRadius * 0.38, fillPaint);
    }

    for (final marker in functionalGroupMarkers) {
      final ringColor = RetrosynthesisDatabase.colorForFunctionalGroup(
        marker.label,
      );

      final ringPaint = Paint()
        ..color = ringColor.withAlpha(0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0;
      canvas.drawCircle(marker.center, marker.radius, ringPaint);

      final fillPaint = Paint()
        ..color = ringColor.withAlpha(35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(marker.center, marker.radius * 0.75, fillPaint);

      final labelPainter = TextPainter(
        text: TextSpan(
          text: marker.label,
          style: const TextStyle(
            color: Color(0xFFEBF7FF),
            fontSize: 0,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      final labelOffset = Offset(
        marker.center.dx - (labelPainter.width / 2),
        marker.center.dy - (labelPainter.height / 2),
      );
      labelPainter.paint(canvas, labelOffset);
    }

    // Draw atoms
    for (final atom in atoms) {
      final isSelected = atom.id == selectedAtomId;
      final isHovered = atom.id == hoveredAtomId;
      const radius = 16.0;

      // Check if over-bonded
      final maxBonds = kMaxBonds[atom.symbol] ?? 4;
      final currentBondOrder = _bondOrderFor(atom.id);
      final isOverBonded = currentBondOrder > maxBonds + atom.charge.abs();

      // Glow for selected
      if (isSelected) {
        final glowPaint = Paint()
          ..color = const Color(0xFF00C8FF).withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(atom.position, radius + 6, glowPaint);
      }

      // Over-bond warning glow
      if (isOverBonded) {
        final warnGlow = Paint()
          ..color = const Color(0xFFFF5252).withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(atom.position, radius + 4, warnGlow);
      }

      // Background circle
      final bgPaint = Paint()
        ..color = isSelected
            ? (isDarkTheme ? const Color(0xFF002A35) : const Color(0xFFE0F2FE))
            : isHovered
            ? (isDarkTheme ? const Color(0xFF1E1E1E) : const Color(0xFFE5E7EB))
            : (isDarkTheme ? const Color(0xFF161616) : const Color(0xFFF8FAFC));
      canvas.drawCircle(atom.position, radius, bgPaint);

      // Border
      final borderPaint = Paint()
        ..color = isOverBonded
            ? const Color(0xFFFF5252)
            : isSelected
            ? const Color(0xFF00C8FF)
            : isHovered
            ? atom.color.withValues(alpha: 0.9)
            : atom.color.withValues(alpha: 0.6)
        ..strokeWidth = isSelected ? 1.8 : 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(atom.position, radius, borderPaint);

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: atom.symbol,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00C8FF) : atom.color,
            fontSize: atom.symbol.length > 1 ? 10 : 12,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, atom.position - Offset(tp.width / 2, tp.height / 2));

      // ── Charge badge ──────────────────────────────────────────────────
      if (atom.charge != 0) {
        final chargeLabel = atom.charge > 0
            ? '+${atom.charge}'
            : '${atom.charge}';
        final chargeColor = atom.charge > 0
            ? const Color(0xFF64B5F6)
            : const Color(0xFFEF5350);

        // Badge circle
        final badgeCenter = atom.position + const Offset(12, -12);
        final badgeBg = Paint()
          ..color = isDarkTheme
              ? const Color(0xFF111111)
              : const Color(0xFFF8FAFC);
        canvas.drawCircle(badgeCenter, 7, badgeBg);
        final badgeBorder = Paint()
          ..color = chargeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(badgeCenter, 7, badgeBorder);

        final chTp = TextPainter(
          text: TextSpan(
            text: chargeLabel,
            style: TextStyle(
              color: chargeColor,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        chTp.layout();
        chTp.paint(
          canvas,
          badgeCenter - Offset(chTp.width / 2, chTp.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant MoleculeCanvasPainter old) => true;
}
