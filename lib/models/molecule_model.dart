import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';

// ─── Atom ────────────────────────────────────────────────────────────────────

enum BondType { single, double, triple }

/// Max bonds each element can form (neutral, uncharged).
const Map<String, int> kMaxBonds = {
  'H': 1,
  'C': 4,
  'N': 3,
  'O': 2,
  'S': 2,
  'P': 3,
  'F': 1,
  'Cl': 1,
  'Br': 1,
  'I': 1,
};

class Atom {
  final String id;
  String symbol;
  Offset position;
  Color color;
  int charge; // formal charge

  Atom({
    required this.id,
    required this.symbol,
    required this.position,
    required this.color,
    this.charge = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'x': position.dx,
        'y': position.dy,
        'color': color.toARGB32(),
        'charge': charge,
      };

  factory Atom.fromJson(Map<String, dynamic> j) => Atom(
        id: j['id'] as String,
        symbol: j['symbol'] as String,
        position: Offset(
          (j['x'] as num).toDouble(),
          (j['y'] as num).toDouble(),
        ),
        color: Color(j['color'] as int),
        charge: (j['charge'] as int?) ?? 0,
      );
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromId': fromId,
        'toId': toId,
        'type': type.index,
      };

  factory Bond.fromJson(Map<String, dynamic> j) => Bond(
        id: j['id'] as String,
        fromId: j['fromId'] as String,
        toId: j['toId'] as String,
        type: BondType.values[j['type'] as int],
      );
}

// ─── Saved molecule ──────────────────────────────────────────────────────────

class SavedMolecule {
  final String name;
  final String timestamp;
  final List<Atom> atoms;
  final List<Bond> bonds;
  final int nextId;

  SavedMolecule({
    required this.name,
    required this.timestamp,
    required this.atoms,
    required this.bonds,
    required this.nextId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'timestamp': timestamp,
        'nextId': nextId,
        'atoms': atoms.map((a) => a.toJson()).toList(),
        'bonds': bonds.map((b) => b.toJson()).toList(),
      };

  factory SavedMolecule.fromJson(Map<String, dynamic> j) => SavedMolecule(
        name: j['name'] as String,
        timestamp: j['timestamp'] as String,
        nextId: (j['nextId'] as int?) ?? 0,
        atoms: (j['atoms'] as List).map((a) => Atom.fromJson(a)).toList(),
        bonds: (j['bonds'] as List).map((b) => Bond.fromJson(b)).toList(),
      );

  String encode() => jsonEncode(toJson());
  static SavedMolecule decode(String s) =>
      SavedMolecule.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

// ─── SMILES generator ────────────────────────────────────────────────────────

/// Generate a SMILES string from a molecule graph.
/// Uses a simple DFS walk. Handles rings, bond types, charges and brackets.
String generateSmiles(List<Atom> atoms, List<Bond> bonds) {
  if (atoms.isEmpty) return '';

  // Build adjacency list
  final Map<String, List<_Edge>> adj = {};
  for (final a in atoms) {
    adj[a.id] = [];
  }
  for (final b in bonds) {
    adj[b.fromId]?.add(_Edge(b.toId, b.type));
    adj[b.toId]?.add(_Edge(b.fromId, b.type));
  }

  final Map<String, Atom> atomMap = {for (final a in atoms) a.id: a};
  final Set<String> visited = {};
  final Map<String, int> ringOpenings = {};
  int ringCounter = 1;
  final buf = StringBuffer();

  // Atoms that need brackets: charged, or multi-char not in organic subset
  bool needsBrackets(Atom a) {
    if (a.charge != 0) return true;
    const organic = {'B', 'C', 'N', 'O', 'P', 'S', 'F', 'Cl', 'Br', 'I'};
    return !organic.contains(a.symbol);
  }

  String bondChar(BondType t) {
    switch (t) {
      case BondType.single:
        return '';
      case BondType.double:
        return '=';
      case BondType.triple:
        return '#';
    }
  }

  String chargeStr(int ch) {
    if (ch == 0) return '';
    if (ch == 1) return '+';
    if (ch == -1) return '-';
    if (ch > 0) return '+$ch';
    return '$ch';
  }

  String atomStr(Atom a) {
    if (needsBrackets(a)) {
      return '[${a.symbol}${chargeStr(a.charge)}]';
    }
    return a.symbol;
  }

  void dfs(String id, String? parentId) {
    visited.add(id);
    final atom = atomMap[id]!;
    buf.write(atomStr(atom));

    final edges = adj[id] ?? [];
    int branchCount = 0;

    for (final edge in edges) {
      if (edge.toId == parentId) continue;

      if (visited.contains(edge.toId)) {
        // Ring closure
        if (!ringOpenings.containsKey(edge.toId)) {
          ringOpenings[edge.toId] = ringCounter;
          buf.write('${bondChar(edge.type)}$ringCounter');
          ringCounter++;
        }
        continue;
      }

      // If this is not the first child, wrap in branch
      if (branchCount > 0) {
        buf.write('(');
      }
      buf.write(bondChar(edge.type));
      dfs(edge.toId, id);
      if (branchCount > 0) {
        buf.write(')');
      }
      branchCount++;
    }

    // Check if this atom had a ring-opening registered; if so, write closing
    if (ringOpenings.containsKey(id)) {
      // ring closure already written at the other end
    }
  }

  // Walk each connected component
  for (final atom in atoms) {
    if (!visited.contains(atom.id)) {
      if (buf.isNotEmpty) buf.write('.');
      dfs(atom.id, null);
    }
  }

  return buf.toString();
}

class _Edge {
  final String toId;
  final BondType type;
  _Edge(this.toId, this.type);
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

  final methylAtoms = [
    const FragmentAtom(
      localId: 'c0',
      symbol: 'C',
      relativeOffset: Offset(kBondLength, 0),
      color: Color(0xFF3A3A3A),
    ),
  ];

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
    const FragmentBond(
        fromLocalId: 'c0', toLocalId: 'o0', type: BondType.double),
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
