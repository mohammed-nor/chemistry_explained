import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/molecule_model.dart';
import '../models/retrosynthesis.dart';
import '../painters/canvas_painter.dart';

// ─── History snapshot ────────────────────────────────────────────────────────

class _Snapshot {
  final List<Atom> atoms;
  final List<Bond> bonds;
  final int nextId;

  _Snapshot({required this.atoms, required this.bonds, required this.nextId});

  factory _Snapshot.capture(List<Atom> atoms, List<Bond> bonds, int nextId) {
    return _Snapshot(
      atoms: atoms
          .map(
            (a) => Atom(
              id: a.id,
              symbol: a.symbol,
              position: a.position,
              color: a.color,
              charge: a.charge,
            ),
          )
          .toList(),
      bonds: bonds
          .map(
            (b) => Bond(id: b.id, fromId: b.fromId, toId: b.toId, type: b.type),
          )
          .toList(),
      nextId: nextId,
    );
  }
}

// ─── Molecule Editor Screen ──────────────────────────────────────────────────

class MoleculeEditorScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<bool>? onThemeChanged;

  const MoleculeEditorScreen({
    super.key,
    this.themeMode = ThemeMode.dark,
    this.onThemeChanged,
  });

  @override
  State<MoleculeEditorScreen> createState() => _MoleculeEditorScreenState();
}

class _MoleculeEditorScreenState extends State<MoleculeEditorScreen>
    with TickerProviderStateMixin {
  bool get _isDarkTheme => widget.themeMode == ThemeMode.dark;

  Color get _appBackground =>
      _isDarkTheme ? const Color(0xFF0E0E0E) : const Color(0xFFF3F5F8);
  Color get _panelBackground =>
      _isDarkTheme ? const Color(0xFF111111) : const Color(0xFFE9EEF5);
  Color get _panelBorder =>
      _isDarkTheme ? const Color(0xFF1E1E1E) : const Color(0xFFD5DCE7);
  Color get _canvasBackground =>
      _isDarkTheme ? const Color(0xFF0D0D0D) : const Color(0xFFF2F4F7);
  Color get _mutedText =>
      _isDarkTheme ? const Color(0xFF555555) : const Color(0xFF5D6978);

  // ── Molecule state ─────────────────────────────────────────────────────────
  final List<Atom> _atoms = [];
  final List<Bond> _bonds = [];
  int _nextId = 0;

  // ── Undo / Redo ────────────────────────────────────────────────────────────
  final List<_Snapshot> _undoStack = [];
  final List<_Snapshot> _redoStack = [];
  static const int _maxHistory = 50;

  // ── Interaction ────────────────────────────────────────────────────────────
  String? _selectedAtomId;
  String? _hoveredAtomId;
  Offset? _previewEnd;
  bool _isDraggingAtom = false;
  String? _draggingAtomId;
  Offset _dragStart = Offset.zero;
  _Snapshot? _preDragSnapshot;
  Size _canvasSize = const Size(800, 600);

  // ── Tool mode ──────────────────────────────────────────────────────────────
  String _mode = 'draw';
  BondType _bondType = BondType.single;

  // ── Palette ────────────────────────────────────────────────────────────────
  String _selectedAtomSymbol = 'C';
  Color _selectedAtomColor = const Color(0xFF3A3A3A);
  MoleculeFragment? _selectedFragment;
  final List<MoleculeFragment> _fragments = buildFragments();

  // ── Saved molecules ────────────────────────────────────────────────────────
  List<SavedMolecule> _savedMolecules = [];
  bool _showSavedPanel = false;

  // ── Retrosynthesis panel ───────────────────────────────────────────────────
  bool _retrosynthesisExpanded = false;
  bool _showFunctionalGroups = true;
  RetrosynthesisAnalysis? _retrosynthesisAnalysis;

  @override
  void initState() {
    super.initState();
    _loadSavedList();
    _ensureDefaultDemoMolecule();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSISTENCE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _ensureDefaultDemoMolecule() async {
    try {
      final dir = await _saveDir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.moldraw.json'))
          .toList();

      if (files.isNotEmpty) return;

      final demo = SavedMolecule.paracetamolDemo();
      final file = File(
        '${dir.path}/Paracetamol_${DateTime.now().millisecondsSinceEpoch}.moldraw.json',
      );
      await file.writeAsString(demo.encode());
      await _loadSavedList();
      if (!mounted) return;
      _loadMolecule(demo);
    } catch (_) {}
  }

  Future<Directory> _saveDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/MolDraw');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _loadSavedList() async {
    try {
      final dir = await _saveDir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.moldraw.json'))
          .toList();
      files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
      final list = <SavedMolecule>[];
      for (final f in files) {
        try {
          list.add(SavedMolecule.decode(await f.readAsString()));
        } catch (_) {}
      }
      setState(() => _savedMolecules = list);
    } catch (_) {}
  }

  Future<void> _saveMolecule(String name) async {
    final mol = SavedMolecule(
      name: name,
      timestamp: DateTime.now().toIso8601String(),
      atoms: _atoms
          .map(
            (a) => Atom(
              id: a.id,
              symbol: a.symbol,
              position: a.position,
              color: a.color,
              charge: a.charge,
            ),
          )
          .toList(),
      bonds: _bonds
          .map(
            (b) => Bond(id: b.id, fromId: b.fromId, toId: b.toId, type: b.type),
          )
          .toList(),
      nextId: _nextId,
    );
    final dir = await _saveDir();
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '');
    final file = File(
      '${dir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.moldraw.json',
    );
    await file.writeAsString(mol.encode());
    await _loadSavedList();
  }

  Future<void> _deleteSaved(SavedMolecule mol) async {
    final dir = await _saveDir();
    final files = dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.moldraw.json'),
    );
    for (final f in files) {
      try {
        final decoded = SavedMolecule.decode(await f.readAsString());
        if (decoded.timestamp == mol.timestamp && decoded.name == mol.name) {
          await f.delete();
          break;
        }
      } catch (_) {}
    }
    await _loadSavedList();
  }

  void _loadMolecule(SavedMolecule mol) {
    _pushUndo();
    setState(() {
      _atoms
        ..clear()
        ..addAll(
          mol.atoms.map(
            (a) => Atom(
              id: a.id,
              symbol: a.symbol,
              position: a.position,
              color: a.color,
              charge: a.charge,
            ),
          ),
        );
      _bonds
        ..clear()
        ..addAll(
          mol.bonds.map(
            (b) => Bond(id: b.id, fromId: b.fromId, toId: b.toId, type: b.type),
          ),
        );
      _nextId = mol.nextId;
      _selectedAtomId = null;
      _previewEnd = null;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SMILES EXPORT
  // ═══════════════════════════════════════════════════════════════════════════

  void _exportSmiles() {
    final smiles = generateSmiles(_atoms, _bonds);
    final isDark = _isDarkTheme;
    final dialogBg = isDark ? const Color(0xFF161616) : const Color(0xFFFFFFFF);
    final borderColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFD7DDE7);
    final fieldBg = isDark ? const Color(0xFF0E0E0E) : const Color(0xFFF2F4F7);
    final sectionText = isDark
        ? const Color(0xFF999999)
        : const Color(0xFF5F6F86);
    final bodyText = isDark ? const Color(0xFFEEEEEE) : const Color(0xFF1F2937);
    final emptyText = isDark
        ? const Color(0xFF444444)
        : const Color(0xFF7A8699);
    final accent = const Color(0xFF00C8FF);
    final subtleText = isDark
        ? const Color(0xFF666666)
        : const Color(0xFF475569);
    final snackBarBg = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFF111827);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SMILES',
                style: TextStyle(
                  color: sectionText,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: fieldBg,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  smiles.isEmpty ? '(empty molecule)' : smiles,
                  style: TextStyle(
                    color: smiles.isEmpty ? emptyText : accent,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: smiles));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('SMILES copied to clipboard'),
                          backgroundColor: snackBarBg,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Text('Copy', style: TextStyle(color: accent)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Close', style: TextStyle(color: subtleText)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _retrosynthesisInfoRow(String label, String value) {
    return RichText(
      text: TextSpan(
        text: '$label: ',
        style: const TextStyle(
          color: Color(0xFF9E9E9E),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SAVE DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  void _showSaveDialog() {
    final controller = TextEditingController();
    final isDark = _isDarkTheme;
    final dialogBg = isDark ? const Color(0xFF161616) : const Color(0xFFFFFFFF);
    final borderColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFD7DDE7);
    final fieldBg = isDark ? const Color(0xFF0E0E0E) : const Color(0xFFF2F4F7);
    final sectionText = isDark
        ? const Color(0xFF999999)
        : const Color(0xFF5F6F86);
    final inputText = isDark
        ? const Color(0xFFEEEEEE)
        : const Color(0xFF1F2937);
    final hintText = isDark ? const Color(0xFF444444) : const Color(0xFF7A8699);
    final secondaryText = isDark
        ? const Color(0xFF666666)
        : const Color(0xFF475569);
    final accent = const Color(0xFF00C8FF);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SAVE MOLECULE',
                style: TextStyle(
                  color: sectionText,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: inputText, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Molecule name…',
                  hintStyle: TextStyle(color: hintText),
                  filled: true,
                  fillColor: fieldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF00C8FF)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    _saveMolecule(v.trim());
                    Navigator.pop(ctx);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: secondaryText),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      final name = controller.text.trim();
                      if (name.isNotEmpty) {
                        _saveMolecule(name);
                        Navigator.pop(ctx);
                      }
                    },
                    child: Text('Save', style: TextStyle(color: accent)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HISTORY
  // ═══════════════════════════════════════════════════════════════════════════

  void _pushUndo() {
    _undoStack.add(_Snapshot.capture(_atoms, _bonds, _nextId));
    if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_Snapshot.capture(_atoms, _bonds, _nextId));
    _applySnapshot(_undoStack.removeLast());
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_Snapshot.capture(_atoms, _bonds, _nextId));
    _applySnapshot(_redoStack.removeLast());
  }

  void _applySnapshot(_Snapshot s) {
    setState(() {
      _atoms
        ..clear()
        ..addAll(s.atoms);
      _bonds
        ..clear()
        ..addAll(s.bonds);
      _nextId = s.nextId;
      _selectedAtomId = null;
      _previewEnd = null;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHARGE
  // ═══════════════════════════════════════════════════════════════════════════

  void _changeCharge(int delta) {
    if (_selectedAtomId == null) return;
    _pushUndo();
    setState(() {
      final atom = _atoms.firstWhere((a) => a.id == _selectedAtomId);
      atom.charge += delta;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _newId() => 'a${_nextId++}';
  String _newBondId() => 'b${_nextId++}';

  Atom? _atomAt(Offset pos, {double radius = 20.0}) {
    for (final a in _atoms.reversed) {
      if ((a.position - pos).distance <= radius) return a;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MUTATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  void _addAtom(Offset pos) {
    _pushUndo();
    setState(() {
      _atoms.add(
        Atom(
          id: _newId(),
          symbol: _selectedAtomSymbol,
          position: pos,
          color: _selectedAtomColor,
        ),
      );
    });
  }

  void _connectAtoms(String fromId, String toId) {
    if (fromId == toId) return;
    final existing = _bonds.where(
      (b) =>
          (b.fromId == fromId && b.toId == toId) ||
          (b.fromId == toId && b.toId == fromId),
    );
    _pushUndo();
    if (existing.isNotEmpty) {
      final bond = existing.first;
      setState(() {
        bond.type =
            BondType.values[(BondType.values.indexOf(bond.type) + 1) %
                BondType.values.length];
      });
      return;
    }
    setState(() {
      _bonds.add(
        Bond(id: _newBondId(), fromId: fromId, toId: toId, type: _bondType),
      );
    });
  }

  void _attachFragment(Atom anchor, MoleculeFragment frag) {
    _pushUndo();
    final Map<String, String> localToGlobal = {};
    localToGlobal[frag.anchorLocalId] = anchor.id;
    setState(() {
      for (final fa in frag.atoms) {
        if (fa.localId == frag.anchorLocalId) continue;
        final newId = _newId();
        localToGlobal[fa.localId] = newId;
        _atoms.add(
          Atom(
            id: newId,
            symbol: fa.symbol,
            position: anchor.position + fa.relativeOffset,
            color: fa.color,
          ),
        );
      }
      final nonAnchor = frag.atoms.where(
        (a) => a.localId != frag.anchorLocalId,
      );
      if (nonAnchor.isNotEmpty) {
        final firstLocalId = nonAnchor.first.localId;
        _bonds.add(
          Bond(
            id: _newBondId(),
            fromId: anchor.id,
            toId: localToGlobal[firstLocalId]!,
            type: BondType.single,
          ),
        );
      }
      for (final fb in frag.bonds) {
        final fromGlobal = localToGlobal[fb.fromLocalId];
        final toGlobal = localToGlobal[fb.toLocalId];
        if (fromGlobal != null && toGlobal != null) {
          _bonds.add(
            Bond(
              id: _newBondId(),
              fromId: fromGlobal,
              toId: toGlobal,
              type: fb.type,
            ),
          );
        }
      }
    });
  }

  void _placeFragment(Offset center, MoleculeFragment frag) {
    _pushUndo();
    final Map<String, String> localToGlobal = {};
    setState(() {
      for (final fa in frag.atoms) {
        final newId = _newId();
        localToGlobal[fa.localId] = newId;
        _atoms.add(
          Atom(
            id: newId,
            symbol: fa.symbol,
            position: center + fa.relativeOffset,
            color: fa.color,
          ),
        );
      }
      for (final fb in frag.bonds) {
        final fromGlobal = localToGlobal[fb.fromLocalId];
        final toGlobal = localToGlobal[fb.toLocalId];
        if (fromGlobal != null && toGlobal != null) {
          _bonds.add(
            Bond(
              id: _newBondId(),
              fromId: fromGlobal,
              toId: toGlobal,
              type: fb.type,
            ),
          );
        }
      }
    });
  }

  void _eraseAtom(Atom atom) {
    _pushUndo();
    setState(() {
      _atoms.remove(atom);
      _bonds.removeWhere((b) => b.fromId == atom.id || b.toId == atom.id);
      if (_selectedAtomId == atom.id) _selectedAtomId = null;
    });
  }

  void _clearCanvas() {
    if (_atoms.isEmpty && _bonds.isEmpty) return;
    _pushUndo();
    setState(() {
      _atoms.clear();
      _bonds.clear();
      _selectedAtomId = null;
    });
  }

  void _cleanStructure() {
    if (_atoms.isEmpty) return;
    _pushUndo();

    final canvasCenter = Offset(
      _canvasSize.width > 0 ? _canvasSize.width / 2 : 400,
      _canvasSize.height > 0 ? _canvasSize.height / 2 : 300,
    );

    // Preserve initial center of mass
    Offset initialCenter = Offset.zero;
    for (final a in _atoms) {
      initialCenter += a.position;
    }
    initialCenter = initialCenter / _atoms.length.toDouble();

    // Target bond length
    const double L = 60.0;
    // Simulation parameters
    const int iterations = 120;
    const double damping = 0.85;

    // We'll store velocities for each atom
    final Map<String, Offset> velocities = {
      for (final a in _atoms) a.id: Offset.zero,
    };

    // Build adjacency list for angular forces
    final Map<String, List<String>> neighbors = {
      for (final a in _atoms) a.id: [],
    };
    for (final b in _bonds) {
      neighbors[b.fromId]?.add(b.toId);
      neighbors[b.toId]?.add(b.fromId);
    }

    // Run simulation
    for (int step = 0; step < iterations; step++) {
      // Temperature / step size decays over time
      final double temp = (1.0 - (step / iterations)) * 10.0;

      final Map<String, Offset> forces = {
        for (final a in _atoms) a.id: Offset.zero,
      };

      // 1. Repulsive forces between all pairs of atoms (to prevent overlap)
      for (int i = 0; i < _atoms.length; i++) {
        final a1 = _atoms[i];
        for (int j = i + 1; j < _atoms.length; j++) {
          final a2 = _atoms[j];
          final delta = a1.position - a2.position;
          double dist = delta.distance;
          if (dist < 0.1) {
            // Avoid division by zero: apply a small random offset
            final randAngle = Random().nextDouble() * 2 * pi;
            final f = Offset(cos(randAngle), sin(randAngle)) * 2.0;
            forces[a1.id] = forces[a1.id]! + f;
            forces[a2.id] = forces[a2.id]! - f;
            continue;
          }

          // Force inversely proportional to distance squared
          final forceMag = (L * L) / (dist * dist) * 0.4;
          final f = (delta / dist) * forceMag;

          forces[a1.id] = forces[a1.id]! + f;
          forces[a2.id] = forces[a2.id]! - f;
        }
      }

      // 2. Attractive forces along bonds (to maintain standard bond length)
      for (final b in _bonds) {
        final a1 = _atoms.firstWhere(
          (a) => a.id == b.fromId,
          orElse: () => _atoms[0],
        );
        final a2 = _atoms.firstWhere(
          (a) => a.id == b.toId,
          orElse: () => _atoms[0],
        );
        if (a1.id == a2.id) continue;

        final delta = a1.position - a2.position;
        final dist = delta.distance;
        if (dist < 0.1) continue;

        // Hooke's law: force proportional to displacement from target length L
        final forceMag = 0.25 * (dist - L);
        final f = (delta / dist) * forceMag;

        forces[a1.id] = forces[a1.id]! - f;
        forces[a2.id] = forces[a2.id]! + f;
      }

      // 3. Angular/Symmetric spacing forces between neighbors of the same atom
      for (final centerId in neighbors.keys) {
        final ns = neighbors[centerId]!;
        if (ns.length < 2) continue;

        // Central atom position
        final centerPos = _atoms.firstWhere((a) => a.id == centerId).position;

        for (int i = 0; i < ns.length; i++) {
          final n1Id = ns[i];
          final n1 = _atoms.firstWhere((a) => a.id == n1Id);
          for (int j = i + 1; j < ns.length; j++) {
            final n2Id = ns[j];
            final n2 = _atoms.firstWhere((a) => a.id == n2Id);

            final v1 = n1.position - centerPos;
            final v2 = n2.position - centerPos;
            final d1 = v1.distance;
            final d2 = v2.distance;
            if (d1 < 0.1 || d2 < 0.1) continue;

            final deltaNeighbors = n1.position - n2.position;
            final distNeighbors = deltaNeighbors.distance;
            if (distNeighbors < 0.1) continue;

            final targetDist = ns.length == 2 ? 2.0 * L : 1.73 * L;
            if (distNeighbors < targetDist) {
              final forceMag = 0.3 * (targetDist - distNeighbors);
              final f = (deltaNeighbors / distNeighbors) * forceMag;
              forces[n1.id] = forces[n1.id]! + f;
              forces[n2.id] = forces[n2.id]! - f;
            }
          }
        }
      }

      // Update positions
      for (final a in _atoms) {
        final f = forces[a.id]!;
        final double fDist = f.distance;
        final cappedForce = fDist > temp ? (f / fDist) * temp : f;

        velocities[a.id] = (velocities[a.id]! + cappedForce) * damping;
        a.position = a.position + velocities[a.id]!;
      }
    }

    // Centering: move the finished structure to the canvas center.
    Offset newCenter = Offset.zero;
    for (final a in _atoms) {
      newCenter += a.position;
    }
    newCenter = newCenter / _atoms.length.toDouble();
    final translation = canvasCenter - newCenter;
    setState(() {
      for (final a in _atoms) {
        a.position += translation;
      }
    });
  }

  void _addHydrogens() {
    _pushUndo();

    final List<Atom> newAtoms = [];
    final List<Bond> newBonds = [];

    int tempNextId = _nextId;
    String getTempId() => 'a${tempNextId++}';
    String getTempBondId() => 'b${tempNextId++}';

    int expectedValence(String symbol, int charge) {
      final neutralValence = kMaxBonds[symbol] ?? 0;
      if (neutralValence == 0) return 0;
      if (symbol == 'C') {
        return max(0, 4 - charge.abs());
      } else if (symbol == 'N') {
        return max(0, 3 + charge);
      } else if (symbol == 'O' || symbol == 'S') {
        return max(0, 2 + charge);
      } else if (symbol == 'H' ||
          symbol == 'F' ||
          symbol == 'Cl' ||
          symbol == 'Br' ||
          symbol == 'I') {
        return max(0, 1 - charge.abs());
      }
      return neutralValence;
    }

    for (final atom in _atoms) {
      if (atom.symbol == 'H') continue;

      final val = expectedValence(atom.symbol, atom.charge);
      if (val == 0) continue;

      int currentBondOrder = 0;
      for (final b in _bonds) {
        if (b.fromId == atom.id || b.toId == atom.id) {
          switch (b.type) {
            case BondType.single:
              currentBondOrder += 1;
              break;
            case BondType.double:
              currentBondOrder += 2;
              break;
            case BondType.triple:
              currentBondOrder += 3;
              break;
          }
        }
      }

      final needed = val - currentBondOrder;
      if (needed <= 0) continue;

      final angles = _getHydrogenAngles(atom, _atoms, _bonds, needed);
      const double hBondLength = 45.0;

      for (final angle in angles) {
        final hId = getTempId();
        final hPos =
            atom.position + Offset(cos(angle), sin(angle)) * hBondLength;

        newAtoms.add(
          Atom(
            id: hId,
            symbol: 'H',
            position: hPos,
            color: const Color(0xFF888888),
          ),
        );

        newBonds.add(
          Bond(
            id: getTempBondId(),
            fromId: atom.id,
            toId: hId,
            type: BondType.single,
          ),
        );
      }
    }

    if (newAtoms.isNotEmpty) {
      setState(() {
        _atoms.addAll(newAtoms);
        _bonds.addAll(newBonds);
        _nextId = tempNextId;
      });
    }
  }

  List<double> _getHydrogenAngles(
    Atom parent,
    List<Atom> allAtoms,
    List<Bond> allBonds,
    int needed,
  ) {
    final List<double> existingAngles = [];
    for (final b in allBonds) {
      if (b.fromId == parent.id || b.toId == parent.id) {
        final otherId = b.fromId == parent.id ? b.toId : b.fromId;
        final other = allAtoms.firstWhere(
          (a) => a.id == otherId,
          orElse: () => parent,
        );
        if (other.id != parent.id) {
          final diff = other.position - parent.position;
          existingAngles.add(atan2(diff.dy, diff.dx));
        }
      }
    }

    final List<double> angles = [];
    if (existingAngles.isEmpty) {
      for (int i = 0; i < needed; i++) {
        angles.add(i * (2 * pi / needed));
      }
      return angles;
    }

    existingAngles.sort();

    if (existingAngles.length == 1) {
      final op = existingAngles[0] + pi;
      if (needed == 1) {
        angles.add(op);
      } else if (needed == 2) {
        angles.add(op + pi / 3);
        angles.add(op - pi / 3);
      } else if (needed == 3) {
        angles.add(op);
        angles.add(op + pi / 2);
        angles.add(op - pi / 2);
      } else {
        for (int i = 0; i < needed; i++) {
          angles.add(op - pi / 2 + i * (pi / (needed - 1)));
        }
      }
      return angles;
    }

    double maxGap = 0.0;
    double gapStart = 0.0;

    for (int i = 0; i < existingAngles.length; i++) {
      final a1 = existingAngles[i];
      final a2 = existingAngles[(i + 1) % existingAngles.length];
      double gap = a2 - a1;
      if (gap < 0) gap += 2 * pi;

      if (gap > maxGap) {
        maxGap = gap;
        gapStart = a1;
      }
    }

    final double step = maxGap / (needed + 1);
    for (int i = 1; i <= needed; i++) {
      double angle = gapStart + i * step;
      if (angle > pi) angle -= 2 * pi;
      angles.add(angle);
    }

    return angles;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // POINTER HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _onTapDown(TapDownDetails details) {
    final pos = details.localPosition;
    final hit = _atomAt(pos);

    if (_mode == 'erase') {
      if (hit != null) _eraseAtom(hit);
      return;
    }

    if (_mode == 'draw') {
      if (_selectedFragment != null) {
        if (hit != null) {
          _attachFragment(hit, _selectedFragment!);
        } else {
          _placeFragment(pos, _selectedFragment!);
        }
        return;
      }

      if (hit != null) {
        if (_selectedAtomId == null) {
          setState(() => _selectedAtomId = hit.id);
        } else {
          _connectAtoms(_selectedAtomId!, hit.id);
          setState(() {
            _selectedAtomId = null;
            _previewEnd = null;
          });
        }
      } else {
        if (_selectedAtomId != null) {
          setState(() {
            _selectedAtomId = null;
            _previewEnd = null;
          });
        } else {
          _addAtom(pos);
        }
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    final pos = details.localPosition;
    final hit = _atomAt(pos);
    if (hit != null && _mode == 'draw' && _selectedFragment == null) {
      _preDragSnapshot = _Snapshot.capture(_atoms, _bonds, _nextId);
      setState(() {
        _isDraggingAtom = true;
        _draggingAtomId = hit.id;
        _dragStart = pos - hit.position;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final pos = details.localPosition;
    if (_isDraggingAtom && _draggingAtomId != null) {
      try {
        final atom = _atoms.firstWhere((a) => a.id == _draggingAtomId);
        atom.position = pos - _dragStart;
        setState(() {});
      } catch (_) {}
    } else if (_selectedAtomId != null) {
      setState(() => _previewEnd = pos);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDraggingAtom && _preDragSnapshot != null) {
      _undoStack.add(_preDragSnapshot!);
      if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
      _redoStack.clear();
      _preDragSnapshot = null;
    }
    setState(() {
      _isDraggingAtom = false;
      _draggingAtomId = null;
    });
  }

  void _onPointerMove(PointerEvent event) {
    final pos = event.localPosition;
    final hit = _atomAt(pos, radius: 22);
    if (hit?.id != _hoveredAtomId) {
      setState(() => _hoveredAtomId = hit?.id);
    }
    if (_selectedAtomId != null && !_isDraggingAtom) {
      setState(() => _previewEnd = pos);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackground,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildPalette(),
                      Expanded(child: _buildCanvas()),
                      if (_showSavedPanel) _buildSavedPanel(),
                    ],
                  ),
                ),
                _buildRetrosynthesisPanel(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOP BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTopBar() {
    final canUndo = _undoStack.isNotEmpty;
    final canRedo = _redoStack.isNotEmpty;
    final hasSelection = _selectedAtomId != null;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: _panelBackground,
        border: Border(bottom: BorderSide(color: _panelBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // ── Mode buttons ────────────────────────────────────────────────
          _modeButton('draw', Icons.edit_outlined, 'Draw'),
          const SizedBox(width: 6),
          _modeButton('erase', Icons.auto_fix_normal_outlined, 'Erase'),

          const SizedBox(width: 6),
          _divider(),
          const SizedBox(width: 6),

          // ── Charge buttons (visible when atom selected) ────────────────
          if (hasSelection) ...[
            const SizedBox(width: 6),
            _divider(),
            const SizedBox(width: 6),
            const Text(
              'Charge',
              style: TextStyle(color: Color(0xFF444444), fontSize: 10),
            ),
            const SizedBox(width: 6),
            _chargeBtn('−', -1),
            const SizedBox(width: 2),
            _chargeBtn('+', 1),
          ],

          const Spacer(),

          // ── History ─────────────────────────────────────────────────────
          _iconBtn(
            icon: Icons.undo_rounded,
            tooltip: 'Undo',
            enabled: canUndo,
            onTap: _undo,
          ),
          const SizedBox(width: 2),
          _iconBtn(
            icon: Icons.redo_rounded,
            tooltip: 'Redo',
            enabled: canRedo,
            onTap: _redo,
          ),

          const SizedBox(width: 2),
          _divider(),
          const SizedBox(width: 2),

          // ── Clean / Hydrogens ───────────────────────────────────────────
          _iconBtn(
            icon: Icons.auto_awesome_outlined,
            tooltip: 'Clean structure (Auto-layout)',
            enabled: _atoms.isNotEmpty,
            onTap: _cleanStructure,
            color: const Color(0xFFB39DDB),
          ),
          const SizedBox(width: 2),
          _iconBtn(
            icon: Icons.opacity,
            tooltip: 'Add hydrogens',
            enabled: _atoms.isNotEmpty,
            onTap: _addHydrogens,
            color: const Color(0xFF80CBC4),
          ),

          const SizedBox(width: 2),

          // ── Erase / Clear ──────────────────────────────────────────────
          _iconBtn(
            icon: Icons.backspace_outlined,
            tooltip: 'Erase selected atom',
            enabled: hasSelection,
            onTap: () {
              if (_selectedAtomId == null) return;
              final a = _atoms.cast<Atom?>().firstWhere(
                (a) => a!.id == _selectedAtomId,
                orElse: () => null,
              );
              if (a != null) _eraseAtom(a);
            },
            color: const Color(0xFFE57373),
          ),
          const SizedBox(width: 2),
          _iconBtn(
            icon: Icons.delete_sweep_outlined,
            tooltip: 'Clear canvas',
            enabled: _atoms.isNotEmpty,
            onTap: _clearCanvas,
            color: const Color(0xFFE57373),
          ),

          const SizedBox(width: 2),

          // ── Save / Load / Export ────────────────────────────────────────
          _iconBtn(
            icon: Icons.save_outlined,
            tooltip: 'Save molecule',
            enabled: _atoms.isNotEmpty,
            onTap: _showSaveDialog,
            color: const Color(0xFF81C784),
          ),
          const SizedBox(width: 2),
          _iconBtn(
            icon: Icons.folder_open_outlined,
            tooltip: 'Saved molecules',
            enabled: true,
            onTap: () => setState(() => _showSavedPanel = !_showSavedPanel),
            color: _showSavedPanel ? const Color(0xFF00C8FF) : null,
          ),
          const SizedBox(width: 2),
          _iconBtn(
            icon: Icons.data_object_outlined,
            tooltip: 'Export SMILES',
            enabled: _atoms.isNotEmpty,
            onTap: _exportSmiles,
            color: const Color(0xFFFFD54F),
          ),
        ],
      ),
    );
  }

  void _toggleRetrosynthesisPanel() {
    if (_atoms.isEmpty) return;
    setState(() {
      _retrosynthesisExpanded = !_retrosynthesisExpanded;
      if (_retrosynthesisExpanded) {
        _retrosynthesisAnalysis = RetrosynthesisEngine.analyze(_atoms, _bonds);
      } else {
        _retrosynthesisAnalysis = null;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recenterMoleculeToCanvas();
    });
  }

  void _recenterMoleculeToCanvas() {
    if (_atoms.isEmpty) return;

    final expandedMode = _retrosynthesisExpanded;
    final desiredCenter = Offset(
      _canvasSize.width > 0 ? _canvasSize.width / 2 : 400,
      expandedMode
          ? (_canvasSize.height > 0 ? _canvasSize.height * 0.25 : 180.0)
          : (_canvasSize.height > 0 ? _canvasSize.height / 2 : 300.0),
    );

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final atom in _atoms) {
      minX = min(minX, atom.position.dx);
      minY = min(minY, atom.position.dy);
      maxX = max(maxX, atom.position.dx);
      maxY = max(maxY, atom.position.dy);
    }

    final currentBoundsCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    final width = max(maxX - minX, 1.0);
    final height = max(maxY - minY, 1.0);

    final padding = 60.0;
    final availableWidth = max(_canvasSize.width - padding, 120.0);
    final availableHeight = max(
      expandedMode
          ? (_canvasSize.height * 0.5) - padding
          : _canvasSize.height - padding,
      120.0,
    );
    final fitScale = min(
      availableWidth / width,
      availableHeight / height,
    ).clamp(0.12, 1.0);

    setState(() {
      for (final atom in _atoms) {
        final relative = atom.position - currentBoundsCenter;
        atom.position = desiredCenter + relative * fitScale;
      }
    });
  }

  Color _confidenceColor(double confidence) {
    final clamped = confidence.clamp(0.0, 1.0);
    if (clamped <= 0.5) {
      return Color.lerp(
        const Color(0xFFD32F2F),
        const Color(0xFFFFEA00),
        (clamped / 0.5).clamp(0.0, 1.0),
      )!;
    }
    return Color.lerp(
      const Color(0xFFFFEA00),
      const Color(0xFF2E7D32),
      ((clamped - 0.5) / 0.5).clamp(0.0, 1.0),
    )!;
  }

  Color _routeColor(int index, double confidence) {
    const palette = <Color>[
      Color(0xFF66D9EF),
      Color(0xFFB388FF),
      Color(0xFFFFC857),
      Color(0xFF7AE582),
      Color(0xFFFF8A80),
      Color(0xFF8DD9FF),
    ];

    final base = palette[index % palette.length];
    final confidenceColor = _confidenceColor(confidence);
    return Color.lerp(base, confidenceColor, 0.45) ?? base;
  }

  Color _functionalGroupPillColor(String functionalGroup) {
    return RetrosynthesisDatabase.colorForFunctionalGroup(functionalGroup);
  }

  List<RetrosynthesisBreakMarker> _retrosynthesisBreakMarkers() {
    if (_atoms.isEmpty || _bonds.isEmpty || !_retrosynthesisExpanded) {
      return const [];
    }

    final analysis =
        _retrosynthesisAnalysis ?? RetrosynthesisEngine.analyze(_atoms, _bonds);
    final atomMap = {for (final atom in _atoms) atom.id: atom};
    final List<RetrosynthesisBreakMarker> markers = [];

    for (int stepIndex = 0; stepIndex < analysis.steps.length; stepIndex++) {
      final step = analysis.steps[stepIndex];
      final stepColor = _routeColor(stepIndex, step.confidence);

      final List<Offset> candidatePoints = [];
      for (final bond in _bonds) {
        final from = atomMap[bond.fromId];
        final to = atomMap[bond.toId];
        if (from == null || to == null) continue;

        final a = from.symbol;
        final b = to.symbol;
        final pair = [a, b];
        final isAmideBond =
            step.reaction.contains('amide') &&
            (pair.contains('C') && pair.contains('N'));
        final isEsterBond =
            step.reaction.contains('ester') &&
            (pair.contains('C') && pair.contains('O'));
        final isAlcoholBond =
            step.reaction.contains('alcohol') &&
            (pair.contains('C') && pair.contains('O'));
        final isFragmentBond =
            step.reaction.contains('fragment') &&
            (pair.contains('C') || pair.contains('N') || pair.contains('O'));

        if (isAmideBond || isEsterBond || isAlcoholBond || isFragmentBond) {
          candidatePoints.add((from.position + to.position) / 2);
        }
      }

      if (candidatePoints.isEmpty && step.reaction.contains('fragment')) {
        candidatePoints.addAll(
          _bonds.map((bond) {
            final from = atomMap[bond.fromId];
            final to = atomMap[bond.toId];
            if (from == null || to == null) return Offset.zero;
            return (from.position + to.position) / 2;
          }),
        );
      }

      for (final point in candidatePoints) {
        if (point != Offset.zero) {
          markers.add(
            RetrosynthesisBreakMarker(
              point: point,
              color: stepColor,
              confidence: step.confidence,
            ),
          );
        }
      }
    }

    return markers;
  }

  List<FunctionalGroupMarker> _functionalGroupMarkers() {
    if (_atoms.isEmpty || !_showFunctionalGroups) {
      return const [];
    }
    return RetrosynthesisEngine.detectGroupMarkers(_atoms, _bonds);
  }

  Widget _buildRetrosynthesisPanel(BuildContext context) {
    final analysis =
        _retrosynthesisAnalysis ?? RetrosynthesisEngine.analyze(_atoms, _bonds);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final height = _retrosynthesisExpanded
        ? (viewportHeight * 0.5).clamp(220.0, viewportHeight * 0.7)
        : 50.0;
    final bodyHeight = _retrosynthesisExpanded ? height - 52.0 : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      height: height,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 0),
      decoration: BoxDecoration(
        color: _panelBackground,
        border: Border(top: BorderSide(color: _panelBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _atoms.isNotEmpty ? _toggleRetrosynthesisPanel : null,
            child: SizedBox(
              height: 49,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 15,
                      color: _isDarkTheme
                          ? const Color(0xFFCE93D8)
                          : const Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Retrosynthesis analysis',
                      style: TextStyle(
                        color: _isDarkTheme
                            ? const Color(0xFFEAEAEA)
                            : const Color(0xFF1F2937),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _retrosynthesisExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: _isDarkTheme
                          ? const Color(0xFF888888)
                          : const Color(0xFF64748B),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_retrosynthesisExpanded)
            SizedBox(
              height: bodyHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_showFunctionalGroups &&
                          analysis.functionalGroups.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: analysis.functionalGroups.map((fg) {
                            final color = _functionalGroupPillColor(fg);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.7),
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                fg,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      if (analysis.steps.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        for (int i = 0; i < analysis.steps.length; i++)
                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(top: i == 0 ? 0 : 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isDarkTheme
                                  ? const Color(0xFF151515)
                                  : const Color(0xFFF8FAFC),
                              border: Border.all(
                                color: _routeColor(
                                  i,
                                  analysis.steps[i].confidence,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        i == 0
                                            ? 'Top suggestion'
                                            : 'Alternative route ${i + 1}',
                                        style: TextStyle(
                                          color: _routeColor(
                                            i,
                                            analysis.steps[i].confidence,
                                          ),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${(analysis.steps[i].confidence * 100).round()}%',
                                      style: TextStyle(
                                        color: _confidenceColor(
                                          analysis.steps[i].confidence,
                                        ),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  analysis.steps[i].reaction,
                                  style: TextStyle(
                                    color: _routeColor(
                                      i,
                                      analysis.steps[i].confidence,
                                    ),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  analysis.steps[i].description,
                                  style: TextStyle(
                                    color: _isDarkTheme
                                        ? const Color(0xFFDADADA)
                                        : const Color(0xFF344054),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _retrosynthesisInfoRow(
                                  'Precursors',
                                  analysis.steps[i].precursors.join(', '),
                                ),
                                const SizedBox(height: 4),
                                _retrosynthesisInfoRow(
                                  'Reagents',
                                  analysis.steps[i].reagents.join(', '),
                                ),
                                const SizedBox(height: 4),
                                _retrosynthesisInfoRow(
                                  'Break point',
                                  analysis.steps[i].breakPoints.join(', '),
                                ),
                              ],
                            ),
                          ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'No confident disconnection rule matched this structure.',
                            style: TextStyle(
                              color: _isDarkTheme
                                  ? const Color(0xFFB0B0B0)
                                  : const Color(0xFF475467),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REUSABLE WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _divider() =>
      Container(width: 1, height: 20, color: const Color(0xFF222222));

  Widget _chargeBtn(String label, int delta) {
    return InkWell(
      onTap: () => _changeCharge(delta),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: const Color(0xFF2A2A2A)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: delta > 0
                ? const Color(0xFF64B5F6)
                : const Color(0xFFEF5350),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = enabled
        ? (color ?? const Color(0xFF888888))
        : const Color(0xFF2A2A2A);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 25,
          height: 25,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled && color != null
                ? color.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: c),
        ),
      ),
    );
  }

  Widget _modeButton(String mode, IconData icon, String label) {
    final active = _mode == mode;
    return InkWell(
      onTap: () => setState(() {
        _mode = mode;
        _selectedAtomId = null;
        _previewEnd = null;
      }),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF00C8FF).withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: active ? const Color(0xFF00C8FF) : const Color(0xFF2A2A2A),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFF00C8FF) : const Color(0xFF555555),
              size: 14,
            ),
            /* const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? const Color(0xFF00C8FF)
                    : const Color(0xFF555555),
                fontSize: 11,
              ),
            ), */
          ],
        ),
      ),
    );
  }

  Widget _bondChip(String label, BondType type) {
    final active = _bondType == type;
    return InkWell(
      onTap: () => setState(() => _bondType = type),
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 28,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF00C8FF).withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: active
                ? const Color(0xFF00C8FF)
                : const Color.fromARGB(7, 42, 42, 42),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF00C8FF) : const Color(0xFF555555),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEFT PALETTE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPalette() {
    return Container(
      width: 50,
      decoration: BoxDecoration(
        color: _panelBackground,
        border: Border(right: BorderSide(color: _panelBorder)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        children: [
          if (_mode == 'draw' && _selectedFragment == null) ...[
            _bondChip('–', BondType.single),
            const SizedBox(width: 4),
            _bondChip('=', BondType.double),
            const SizedBox(width: 4),
            _bondChip('≡', BondType.triple),
          ],
          ...kAtomPalette.map((e) => _atomTile(e)),
          const SizedBox(height: 12),
          ..._fragments.map((f) => _fragmentTile(f)),
          const SizedBox(height: 10),
          Divider(color: const Color(0xFF1C1C1C), height: 1, thickness: 1),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'FGs',
                  style: TextStyle(
                    color: _mutedText,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Transform.scale(
                  scale: 0.75,
                  child: Switch.adaptive(
                    value: _showFunctionalGroups,
                    activeThumbColor: const Color(0xFF8DD9FF),
                    activeTrackColor: const Color(
                      0xFF8DD9FF,
                    ).withValues(alpha: 0.35),
                    onChanged: (value) {
                      setState(() => _showFunctionalGroups = value);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Theme',
                  style: TextStyle(
                    color: _mutedText,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () => widget.onThemeChanged?.call(
                    widget.themeMode != ThemeMode.dark,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    width: 42,
                    height: 22,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: widget.themeMode == ThemeMode.dark
                          ? const Color(0xFF1D2430)
                          : const Color(0xFFF6D365),
                      border: Border.all(
                        color: widget.themeMode == ThemeMode.dark
                            ? const Color(0xFF3A4A5C)
                            : const Color(0xFFE7B93B),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Align(
                          alignment: widget.themeMode == ThemeMode.dark
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeInOut,
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: widget.themeMode == ThemeMode.dark
                                  ? const Color(0xFF8DD9FF)
                                  : const Color(0xFFFFF7D6),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (widget.themeMode == ThemeMode.dark
                                              ? const Color(0xFF8DD9FF)
                                              : const Color(0xFFFFC857))
                                          .withValues(alpha: 0.45),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 4,
                          top: 3,
                          child: Icon(
                            Icons.dark_mode_rounded,
                            size: 10,
                            color: widget.themeMode == ThemeMode.dark
                                ? const Color(0xFFBFE9FF)
                                : const Color(0xFF7A5C00),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 3,
                          child: Icon(
                            Icons.light_mode_rounded,
                            size: 10,
                            color: widget.themeMode == ThemeMode.dark
                                ? const Color(0xFF68758A)
                                : const Color(0xFFFFF6D6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _atomTile(AtomEntry entry) {
    final isSelected =
        _selectedFragment == null &&
        _selectedAtomSymbol == entry.symbol &&
        _mode == 'draw';
    return GestureDetector(
      onTap: () => setState(() {
        _selectedAtomSymbol = entry.symbol;
        _selectedAtomColor = entry.color;
        _selectedFragment = null;
        _mode = 'draw';
        _selectedAtomId = null;
        _previewEnd = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        height: 25,
        decoration: BoxDecoration(
          color: isSelected
              ? entry.color.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? entry.color.withValues(alpha: 0.7)
                : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            entry.symbol,
            style: TextStyle(
              color: entry.color,
              fontSize: entry.symbol.length > 1 ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _fragmentTile(MoleculeFragment frag) {
    final isSelected = _selectedFragment?.name == frag.name && _mode == 'draw';
    return GestureDetector(
      onTap: () => setState(() {
        _selectedFragment = frag;
        _mode = 'draw';
        _selectedAtomId = null;
        _previewEnd = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        height: 34,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00C8FF).withValues(alpha: 0.10)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00C8FF).withValues(alpha: 0.6)
                : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            frag.displayLabel,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF00C8FF)
                  : const Color(0xFF555555),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SAVED MOLECULES PANEL (RIGHT)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSavedPanel() {
    final headerColor = _isDarkTheme
        ? const Color(0xFF555555)
        : const Color(0xFF64748B);
    final emptyColor = _isDarkTheme
        ? const Color(0xFF333333)
        : const Color(0xFF475467);
    final closeColor = _isDarkTheme
        ? const Color(0xFF444444)
        : const Color(0xFF667085);

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: _panelBackground,
        border: Border(left: BorderSide(color: _panelBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _panelBorder)),
            ),
            child: Row(
              children: [
                Text(
                  'SAVED',
                  style: TextStyle(
                    color: headerColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _showSavedPanel = false),
                  child: Icon(Icons.close, size: 14, color: closeColor),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _savedMolecules.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No saved molecules',
                        style: TextStyle(color: emptyColor, fontSize: 11),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _savedMolecules.length,
                    itemBuilder: (_, i) => _savedTile(_savedMolecules[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _savedTile(SavedMolecule mol) {
    final smiles = generateSmiles(mol.atoms, mol.bonds);
    final dt = DateTime.tryParse(mol.timestamp);
    final timeStr = dt != null
        ? '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';
    final cardColor = _isDarkTheme
        ? const Color(0xFF161616)
        : const Color(0xFFFFFFFF);
    final cardBorder = _isDarkTheme
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFD5DCE7);
    final nameColor = _isDarkTheme
        ? const Color(0xFFCCCCCC)
        : const Color(0xFF1F2937);
    final timestampColor = _isDarkTheme
        ? const Color(0xFF333333)
        : const Color(0xFF667085);
    final closeColor = _isDarkTheme
        ? const Color(0xFF444444)
        : const Color(0xFF667085);

    return InkWell(
      onTap: () => _loadMolecule(mol),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: cardBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mol.name,
                    style: TextStyle(
                      color: nameColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => _deleteSaved(mol),
                  child: Icon(Icons.close, size: 12, color: closeColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              smiles.isEmpty ? '(empty)' : smiles,
              style: TextStyle(
                color: _isDarkTheme
                    ? const Color(0xFF00C8FF)
                    : const Color(0xFF2563EB),
                fontSize: 9,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(timeStr, style: TextStyle(color: timestampColor, fontSize: 8)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CANVAS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasSize = constraints.biggest;
        return Listener(
          onPointerMove: _onPointerMove,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Container(
              color: _canvasBackground,
              child: Stack(
                children: [
                  // Dot-grid
                  CustomPaint(
                    painter: _GridPainter(isDark: _isDarkTheme),
                    child: Container(),
                  ),
                  // Molecule
                  CustomPaint(
                    painter: MoleculeCanvasPainter(
                      atoms: _atoms,
                      bonds: _bonds,
                      selectedAtomId: _selectedAtomId,
                      hoveredAtomId: _hoveredAtomId,
                      previewLineEnd: _previewEnd,
                      isDarkTheme: _isDarkTheme,
                      retrosynthesisBreakMarkers: _retrosynthesisBreakMarkers(),
                      functionalGroupMarkers: _functionalGroupMarkers(),
                    ),
                    child: Container(),
                  ),
                  // Empty-canvas hint
                  if (_atoms.isEmpty)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.science_outlined,
                            color: const Color(0xFF1E1E1E),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Select an atom or group\nthen click to place',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF252525),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Bond-mode toast
                  if (_selectedAtomId != null)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF001820),
                            border: Border.all(color: const Color(0xFF004050)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Click another atom to bond · Click empty space to cancel',
                            style: TextStyle(
                              color: Color(0xFF00C8FF),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Erase-mode hint
                  if (_mode == 'erase')
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A0000),
                            border: Border.all(color: const Color(0xFF500000)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Click an atom to erase it',
                            style: TextStyle(
                              color: Color(0xFFE57373),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Dot-grid background ──────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final bool isDark;

  const _GridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFD9DEE6);
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.isDark != isDark;
}
