import 'package:chemistry_explained/models/molecule_model.dart';
import 'package:chemistry_explained/models/retrosynthesis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects a simple amide and proposes a retrosynthetic step', () {
    final atoms = [
      Atom(
        id: 'a0',
        symbol: 'C',
        position: const Offset(0, 0),
        color: Colors.white,
      ),
      Atom(
        id: 'a1',
        symbol: 'O',
        position: const Offset(1, 0),
        color: Colors.red,
      ),
      Atom(
        id: 'a2',
        symbol: 'N',
        position: const Offset(0, 1),
        color: Colors.blue,
      ),
      Atom(
        id: 'a3',
        symbol: 'C',
        position: const Offset(0, 2),
        color: Colors.white,
      ),
    ];

    final bonds = [
      Bond(id: 'b0', fromId: 'a0', toId: 'a1', type: BondType.double),
      Bond(id: 'b1', fromId: 'a0', toId: 'a2', type: BondType.single),
      Bond(id: 'b2', fromId: 'a2', toId: 'a3', type: BondType.single),
    ];

    final analysis = RetrosynthesisEngine.analyze(atoms, bonds);

    expect(analysis.functionalGroups, contains('amide'));
    expect(analysis.steps, isNotEmpty);
    expect(analysis.steps.first.reaction, contains('amide'));
    expect(analysis.steps.first.precursors, isNotEmpty);
  });

  test('detects alcohol and ester chemistry in valid graphs', () {
    final alcoholAtoms = [
      Atom(
        id: 'a0',
        symbol: 'C',
        position: const Offset(0, 0),
        color: Colors.white,
      ),
      Atom(
        id: 'a1',
        symbol: 'O',
        position: const Offset(1, 0),
        color: Colors.red,
      ),
    ];

    final alcoholBonds = [
      Bond(id: 'b0', fromId: 'a0', toId: 'a1', type: BondType.single),
    ];

    final alcoholAnalysis = RetrosynthesisEngine.analyze(
      alcoholAtoms,
      alcoholBonds,
    );

    expect(alcoholAnalysis.functionalGroups, contains('alcohol'));
    expect(alcoholAnalysis.steps, isNotEmpty);

    final esterAtoms = [
      Atom(
        id: 'e0',
        symbol: 'C',
        position: const Offset(0, 0),
        color: Colors.white,
      ),
      Atom(
        id: 'e1',
        symbol: 'O',
        position: const Offset(1, 0),
        color: Colors.red,
      ),
      Atom(
        id: 'e2',
        symbol: 'C',
        position: const Offset(2, 0),
        color: Colors.white,
      ),
      Atom(
        id: 'e3',
        symbol: 'O',
        position: const Offset(3, 0),
        color: Colors.red,
      ),
      Atom(
        id: 'e4',
        symbol: 'C',
        position: const Offset(4, 0),
        color: Colors.white,
      ),
    ];

    final esterBonds = [
      Bond(id: 'eb0', fromId: 'e0', toId: 'e1', type: BondType.double),
      Bond(id: 'eb1', fromId: 'e0', toId: 'e2', type: BondType.single),
      Bond(id: 'eb2', fromId: 'e2', toId: 'e3', type: BondType.single),
      Bond(id: 'eb3', fromId: 'e3', toId: 'e4', type: BondType.single),
    ];

    final esterAnalysis = RetrosynthesisEngine.analyze(esterAtoms, esterBonds);

    expect(esterAnalysis.functionalGroups, contains('ester'));
  });

  test('creates functional-group markers for detected groups', () {
    final atoms = [
      Atom(
        id: 'a0',
        symbol: 'C',
        position: const Offset(0, 0),
        color: Colors.white,
      ),
      Atom(
        id: 'a1',
        symbol: 'O',
        position: const Offset(1, 0),
        color: Colors.red,
      ),
      Atom(
        id: 'a2',
        symbol: 'N',
        position: const Offset(0, 1),
        color: Colors.blue,
      ),
      Atom(
        id: 'a3',
        symbol: 'C',
        position: const Offset(0, 2),
        color: Colors.white,
      ),
    ];

    final bonds = [
      Bond(id: 'b0', fromId: 'a0', toId: 'a1', type: BondType.double),
      Bond(id: 'b1', fromId: 'a0', toId: 'a2', type: BondType.single),
      Bond(id: 'b2', fromId: 'a2', toId: 'a3', type: BondType.single),
    ];

    final markers = RetrosynthesisEngine.detectGroupMarkers(atoms, bonds);

    expect(markers, isNotEmpty);
    expect(
      markers.any((marker) => marker.label.toLowerCase() == 'amide'),
      isTrue,
    );
    expect(markers.first.center, isA<Offset>());
  });

  test(
    'detects a simple ketone from a carbonyl carbon bound to two carbons',
    () {
      final atoms = [
        Atom(
          id: 'a0',
          symbol: 'C',
          position: const Offset(0, 0),
          color: Colors.white,
        ),
        Atom(
          id: 'a1',
          symbol: 'O',
          position: const Offset(1, 0),
          color: Colors.red,
        ),
        Atom(
          id: 'a2',
          symbol: 'C',
          position: const Offset(2, 0),
          color: Colors.white,
        ),
        Atom(
          id: 'a3',
          symbol: 'C',
          position: const Offset(3, 0),
          color: Colors.white,
        ),
      ];

      final bonds = [
        Bond(id: 'b0', fromId: 'a0', toId: 'a1', type: BondType.double),
        Bond(id: 'b1', fromId: 'a0', toId: 'a2', type: BondType.single),
        Bond(id: 'b2', fromId: 'a0', toId: 'a3', type: BondType.single),
      ];

      final analysis = RetrosynthesisEngine.analyze(atoms, bonds);

      expect(analysis.functionalGroups, contains('ketone'));
    },
  );

  test('only reports functional groups that are actually present', () {
    final atoms = [
      Atom(
        id: 'a0',
        symbol: 'C',
        position: const Offset(0, 0),
        color: Colors.white,
      ),
      Atom(
        id: 'a1',
        symbol: 'C',
        position: const Offset(1.5, 0),
        color: Colors.white,
      ),
      Atom(
        id: 'a2',
        symbol: 'C',
        position: const Offset(3, 0),
        color: Colors.white,
      ),
    ];

    final bonds = [
      Bond(id: 'b0', fromId: 'a0', toId: 'a1', type: BondType.single),
      Bond(id: 'b1', fromId: 'a1', toId: 'a2', type: BondType.single),
    ];

    final analysis = RetrosynthesisEngine.analyze(atoms, bonds);

    expect(analysis.functionalGroups, contains('hydrocarbon'));
    expect(analysis.functionalGroups, isNot(contains('alcohol')));
    expect(analysis.functionalGroups, isNot(contains('ether')));
    expect(analysis.functionalGroups, isNot(contains('amide')));
    expect(analysis.functionalGroups, isNot(contains('ester')));
  });

  test('defines a full 40-group functional-group catalog', () {
    expect(
      RetrosynthesisDatabase.functionalGroupCatalog.length,
      greaterThanOrEqualTo(40),
    );
    expect(
      RetrosynthesisDatabase.functionalGroupCatalog,
      containsAll([
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
      ]),
    );
  });

  test('uses a distinct color for carboxylic acid', () {
    expect(
      RetrosynthesisDatabase.colorForFunctionalGroup('carboxylic acid'),
      isNot(RetrosynthesisDatabase.colorForFunctionalGroup('amide')),
    );
  });

  test('builds multiple route suggestions from multiple functional groups', () {
    final atoms = [
      Atom(
        id: 'a0',
        symbol: 'C',
        position: const Offset(0, 0),
        color: Colors.white,
      ),
      Atom(
        id: 'a1',
        symbol: 'O',
        position: const Offset(1, 0),
        color: Colors.red,
      ),
      Atom(
        id: 'a2',
        symbol: 'C',
        position: const Offset(2, 0),
        color: Colors.white,
      ),
      Atom(
        id: 'a3',
        symbol: 'C',
        position: const Offset(3, 0),
        color: Colors.white,
      ),
      Atom(
        id: 'a4',
        symbol: 'C',
        position: const Offset(4, 0),
        color: Colors.white,
      ),
      Atom(
        id: 'a5',
        symbol: 'O',
        position: const Offset(5, 0),
        color: Colors.red,
      ),
    ];

    final bonds = [
      Bond(id: 'b0', fromId: 'a0', toId: 'a1', type: BondType.double),
      Bond(id: 'b1', fromId: 'a0', toId: 'a2', type: BondType.single),
      Bond(id: 'b2', fromId: 'a0', toId: 'a3', type: BondType.single),
      Bond(id: 'b3', fromId: 'a3', toId: 'a4', type: BondType.single),
      Bond(id: 'b4', fromId: 'a4', toId: 'a5', type: BondType.single),
    ];

    final analysis = RetrosynthesisEngine.analyze(atoms, bonds);

    expect(analysis.functionalGroups, contains('ketone'));
    expect(analysis.functionalGroups, contains('alcohol'));
    expect(analysis.steps.length, greaterThanOrEqualTo(2));
  });
}
