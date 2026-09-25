/// The families a theme tag can belong to — how the theme picker sections
/// its list (see [themesByGroup]). Purely presentational: a game stores just
/// the tag ids. Declaration order is display order.
enum ThemeGroup {
  format('Format'),
  famille('Famille'),
  genre('Genre'),
  discipline('Discipline'),
  mecanique('Mécanique'),
  paquet('Paquet'),
  univers('Univers'),
  cadre('Cadre'),
  public('Public'),
  duree('Durée'),
  niveau('Niveau');

  const ThemeGroup(this.label);
  final String label;
}

/// One selectable theme tag for a game. Each `Game.category` has its own
/// closed list (see [themesForCategory]); a game stores the picked tags by
/// [id], which is the enum's own name and so must stay stable — rename a
/// [label] or move a tag between groups freely, but never rename an enum
/// value already in use.
abstract interface class GameThemeTag {
  String get id;
  String get label;
  ThemeGroup get group;
}

/// Thèmes des jeux de société.
enum BoardGameTheme implements GameThemeTag {
  // format
  duel('Duel', ThemeGroup.format),
  solo('Solo', ThemeGroup.format),
  cooperatif('Coopératif', ThemeGroup.format),
  equipes('Équipes', ThemeGroup.format),
  unContreTous('Un contre tous', ThemeGroup.format),
  grandGroupe('Grand groupe', ThemeGroup.format),
  // genre
  strategie('Stratégie', ThemeGroup.genre),
  gestion('Gestion', ThemeGroup.genre),
  roles('Jeu de rôle', ThemeGroup.genre),
  tcg('TCG', ThemeGroup.genre),
  aventure('Aventure', ThemeGroup.genre),
  deduction('Déduction', ThemeGroup.genre),
  bluff('Bluff', ThemeGroup.genre),
  reflexion('Réflexion', ThemeGroup.genre),
  abstrait('Abstrait', ThemeGroup.genre),
  combat('Combat', ThemeGroup.genre),
  guerre('Guerre & conquête', ThemeGroup.genre),
  course('Course', ThemeGroup.genre),
  economie('Économie', ThemeGroup.genre),
  civilisation('Civilisation', ThemeGroup.genre),
  exploration('Exploration', ThemeGroup.genre),
  enquete('Enquête', ThemeGroup.genre),
  quiz('Culture générale', ThemeGroup.genre),
  ambiance('Ambiance', ThemeGroup.genre),
  devinettes('Devinettes & dessin', ThemeGroup.genre),
  mots('Mots', ThemeGroup.genre),
  memoire('Mémoire', ThemeGroup.genre),
  adresse('Adresse', ThemeGroup.genre),
  escapeGame('Escape game', ThemeGroup.genre),
  narratif('Narratif', ThemeGroup.genre),
  survie('Survie', ThemeGroup.genre),
  negociation('Négociation', ThemeGroup.genre),
  paris('Paris', ThemeGroup.genre),
  // mecanique
  deckBuilding('Deck-building', ThemeGroup.mecanique),
  draft('Draft', ThemeGroup.mecanique),
  placementOuvriers('Placement d’ouvriers', ThemeGroup.mecanique),
  placementTuiles('Placement de tuiles', ThemeGroup.mecanique),
  des('Dés', ThemeGroup.mecanique),
  gestionMain('Gestion de main', ThemeGroup.mecanique),
  encheres('Enchères', ThemeGroup.mecanique),
  majorite('Majorité', ThemeGroup.mecanique),
  programmation('Programmation', ThemeGroup.mecanique),
  legacy('Legacy', ThemeGroup.mecanique),
  campagne('Campagne', ThemeGroup.mecanique),
  rolesCaches('Rôles cachés', ThemeGroup.mecanique),
  traitre('Traître', ThemeGroup.mecanique),
  tempsReel('Temps réel', ThemeGroup.mecanique),
  figurines('Figurines', ThemeGroup.mecanique),
  reseau('Construction de réseau', ThemeGroup.mecanique),
  collection('Collection', ThemeGroup.mecanique),
  pousseTaChance('Push your luck', ThemeGroup.mecanique),
  plateauModulaire('Plateau modulaire', ThemeGroup.mecanique),
  // univers
  fantasy('Fantasy', ThemeGroup.univers),
  scienceFiction('Science-fiction', ThemeGroup.univers),
  historique('Historique', ThemeGroup.univers),
  medieval('Médiéval', ThemeGroup.univers),
  antiquite('Antiquité', ThemeGroup.univers),
  mythologie('Mythologie', ThemeGroup.univers),
  pirates('Pirates', ThemeGroup.univers),
  western('Western', ThemeGroup.univers),
  polar('Polar', ThemeGroup.univers),
  espionnage('Espionnage', ThemeGroup.univers),
  horreur('Horreur', ThemeGroup.univers),
  postApo('Post-apocalyptique', ThemeGroup.univers),
  superHeros('Super-héros', ThemeGroup.univers),
  nature('Nature & animaux', ThemeGroup.univers),
  espace('Espace', ThemeGroup.univers),
  // public
  familial('Familial', ThemeGroup.public),
  enfants('Enfants', ThemeGroup.public),
  debutant('Débutant', ThemeGroup.public),
  expert('Expert', ThemeGroup.public),
  apero('Apéro', ThemeGroup.public),
  // duree
  rapide('Rapide (< 30 min)', ThemeGroup.duree),
  moyen('Moyen (30 min – 1 h)', ThemeGroup.duree),
  long('Long (1 h – 2 h)', ThemeGroup.duree),
  marathon('Très long (> 2 h)', ThemeGroup.duree);

  const BoardGameTheme(this.label, this.group);
  @override
  final String label;
  @override
  final ThemeGroup group;
  @override
  String get id => name;
}

/// Thèmes des jeux de cartes.
enum CardGameTheme implements GameThemeTag {
  // format
  duel('Duel', ThemeGroup.format),
  solo('Solo / Patience', ThemeGroup.format),
  cooperatif('Coopératif', ThemeGroup.format),
  equipes('Équipes', ThemeGroup.format),
  grandGroupe('Grand groupe', ThemeGroup.format),
  // paquet
  cartes32('Jeu de 32 cartes', ThemeGroup.paquet),
  cartes52('Jeu de 52 cartes', ThemeGroup.paquet),
  cartes54('Jeu de 54 cartes (jokers)', ThemeGroup.paquet),
  tarot('Tarot', ThemeGroup.paquet),
  paquetSpecifique('Paquet spécifique', ThemeGroup.paquet),
  // genre
  classique('Jeu classique', ThemeGroup.genre),
  plis('Plis', ThemeGroup.genre),
  combinaisons('Combinaisons', ThemeGroup.genre),
  defausse('Défausse', ThemeGroup.genre),
  bluff('Bluff', ThemeGroup.genre),
  poker('Poker & paris', ThemeGroup.genre),
  ambiance('Ambiance', ThemeGroup.genre),
  collection('Collection', ThemeGroup.genre),
  tcg('TCG', ThemeGroup.genre),
  strategie('Stratégie', ThemeGroup.genre),
  memoire('Mémoire', ThemeGroup.genre),
  rapidite('Rapidité', ThemeGroup.genre),
  reflexion('Réflexion', ThemeGroup.genre),
  deduction('Déduction', ThemeGroup.genre),
  mots('Mots', ThemeGroup.genre),
  quiz('Culture générale', ThemeGroup.genre),
  aventure('Aventure', ThemeGroup.genre),
  combat('Combat', ThemeGroup.genre),
  course('Course', ThemeGroup.genre),
  // mecanique
  deckBuilding('Deck-building', ThemeGroup.mecanique),
  draft('Draft', ThemeGroup.mecanique),
  gestionMain('Gestion de main', ThemeGroup.mecanique),
  encheres('Enchères', ThemeGroup.mecanique),
  majorite('Majorité', ThemeGroup.mecanique),
  tempsReel('Temps réel', ThemeGroup.mecanique),
  rolesCaches('Rôles cachés', ThemeGroup.mecanique),
  pousseTaChance('Push your luck', ThemeGroup.mecanique),
  pioche('Pioche', ThemeGroup.mecanique),
  // univers
  fantasy('Fantasy', ThemeGroup.univers),
  scienceFiction('Science-fiction', ThemeGroup.univers),
  historique('Historique', ThemeGroup.univers),
  horreur('Horreur', ThemeGroup.univers),
  humour('Humour', ThemeGroup.univers),
  nature('Nature & animaux', ThemeGroup.univers),
  // public
  familial('Familial', ThemeGroup.public),
  enfants('Enfants', ThemeGroup.public),
  debutant('Débutant', ThemeGroup.public),
  expert('Expert', ThemeGroup.public),
  apero('Apéro', ThemeGroup.public),
  // duree
  rapide('Rapide (< 15 min)', ThemeGroup.duree),
  moyen('Moyen (15–45 min)', ThemeGroup.duree),
  long('Long (> 45 min)', ThemeGroup.duree);

  const CardGameTheme(this.label, this.group);
  @override
  final String label;
  @override
  final ThemeGroup group;
  @override
  String get id => name;
}

/// Thèmes des jeux vidéo.
enum VideoGameTheme implements GameThemeTag {
  // format
  solo('Solo', ThemeGroup.format),
  duel('Duel (1 contre 1)', ThemeGroup.format),
  cooperatif('Coopératif', ThemeGroup.format),
  equipes('Équipes', ThemeGroup.format),
  unContreTous('Un contre tous', ThemeGroup.format),
  grandGroupe('Grand groupe', ThemeGroup.format),
  multiLocal('Multijoueur local', ThemeGroup.format),
  ecranPartage('Écran partagé', ThemeGroup.format),
  enLigne('En ligne', ThemeGroup.format),
  // genre
  combat('Combat', ThemeGroup.genre),
  tir('Tir (FPS)', ThemeGroup.genre),
  tirTps('Tir à la 3e personne (TPS)', ThemeGroup.genre),
  battleRoyale('Battle royale', ThemeGroup.genre),
  moba('MOBA', ThemeGroup.genre),
  course('Course', ThemeGroup.genre),
  sport('Sport', ThemeGroup.genre),
  strategie('Stratégie', ThemeGroup.genre),
  rts('Stratégie temps réel (RTS)', ThemeGroup.genre),
  tourParTour('Tour par tour', ThemeGroup.genre),
  rpg('Rôle (RPG)', ThemeGroup.genre),
  actionRpg('Action-RPG', ThemeGroup.genre),
  mmo('MMO', ThemeGroup.genre),
  action('Action', ThemeGroup.genre),
  aventure('Aventure', ThemeGroup.genre),
  plateforme('Plateforme', ThemeGroup.genre),
  beatThemAll('Beat them all', ThemeGroup.genre),
  shootThemUp('Shoot them up', ThemeGroup.genre),
  party('Party game', ThemeGroup.genre),
  puzzle('Puzzle', ThemeGroup.genre),
  simulation('Simulation', ThemeGroup.genre),
  gestion('Gestion', ThemeGroup.genre),
  constructionVille('Construction de ville', ThemeGroup.genre),
  survie('Survie', ThemeGroup.genre),
  horreur('Horreur', ThemeGroup.genre),
  rythme('Rythme', ThemeGroup.genre),
  bacASable('Bac à sable', ThemeGroup.genre),
  roguelike('Roguelike', ThemeGroup.genre),
  metroidvania('Metroidvania', ThemeGroup.genre),
  infiltration('Infiltration', ThemeGroup.genre),
  arcade('Arcade', ThemeGroup.genre),
  jeuDeCartes('Jeu de cartes', ThemeGroup.genre),
  autoBattler('Auto-battler', ThemeGroup.genre),
  towerDefense('Tower defense', ThemeGroup.genre),
  visualNovel('Visual novel', ThemeGroup.genre),
  pointAndClick('Point & click', ThemeGroup.genre),
  quiz('Quiz', ThemeGroup.genre),
  adaptationSociete('Adaptation de jeu de société', ThemeGroup.genre),
  // mecanique
  mondeOuvert('Monde ouvert', ThemeGroup.mecanique),
  crafting('Crafting', ThemeGroup.mecanique),
  competitif('Compétitif', ThemeGroup.mecanique),
  esport('E-sport', ThemeGroup.mecanique),
  speedrun('Speedrun', ThemeGroup.mecanique),
  classement('Classement en ligne', ThemeGroup.mecanique),
  // univers
  fantasy('Fantasy', ThemeGroup.univers),
  scienceFiction('Science-fiction', ThemeGroup.univers),
  historique('Historique', ThemeGroup.univers),
  medieval('Médiéval', ThemeGroup.univers),
  guerre('Guerre', ThemeGroup.univers),
  postApo('Post-apocalyptique', ThemeGroup.univers),
  zombies('Zombies', ThemeGroup.univers),
  cyberpunk('Cyberpunk', ThemeGroup.univers),
  superHeros('Super-héros', ThemeGroup.univers),
  mythologie('Mythologie', ThemeGroup.univers),
  manga('Manga & anime', ThemeGroup.univers),
  retro('Rétro', ThemeGroup.univers),
  pixelArt('Pixel art', ThemeGroup.univers),
  humour('Humour', ThemeGroup.univers),
  sportReel('Sport réel', ThemeGroup.univers),
  // public
  familial('Familial', ThemeGroup.public),
  enfants('Enfants', ThemeGroup.public),
  accessible('Accessible', ThemeGroup.public),
  hardcore('Hardcore', ThemeGroup.public),
  // duree
  sessionCourte('Sessions courtes (< 15 min)', ThemeGroup.duree),
  sessionMoyenne('Moyen (15–60 min)', ThemeGroup.duree),
  sessionLongue('Long (> 1 h)', ThemeGroup.duree);

  const VideoGameTheme(this.label, this.group);
  @override
  final String label;
  @override
  final ThemeGroup group;
  @override
  String get id => name;
}

/// Thèmes des sports.
enum SportTheme implements GameThemeTag {
  // format
  duel('Duel (1 contre 1)', ThemeGroup.format),
  individuel('Individuel', ThemeGroup.format),
  equipes('Par équipes', ThemeGroup.format),
  binome('En binôme', ThemeGroup.format),
  grandGroupe('Grand groupe', ThemeGroup.format),
  relais('Relais', ThemeGroup.format),
  contreLaMontre('Contre la montre', ThemeGroup.format),
  // famille
  collectif('Collectif', ThemeGroup.famille),
  raquette('Raquette', ThemeGroup.famille),
  combat('Combat', ThemeGroup.famille),
  precision('Précision', ThemeGroup.famille),
  athletisme('Athlétisme', ThemeGroup.famille),
  endurance('Endurance', ThemeGroup.famille),
  cyclisme('Cyclisme', ThemeGroup.famille),
  nautique('Nautique', ThemeGroup.famille),
  glisse('Glisse', ThemeGroup.famille),
  fitness('Fitness', ThemeGroup.famille),
  ballon('Ballon', ThemeGroup.famille),
  motorise('Motorisé', ThemeGroup.famille),
  adresse('Adresse', ThemeGroup.famille),
  // discipline
  football('Football', ThemeGroup.discipline),
  basket('Basket', ThemeGroup.discipline),
  handball('Handball', ThemeGroup.discipline),
  volley('Volley', ThemeGroup.discipline),
  rugby('Rugby', ThemeGroup.discipline),
  tennis('Tennis', ThemeGroup.discipline),
  tennisDeTable('Tennis de table', ThemeGroup.discipline),
  badminton('Badminton', ThemeGroup.discipline),
  squash('Squash', ThemeGroup.discipline),
  padel('Padel', ThemeGroup.discipline),
  petanque('Pétanque', ThemeGroup.discipline),
  boules('Boules', ThemeGroup.discipline),
  molkky('Mölkky', ThemeGroup.discipline),
  fleches('Fléchettes', ThemeGroup.discipline),
  billard('Billard', ThemeGroup.discipline),
  bowling('Bowling', ThemeGroup.discipline),
  golf('Golf', ThemeGroup.discipline),
  miniGolf('Mini-golf', ThemeGroup.discipline),
  babyFoot('Baby-foot', ThemeGroup.discipline),
  boxe('Boxe', ThemeGroup.discipline),
  artsMartiaux('Arts martiaux', ThemeGroup.discipline),
  escalade('Escalade', ThemeGroup.discipline),
  courseAPied('Course à pied', ThemeGroup.discipline),
  natation('Natation', ThemeGroup.discipline),
  ski('Ski & snowboard', ThemeGroup.discipline),
  skate('Skate & roller', ThemeGroup.discipline),
  frisbee('Frisbee', ThemeGroup.discipline),
  cricket('Cricket', ThemeGroup.discipline),
  baseball('Baseball', ThemeGroup.discipline),
  hockey('Hockey', ThemeGroup.discipline),
  karting('Karting', ThemeGroup.discipline),
  tirALArc('Tir à l’arc', ThemeGroup.discipline),
  paintball('Paintball', ThemeGroup.discipline),
  laserGame('Laser game', ThemeGroup.discipline),
  // cadre
  exterieur('Jeux d’extérieur', ThemeGroup.cadre),
  salle('En salle', ThemeGroup.cadre),
  bar('Jeux de bar', ThemeGroup.cadre),
  plage('Plage', ThemeGroup.cadre),
  montagne('Montagne', ThemeGroup.cadre),
  piscine('Piscine', ThemeGroup.cadre),
  // public
  familial('Familial', ThemeGroup.public),
  enfants('Enfants', ThemeGroup.public),
  // niveau
  loisir('Loisir', ThemeGroup.niveau),
  competition('Compétition', ThemeGroup.niveau),
  entrainement('Entraînement', ThemeGroup.niveau),
  defi('Défi', ThemeGroup.niveau);

  const SportTheme(this.label, this.group);
  @override
  final String label;
  @override
  final ThemeGroup group;
  @override
  String get id => name;
}

/// The theme list offered for a `Game.category` — empty for a category with
/// no dedicated list ("Autre"), in which case the form hides the section.
List<GameThemeTag> themesForCategory(String category) => switch (category) {
      'Société' => BoardGameTheme.values,
      'Cartes' => CardGameTheme.values,
      'Jeu vidéo' => VideoGameTheme.values,
      'Sport' => SportTheme.values,
      _ => const [],
    };

/// [themesForCategory] split by [ThemeGroup], in group display order —
/// groups a category doesn't use are absent.
Map<ThemeGroup, List<GameThemeTag>> themesByGroup(String category) {
  final tags = themesForCategory(category);
  return {
    for (final g in ThemeGroup.values)
      if (tags.any((t) => t.group == g)) g: tags.where((t) => t.group == g).toList(),
  };
}
