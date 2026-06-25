import 'dart:math';
import 'package:flutter/material.dart';

// ─── Atom ────────────────────────────────────────────────────────────────────

enum BondType { single, double, triple }

class Atom {
  final String id;
  String symbol;
  Offset position;
  Color color;

  Atom({
    required this.id,
    required this.symbol,
    required this.position,
    required this.color,
  });
}

// ─── Bond ────────────────────────────────────────────────────────────────────

class Bond {
  final String id;
  final String fromId;
  final String toId;
  BondType type;

  Bond({
    required this.id,
    required this.fromId,
    required this.toId,
    this.type = BondType.single,
  });
}

// ─── Fragment (preset group of atoms + bonds) ────────────────────────────────

class FragmentAtom {
  final String localId;
  final String symbol;
  final Offset relativeOffset; // relative to anchor atom
  final Color color;

  const FragmentAtom({
    required this.localId,
    required this.symbol,
    required this.relativeOffset,
    required this.color,
  });
}

class FragmentBond {
  final String fromLocalId;
  final String toLocalId;
  final BondType type;

  const FragmentBond({
    required this.fromLocalId,
    required this.toLocalId,
    this.type = BondType.single,
  });
}

class MoleculeFragment {
  final String name;
  final String displayLabel;
  final List<FragmentAtom> atoms;
  final List<FragmentBond> bonds;
  // which localId is the anchor (attaches to clicked atom)
  final String anchorLocalId;

  const MoleculeFragment({
    required this.name,
    required this.displayLabel,
    required this.atoms,
    required this.bonds,
    required this.anchorLocalId,
  });
}

// ─── Palette data ────────────────────────────────────────────────────────────

class AtomEntry {
  final String symbol;
  final Color color;
  const AtomEntry(this.symbol, this.color);
}

const List<AtomEntry> kAtomPalette = [
  AtomEntry('C', Color(0xFF3A3A3A)),
  AtomEntry('H', Color(0xFF888888)),
  AtomEntry('O', Color(0xFFE53935)),
  AtomEntry('N', Color(0xFF1565C0)),
  AtomEntry('S', Color(0xFFF9A825)),
  AtomEntry('P', Color(0xFFAD1457)),
  AtomEntry('F', Color(0xFF00897B)),
  AtomEntry('Cl', Color(0xFF2E7D32)),
  AtomEntry('Br', Color(0xFF6D4C41)),
  AtomEntry('I', Color(0xFF4527A0)),
];

const double kBondLength = 60.0;

List<MoleculeFragment> buildFragments() {
  // Benzene ring (6-membered)
  const double r = 40.0;
  final benzeneAtoms = List.generate(6, (i) {
    final angle = pi / 2 + i * (2 * pi / 6);
    return FragmentAtom(
      localId: 'c$i',
      symbol: 'C',
      relativeOffset: Offset(r * cos(angle), -r * sin(angle)),
      color: const Color(0xFF3A3A3A),
    );
  });
  final benzeneBonds = [
    for (int i = 0; i < 6; i++)
      FragmentBond(
        fromLocalId: 'c$i',
        toLocalId: 'c${(i + 1) % 6}',
        type: i.isEven ? BondType.double : BondType.single,
      ),
  ];

  // Methyl –CH₃ (single C attached)
  final methylAtoms = [
    const FragmentAtom(
      localId: 'c0',
      symbol: 'C',
      relativeOffset: Offset(kBondLength, 0),
      color: Color(0xFF3A3A3A),
    ),
  ];

  // Hydroxyl –OH
  final hydroxylAtoms = [
    const FragmentAtom(
      localId: 'o0',
      symbol: 'O',
      relativeOffset: Offset(kBondLength, 0),
      color: Color(0xFFE53935),
    ),
    const FragmentAtom(
      localId: 'h0',
      symbol: 'H',
      relativeOffset: Offset(kBondLength * 1.8, 0),
      color: Color(0xFF888888),
    ),
  ];
  final hydroxylBonds = [
    const FragmentBond(fromLocalId: 'o0', toLocalId: 'h0'),
  ];

  // Amino –NH₂
  final aminoAtoms = [
    const FragmentAtom(
      localId: 'n0',
      symbol: 'N',
      relativeOffset: Offset(kBondLength, 0),
      color: Color(0xFF1565C0),
    ),
    const FragmentAtom(
      localId: 'h0',
      symbol: 'H',
      relativeOffset: Offset(kBondLength * 1.6, -kBondLength * 0.6),
      color: Color(0xFF888888),
    ),
    const FragmentAtom(
      localId: 'h1',
      symbol: 'H',
      relativeOffset: Offset(kBondLength * 1.6, kBondLength * 0.6),
      color: Color(0xFF888888),
    ),
  ];
  final aminoBonds = [
    const FragmentBond(fromLocalId: 'n0', toLocalId: 'h0'),
    const FragmentBond(fromLocalId: 'n0', toLocalId: 'h1'),
  ];

  // Carboxyl –COOH
  final carboxylAtoms = [
    const FragmentAtom(
      localId: 'c0',
      symbol: 'C',
      relativeOffset: Offset(kBondLength, 0),
      color: Color(0xFF3A3A3A),
    ),
    const FragmentAtom(
      localId: 'o0',
      symbol: 'O',
      relativeOffset: Offset(kBondLength * 1.8, -kBondLength * 0.7),
      color: Color(0xFFE53935),
    ),
    const FragmentAtom(
      localId: 'o1',
      symbol: 'O',
      relativeOffset: Offset(kBondLength * 1.8, kBondLength * 0.7),
      color: Color(0xFFE53935),
    ),
    const FragmentAtom(
      localId: 'h0',
      symbol: 'H',
      relativeOffset: Offset(kBondLength * 2.5, kBondLength * 0.7),
      color: Color(0xFF888888),
    ),
  ];
  final carboxylBonds = [
    const FragmentBond(fromLocalId: 'c0', toLocalId: 'o0', type: BondType.double),
    const FragmentBond(fromLocalId: 'c0', toLocalId: 'o1'),
    const FragmentBond(fromLocalId: 'o1', toLocalId: 'h0'),
  ];

  return [
    MoleculeFragment(
      name: 'Benzene',
      displayLabel: 'Ph',
      atoms: benzeneAtoms,
      bonds: benzeneBonds,
      anchorLocalId: 'c0',
    ),
    MoleculeFragment(
      name: 'Methyl',
      displayLabel: 'CH₃',
      atoms: methylAtoms,
      bonds: const [],
      anchorLocalId: 'c0',
    ),
    MoleculeFragment(
      name: 'Hydroxyl',
      displayLabel: 'OH',
      atoms: hydroxylAtoms,
      bonds: hydroxylBonds,
      anchorLocalId: 'o0',
    ),
    MoleculeFragment(
      name: 'Amino',
      displayLabel: 'NH₂',
      atoms: aminoAtoms,
      bonds: aminoBonds,
      anchorLocalId: 'n0',
    ),
    MoleculeFragment(
      name: 'Carboxyl',
      displayLabel: 'COOH',
      atoms: carboxylAtoms,
      bonds: carboxylBonds,
      anchorLocalId: 'c0',
    ),
  ];
}
