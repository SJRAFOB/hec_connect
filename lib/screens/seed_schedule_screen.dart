import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

class SeedScheduleScreen extends StatefulWidget {
  const SeedScheduleScreen({super.key});
  @override
  State<SeedScheduleScreen> createState() => _SeedScheduleScreenState();
}

class _SeedScheduleScreenState extends State<SeedScheduleScreen> {
  bool _isLoading = false;
  int _uploaded = 0;
  int _total = 0;
  String _status = '';

  // ── Toutes les données de l'emploi du temps S2 2025-2026 ──
  List<Map<String, String>> get _allEntries => [

    // ════════════════════════════════
    // LICENCE 1 — Classe commune
    // ════════════════════════════════
    _e('Commune','Licence 1','Lundi','8h00-10h00','Introduction au Marketing','MR KOUASSI'),
    _e('Commune','Licence 1','Lundi','10h30-12h00','Introduction au Marketing','MR KOUASSI'),
    _e('Commune','Licence 1','Lundi','13h00-15h00','Mathematique Financiere','MR HOUSSOU'),
    _e('Commune','Licence 1','Mardi','8h00-10h00','Economie','DR KOUAKOU RICHARD'),
    _e('Commune','Licence 1','Mardi','10h30-12h00','Economie','DR KOUAKOU RICHARD'),
    _e('Commune','Licence 1','Mardi','13h00-15h00','Fiscalite','MR HOUSSOU'),
    _e('Commune','Licence 1','Mercredi','8h00-10h00','Fiscalite','MR HOUSSOU'),
    _e('Commune','Licence 1','Mercredi','10h30-12h00','Fiscalite','MR HOUSSOU'),
    _e('Commune','Licence 1','Mercredi','13h00-15h00','Economie','DR KOUAKOU RICHARD'),
    _e('Commune','Licence 1','Jeudi','8h00-10h00','Droit Commercial General','MME BALLY'),
    _e('Commune','Licence 1','Jeudi','10h30-12h00','Droit Commercial General','MME BALLY'),
    _e('Commune','Licence 1','Vendredi','8h00-10h00','Comptabilite Analytique','MR TABLEY'),
    _e('Commune','Licence 1','Vendredi','10h30-12h00','Comptabilite Analytique','MR TABLEY'),

    // ════════════════════════════════
    // LICENCE 2 MARKETING
    // ════════════════════════════════
    _e('Marketing','Licence 2','Lundi','8h00-10h00','Droit Commercial','MME BALLY'),
    _e('Marketing','Licence 2','Lundi','10h30-12h00','Droit Commercial','MME BALLY'),
    _e('Marketing','Licence 2','Lundi','13h00-15h00','Economie','DR KOUAKOU RICHARD'),
    _e('Marketing','Licence 2','Mardi','8h00-10h00','Analyse et Prevision de la Demande','MR BOSSON'),
    _e('Marketing','Licence 2','Mardi','10h30-12h00','Analyse et Prevision de la Demande','MR BOSSON'),
    _e('Marketing','Licence 2','Mardi','13h00-15h00','Etude du Marche','DR MONNET'),
    _e('Marketing','Licence 2','Mercredi','8h00-10h00','Comptabilite General','MR TABLEY'),
    _e('Marketing','Licence 2','Mercredi','10h30-12h00','Comptabilite General','MR TABLEY'),
    _e('Marketing','Licence 2','Jeudi','8h00-10h00','Strategie Commerciale','DR MOUSSILOU'),
    _e('Marketing','Licence 2','Jeudi','10h30-12h00','Strategie Commerciale','DR MOUSSILOU'),
    _e('Marketing','Licence 2','Vendredi','8h00-10h00','Economie','DR KOUAKOU RICHARD'),
    _e('Marketing','Licence 2','Vendredi','10h30-12h00','Economie','DR KOUAKOU RICHARD'),

    // ════════════════════════════════
    // LICENCE 2 LOGISTIQUE
    // ════════════════════════════════
    _e('Logistique','Licence 2','Lundi','8h00-10h00','Droit Commercial','MME BALLY'),
    _e('Logistique','Licence 2','Lundi','10h30-12h00','Droit Commercial','MME BALLY'),
    _e('Logistique','Licence 2','Lundi','13h00-15h00','Consignation','DR GNADJA'),
    _e('Logistique','Licence 2','Mardi','8h00-10h00','Gestion Transport Conteneurise','DR GNADJA'),
    _e('Logistique','Licence 2','Mardi','10h30-12h00','Gestion Transport Conteneurise','DR GNADJA'),
    _e('Logistique','Licence 2','Mardi','13h00-15h00','Economie','DR KOUAKOU RICHARD'),
    _e('Logistique','Licence 2','Mercredi','8h00-10h00','Comptabilite General','MR TABLEY'),
    _e('Logistique','Licence 2','Mercredi','10h30-12h00','Comptabilite General','MR TABLEY'),
    _e('Logistique','Licence 2','Mercredi','13h00-15h00','Facturation','MR AMICHIA'),
    _e('Logistique','Licence 2','Jeudi','8h00-10h00','Recherche Operationnelle','MR HOUSSOU'),
    _e('Logistique','Licence 2','Jeudi','10h30-12h00','Recherche Operationnelle','MR HOUSSOU'),
    _e('Logistique','Licence 2','Vendredi','8h00-10h00','Economie','DR KOUAKOU RICHARD'),
    _e('Logistique','Licence 2','Vendredi','10h30-12h00','Economie','DR KOUAKOU RICHARD'),

    // ════════════════════════════════
    // LICENCE 2 DAF
    // ════════════════════════════════
    _e('DAF','Licence 2','Lundi','8h00-10h00','Comptabilite Analytique','MR BADJI'),
    _e('DAF','Licence 2','Lundi','10h30-12h00','Comptabilite Analytique','MR BADJI'),
    _e('DAF','Licence 2','Lundi','13h00-15h00','Droit Administratif','MR GALI'),
    _e('DAF','Licence 2','Mardi','8h00-10h00','Comptabilite des Societes','MR TABLEY'),
    _e('DAF','Licence 2','Mardi','10h30-12h00','Comptabilite des Societes','MR TABLEY'),
    _e('DAF','Licence 2','Mardi','13h00-15h00','Economie','DR KOUAKOU RICHARD'),
    _e('DAF','Licence 2','Mercredi','8h00-10h00','Comptabilite Analytique','MR BADJI'),
    _e('DAF','Licence 2','Mercredi','10h30-12h00','Comptabilite Analytique','MR BADJI'),
    _e('DAF','Licence 2','Mercredi','13h00-15h00','Comptabilite des Societes','MR TABLEY'),
    _e('DAF','Licence 2','Jeudi','8h00-10h00','Droit des Obligations','MME KORE'),
    _e('DAF','Licence 2','Jeudi','10h30-12h00','Droit des Obligations','MME KORE'),
    _e('DAF','Licence 2','Vendredi','8h00-10h00','Economie','DR KOUAKOU RICHARD'),
    _e('DAF','Licence 2','Vendredi','10h30-12h00','Economie','DR KOUAKOU RICHARD'),

    // ════════════════════════════════
    // LICENCE 2 FINANCE
    // ════════════════════════════════
    _e('Finance','Licence 2','Lundi','8h00-10h00','Droit Commercial','MME BALLY'),
    _e('Finance','Licence 2','Lundi','10h30-12h00','Droit Commercial','MME BALLY'),
    _e('Finance','Licence 2','Mardi','8h00-10h00','Comptabilite des Societes','MR TABLEY'),
    _e('Finance','Licence 2','Mardi','10h30-12h00','Comptabilite des Societes','MR TABLEY'),
    _e('Finance','Licence 2','Mardi','13h00-15h00','Economie','DR KOUAKOU RICHARD'),
    _e('Finance','Licence 2','Mercredi','13h00-15h00','Comptabilite des Societes','MR TABLEY'),
    _e('Finance','Licence 2','Jeudi','8h00-10h00','Recherche Operationnelle','MR HOUSSOU'),
    _e('Finance','Licence 2','Jeudi','10h30-12h00','Recherche Operationnelle','MR HOUSSOU'),
    _e('Finance','Licence 2','Vendredi','8h00-10h00','Economie','DR KOUAKOU RICHARD'),
    _e('Finance','Licence 2','Vendredi','10h30-12h00','Economie','DR KOUAKOU RICHARD'),

    // ════════════════════════════════
    // LICENCE 2 INFORMATIQUE
    // ════════════════════════════════
    _e('Informatique','Licence 2','Lundi','8h00-10h00','Informatique','MR AMOI'),
    _e('Informatique','Licence 2','Lundi','10h30-12h00','Informatique','MR AMOI'),
    _e('Informatique','Licence 2','Mardi','8h00-10h00','Informatique','MR AMOI'),
    _e('Informatique','Licence 2','Mardi','10h30-12h00','Informatique','MR AMOI'),
    _e('Informatique','Licence 2','Mercredi','8h00-10h00','Informatique','MR AMOI'),
    _e('Informatique','Licence 2','Mercredi','10h30-12h00','Informatique','MR AMOI'),
    _e('Informatique','Licence 2','Jeudi','8h00-10h00','Informatique','MR ASSANE'),
    _e('Informatique','Licence 2','Jeudi','10h30-12h00','Informatique','MR ASSANE'),
    _e('Informatique','Licence 2','Vendredi','8h00-10h00','Informatique','MR ASSANE'),
    _e('Informatique','Licence 2','Vendredi','10h30-12h00','Informatique','MR ASSANE'),

    // ════════════════════════════════
    // LICENCE 3 INFORMATIQUE
    // ════════════════════════════════
    _e('Informatique','Licence 3','Lundi','8h00-10h00','Informatique','MR AMOI'),
    _e('Informatique','Licence 3','Lundi','10h30-12h00','Informatique','MR AMOI'),
    _e('Informatique','Licence 3','Mardi','8h00-10h00','Informatique','MR AMOI'),
    _e('Informatique','Licence 3','Mardi','10h30-12h00','Informatique','MR AMOI'),
    _e('Informatique','Licence 3','Mercredi','8h00-10h00','Informatique','MR AMOI'),
    _e('Informatique','Licence 3','Mercredi','10h30-12h00','Informatique','MR AMOI'),
    _e('Informatique','Licence 3','Jeudi','8h00-10h00','Informatique','MR ASSANE'),
    _e('Informatique','Licence 3','Jeudi','10h30-12h00','Informatique','MR ASSANE'),
    _e('Informatique','Licence 3','Vendredi','8h00-10h00','Informatique','MR ASSANE'),
    _e('Informatique','Licence 3','Vendredi','10h30-12h00','Informatique','MR ASSANE'),

    // ════════════════════════════════
    // LICENCE 3 MARKETING
    // ════════════════════════════════
    _e('Marketing','Licence 3','Lundi','8h00-10h00','Communication Entreprise','DR BERANGER NIKPASSO'),
    _e('Marketing','Licence 3','Lundi','10h30-12h00','Communication Entreprise','DR BERANGER NIKPASSO'),
    _e('Marketing','Licence 3','Lundi','13h00-15h00','Evaluation Entreprise','DR BERANGER NIKPASSO'),
    _e('Marketing','Licence 3','Mardi','8h00-10h00','Evaluation Entreprise','DR BERANGER NIKPASSO'),
    _e('Marketing','Licence 3','Mardi','10h30-12h00','Evaluation Entreprise','DR BERANGER NIKPASSO'),
    _e('Marketing','Licence 3','Mardi','13h00-15h00','Marketing Evenementiel','MR BOSSON'),
    _e('Marketing','Licence 3','Mercredi','8h00-10h00','Recherche Commerciale et Negociation','DR MONNET'),
    _e('Marketing','Licence 3','Mercredi','10h30-12h00','Recherche Commerciale et Negociation','DR MONNET'),
    _e('Marketing','Licence 3','Mercredi','13h00-15h00','Marketing Relationnel','DR MOUSSILOU'),
    _e('Marketing','Licence 3','Jeudi','13h00-15h00','Marketing Relationnel','DR MOUSSILOU'),
    _e('Marketing','Licence 3','Vendredi','8h00-10h00','Comportement du Consommateur','DR MOUSSILOU'),
    _e('Marketing','Licence 3','Vendredi','10h30-12h00','Comportement du Consommateur','DR MOUSSILOU'),

    // ════════════════════════════════
    // LICENCE 3 LOGISTIQUE
    // ════════════════════════════════
    _e('Logistique','Licence 3','Lundi','8h00-10h00','Communication Entreprise','DR BERANGER NIKPASSO'),
    _e('Logistique','Licence 3','Lundi','10h30-12h00','Communication Entreprise','DR BERANGER NIKPASSO'),
    _e('Logistique','Licence 3','Lundi','13h00-15h00','Evaluation Entreprise','DR BERANGER NIKPASSO'),
    _e('Logistique','Licence 3','Mardi','8h00-10h00','Evaluation Entreprise','DR BERANGER NIKPASSO'),
    _e('Logistique','Licence 3','Mardi','10h30-12h00','Evaluation Entreprise','DR BERANGER NIKPASSO'),
    _e('Logistique','Licence 3','Mercredi','8h00-10h00','Recherche Commerciale et Negociation','DR MONNET'),
    _e('Logistique','Licence 3','Mercredi','10h30-12h00','Recherche Commerciale et Negociation','DR MONNET'),
    _e('Logistique','Licence 3','Jeudi','8h00-10h00','LPDP','MR NDRI'),
    _e('Logistique','Licence 3','Jeudi','10h30-12h00','LPDP','MR NDRI'),
    _e('Logistique','Licence 3','Vendredi','8h00-10h00','Processus Achat','MR NDRI'),
    _e('Logistique','Licence 3','Vendredi','10h30-12h00','Processus Achat','MR NDRI'),

    // ════════════════════════════════
    // LICENCE 3 FINANCE
    // ════════════════════════════════
    _e('Finance','Licence 3','Lundi','8h00-10h00','Communication Entreprise','DR BERANGER NIKPASSO'),
    _e('Finance','Licence 3','Lundi','10h30-12h00','Communication Entreprise','DR BERANGER NIKPASSO'),
    _e('Finance','Licence 3','Lundi','13h00-15h00','Evaluation Entreprise','DR BERANGER NIKPASSO'),
    _e('Finance','Licence 3','Mardi','8h00-10h00','Evaluation Entreprise','DR BERANGER NIKPASSO'),
    _e('Finance','Licence 3','Mardi','10h30-12h00','Evaluation Entreprise','DR BERANGER NIKPASSO'),
    _e('Finance','Licence 3','Mardi','13h00-15h00','MFI','MR HOUSSOU'),
    _e('Finance','Licence 3','Mercredi','8h00-10h00','Comptabilite Analytique','MR YAO HENRI'),
    _e('Finance','Licence 3','Mercredi','10h30-12h00','Comptabilite Analytique','MR YAO HENRI'),
    _e('Finance','Licence 3','Jeudi','8h00-10h00','Audit Interne','MR YAO HENRI'),
    _e('Finance','Licence 3','Jeudi','10h30-12h00','Audit Interne','MR YAO HENRI'),
    _e('Finance','Licence 3','Jeudi','13h00-15h00','Analyse Financiere','MR MELA'),
    _e('Finance','Licence 3','Vendredi','8h00-10h00','MFI','MR HOUSSOU'),
    _e('Finance','Licence 3','Vendredi','10h30-12h00','MFI','MR HOUSSOU'),

    // ════════════════════════════════
    // LICENCE 3 DAF
    // ════════════════════════════════
    _e('DAF','Licence 3','Lundi','8h00-10h00','Communication Entreprise','DR BERANGER NIKPASSO'),
    _e('DAF','Licence 3','Lundi','10h30-12h00','Communication Entreprise','DR BERANGER NIKPASSO'),
    _e('DAF','Licence 3','Lundi','13h00-15h00','Evaluation Entreprise','DR BERANGER NIKPASSO'),
    _e('DAF','Licence 3','Mardi','8h00-10h00','Evaluation Entreprise','DR BERANGER NIKPASSO'),
    _e('DAF','Licence 3','Mardi','10h30-12h00','Evaluation Entreprise','DR BERANGER NIKPASSO'),
    _e('DAF','Licence 3','Mercredi','8h00-10h00','Comptabilite Analytique','MR YAO HENRI'),
    _e('DAF','Licence 3','Mercredi','10h30-12h00','Comptabilite Analytique','MR YAO HENRI'),
    _e('DAF','Licence 3','Jeudi','8h00-10h00','Procedure Simplifiee','MME BALLY'),
    _e('DAF','Licence 3','Jeudi','10h30-12h00','Procedure Simplifiee','MME BALLY'),
    _e('DAF','Licence 3','Vendredi','13h00-15h00','Droit Civil : Obligation et Surete','MR GALI'),

    // ════════════════════════════════
    // MASTER 1 — Classe commune
    // ════════════════════════════════
    _e('Commune','Master 1','Lundi','8h00-10h00','Gestion Commerciale','MR BOSSON'),
    _e('Commune','Master 1','Lundi','10h30-12h00','Gestion Commerciale','MR BOSSON'),
    _e('Commune','Master 1','Mardi','8h00-10h00','Droit des Entreprises en Difficultes','MME BALLY'),
    _e('Commune','Master 1','Mardi','10h30-12h00','Droit des Entreprises en Difficultes','MME BALLY'),
    _e('Commune','Master 1','Mercredi','8h00-10h00','Management Equipe','DR BERENGER NIKPASSO'),
    _e('Commune','Master 1','Mercredi','10h30-12h00','Management Equipe','DR BERENGER NIKPASSO'),
    _e('Commune','Master 1','Jeudi','13h00-15h00','Management Equipe','DR BERENGER NIKPASSO'),
    _e('Commune','Master 1','Vendredi','8h00-10h00','Droit Administratif','MR GALI'),
    _e('Commune','Master 1','Vendredi','10h30-12h00','Droit Administratif','MR GALI'),

    // ════════════════════════════════
    // MASTER 2 MARKETING
    // ════════════════════════════════
    _e('Marketing','Master 2','Lundi','8h00-10h00','Transit Douane','DR GNADJA'),
    _e('Marketing','Master 2','Lundi','10h30-12h00','Transit Douane','DR GNADJA'),
    _e('Marketing','Master 2','Lundi','13h00-15h00','Telemarketing','MR BOSSON'),
    _e('Marketing','Master 2','Mardi','8h00-10h00','Droit des Entreprises en Difficultes','MME KORE'),
    _e('Marketing','Master 2','Mardi','10h30-12h00','Droit des Entreprises en Difficultes','MME KORE'),
    _e('Marketing','Master 2','Mardi','13h00-15h00','Droit des Assurances','MME BALLY'),
    _e('Marketing','Master 2','Mercredi','8h00-10h00','Communication Hors Media','DR MOUSSILOU'),
    _e('Marketing','Master 2','Mercredi','10h30-12h00','Communication Hors Media','DR MOUSSILOU'),
    _e('Marketing','Master 2','Mercredi','13h00-15h00','Droit des Assurances','MME BALLY'),
    _e('Marketing','Master 2','Jeudi','8h00-10h00','Technique Expression Orale','DR BERANGER NIKPASSO'),
    _e('Marketing','Master 2','Jeudi','10h30-12h00','Technique Expression Orale','DR BERANGER NIKPASSO'),
    _e('Marketing','Master 2','Vendredi','8h00-10h00','Developpement Personnel','DR BERANGER NIKPASSO'),
    _e('Marketing','Master 2','Vendredi','10h30-12h00','Developpement Personnel','DR BERANGER NIKPASSO'),

    // ════════════════════════════════
    // MASTER 2 LOGISTIQUE
    // ════════════════════════════════
    _e('Logistique','Master 2','Lundi','8h00-10h00','Transit Douane','DR GNADJA'),
    _e('Logistique','Master 2','Lundi','10h30-12h00','Transit Douane','DR GNADJA'),
    _e('Logistique','Master 2','Lundi','13h00-15h00','Droit des Entreprises en Difficultes','MME KORE'),
    _e('Logistique','Master 2','Mardi','8h00-10h00','Droit des Entreprises en Difficultes','MME KORE'),
    _e('Logistique','Master 2','Mardi','10h30-12h00','Droit des Entreprises en Difficultes','MME KORE'),
    _e('Logistique','Master 2','Mardi','13h00-15h00','Droit des Assurances','MME BALLY'),
    _e('Logistique','Master 2','Mercredi','8h00-10h00','Management des Transports','MR AMICHIA'),
    _e('Logistique','Master 2','Mercredi','10h30-12h00','Management des Transports','MR AMICHIA'),
    _e('Logistique','Master 2','Mercredi','13h00-15h00','Droit des Assurances','MME BALLY'),
    _e('Logistique','Master 2','Jeudi','8h00-10h00','Technique Expression Orale','DR BERANGER NIKPASSO'),
    _e('Logistique','Master 2','Jeudi','10h30-12h00','Technique Expression Orale','DR BERANGER NIKPASSO'),
    _e('Logistique','Master 2','Vendredi','8h00-10h00','Developpement Personnel','DR BERANGER NIKPASSO'),
    _e('Logistique','Master 2','Vendredi','10h30-12h00','Developpement Personnel','DR BERANGER NIKPASSO'),

    // ════════════════════════════════
    // MASTER 2 FINANCE
    // ════════════════════════════════
    _e('Finance','Master 2','Lundi','8h00-10h00','Droit Bancaire et Droit Financier','MME KORE'),
    _e('Finance','Master 2','Lundi','10h30-12h00','Droit Bancaire et Droit Financier','MME KORE'),
    _e('Finance','Master 2','Mardi','8h00-10h00','Technique Fiscale Salaire','MR HOUSSOU'),
    _e('Finance','Master 2','Mardi','10h30-12h00','Technique Fiscale Salaire','MR HOUSSOU'),
    _e('Finance','Master 2','Mardi','13h00-15h00','Droit des Assurances','MME BALLY'),
    _e('Finance','Master 2','Mercredi','8h00-10h00','Ingenierie Financiere','M MELA'),
    _e('Finance','Master 2','Mercredi','10h30-12h00','Ingenierie Financiere','M MELA'),
    _e('Finance','Master 2','Mercredi','13h00-15h00','Droit des Assurances','MME BALLY'),
    _e('Finance','Master 2','Jeudi','8h00-10h00','Evaluation des Actifs Financiers','M MELA'),
    _e('Finance','Master 2','Jeudi','10h30-12h00','Evaluation des Actifs Financiers','M MELA'),
    _e('Finance','Master 2','Jeudi','13h00-15h00','Technique Expression Orale','DR BERANGER NIKPASSO'),
    _e('Finance','Master 2','Vendredi','8h00-10h00','Audit Comptable','MR BADJI'),
    _e('Finance','Master 2','Vendredi','10h30-12h00','Audit Comptable','MR BADJI'),

    // ════════════════════════════════
    // MASTER 2 DAF
    // ════════════════════════════════
    _e('DAF','Master 2','Lundi','8h00-10h00','Droit Bancaire et Droit Financier','MME KORE'),
    _e('DAF','Master 2','Lundi','10h30-12h00','Droit Bancaire et Droit Financier','MME KORE'),
    _e('DAF','Master 2','Lundi','13h00-15h00','Droit Foncier Rural','MME BALLY'),
    _e('DAF','Master 2','Mardi','8h00-10h00','Technique Fiscale Salaire','MR HOUSSOU'),
    _e('DAF','Master 2','Mardi','10h30-12h00','Technique Fiscale Salaire','MR HOUSSOU'),
    _e('DAF','Master 2','Mardi','13h00-15h00','Droit des Assurances','MME BALLY'),
    _e('DAF','Master 2','Mercredi','13h00-15h00','Droit des Assurances','MME BALLY'),
    _e('DAF','Master 2','Jeudi','8h00-10h00','Technique Expression Orale','DR BERANGER NIKPASSO'),
    _e('DAF','Master 2','Jeudi','10h30-12h00','Technique Expression Orale','DR BERANGER NIKPASSO'),
    _e('DAF','Master 2','Vendredi','8h00-10h00','Developpement Personnel','DR BERANGER NIKPASSO'),
    _e('DAF','Master 2','Vendredi','10h30-12h00','Developpement Personnel','DR BERANGER NIKPASSO'),
  ];

  Map<String, String> _e(String filiere, String niveau, String jour,
      String slot, String matiere, String prof) {
    return {
      'filiere': filiere,
      'niveau': niveau,
      'jour': jour,
      'slot': slot,
      'matiere': matiere,
      'professeurNom': prof,
    };
  }

  Future<void> _seed() async {
    final entries = _allEntries;
    setState(() {
      _isLoading = true;
      _uploaded = 0;
      _total = entries.length;
      _status = 'Suppression des anciens cours...';
    });

    try {
      // Supprimer les anciens documents
      final existing = await FirebaseFirestore.instance
          .collection(AppConstants.collectionSchedules)
          .get();
      for (final doc in existing.docs) {
        await doc.reference.delete();
      }

      setState(() => _status = 'Import en cours...');

      // Ajouter les nouveaux
      for (int i = 0; i < entries.length; i++) {
        final e = entries[i];
        await FirebaseFirestore.instance
            .collection(AppConstants.collectionSchedules)
            .add({
          ...e,
          'salle': '',
          'status': 'normal',
          'semestre': 'S2',
          'annee': '2025-2026',
          'etablissement': 'HEC Bietry',
          'createdAt': Timestamp.now(),
        });
        setState(() {
          _uploaded = i + 1;
          _status = 'Import ${e['niveau']} ${e['filiere']} — ${e['jour']} ${e['slot']}';
        });
        // Petite pause pour ne pas saturer Firestore
        await Future.delayed(const Duration(milliseconds: 50));
      }

      setState(() {
        _isLoading = false;
        _status = '$_total cours importes avec succes !';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_total cours importes !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Erreur : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A6B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Import EDT S2 2025-2026',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C3A6B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1C3A6B).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.info_outline, color: Color(0xFF1C3A6B), size: 18),
                    SizedBox(width: 8),
                    Text('Emploi du temps S2 2025-2026 — HEC Bietry',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            color: Color(0xFF1C3A6B))),
                  ]),
                  const SizedBox(height: 10),
                  Text('${_allEntries.length} cours a importer pour :',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  const SizedBox(height: 6),
                  ...['Licence 1 (Commune)', 'Licence 2 : Marketing, Finance, Logistique, DAF, Informatique',
                    'Licence 3 : Marketing, Finance, Logistique, DAF, Informatique',
                    'Master 1 (Commune)', 'Master 2 : Marketing, Finance, Transport et Logistique, DAF']
                      .map((t) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 3),
                        child: Row(children: [
                          Container(width: 5, height: 5,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF1C3A6B), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(t,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                        ]),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Progression
            if (_isLoading || _uploaded > 0) ...[
              Text(_status,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _total > 0 ? _uploaded / _total : 0,
                backgroundColor: Colors.grey.shade200,
                color: const Color(0xFF1C3A6B),
              ),
              const SizedBox(height: 6),
              Text('$_uploaded / $_total',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1C3A6B),
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
            ],

            // Avertissement
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Cette action supprimera tous les cours existants avant d\'importer les nouveaux.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                )),
              ]),
            ),
            const Spacer(),

            // Bouton
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _confirmAndSeed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C3A6B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.upload, color: Colors.white),
                label: Text(
                  _isLoading
                      ? 'Import en cours... $_uploaded/$_total'
                      : 'Importer l\'emploi du temps S2',
                  style: const TextStyle(color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmAndSeed() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer l\'import'),
        content: Text(
          'Cela va supprimer tous les cours existants et importer ${_allEntries.length} cours du S2 2025-2026. Continuer ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C3A6B)),
            onPressed: () {
              Navigator.pop(context);
              _seed();
            },
            child: const Text('Importer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}