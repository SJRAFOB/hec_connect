import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'create_schedule_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isGridView = false;
  String? _filterFiliere;
  String? _filterNiveau;

  final List<String> _jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];

  static const List<Map<String, String>> _slots = [
    {'label': '8h00 - 10h00',  'key': '8h00-10h00'},
    {'label': '10h30 - 12h00', 'key': '10h30-12h00'},
    {'label': '13h00 - 15h00', 'key': '13h00-15h00'},
  ];

  // Couleurs par matière (générées depuis le nom)
  static const List<Color> _palette = [
    Color(0xFF1C3A6B), Color(0xFF9C27B0), Color(0xFF2196F3),
    Color(0xFF00897B), Color(0xFFE53935), Color(0xFFFF6F00),
    Color(0xFF43A047), Color(0xFF5E35B1), Color(0xFFD81B60),
  ];

  Color _subjectColor(String subject) {
    if (subject.isEmpty) return _palette[0];
    return _palette[subject.codeUnits.fold(0, (a, b) => a + b) % _palette.length];
  }

  // Jour actuel (1=Lundi ... 5=Vendredi, 0=weekend)
  int get _todayIndex {
    final wd = DateTime.now().weekday; // 1=Mon, 7=Sun
    if (wd >= 1 && wd <= 5) return wd - 1;
    return -1;
  }

  String get _currentSlotKey {
    final h = DateTime.now().hour;
    final m = DateTime.now().minute;
    final total = h * 60 + m;
    if (total >= 8 * 60 && total < 10 * 60) return '8h00-10h00';
    if (total >= 10 * 60 + 30 && total < 12 * 60) return '10h30-12h00';
    if (total >= 13 * 60 && total < 15 * 60) return '13h00-15h00';
    return '';
  }

  @override
  void initState() {
    super.initState();
    final today = _todayIndex;
    _tabController = TabController(
      length: 5, vsync: this,
      initialIndex: today >= 0 ? today : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _canEdit(AppUser? user) {
    if (user == null) return false;
    return user.role == UserRole.admin || user.role == UserRole.teacher;
  }

  // Compatibilité anciens profils (Bachelor → Licence)
  String _normalizeNiveau(String? niveau) {
    if (niveau == null) return '';
    return niveau
        .replaceAll('Bachelor 1', 'Licence 1')
        .replaceAll('Bachelor 2', 'Licence 2')
        .replaceAll('Bachelor 3', 'Licence 3');
  }

  String _normalizeFiliere(String? filiere) {
    if (filiere == null) return '';
    const map = <String, String>{
      'Finance et Comptabilite': 'Finance',
      'Finance et Comptabilité': 'Finance',
      'Gestion des Ressources Humaines': 'GRH',
    };
    return map[filiere] ?? filiere;
  }

  Query<Map<String, dynamic>> _buildQuery(AppUser user) {
    var q = FirebaseFirestore.instance
        .collection(AppConstants.collectionSchedules)
        .limit(500);

    if (user.role == UserRole.student) {
      // Normaliser Bachelor → Licence et filière pour correspondre au seed
      final niveauNorm = _normalizeNiveau(user.niveau);
      final isTronc = AppConstants.isTroncCommun(niveauNorm);

      if (niveauNorm.isNotEmpty) {
        q = q.where('niveau', isEqualTo: niveauNorm);
      }
      // Tronc commun (L1, M1) : pas de filtre filière
      // Autres niveaux : filtre par filière normalisée
      if (!isTronc) {
        final filiereNorm = _normalizeFiliere(user.filiere);
        if (filiereNorm.isNotEmpty && filiereNorm != 'Tronc commun') {
          q = q.where('filiere', isEqualTo: filiereNorm);
        }
      }
    } else if (user.role == UserRole.teacher) {
      q = q.where('professeurId', isEqualTo: user.uid);
    } else {
      // Admin/Staff : filtres optionnels
      if (_filterFiliere != null) q = q.where('filiere', isEqualTo: _filterFiliere);
      if (_filterNiveau != null) q = q.where('niveau', isEqualTo: _filterNiveau);
    }
    return q;
  }

  // Marquer annulé / remplacé / normal
  void _showStatusMenu(String docId, Map<String, dynamic> data) {
    final current = data['status'] ?? 'normal';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text('Modifier le statut — ${data['matiere'] ?? ''}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    color: Color(0xFF1C3A6B))),
            const SizedBox(height: 6),
            Text('${data['jour']} • ${_slots.firstWhere((s) => s['key'] == data['slot'], orElse: () => {'label': ''})['label']}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            _statusOption(docId, 'normal', 'Cours normal', Icons.check_circle_outline, Colors.green, current),
            _statusOption(docId, 'cancelled', 'Annuler ce cours', Icons.cancel_outlined, Colors.red, current),
            _statusOption(docId, 'replaced', 'Marquer comme remplacé', Icons.swap_horiz, Colors.orange, current),
            const SizedBox(height: 8),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Supprimer définitivement',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(docId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusOption(String docId, String status, String label,
      IconData icon, Color color, String current) {
    final isSelected = current == status;
    return GestureDetector(
      onTap: () async {
        await FirebaseFirestore.instance
            .collection(AppConstants.collectionSchedules)
            .doc(docId)
            .update({'status': status});
        if (mounted) Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? color : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: isSelected ? color : Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: TextStyle(fontSize: 14,
                  color: isSelected ? color : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))),
          if (isSelected) Icon(Icons.check, size: 16, color: color),
        ]),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce cours'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection(AppConstants.collectionSchedules)
                  .doc(id).delete();
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A6B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Emploi du temps',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // Toggle grille / liste
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view,
                color: Colors.white),
            tooltip: _isGridView ? 'Vue liste' : 'Vue grille',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
        bottom: _isGridView ? null : TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _jours.asMap().entries.map((e) {
            final isToday = e.key == _todayIndex;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.value),
                  if (isToday) ...[
                    const SizedBox(width: 4),
                    Container(width: 6, height: 6,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle)),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      floatingActionButton: _canEdit(user)
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1C3A6B),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Ajouter un cours',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreateScheduleScreen())),
            )
          : null,
      body: user == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1C3A6B)))
          : Column(
              children: [
                // Bandeau profil pour étudiant (aide au debug)
                if (user.role == UserRole.student)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.school_outlined, size: 14, color: Color(0xFF1C3A6B)),
                        const SizedBox(width: 6),
                        Text(
                          AppConstants.isTroncCommun(user.niveau)
                              ? '${user.niveau ?? "-"} — Tronc commun'
                              : '${user.niveau ?? "Niveau non defini"} • ${user.filiere ?? "Filiere non definie"}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(user).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1C3A6B)));
                }
                var allCours = snapshot.data?.docs ?? [];
                // Tri client-side (évite l'index composite Firestore)
                allCours = [...allCours]..sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                  final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                  return aTime.compareTo(bTime);
                });
                // Filtre niveau côté client pour les étudiants non-tronc
                if (user.role == UserRole.student &&
                    !AppConstants.isTroncCommun(user.niveau) &&
                    user.niveau != null) {
                  allCours = allCours.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data['niveau'] == user.niveau;
                  }).toList();
                }

                return Column(children: [
                  // Filtre admin
                  if (user.role == UserRole.admin) _buildAdminFilter(),
                  // Bandeau aujourd'hui
                  if (_todayIndex >= 0) _buildTodayBanner(allCours),
                  // Vue principale
                  Expanded(
                    child: _isGridView
                        ? _buildGridView(allCours, user)
                        : _buildListView(allCours, user),
                  ),
                ]);
              },
            ),
                ),
              ],
            ),
    );
  }

  // ── Bandeau "Aujourd'hui" ──
  Widget _buildTodayBanner(List<QueryDocumentSnapshot> allCours) {
    final todayName = _jours[_todayIndex];
    final coursDuJour = allCours.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['jour'] == todayName && (data['status'] ?? 'normal') != 'cancelled';
    }).toList();

    final currentSlot = _currentSlotKey;
    final currentCours = currentSlot.isEmpty ? null : coursDuJour.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['slot'] == currentSlot;
    }).firstOrNull;

    // Prochain cours
    final now = DateTime.now().hour * 60 + DateTime.now().minute;
    final slotStarts = {'8h00-10h00': 8 * 60, '10h30-12h00': 10 * 60 + 30, '13h00-15h00': 13 * 60};
    QueryDocumentSnapshot? nextCours;
    String? nextSlotLabel;

    for (final slot in _slots) {
      final start = slotStarts[slot['key']]!;
      if (start > now) {
        final match = coursDuJour.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['slot'] == slot['key'];
        }).firstOrNull;
        if (match != null) {
          nextCours = match;
          nextSlotLabel = slot['label'];
          break;
        }
      }
    }

    if (currentCours == null && nextCours == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1C3A6B),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.today, color: Colors.white70, size: 14),
            const SizedBox(width: 6),
            Text('Aujourd\'hui — $todayName',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
          if (currentCours != null) ...[
            const SizedBox(height: 8),
            _bannerCours(currentCours, true),
          ],
          if (nextCours != null) ...[
            const SizedBox(height: 6),
            _bannerCours(nextCours, false, slotLabel: nextSlotLabel),
          ],
        ],
      ),
    );
  }

  Widget _bannerCours(QueryDocumentSnapshot doc, bool isCurrent, {String? slotLabel}) {
    final data = doc.data() as Map<String, dynamic>;
    final matiere = data['matiere'] ?? '';
    final salle = data['salle'] ?? '';
    final color = _subjectColor(matiere);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isCurrent ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(isCurrent ? 0.3 : 0.1)),
      ),
      child: Row(children: [
        Container(width: 4, height: 36,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(matiere, style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 13)),
          if (salle.isNotEmpty)
            Text('Salle $salle', style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isCurrent ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isCurrent ? 'En cours' : (slotLabel ?? ''),
            style: TextStyle(
                color: isCurrent ? Colors.greenAccent : Colors.white70,
                fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  // ── Vue Grille ──
  Widget _buildGridView(List<QueryDocumentSnapshot> allCours, AppUser user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
      child: Column(children: [
        // Légende des couleurs
        _buildColorLegend(allCours),
        const SizedBox(height: 12),
        // Grille
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicWidth(
              child: Column(children: [
                // En-tête jours
                _buildGridHeader(),
                // Créneaux
                ..._slots.asMap().entries.expand((entry) {
                  final i = entry.key;
                  final slot = entry.value;
                  return [
                    _buildGridRow(slot, allCours, user),
                    if (i < _slots.length - 1) _buildPauseRow(i),
                  ];
                }),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildColorLegend(List<QueryDocumentSnapshot> allCours) {
    final matieres = allCours
        .map((d) => (d.data() as Map<String, dynamic>)['matiere'] as String? ?? '')
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();

    if (matieres.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8, runSpacing: 6,
      children: matieres.map((m) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: _subjectColor(m), borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text(m.length > 12 ? '${m.substring(0, 12)}...' : m,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      )).toList(),
    );
  }

  Widget _buildGridHeader() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C3A6B).withOpacity(0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(children: [
        SizedBox(width: 62, child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text('Horaire', style: TextStyle(fontSize: 10,
              color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
        )),
        ..._jours.asMap().entries.map((e) => Container(
          width: 68,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: e.key == _todayIndex ? const Color(0xFF1C3A6B).withOpacity(0.12) : null,
            border: Border(left: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(children: [
            Text(_jours[e.key].substring(0, 3),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                    color: e.key == _todayIndex ? const Color(0xFF1C3A6B) : Colors.grey.shade600),
                textAlign: TextAlign.center),
            if (e.key == _todayIndex)
              Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 2),
                  decoration: const BoxDecoration(color: Color(0xFF1C3A6B), shape: BoxShape.circle)),
          ]),
        )),
      ]),
    );
  }

  Widget _buildGridRow(Map<String, String> slot, List<QueryDocumentSnapshot> allCours, AppUser user) {
    final isCurrent = slot['key'] == _currentSlotKey && _todayIndex >= 0;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        color: isCurrent ? Colors.green.withOpacity(0.03) : null,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Heure
        SizedBox(width: 62,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ...slot['label']!.split(' - ').map((t) =>
                  Text(t, style: const TextStyle(fontSize: 9,
                      fontWeight: FontWeight.bold, color: Color(0xFF1C3A6B)),
                      textAlign: TextAlign.center)),
                if (isCurrent)
                  Container(margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: Colors.green,
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('Now', style: TextStyle(color: Colors.white, fontSize: 8))),
              ],
            ),
          ),
        ),
        // Cellules par jour
        ..._jours.asMap().entries.map((entry) {
          final dayIndex = entry.key;
          final jour = entry.value;
          final coursDuSlot = allCours.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['jour'] == jour && data['slot'] == slot['key'];
          }).toList();

          return Container(
            width: 68,
            constraints: const BoxConstraints(minHeight: 70),
            decoration: BoxDecoration(
              color: dayIndex == _todayIndex ? const Color(0xFF1C3A6B).withOpacity(0.03) : null,
              border: Border(left: BorderSide(color: Colors.grey.shade100)),
            ),
            padding: const EdgeInsets.all(4),
            child: coursDuSlot.isEmpty
                ? const SizedBox.shrink()
                : Column(children: coursDuSlot.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final matiere = data['matiere'] ?? '';
                    final status = data['status'] ?? 'normal';
                    final color = _subjectColor(matiere);
                    final isCancelled = status == 'cancelled';
                    final isReplaced = status == 'replaced';

                    return GestureDetector(
                      onLongPress: _canEdit(user)
                          ? () => _showStatusMenu(doc.id, data) : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 3),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isCancelled
                              ? Colors.red.withOpacity(0.08)
                              : color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCancelled ? Colors.red.withOpacity(0.3)
                                : isReplaced ? Colors.orange.withOpacity(0.4)
                                : color.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              matiere.length > 10 ? '${matiere.substring(0, 10)}...' : matiere,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isCancelled ? Colors.red.shade700 : color,
                                decoration: isCancelled ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (isCancelled)
                              const Text('Annulé', style: TextStyle(
                                  fontSize: 8, color: Colors.red, fontWeight: FontWeight.w600)),
                            if (isReplaced)
                              const Text('Remplacé', style: TextStyle(
                                  fontSize: 8, color: Colors.orange, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  }).toList()),
          );
        }),
      ]),
    );
  }

  Widget _buildPauseRow(int index) {
    final labels = ['Pause — 30 min', 'Déjeuner — 1h'];
    final hours = ['10h00 - 10h30', '12h00 - 13h00'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.06),
        border: Border(top: BorderSide(color: Colors.orange.withOpacity(0.2))),
      ),
      child: Row(children: [
        SizedBox(width: 62,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            child: Text(hours[index],
                style: TextStyle(fontSize: 8, color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        ),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(labels[index],
              style: TextStyle(fontSize: 11, color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600)),
        )),
      ]),
    );
  }

  // ── Vue Liste (par onglets) ──
  Widget _buildListView(List<QueryDocumentSnapshot> allCours, AppUser user) {
    return TabBarView(
      controller: _tabController,
      children: _jours.map((jour) {
        final coursDuJour = allCours.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['jour'] == jour;
        }).toList();
        return _buildJourListView(jour, coursDuJour, user);
      }).toList(),
    );
  }

  Widget _buildJourListView(String jour, List<QueryDocumentSnapshot> cours, AppUser user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(children: [
        _buildSlotCard(_slots[0], cours, user, jour),
        _pauseCard('Pause', '10h00 - 10h30', '30 min'),
        _buildSlotCard(_slots[1], cours, user, jour),
        _pauseCard('Déjeuner', '12h00 - 13h00', '1 heure'),
        _buildSlotCard(_slots[2], cours, user, jour),
      ]),
    );
  }

  Widget _buildSlotCard(Map<String, String> slot, List<QueryDocumentSnapshot> cours,
      AppUser user, String jour) {
    final coursDuSlot = cours.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['slot'] == slot['key'];
    }).toList();

    final isCurrent = slot['key'] == _currentSlotKey && jour == _jours[_todayIndex >= 0 ? _todayIndex : 0]
        && _todayIndex >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isCurrent ? Border.all(color: Colors.green, width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Heure
          Container(
            width: 72,
            decoration: BoxDecoration(
              color: isCurrent
                  ? Colors.green.withOpacity(0.08)
                  : const Color(0xFF1C3A6B).withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...slot['label']!.split(' - ').map((t) =>
                    Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                        color: isCurrent ? Colors.green.shade700 : const Color(0xFF1C3A6B)),
                        textAlign: TextAlign.center)),
                if (isCurrent) ...[
                  const SizedBox(height: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('En cours', style: TextStyle(color: Colors.white,
                          fontSize: 8, fontWeight: FontWeight.bold))),
                ],
              ],
            ),
          ),
          // Contenu
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: coursDuSlot.isEmpty
                  ? _emptySlot()
                  : Column(children: coursDuSlot.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _coursCardList(doc.id, data, user);
                    }).toList()),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _coursCardList(String id, Map<String, dynamic> data, AppUser user) {
    final matiere = data['matiere'] ?? '';
    final professeur = data['professeurNom'] ?? '';
    final filiere = data['filiere'] ?? '';
    final niveau = data['niveau'] ?? '';
    final salle = data['salle'] ?? '';
    final status = data['status'] ?? 'normal';
    final isCancelled = status == 'cancelled';
    final isReplaced = status == 'replaced';
    final color = _subjectColor(matiere);

    return GestureDetector(
      onLongPress: _canEdit(user) ? () => _showStatusMenu(id, data) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isCancelled
              ? Colors.red.withOpacity(0.05)
              : isReplaced
                  ? Colors.orange.withOpacity(0.05)
                  : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCancelled ? Colors.red.withOpacity(0.3)
                : isReplaced ? Colors.orange.withOpacity(0.3)
                : color.withOpacity(0.2),
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 4, height: 48, margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isCancelled ? Colors.red : isReplaced ? Colors.orange : color,
                borderRadius: BorderRadius.circular(2),
              )),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(matiere,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                        color: isCancelled ? Colors.red.shade700 : color,
                        decoration: isCancelled ? TextDecoration.lineThrough : null)),
              ),
              if (isCancelled)
                _statusBadge('Annulé', Colors.red),
              if (isReplaced)
                _statusBadge('Remplacé', Colors.orange),
              if (_canEdit(user))
                GestureDetector(
                  onTap: () => _showStatusMenu(id, data),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade400),
                  ),
                ),
            ]),
            const SizedBox(height: 3),
            if (user.role != UserRole.teacher && professeur.isNotEmpty)
              Text(professeur, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if ((user.role == UserRole.teacher || user.role == UserRole.admin)
                && filiere.isNotEmpty)
              Text('$filiere • $niveau',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            if (salle.isNotEmpty)
              Row(children: [
                Icon(Icons.room_outlined, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text('Salle $salle',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ]),
          ])),
        ]),
      ),
    );
  }

  Widget _statusBadge(String label, Color color) => Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color,
          fontWeight: FontWeight.bold)));

  Widget _emptySlot() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(Icons.add_circle_outline, size: 15, color: Colors.grey.shade300),
        const SizedBox(width: 8),
        Text('Pas de cours', style: TextStyle(fontSize: 13,
            color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
      ]));

  Widget _pauseCard(String label, String heure, String duree) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(children: [
        Text('$label • $heure', style: TextStyle(fontSize: 13,
            color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8)),
            child: Text(duree, style: TextStyle(fontSize: 11,
                color: Colors.orange.shade700, fontWeight: FontWeight.w600))),
      ]));

  Widget _buildAdminFilter() => Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _filterNiveau,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Tous niveaux',
              hintStyle: const TextStyle(fontSize: 12),
              filled: true, fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
            items: [const DropdownMenuItem(value: null, child: Text('Tous niveaux')),
              ...AppConstants.niveaux.map((n) => DropdownMenuItem(value: n,
                  child: Text(n, style: const TextStyle(fontSize: 12))))],
            onChanged: (v) => setState(() { _filterNiveau = v; _filterFiliere = null; }),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _filterFiliere,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Toutes filières',
              hintStyle: const TextStyle(fontSize: 12),
              filled: true, fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
            items: [const DropdownMenuItem(value: null, child: Text('Toutes filières')),
              ...AppConstants.getFilieresByNiveau(_filterNiveau).map((f) =>
                  DropdownMenuItem(value: f, child: Text(f,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis)))],
            onChanged: (v) => setState(() => _filterFiliere = v),
          ),
        ),
      ]));
}

extension on Iterable<QueryDocumentSnapshot> {
  QueryDocumentSnapshot? get firstOrNull {
    final iter = iterator;
    if (iter.moveNext()) return iter.current;
    return null;
  }
}