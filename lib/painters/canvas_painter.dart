import 'dart:math';
import 'package:flutter/material.dart';
import '../models/molecule_model.dart';

// ─── Canvas Painter ───────────────────────────────────────────────────────────

class MoleculeCanvasPainter extends CustomPainter {
  final List<Atom> atoms;
  final List<Bond> bonds;
  final String? selectedAtomId;
  final String? hoveredAtomId;
  final Offset? previewLineEnd;

  MoleculeCanvasPainter({
    required this.atoms,
    required this.bonds,
    this.selectedAtomId,
    this.hoveredAtomId,
    this.previewLineEnd,
  });

  Atom? _atomById(String id) {
    try {
      return atoms.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  void _drawBond(Canvas canvas, Offset a, Offset b, BondType type, Paint paint) {
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
      ..color = const Color(0xFFCCCCCC)
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

    // Preview bond line (while dragging from selected atom)
    if (selectedAtomId != null && previewLineEnd != null) {
      final sel = _atomById(selectedAtomId!);
      if (sel != null) {
        final previewPaint = Paint()
          ..color = const Color(0xFF00C8FF).withOpacity(0.5)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(sel.position, previewLineEnd!, previewPaint);
      }
    }

    // Draw atoms
    for (final atom in atoms) {
      final isSelected = atom.id == selectedAtomId;
      final isHovered = atom.id == hoveredAtomId;
      const radius = 16.0;

      // Glow for selected
      if (isSelected) {
        final glowPaint = Paint()
          ..color = const Color(0xFF00C8FF).withOpacity(0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(atom.position, radius + 6, glowPaint);
      }

      // Background circle
      final bgPaint = Paint()
        ..color = isSelected
            ? const Color(0xFF002A35)
            : isHovered
                ? const Color(0xFF1E1E1E)
                : const Color(0xFF161616);
      canvas.drawCircle(atom.position, radius, bgPaint);

      // Border
      final borderPaint = Paint()
        ..color = isSelected
            ? const Color(0xFF00C8FF)
            : isHovered
                ? atom.color.withOpacity(0.9)
                : atom.color.withOpacity(0.6)
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
      tp.paint(
        canvas,
        atom.position - Offset(tp.width / 2, tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MoleculeCanvasPainter old) => true;
}
