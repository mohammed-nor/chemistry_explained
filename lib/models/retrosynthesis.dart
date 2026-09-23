import 'dart:math';
import 'package:flutter/material.dart';
import 'molecule_model.dart';

class RetrosynthesisStep {
  final String reaction;
  final String description;
  final List<String> precursors;
  final List<String> reagents;
  final double confidence;
  final List<String> breakPoints;

  const RetrosynthesisStep({
    required this.reaction,
    required this.description,
    required this.precursors,
    required this.reagents,
    required this.confidence,
    required this.breakPoints,
  });
}

class RetrosynthesisAnalysis {
  final List<String> functionalGroups;
  final List<String> summary;
  final List<RetrosynthesisStep> steps;

  const RetrosynthesisAnalysis({
    required this.functionalGroups,
    required this.summary,
    required this.steps,
  });
}

class FunctionalGroupMarker {
  final String label;
  final Offset center;
  final double radius;

  const FunctionalGroupMarker({
    required this.label,
    required this.center,
    required this.radius,
  });
}

class RetrosynthesisDatabase {
  static const List<String> functionalGroupCatalog = [
    'alcohol',
    'ether',
    'aldehyde',
    'ketone',
    'carboxylic acid',
    'ester',
    'amide',
    'amine',
    'nitrile',
    'nitro',
    'thiol',
    'sulfide',
    'sulfoxide',
    'sulfone',
    'halide',
    'alkene',
    'alkyne',
    'arene',
    'epoxide',
    'anhydride',
    'acid chloride',
    'imine',
    'enamine',
    'oxime',
    'hydrazone',
    'azide',
    'diazo',
    'carbamate',
    'urea',
    'guanidine',
    'amidine',
    'isocyanate',
    'isothiocyanate',
    'phosphate',
    'phosphonate',
    'sulfonamide',
    'sulfonic acid',
    'acetal',
    'hemiacetal',
    'peroxide',
  ];

  static Color colorForFunctionalGroup(String functionalGroup) {
    switch (functionalGroup.trim().toLowerCase()) {
      case 'alcohol':
      case 'ether':
        return const Color(0xFFB388FF);
      case 'aldehyde':
      case 'ketone':
      case 'c=o':
        return const Color(0xFFFFC857);
      case 'carboxylic acid':
        return const Color(0xFFFFA726);
      case 'amide':
        return const Color(0xFF7CB8FF);
      case 'ester':
        return const Color(0xFF7AE582);
      case 'amine':
      case 'nh2':
        return const Color(0xFFFF9AA2);
      case 'nitrile':
        return const Color(0xFF8DD9FF);
      case 'nitro':
        return const Color(0xFF80CBC4);
      case 'thiol':
      case 'sulfide':
      case 'sulfoxide':
      case 'sulfone':
      case 'sulfonamide':
      case 'sulfonic acid':
        return const Color(0xFF66D9EF);
      case 'halide':
      case 'acid chloride':
        return const Color(0xFFDBA7FF);
      case 'alkene':
        return const Color(0xFFFFB74D);
      case 'alkyne':
        return const Color(0xFFFF8A65);
      case 'arene':
        return const Color(0xFFDCE775);
      case 'epoxide':
        return const Color(0xFF5C6BC0);
      case 'anhydride':
        return const Color(0xFF9CCC65);
      case 'imine':
      case 'enamine':
      case 'oxime':
      case 'hydrazone':
        return const Color(0xFFFFB300);
      case 'azide':
      case 'diazo':
        return const Color(0xFFB0BEC5);
      case 'carbamate':
      case 'urea':
      case 'guanidine':
      case 'amidine':
      case 'isocyanate':
      case 'isothiocyanate':
        return const Color(0xFF90CAF9);
      case 'phosphate':
      case 'phosphonate':
        return const Color(0xFFFFE082);
      case 'acetal':
      case 'hemiacetal':
        return const Color(0xFFB2FF59);
      case 'peroxide':
        return const Color(0xFFCFD8DC);
      case 'oh':
        return const Color(0xFFB388FF);
      default:
        return const Color(0xFF8DD9FF);
    }
  }

  static const Map<String, List<String>> reagentLibrary = {
    'alcohol': ['oxidant', 'alkylating reagent', 'reducing agent'],
    'ether': ['alkoxide', 'alkyl halide', 'base'],
    'aldehyde': [
      'hydride reagent',
      'organometallic reagent',
      'oxidation precursor',
    ],
    'ketone': ['organometallic reagent', 'hydride reagent', 'imine precursor'],
    'carboxylic acid': ['acid chloride', 'activated ester', 'nucleophile'],
    'ester': ['carboxylic acid', 'alcohol', 'acid or base'],
    'amide': ['acyl chloride or activated ester', 'amine', 'base'],
    'amine': ['amine precursor', 'electrophile', 'base'],
    'nitrile': ['organometallic reagent', 'cyanide source', 'reductant'],
    'nitro': ['reducing agent', 'hydrogen source', 'nucleophile'],
    'thiol': ['alkyl halide', 'base', 'thiol precursor'],
    'sulfide': ['thiol', 'alkyl halide', 'oxidant'],
    'sulfoxide': ['oxidant', 'sulfide precursor', 'reducing agent'],
    'sulfone': ['oxidant', 'sulfide precursor', 'base'],
    'halide': ['nucleophile', 'organometallic precursor', 'base'],
    'alkene': ['organometallic reagent', 'halide', 'hydrogenation catalyst'],
    'alkyne': ['alkyne precursor', 'base', 'halide'],
    'arene': ['electrophile', 'cross-coupling partner', 'directing group'],
    'epoxide': ['peroxide', 'base', 'nucleophile'],
    'anhydride': ['carboxylic acid', 'acid chloride', 'base'],
    'acid chloride': ['carboxylic acid', 'chlorinating reagent', 'base'],
    'imine': ['amine', 'carbonyl precursor', 'reducing agent'],
    'enamine': ['carbonyl precursor', 'amine', 'acid catalyst'],
    'oxime': ['amine', 'carbonyl precursor', 'oxidant'],
    'hydrazone': ['hydrazine', 'carbonyl precursor', 'acid catalyst'],
    'azide': ['organic halide', 'azide source', 'reducing agent'],
    'diazo': ['diazo transfer reagent', 'base', 'metal catalyst'],
    'carbamate': ['alcohol', 'isocyanate', 'base'],
    'urea': ['amine', 'isocyanate', 'base'],
    'guanidine': ['amine', 'cyanamide', 'base'],
    'amidine': ['nitrile', 'amine', 'base'],
    'isocyanate': ['amine', 'alcohol', 'base'],
    'isothiocyanate': ['amine', 'thiophosgene', 'base'],
    'phosphate': ['phosphorylating reagent', 'alcohol', 'base'],
    'phosphonate': ['phosphite', 'alkyl halide', 'base'],
    'sulfonamide': ['sulfonyl chloride', 'amine', 'base'],
    'sulfonic acid': ['sulfonyl chloride', 'nucleophile', 'water'],
    'acetal': ['carbonyl precursor', 'alcohol', 'acid catalyst'],
    'hemiacetal': ['carbonyl precursor', 'alcohol', 'acid catalyst'],
    'peroxide': ['oxygen source', 'radical initiator', 'base'],
    'carbonyl': ['carbonyl precursor', 'nucleophile', 'acid catalyst'],
    'hydrocarbon': [
      'alkyl halide',
      'organometallic reagent',
      'cross-coupling partner',
    ],
  };

  static const Map<String, List<String>> retrosynthesisRouteLibrary = {
    'alcohol': [
      'oxidation to carbonyl',
      'substitution to halide',
      'deprotection / reduction',
    ],
    'ether': [
      'Williamson ether synthesis',
      'acidic cleavage',
      'nucleophilic substitution',
    ],
    'aldehyde': [
      'Grignard addition',
      'Wittig olefination',
      'oxidation / reduction sequence',
    ],
    'ketone': [
      'Grignard addition',
      'Wittig olefination',
      'Weinreb amide cleavage',
    ],
    'carboxylic acid': [
      'acid chloride formation',
      'esterification / hydrolysis',
      'decarboxylation',
    ],
    'ester': [
      'hydrolysis to acid + alcohol',
      'transesterification',
      'Claisen / acyl substitution',
    ],
    'amide': [
      'acidic or basic hydrolysis',
      'acyl substitution',
      'Curtius or Schmidt rearrangement',
    ],
    'amine': [
      'Gabriel synthesis',
      'reductive amination',
      'Hofmann / SN2 alkylation',
    ],
    'nitrile': [
      'hydrolysis to acid',
      'reduction to amine',
      'cyanide addition / alkylation',
    ],
    'nitro': [
      'reduction to amine',
      'Nef reaction',
      'nucleophilic aromatic substitution',
    ],
    'thiol': [
      'alkylation to thioether',
      'oxidation to disulfide',
      'S_N2 substitution',
    ],
    'sulfide': [
      'oxidation to sulfoxide/sulfone',
      'thiol precursor disconnection',
      'alkylation strategy',
    ],
    'halide': [
      'SN2 displacement',
      'elimination to alkene',
      'organometallic coupling',
    ],
    'alkene': [
      'ozonolysis',
      'hydroboration-oxidation',
      'Diels-Alder / cross-metathesis',
    ],
    'alkyne': [
      'reduction to alkene',
      'hydroboration / hydration',
      'Sonogashira coupling',
    ],
    'epoxide': [
      'nucleophilic ring opening',
      'Sharpless epoxidation',
      'reductive opening',
    ],
    'arene': [
      'electrophilic aromatic substitution',
      'cross-coupling disconnection',
      'Birch reduction',
    ],
    'acid chloride': [
      'acyl substitution',
      'hydrolysis to acid',
      'Friedel-Crafts acylation',
    ],
    'imine': [
      'reductive amination',
      'hydrolysis to carbonyl + amine',
      'Mannich equivalent',
    ],
    'hydrocarbon': [
      'C-C bond disconnection',
      'functionalization of alkyl chain',
      'cross-coupling strategy',
    ],
  };

  static List<String> routeSuggestionsForGroup(String group) {
    final normalized = normalizeFunctionalGroupLabel(group);
    return retrosynthesisRouteLibrary[normalized] ?? const [];
  }

  static String normalizeFunctionalGroupLabel(String group) {
    final normalized = group.trim().toLowerCase();
    final aliases = <String, String>{
      'oh': 'alcohol',
      'nh2': 'amine',
      'c=o': 'ketone',
      'amide ': 'amide',
      'ester ': 'ester',
      'alcohol ': 'alcohol',
    };
    return aliases[normalized] ?? normalized;
  }
}

class RetrosynthesisEngine {
  static RetrosynthesisAnalysis analyze(List<Atom> atoms, List<Bond> bonds) {
    final functionalGroups = _detectFunctionalGroups(atoms, bonds);
    final steps = _buildSteps(functionalGroups);

    return RetrosynthesisAnalysis(
      functionalGroups: functionalGroups,
      summary: _buildSummary(functionalGroups),
      steps: steps,
    );
  }

  static List<String> detectFunctionalGroupsFromSmiles(String smiles) {
    final lower = smiles.toLowerCase();
    final matches = <String>{};

    final patternGroups = <String, List<String>>{
      'alcohol': ['[oh]', 'oh', 'c-o', 'coh', 'c(o)h'],
      'ether': ['coc', 'c-o-c', 'oc', 'c-o-c'],
      'aldehyde': ['c=o', 'cho', 'hc=o', 'o=ch'],
      'ketone': ['c(=o)c', 'cc(=o)', 'o=c(c)', 'c(=o)'],
      'carboxylic acid': ['c(=o)oh', 'oc(=o)', 'c(=o)o'],
      'ester': ['c(=o)oc', 'oc(=o)c', 'coo', 'c(o)'],
      'amide': ['c(=o)n', 'nc(=o)', 'n[c](=o)', 'n(c)'],
      'amine': ['n', 'nh2', 'nc', 'cn'],
      'nitrile': ['c#n', '#n'],
      'nitro': ['[n+](=o)[o-]', 'n(=o)=o', 'no2'],
      'thiol': ['sh', 's-h', 'csh'],
      'sulfide': ['cssc', 'cs', 'scc', 'csc'],
      'sulfoxide': ['s(=o)', 's(=o)s'],
      'sulfone': ['s(=o)(=o)', 's(=o)(=o)n', 's(=o)(=o)c'],
      'halide': ['cl', 'br', 'f', 'i'],
      'alkene': ['c=c', 'c=c', 'cc=c'],
      'alkyne': ['c#c', 'c#c', 'c#n'],
      'arene': ['c1ccccc1', 'c1ccccc1', 'c1ccccc1'],
      'epoxide': ['c1oc1', 'o1cc1'],
      'anhydride': ['c(=o)o(c=o)', 'o=c(o)c(=o)'],
      'acid chloride': ['c(=o)cl', 'clc(=o)'],
      'imine': ['c=n', 'n=c'],
      'enamine': ['c=c[n', 'nc=c'],
      'oxime': ['c=no', 'n=o'],
      'hydrazone': ['c=nn', 'nn=c'],
      'azide': ['n=n+=n', 'n3n'],
      'diazo': ['[n+]#n', 'n#n'],
      'carbamate': ['nc(=o)oc', 'oc(=o)nc'],
      'urea': ['nc(=o)nc', 'ncn'],
      'guanidine': ['nc(=n)n', 'n=c(n)n'],
      'amidine': ['nc(=n)', 'n=c(n)'],
      'isocyanate': ['n=c=o', 'o=c=n'],
      'isothiocyanate': ['n=c=s', 's=c=n'],
      'phosphate': ['p(=o)(o)(o)', 'op(=o)(o)'],
      'phosphonate': ['p(=o)(o)(c)', 'cp(=o)(o)'],
      'sulfonamide': ['s(=o)(=o)nc', 'ns(=o)(=o)'],
      'sulfonic acid': ['s(=o)(=o)oh', 'os(=o)(=o)'],
      'acetal': ['c(o)(o)c', 'oc(o)c'],
      'hemiacetal': ['c(o)oc', 'oc(o)c'],
      'peroxide': ['roor', 'oo', 'c-o-o-c'],
    };

    for (final entry in patternGroups.entries) {
      if (entry.value.any((pattern) => lower.contains(pattern))) {
        matches.add(entry.key);
      }
    }

    if (matches.isEmpty) {
      matches.add('hydrocarbon');
    }

    final catalogOrder = RetrosynthesisDatabase.functionalGroupCatalog;
    final ordered = matches.toList()
      ..sort((left, right) {
        final leftIndex = catalogOrder.indexOf(left);
        final rightIndex = catalogOrder.indexOf(right);
        if (leftIndex == -1 && rightIndex == -1) return left.compareTo(right);
        if (leftIndex == -1) return 1;
        if (rightIndex == -1) return -1;
        return leftIndex.compareTo(rightIndex);
      });
    return ordered;
  }

  static List<String> _detectFunctionalGroups(
    List<Atom> atoms,
    List<Bond> bonds,
  ) {
    final atomMap = {for (final atom in atoms) atom.id: atom};
    final neighbors = <String, List<String>>{
      for (final atom in atoms) atom.id: [],
    };

    for (final bond in bonds) {
      neighbors[bond.fromId]?.add(bond.toId);
      neighbors[bond.toId]?.add(bond.fromId);
    }

    bool hasBondBetween(String idA, String idB) {
      return bonds.any(
        (bond) =>
            ((bond.fromId == idA && bond.toId == idB) ||
            (bond.fromId == idB && bond.toId == idA)),
      );
    }

    Bond? bondBetween(String idA, String idB) {
      for (final bond in bonds) {
        if ((bond.fromId == idA && bond.toId == idB) ||
            (bond.fromId == idB && bond.toId == idA)) {
          return bond;
        }
      }
      return null;
    }

    bool isCarbon(String id) => atomMap[id]?.symbol == 'C';
    bool isOxygen(String id) => atomMap[id]?.symbol == 'O';
    bool isNitrogen(String id) => atomMap[id]?.symbol == 'N';
    bool isSulfur(String id) => atomMap[id]?.symbol == 'S';
    bool isHalogen(String id) =>
        ['F', 'Cl', 'Br', 'I'].contains(atomMap[id]?.symbol);
    bool isPhosphorus(String id) => atomMap[id]?.symbol == 'P';
    bool isCarbonyl(String id) {
      final connected = neighbors[id] ?? const [];
      return connected.any(
        (neighborId) =>
            isOxygen(neighborId) &&
            bondBetween(id, neighborId)?.type == BondType.double,
      );
    }

    final matches = <String>{};

    // Carbonyl and heteroatom motifs.
    for (final atom in atoms) {
      if (atom.symbol != 'C') continue;
      final carbonNeighbors = neighbors[atom.id] ?? const [];
      final carbonylOxygenIds = carbonNeighbors.where(
        (neighborId) =>
            isOxygen(neighborId) &&
            bondBetween(atom.id, neighborId)?.type == BondType.double,
      );

      if (carbonylOxygenIds.isEmpty) continue;

      final carbonNeighborsHeavy = carbonNeighbors.where(isCarbon).toList();
      final nitrogenNeighbors = carbonNeighbors.where(isNitrogen).toList();
      final oxygenNeighbors = carbonNeighbors.where(isOxygen).toList();
      final halogenNeighbors = carbonNeighbors.where(isHalogen).toList();
      final singleBondOxygenIds = oxygenNeighbors
          .where(
            (oxygenId) =>
                bondBetween(atom.id, oxygenId)?.type == BondType.single,
          )
          .toList();

      final adjacentEsterOxygen = carbonNeighborsHeavy.any(
        (carbonId) => (neighbors[carbonId] ?? const []).any(
          (neighborId) =>
              isOxygen(neighborId) &&
              bondBetween(carbonId, neighborId)?.type == BondType.single &&
              ((neighbors[neighborId] ?? const []).where(isCarbon).length >= 1),
        ),
      );

      if (nitrogenNeighbors.isNotEmpty) {
        matches.add('amide');
      } else if (halogenNeighbors.isNotEmpty) {
        matches.add('acid chloride');
      } else if (adjacentEsterOxygen) {
        matches.add('ester');
      } else if (singleBondOxygenIds.isNotEmpty) {
        matches.add('carboxylic acid');
      } else if (carbonNeighborsHeavy.length <= 1) {
        matches.add('aldehyde');
      } else {
        matches.add('ketone');
      }
    }

    // Simple alcohol / ether detection.
    for (final atom in atoms) {
      if (atom.symbol != 'O') continue;
      final connected = neighbors[atom.id] ?? const [];
      final carbonNeighbors = connected.where(isCarbon).toList();
      final oxygenNeighbors = connected.where(isOxygen).toList();

      if (carbonNeighbors.length == 1 && oxygenNeighbors.isEmpty) {
        matches.add('alcohol');
      }

      if (carbonNeighbors.length >= 2 && oxygenNeighbors.isEmpty) {
        matches.add('ether');
      }
    }

    // Nitrogen-containing motifs.
    for (final atom in atoms) {
      if (atom.symbol != 'N') continue;
      final connected = neighbors[atom.id] ?? const [];
      final carbonNeighbors = connected.where(isCarbon).toList();
      final oxygens = connected.where(isOxygen).toList();

      if (carbonNeighbors.isNotEmpty && !connected.any(isCarbonyl)) {
        matches.add('amine');
      }

      if (connected.any(isCarbon) && oxygens.isNotEmpty) {
        matches.add('carbamate');
      }

      if (connected.any(isCarbon) &&
          connected.any((id) => atomMap[id]?.symbol == 'N')) {
        matches.add('guanidine');
      }
    }

    // Double bonds and unsaturation patterns.
    if (bonds.any(
      (bond) =>
          bond.type == BondType.double &&
          isCarbon(bond.fromId) &&
          isCarbon(bond.toId),
    )) {
      matches.add('alkene');
    }

    if (bonds.any(
      (bond) =>
          bond.type == BondType.triple &&
          isCarbon(bond.fromId) &&
          isCarbon(bond.toId),
    )) {
      matches.add('alkyne');
    }

    for (final bond in bonds) {
      if (bond.type == BondType.triple &&
          isCarbon(bond.fromId) &&
          atomMap[bond.toId]?.symbol == 'N') {
        matches.add('nitrile');
      }
      if (bond.type == BondType.double &&
          isCarbon(bond.fromId) &&
          atomMap[bond.toId]?.symbol == 'N') {
        matches.add('imine');
      }
    }

    // Sulfur motifs.
    for (final atom in atoms) {
      if (atom.symbol != 'S') continue;
      final connected = neighbors[atom.id] ?? const [];
      final carbonNeighbors = connected.where(isCarbon).toList();
      final oxygenNeighbors = connected.where(isOxygen).toList();

      if (carbonNeighbors.length == 1 && oxygenNeighbors.isEmpty) {
        matches.add('thiol');
      }
      if (carbonNeighbors.length >= 2 && oxygenNeighbors.isEmpty) {
        matches.add('sulfide');
      }
      if (oxygenNeighbors.isNotEmpty && carbonNeighbors.isNotEmpty) {
        matches.add('sulfoxide');
      }
      if (oxygenNeighbors.length >= 2) {
        matches.add('sulfone');
      }
      if (connected.any(isNitrogen) && oxygenNeighbors.isNotEmpty) {
        matches.add('sulfonamide');
      }
      if (connected.any(isNitrogen) && atomMap[atom.id]?.symbol == 'S') {
        matches.add('isothiocyanate');
      }
    }

    // Halides and phosphates.
    for (final atom in atoms) {
      if (isHalogen(atom.id) &&
          (neighbors[atom.id] ?? const []).any(isCarbon)) {
        matches.add('halide');
      }
      if (isPhosphorus(atom.id)) {
        final connected = neighbors[atom.id] ?? const [];
        if (connected.where(isOxygen).length >= 2) {
          matches.add('phosphate');
        }
        if (connected.where(isCarbon).length >= 1) {
          matches.add('phosphonate');
        }
      }
    }

    // Ring and peroxide motifs.
    if (atoms.length >= 6 && atoms.any((atom) => atom.symbol == 'C')) {
      final carbonSet = atoms
          .where((atom) => atom.symbol == 'C')
          .map((atom) => atom.id)
          .toSet();
      final ringCandidates = <String>{};
      for (final carbonId in carbonSet) {
        final chain = <String>{carbonId};
        String? next = null;
        for (final neighbor in neighbors[carbonId] ?? const []) {
          if (carbonSet.contains(neighbor)) {
            next = neighbor;
            break;
          }
        }
        if (next != null) {
          chain.add(next);
        }
        if (chain.length >= 6) {
          ringCandidates.add(carbonId);
        }
      }
      if (ringCandidates.isNotEmpty) {
        matches.add('arene');
      }
    }

    if (bonds.any(
      (bond) =>
          atomMap[bond.fromId]?.symbol == 'O' &&
          atomMap[bond.toId]?.symbol == 'O' &&
          bond.type == BondType.single,
    )) {
      matches.add('peroxide');
    }

    if (matches.isEmpty) {
      matches.add('hydrocarbon');
    }

    final catalogOrder = RetrosynthesisDatabase.functionalGroupCatalog;
    final ordered = matches.toList()
      ..sort((left, right) {
        final leftIndex = catalogOrder.indexOf(left);
        final rightIndex = catalogOrder.indexOf(right);
        if (leftIndex == -1 && rightIndex == -1) return left.compareTo(right);
        if (leftIndex == -1) return 1;
        if (rightIndex == -1) return -1;
        return leftIndex.compareTo(rightIndex);
      });
    return ordered;
  }

  static List<FunctionalGroupMarker> detectGroupMarkers(
    List<Atom> atoms,
    List<Bond> bonds,
  ) {
    final atomMap = {for (final atom in atoms) atom.id: atom};
    final neighbors = <String, List<String>>{
      for (final atom in atoms) atom.id: [],
    };

    for (final bond in bonds) {
      neighbors[bond.fromId]?.add(bond.toId);
      neighbors[bond.toId]?.add(bond.fromId);
    }

    final markers = <FunctionalGroupMarker>[];
    final seen = <String>{};

    void addMarker(String key, String label, List<String> atomIds) {
      if (atomIds.isEmpty || seen.contains(key)) return;
      final positions = atomIds
          .map((id) => atomMap[id]?.position)
          .whereType<Offset>()
          .toList();
      if (positions.isEmpty) return;

      final center = Offset(
        positions.map((p) => p.dx).reduce((a, b) => a + b) / positions.length,
        positions.map((p) => p.dy).reduce((a, b) => a + b) / positions.length,
      );
      final radius = max(
        24.0,
        positions.fold<double>(0, (maxRadius, point) {
              final distance = (point - center).distance;
              return distance > maxRadius ? distance : maxRadius;
            }) +
            18.0,
      );

      markers.add(
        FunctionalGroupMarker(label: label, center: center, radius: radius),
      );
      seen.add(key);
    }

    for (final atom in atoms) {
      if (atom.symbol == 'O') {
        final connected = neighbors[atom.id] ?? const [];
        final carbonNeighbors = connected.where(
          (id) => atomMap[id]?.symbol == 'C',
        );
        final carbonylNeighbor = connected.any(
          (id) =>
              atomMap[id]?.symbol == 'C' &&
              bonds.any(
                (bond) =>
                    ((bond.fromId == id && bond.toId == atom.id) ||
                        (bond.fromId == atom.id && bond.toId == id)) &&
                    bond.type == BondType.double,
              ),
        );

        if (carbonNeighbors.isNotEmpty && !carbonylNeighbor) {
          addMarker('alcohol-${atom.id}', 'OH', [atom.id, ...carbonNeighbors]);
        }
      }

      if (atom.symbol == 'N') {
        final connected = neighbors[atom.id] ?? const [];
        final carbonNeighbors = connected.where(
          (id) => atomMap[id]?.symbol == 'C',
        );
        if (carbonNeighbors.isNotEmpty) {
          addMarker('amine-${atom.id}', 'NH2', [atom.id, ...carbonNeighbors]);
        }
      }
    }

    for (final atom in atoms) {
      if (atom.symbol != 'C') continue;
      final carbonNeighbors = neighbors[atom.id] ?? const [];
      final oxygenIds = carbonNeighbors.where(
        (id) => atomMap[id]?.symbol == 'O',
      );
      final nitrogenIds = carbonNeighbors.where(
        (id) => atomMap[id]?.symbol == 'N',
      );

      final hasCarbonyl = oxygenIds.any(
        (oxygenId) => bonds.any(
          (bond) =>
              ((bond.fromId == atom.id && bond.toId == oxygenId) ||
                  (bond.fromId == oxygenId && bond.toId == atom.id)) &&
              bond.type == BondType.double,
        ),
      );

      if (hasCarbonyl && nitrogenIds.isNotEmpty) {
        addMarker('amide-${atom.id}', 'Amide', [
          atom.id,
          ...oxygenIds,
          ...nitrogenIds,
        ]);
      }

      if (hasCarbonyl && oxygenIds.length > 1) {
        addMarker('ester-${atom.id}', 'Ester', [atom.id, ...oxygenIds]);
      }

      if (hasCarbonyl && oxygenIds.isNotEmpty && nitrogenIds.isEmpty) {
        addMarker('carbonyl-${atom.id}', 'C=O', [atom.id, ...oxygenIds]);
      }
    }

    return markers;
  }

  static List<String> _buildSummary(List<String> functionalGroups) {
    if (functionalGroups.isEmpty) {
      return ['No strong functional groups detected.'];
    }
    return ['Detected functional groups: ${functionalGroups.join(', ')}'];
  }

  static List<RetrosynthesisStep> _buildSteps(List<String> functionalGroups) {
    final steps = <RetrosynthesisStep>[];

    final carbonylScore = functionalGroups.contains('amide') ? 1.0 : 0.0;
    final esterScore = functionalGroups.contains('ester') ? 0.9 : 0.0;
    final alcoholScore = functionalGroups.contains('alcohol') ? 0.75 : 0.0;
    final hydrocarbonScore = functionalGroups.contains('hydrocarbon')
        ? 0.4
        : 0.0;

    if (functionalGroups.contains('amide')) {
      steps.add(
        const RetrosynthesisStep(
          reaction: 'amide bond disconnection',
          description:
              'Break the amide C–N bond to reveal an acyl component and an amine component.',
          precursors: ['carboxylic acid derivative', 'amine'],
          reagents: ['acyl chloride or activated ester', 'amine', 'base'],
          confidence: 0.92,
          breakPoints: ['C–N amide bond'],
        ),
      );
    }

    if (functionalGroups.contains('ester')) {
      steps.add(
        const RetrosynthesisStep(
          reaction: 'ester hydrolysis / acyl substitution',
          description:
              'Disconnect the ester to give a carboxylic acid and an alcohol precursor.',
          precursors: ['carboxylic acid', 'alcohol'],
          reagents: ['acid or base hydrolysis', 'alcohol', 'coupling reagent'],
          confidence: 0.88,
          breakPoints: ['ester C–O bond'],
        ),
      );
    }

    if (functionalGroups.contains('alcohol')) {
      steps.add(
        const RetrosynthesisStep(
          reaction: 'alcohol functionalization',
          description:
              'Consider oxidation or substitution at the alcohol-bearing carbon depending on the intended transformation.',
          precursors: ['primary/secondary alcohol precursor'],
          reagents: ['oxidant or alkylating reagent'],
          confidence: 0.72,
          breakPoints: ['C–O bond adjacent to alcohol'],
        ),
      );
    }

    if (functionalGroups.contains('carboxylic acid')) {
      steps.add(
        const RetrosynthesisStep(
          reaction: 'carboxylic acid activation',
          description:
              'Disconnect the acid to reveal a carbonyl precursor and a suitable nucleophile or acyl-transfer partner.',
          precursors: ['carboxylic acid precursor', 'nucleophile'],
          reagents: ['activating agent', 'coupling reagent', 'base'],
          confidence: 0.8,
          breakPoints: ['acyl C–O bond'],
        ),
      );
    }

    if (functionalGroups.contains('ketone')) {
      steps.add(
        const RetrosynthesisStep(
          reaction: 'ketone carbonyl disconnection',
          description:
              'Break the carbonyl bond to identify an organometallic nucleophile and an acyl precursor or electrophile.',
          precursors: ['organometallic reagent', 'carbonyl precursor'],
          reagents: ['Grignard or organolithium equivalent', 'acid workup'],
          confidence: 0.78,
          breakPoints: ['carbonyl C–C bond'],
        ),
      );
    }

    if (functionalGroups.contains('aldehyde')) {
      steps.add(
        const RetrosynthesisStep(
          reaction: 'aldehyde precursor disconnection',
          description:
              'Treat the aldehyde as an oxidized carbonyl and reconnect to a more accessible alcohol or organometallic precursor.',
          precursors: ['primary alcohol precursor', 'organometallic reagent'],
          reagents: [
            'oxidation or reduction sequence',
            'appropriate carbonyl equivalent',
          ],
          confidence: 0.74,
          breakPoints: ['aldehyde C–H / C–C bond'],
        ),
      );
    }

    if (functionalGroups.contains('nitrile')) {
      steps.add(
        const RetrosynthesisStep(
          reaction: 'nitrile hydrolysis / reduction',
          description:
              'Disconnect the nitrile to a carbon source and a cyanide equivalent or reduce to an amine precursor.',
          precursors: ['cyanide equivalent', 'carbon fragment'],
          reagents: ['cyanide source', 'hydrolysis or reduction reagent'],
          confidence: 0.7,
          breakPoints: ['C≡N bond'],
        ),
      );
    }

    if (functionalGroups.contains('alkene')) {
      steps.add(
        const RetrosynthesisStep(
          reaction: 'alkene cleavage / functionalization',
          description:
              'Use the alkene as a handle for oxidative cleavage or conjugate-addition disconnection to reveal simpler carbon fragments.',
          precursors: ['alkene precursor', 'electrophile or oxidant'],
          reagents: ['oxidant', 'nucleophile', 'metal catalyst'],
          confidence: 0.68,
          breakPoints: ['C=C bond'],
        ),
      );
    }

    if (steps.isEmpty) {
      steps.add(
        RetrosynthesisStep(
          reaction: 'fragment-based disconnection',
          description:
              'No strong functional-group trigger was found; treat the molecule as a hydrocarbon scaffold and seek a suitable bond break near the most substituted region.',
          precursors: ['simple precursor fragments'],
          reagents: ['standard synthetic equivalent'],
          confidence:
              max(
                max(carbonylScore, esterScore),
                max(alcoholScore, hydrocarbonScore),
              ) *
              0.7,
          breakPoints: ['least substituted C–C bond'],
        ),
      );
    }

    final routeDatabaseEntries = <RetrosynthesisStep>[];
    for (final group in functionalGroups) {
      final isHandled =
          group == 'amide' ||
          group == 'ester' ||
          group == 'alcohol' ||
          group == 'carboxylic acid' ||
          group == 'ketone' ||
          group == 'aldehyde' ||
          group == 'nitrile' ||
          group == 'alkene';
      if (isHandled) continue;

      final routes = RetrosynthesisDatabase.routeSuggestionsForGroup(group);
      if (routes.isEmpty) continue;

      final routeName = routes.first;
      routeDatabaseEntries.add(
        RetrosynthesisStep(
          reaction: '${group} disconnection via $routeName',
          description:
              'Database-backed retrosynthesis route: disconnect the ${group} handle using the $routeName strategy and reconnect to an appropriate precursor set.',
          precursors: ['${group} precursor', 'synthetic equivalent'],
          reagents:
              RetrosynthesisDatabase.reagentLibrary[group] ??
              const ['standard precursor equivalent'],
          confidence: 0.65,
          breakPoints: ['${group} functional handle'],
        ),
      );
    }

    steps.addAll(routeDatabaseEntries);

    if (steps.length < 2 && functionalGroups.length > 1) {
      steps.add(
        const RetrosynthesisStep(
          reaction: 'secondary disconnection',
          description:
              'A second, lower-confidence route is available by disconnecting the next most reactive handle in the molecule and considering a complementary precursor set.',
          precursors: ['secondary precursor set'],
          reagents: ['standard catalytic or stoichiometric equivalent'],
          confidence: 0.62,
          breakPoints: ['secondary functional handle'],
        ),
      );
    }

    final ranked = steps.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    return ranked;
  }
}
