import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ItemCategory { food, toy, furniture, decor }

enum CatInteraction { none, sleep, scratch, play }

@immutable
class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.width = 1,
    this.depth = 1,
    this.interaction = CatInteraction.none,
    this.walkable = false,
    this.effect = 0,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final ItemCategory category;
  final int width;
  final int depth;
  final CatInteraction interaction;
  final bool walkable;
  final int effect;

  bool get placeable =>
      category == ItemCategory.furniture || category == ItemCategory.decor;
}

const catalog = <CatalogItem>[
  CatalogItem(
    id: 'kibble',
    name: 'Crunchy Kibble',
    description: 'An everyday meal that eases 28 hunger.',
    price: 8,
    category: ItemCategory.food,
    effect: 28,
  ),
  CatalogItem(
    id: 'salmon',
    name: 'Salmon Supper',
    description: 'A special meal that eases 45 hunger.',
    price: 18,
    category: ItemCategory.food,
    effect: 45,
  ),
  CatalogItem(
    id: 'yarn',
    name: 'Ball of Yarn',
    description: 'A reusable toy that adds 6 happiness during play.',
    price: 20,
    category: ItemCategory.toy,
    effect: 6,
  ),
  CatalogItem(
    id: 'feather',
    name: 'Feather Wand',
    description: 'A reusable toy that adds 12 happiness during play.',
    price: 26,
    category: ItemCategory.toy,
    effect: 12,
  ),
  CatalogItem(
    id: 'bed',
    name: 'Cushion Bed',
    description: 'A soft place to curl up and recover energy.',
    price: 36,
    category: ItemCategory.furniture,
    width: 2,
    interaction: CatInteraction.sleep,
  ),
  CatalogItem(
    id: 'scratcher',
    name: 'Scratching Post',
    description: 'A place to stretch, scratch, and lift the cat’s mood.',
    price: 42,
    category: ItemCategory.furniture,
    interaction: CatInteraction.scratch,
  ),
  CatalogItem(
    id: 'sofa',
    name: 'Apricot Sofa',
    description: 'A roomy seat with space for a catnap.',
    price: 66,
    category: ItemCategory.furniture,
    width: 2,
    interaction: CatInteraction.sleep,
  ),
  CatalogItem(
    id: 'plant',
    name: 'Potted Calathea',
    description: 'A leafy little accent for an empty corner.',
    price: 24,
    category: ItemCategory.decor,
  ),
  CatalogItem(
    id: 'rug',
    name: 'Woven Rug',
    description: 'A soft spot for rolling around and playing.',
    price: 24,
    category: ItemCategory.decor,
    width: 2,
    depth: 2,
    interaction: CatInteraction.play,
    walkable: true,
  ),
  CatalogItem(
    id: 'shelf',
    name: 'Oak Bookshelf',
    description: 'A low shelf to make the room feel lived in.',
    price: 52,
    category: ItemCategory.decor,
    width: 2,
  ),
];

final itemsById = Map<String, CatalogItem>.unmodifiable({
  for (final item in catalog) item.id: item,
});

@immutable
class Placement {
  const Placement(this.id, this.itemId, this.x, this.y);

  final String id;
  final String itemId;
  final int x;
  final int y;

  CatalogItem get item => itemsById[itemId]!;

  bool covers(int column, int row) =>
      column >= x &&
      column < x + item.width &&
      row >= y &&
      row < y + item.depth;
}

@immutable
class Objective {
  const Objective({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    required this.target,
    required this.progress,
    required this.claimed,
    required this.daily,
  });

  final String id;
  final String title;
  final String description;
  final int reward;
  final int target;
  final int progress;
  final bool claimed;
  final bool daily;

  bool get ready => !claimed && progress >= target;
}

typedef _Goal = ({
  String id,
  String title,
  String description,
  int reward,
  int target,
  bool daily,
});

const _goals = <_Goal>[
  (
    id: 'feed',
    title: 'Dinner Bell',
    description: 'Serve two meals.',
    reward: 18,
    target: 2,
    daily: true,
  ),
  (
    id: 'play',
    title: 'Play Break',
    description: 'Play together twice.',
    reward: 22,
    target: 2,
    daily: true,
  ),
  (
    id: 'shop',
    title: 'A Little Treat',
    description: 'Buy any item from the shop.',
    reward: 16,
    target: 1,
    daily: true,
  ),
  (
    id: 'decorate',
    title: 'Make It Yours',
    description: 'Place or move a piece of furniture or décor.',
    reward: 25,
    target: 1,
    daily: false,
  ),
  (
    id: 'expand',
    title: 'Room to Grow',
    description: 'Expand your home for the first time.',
    reward: 45,
    target: 1,
    daily: false,
  ),
];

const _upgrades = [(price: 90, affection: 20), (price: 195, affection: 65)];

class HomeState extends ChangeNotifier {
  HomeState.fresh({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final now = _clock();
    _lastAccruedAt = now.millisecondsSinceEpoch;
    _date = _dateKey(now);
  }

  static const _storageKey = 'purrfect_home.save.v1';
  static const incomeCap = 120;
  static const incomeInterval = Duration(seconds: 30);
  static const _needsInterval = Duration(seconds: 90);
  static const _maxNeedsElapsed = Duration(hours: 2);
  static const _petCooldown = Duration(seconds: 5);

  static Future<HomeState> load({
    DateTime Function()? clock,
    bool startTimer = true,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final state = HomeState.fresh(clock: clock).._preferences = preferences;
    final snapshot = preferences.getString(_storageKey);
    if (snapshot != null) {
      try {
        final decoded = jsonDecode(snapshot);
        if (decoded is Map<String, dynamic> && decoded['version'] == 1) {
          state._restore(decoded);
        }
      } on FormatException catch (error) {
        debugPrint('Purrfect Home could not read the saved game: $error');
      }
    }
    state.syncTime();
    if (snapshot == null) state._saveInBackground();
    if (startTimer) {
      state._timer = Timer.periodic(const Duration(seconds: 1), (_) {
        state.syncTime();
      });
    }
    return state;
  }

  final DateTime Function() _clock;
  SharedPreferences? _preferences;
  Timer? _timer;
  Future<void> _saveQueue = Future.value();
  late int _lastAccruedAt;
  late String _date;
  int _incomeRemainder = 0;
  int _needsRemainder = 0;
  int? _lastPetAt;
  int _nextPlacementNumber = 4;
  int _coins = 95;
  int _bankedCoins = 0;
  int _hunger = 54;
  int _energy = 78;
  int _happiness = 65;
  int _affection = 0;
  int _roomLevel = 1;
  final _inventory = <String, int>{'kibble': 3, 'yarn': 1};
  final _placements = <Placement>[
    const Placement('p1', 'bed', 3, 0),
    const Placement('p2', 'rug', 1, 2),
    const Placement('p3', 'plant', 0, 1),
  ];
  late final _placementView = UnmodifiableListView(_placements);
  final _progress = <String, int>{};
  final _claimed = <String>{};

  int get coins => _coins;
  int get bankedCoins => _bankedCoins;
  int get hunger => _hunger;
  int get energy => _energy;
  int get happiness => _happiness;
  int get affection => _affection;
  int get roomLevel => _roomLevel;
  int get roomSize => 4 + _roomLevel;
  List<Placement> get placements => _placementView;
  List<Objective> get objectives => _goals.map(_objective).toList();

  int owned(String itemId) => _inventory[itemId] ?? 0;

  bool canFeed({String itemId = 'kibble'}) =>
      itemsById[itemId]?.category == ItemCategory.food &&
      owned(itemId) > 0 &&
      _hunger >= 8;

  bool get canPet {
    final lastPetAt = _lastPetAt;
    return lastPetAt == null ||
        _clock().millisecondsSinceEpoch - lastPetAt >=
            _petCooldown.inMilliseconds;
  }

  bool canPlay({String? itemId}) =>
      _energy >= 10 &&
      (itemId == null ||
          (itemsById[itemId]?.category == ItemCategory.toy &&
              owned(itemId) > 0));

  ({int price, int affection})? get _nextUpgrade =>
      _roomLevel <= _upgrades.length ? _upgrades[_roomLevel - 1] : null;

  int? get expansionPrice => _nextUpgrade?.price;
  int? get expansionAffection => _nextUpgrade?.affection;

  bool get canExpand {
    final upgrade = _nextUpgrade;
    return upgrade != null &&
        _coins >= upgrade.price &&
        _affection >= upgrade.affection;
  }

  bool feed({String itemId = 'kibble'}) {
    syncTime();
    if (!canFeed(itemId: itemId)) return false;
    final item = itemsById[itemId]!;
    _removeStock(item.id);
    _hunger = _need(_hunger - item.effect);
    _happiness = _need(_happiness + 4);
    _affection = _need(_affection + 4);
    _record('feed');
    _changed();
    return true;
  }

  bool pet() {
    syncTime();
    if (!canPet) return false;
    _lastPetAt = _clock().millisecondsSinceEpoch;
    _happiness = _need(_happiness + 12);
    _affection = _need(_affection + 3);
    _changed();
    return true;
  }

  bool play({String? itemId}) {
    syncTime();
    if (!canPlay(itemId: itemId)) return false;
    final toy = itemsById[itemId];
    _happiness = _need(_happiness + 12 + (toy?.effect ?? 0));
    _hunger = _need(_hunger + 4);
    _energy = _need(_energy - 10);
    _affection = _need(_affection + 5);
    _record('play');
    _changed();
    return true;
  }

  bool rest({int energy = 4}) {
    if (energy <= 0 || _energy == 100) return false;
    _energy = _need(_energy + energy);
    _changed();
    return true;
  }

  bool amuse({int happiness = 2}) {
    if (happiness <= 0 || _happiness == 100) return false;
    _happiness = _need(_happiness + happiness);
    _changed();
    return true;
  }

  bool buy(String itemId) {
    syncTime();
    final item = itemsById[itemId];
    if (item == null || _coins < item.price) return false;
    _coins -= item.price;
    _inventory[itemId] = owned(itemId) + 1;
    _record('shop');
    _changed();
    return true;
  }

  bool expand() {
    syncTime();
    final price = expansionPrice;
    if (price == null || !canExpand) return false;
    _coins -= price;
    _roomLevel++;
    _record('expand');
    _changed();
    return true;
  }

  int collectIncome() {
    syncTime();
    final amount = _bankedCoins;
    if (amount == 0) return 0;
    _bankedCoins = 0;
    _coins += amount;
    _changed();
    return amount;
  }

  bool claimObjective(String id) {
    syncTime();
    for (final goal in _goals) {
      if (goal.id != id || !_objective(goal).ready) continue;
      _claimed.add(id);
      _coins += goal.reward;
      _changed();
      return true;
    }
    return false;
  }

  Placement? placementAt(int x, int y) {
    for (final placement in _placements) {
      if (placement.covers(x, y)) return placement;
    }
    return null;
  }

  bool canPlace(String itemId, int x, int y, {String? movingId}) {
    final item = itemsById[itemId];
    return item != null && _fits(item, x, y, ignoreId: movingId);
  }

  bool place(String itemId, int x, int y) {
    syncTime();
    if (owned(itemId) == 0 || !canPlace(itemId, x, y)) return false;
    String id;
    do {
      id = 'p${_nextPlacementNumber++}';
    } while (_placements.any((placement) => placement.id == id));
    _placements.add(Placement(id, itemId, x, y));
    _removeStock(itemId);
    _record('decorate');
    _changed();
    return true;
  }

  bool move(String placementId, int x, int y) {
    syncTime();
    final index = _placements.indexWhere((placed) => placed.id == placementId);
    if (index < 0) return false;
    final old = _placements[index];
    if (old.x == x && old.y == y) return true;
    if (!canPlace(old.itemId, x, y, movingId: placementId)) return false;
    _placements[index] = Placement(old.id, old.itemId, x, y);
    _record('decorate');
    _changed();
    return true;
  }

  bool store(String placementId) {
    syncTime();
    final index = _placements.indexWhere((placed) => placed.id == placementId);
    if (index < 0) return false;
    final placement = _placements.removeAt(index);
    _inventory[placement.itemId] = owned(placement.itemId) + 1;
    _changed();
    return true;
  }

  void syncTime() {
    final now = _clock();
    final nowMs = now.millisecondsSinceEpoch;
    final date = _dateKey(now);
    final dayChanged = date.compareTo(_date) > 0;
    if (dayChanged) {
      _date = date;
      for (final goal in _goals.where((goal) => goal.daily)) {
        _progress.remove(goal.id);
        _claimed.remove(goal.id);
      }
    }

    final elapsed = nowMs - _lastAccruedAt;
    final petAt = _lastPetAt;
    final petReady =
        petAt != null && nowMs - petAt >= _petCooldown.inMilliseconds;
    if (petReady) _lastPetAt = null;
    if (elapsed <= 0) {
      if (dayChanged || petReady) _changed();
      return;
    }
    _lastAccruedAt = nowMs;

    final incomeMs = _incomeRemainder + elapsed;
    final incomeIntervalMs = incomeInterval.inMilliseconds;
    final bank = math.min(
      incomeCap,
      _bankedCoins + incomeMs ~/ incomeIntervalMs,
    );
    _incomeRemainder = incomeMs % incomeIntervalMs;

    final needsElapsed = math.min<int>(
      elapsed,
      _maxNeedsElapsed.inMilliseconds,
    );
    final needsMs = _needsRemainder + needsElapsed;
    final needsIntervalMs = _needsInterval.inMilliseconds;
    final needsSteps = needsMs ~/ needsIntervalMs;
    _needsRemainder = needsMs % needsIntervalMs;
    final hunger = _need(_hunger + needsSteps * 2);
    final energy = _need(_energy - needsSteps);
    final happiness = _need(_happiness - needsSteps);

    final changed =
        dayChanged ||
        petReady ||
        bank != _bankedCoins ||
        hunger != _hunger ||
        energy != _energy ||
        happiness != _happiness;
    _bankedCoins = bank;
    _hunger = hunger;
    _energy = energy;
    _happiness = happiness;
    if (changed) _changed();
  }

  Future<void> save() {
    syncTime();
    return _persist();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _fits(CatalogItem item, int x, int y, {String? ignoreId}) {
    if (!item.placeable ||
        x < 0 ||
        y < 0 ||
        x + item.width > roomSize ||
        y + item.depth > roomSize) {
      return false;
    }
    for (final other in _placements) {
      if (other.id == ignoreId) continue;
      final overlaps =
          x < other.x + other.item.width &&
          x + item.width > other.x &&
          y < other.y + other.item.depth &&
          y + item.depth > other.y;
      if (overlaps) return false;
    }
    return true;
  }

  void _removeStock(String itemId) {
    final count = owned(itemId) - 1;
    if (count == 0) {
      _inventory.remove(itemId);
    } else {
      _inventory[itemId] = count;
    }
  }

  Objective _objective(_Goal goal) => Objective(
    id: goal.id,
    title: goal.title,
    description: goal.description,
    reward: goal.reward,
    target: goal.target,
    progress: math.min(goal.target, _progress[goal.id] ?? 0),
    claimed: _claimed.contains(goal.id),
    daily: goal.daily,
  );

  void _record(String id) =>
      _progress.update(id, (value) => value + 1, ifAbsent: () => 1);

  void _changed() {
    _saveInBackground();
    notifyListeners();
  }

  void _saveInBackground() => unawaited(_persist().catchError((Object _) {}));

  Future<void> _persist() {
    final preferences = _preferences;
    if (preferences == null) return Future.value();
    final snapshot = jsonEncode(_snapshot());
    final write = _saveQueue.then((_) async {
      if (!await preferences.setString(_storageKey, snapshot)) {
        throw StateError('Could not save Purrfect Home progress.');
      }
    });
    _saveQueue = write.catchError((Object error, StackTrace stack) {
      debugPrint('Purrfect Home could not save progress: $error');
    });
    return write;
  }

  Map<String, Object?> _snapshot() => {
    'version': 1,
    'lastAccruedAt': _lastAccruedAt,
    'date': _date,
    'incomeRemainder': _incomeRemainder,
    'needsRemainder': _needsRemainder,
    'lastPetAt': _lastPetAt,
    'nextPlacementNumber': _nextPlacementNumber,
    'coins': _coins,
    'bankedCoins': _bankedCoins,
    'hunger': _hunger,
    'energy': _energy,
    'happiness': _happiness,
    'affection': _affection,
    'roomLevel': _roomLevel,
    'inventory': _inventory,
    'placements': [
      for (final placement in _placements)
        {
          'id': placement.id,
          'itemId': placement.itemId,
          'x': placement.x,
          'y': placement.y,
        },
    ],
    'progress': _progress,
    'claimed': _claimed.toList(),
  };

  void _restore(Map<String, dynamic> snapshot) {
    int readInt(String key, int fallback) {
      final value = snapshot[key];
      return value is int && value >= 0 ? value : fallback;
    }

    _lastAccruedAt = readInt('lastAccruedAt', _lastAccruedAt);
    final date = snapshot['date'];
    if (date is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      _date = date;
    }
    _incomeRemainder =
        readInt('incomeRemainder', 0) % incomeInterval.inMilliseconds;
    _needsRemainder =
        readInt('needsRemainder', 0) % _needsInterval.inMilliseconds;
    _lastPetAt = snapshot['lastPetAt'] is int ? snapshot['lastPetAt'] : null;
    _nextPlacementNumber = readInt('nextPlacementNumber', _nextPlacementNumber);
    _coins = readInt('coins', _coins);
    _bankedCoins = math.min(incomeCap, readInt('bankedCoins', _bankedCoins));
    _hunger = _need(readInt('hunger', _hunger));
    _energy = _need(readInt('energy', _energy));
    _happiness = _need(readInt('happiness', _happiness));
    _affection = _need(readInt('affection', _affection));
    _roomLevel = readInt(
      'roomLevel',
      _roomLevel,
    ).clamp(1, _upgrades.length + 1);

    final inventory = snapshot['inventory'];
    if (inventory is Map<String, dynamic>) {
      _inventory.clear();
      for (final entry in inventory.entries) {
        final value = entry.value;
        if (itemsById.containsKey(entry.key) && value is int && value > 0) {
          _inventory[entry.key] = value;
        }
      }
    }

    final placements = snapshot['placements'];
    if (placements is List<dynamic>) {
      _placements.clear();
      final ids = <String>{};
      for (final placement in placements.whereType<Map<String, dynamic>>()) {
        final id = placement['id'];
        final itemId = placement['itemId'];
        final x = placement['x'];
        final y = placement['y'];
        if (id is String &&
            itemId is String &&
            x is int &&
            y is int &&
            canPlace(itemId, x, y) &&
            ids.add(id)) {
          _placements.add(Placement(id, itemId, x, y));
        }
      }
    }

    final progress = snapshot['progress'];
    final claimed = snapshot['claimed'];
    for (final goal in _goals) {
      if (progress is Map<String, dynamic>) {
        final value = progress[goal.id];
        if (value is int && value >= 0) _progress[goal.id] = value;
      }
      if (claimed is List<dynamic> && claimed.contains(goal.id)) {
        _claimed.add(goal.id);
      }
    }
  }

  static int _need(int value) => value.clamp(0, 100);

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
