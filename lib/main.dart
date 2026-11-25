import 'dart:async';
import 'dart:math' show Point;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'home_state.dart';
import 'room_game.dart';

part 'home_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PurrfectHomeApp());
}

class PurrfectHomeApp extends StatefulWidget {
  const PurrfectHomeApp({super.key});

  @override
  State<PurrfectHomeApp> createState() => _PurrfectHomeAppState();
}

class _PurrfectHomeAppState extends State<PurrfectHomeApp> {
  HomeState? _state;
  late Future<HomeState> _loading;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  Future<HomeState> _load() async {
    final state = await HomeState.load();
    if (mounted) {
      _state = state;
    } else {
      state.dispose();
    }
    return state;
  }

  @override
  void dispose() {
    _state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      fontFamily: 'Nunito Sans',
      scaffoldBackgroundColor: _paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _wine,
        primary: _wine,
        onPrimary: Colors.white,
        surface: _card,
        onSurface: _ink,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _ink,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
    return MaterialApp(
      title: 'Purrfect Home',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: FutureBuilder<HomeState>(
        future: _loading,
        builder: (context, snapshot) {
          final state = snapshot.data;
          if (state != null) return _Home(state: state);
          return Scaffold(
            body: Center(
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Your home could not be loaded.'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => setState(() => _loading = _load()),
                          child: const Text('Try again'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}

enum _Tab {
  room('Home', Icons.home_outlined, Icons.home_rounded),
  shop('Market', Icons.storefront_outlined, Icons.storefront_rounded),
  storage('Storage', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
  journal('Journal', Icons.menu_book_outlined, Icons.menu_book_rounded);

  const _Tab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _Home extends StatefulWidget {
  const _Home({required this.state});

  final HomeState state;

  @override
  State<_Home> createState() => _HomeViewState();
}

class _HomeViewState extends State<_Home> {
  late final RoomGame _game;
  late final Widget _scene;
  late final AppLifecycleListener _lifecycle;
  _Tab _tab = _Tab.room;
  ItemCategory? _filter;
  bool _editing = false;
  String? _placing;
  String? _moving;

  HomeState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    _game = RoomGame(_state, onCellTap: _tapCell, onCatTap: _tapCat);
    _scene = GameWidget(
      key: GlobalKey(),
      game: _game,
      loadingBuilder: (_) => const Center(child: CircularProgressIndicator()),
      errorBuilder: (_, _) =>
          const Center(child: Text('The room could not be displayed.')),
    );
    _lifecycle = AppLifecycleListener(
      onResume: _state.syncTime,
      onHide: () => unawaited(_state.save().catchError((Object _) {})),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _notify(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
  }

  void _selectTab(_Tab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _editing = false;
      _placing = null;
      _moving = null;
    });
    _game.setEditMode(false);
  }

  void _setEditing(bool editing, {String? item, String? moving}) {
    setState(() {
      _editing = editing;
      _placing = item;
      _moving = moving;
    });
    _game.setEditMode(editing, itemId: item, movingId: moving);
  }

  void _startPlacement(CatalogItem item) {
    _selectTab(_Tab.room);
    _setEditing(true, item: item.id);
  }

  void _tapCell(Point<int> cell) {
    if (!_editing) return;
    final moving = _moving;
    final placing = _placing;
    if (moving != null) {
      if (_state.move(moving, cell.x, cell.y)) {
        _setEditing(true);
        _notify('Furniture moved.');
      } else {
        _notify('Choose a highlighted tile with enough space.');
      }
      return;
    }
    if (placing != null) {
      if (_state.place(placing, cell.x, cell.y)) {
        _setEditing(true);
        _notify('${itemsById[placing]?.name ?? 'Item'} placed.');
      } else {
        _notify('Choose a highlighted tile with enough space.');
      }
      return;
    }
    final placement = _state.placementAt(cell.x, cell.y);
    if (placement != null) {
      _setEditing(true, item: placement.itemId, moving: placement.id);
    }
  }

  void _tapCat() {
    if (!_editing) _pet();
  }

  void _pet() {
    if (_state.pet()) {
      _game.reactToCare('pet');
      _notify('Mochi loved the attention.');
    } else {
      _notify('Give Mochi a moment between pets.');
    }
  }

  Future<String?> _pickItem({
    required String title,
    required List<CatalogItem> items,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: _display(25)),
            const SizedBox(height: 8),
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _ItemIcon(item: item, size: 42),
                title: Text(item.name),
                subtitle: Text(item.description),
                trailing: Text('×${_state.owned(item.id)}'),
                onTap: () => Navigator.pop(context, item.id),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _feed() async {
    final food = catalog
        .where(
          (item) =>
              item.category == ItemCategory.food && _state.owned(item.id) > 0,
        )
        .toList();
    if (food.isEmpty) {
      _notify('You are out of food. Visit the Market to restock.');
      return;
    }
    if (!_state.canFeed(itemId: food.first.id)) {
      _notify('Mochi is already full.');
      return;
    }
    final item = food.length == 1
        ? food.single.id
        : await _pickItem(title: 'What’s for dinner?', items: food);
    if (item == null || !mounted) return;
    if (_state.feed(itemId: item)) {
      _game.reactToCare('feed');
      _notify('Mochi enjoyed the meal.');
    }
  }

  Future<void> _play() async {
    if (!_state.canPlay()) {
      _notify('Mochi needs a little rest first.');
      return;
    }
    final toys = catalog
        .where(
          (item) =>
              item.category == ItemCategory.toy && _state.owned(item.id) > 0,
        )
        .toList();
    final picked = toys.length > 1
        ? await _pickItem(title: 'Pick a toy', items: toys)
        : toys.firstOrNull?.id ?? '';
    if (picked == null || !mounted) return;
    if (_state.play(itemId: picked.isEmpty ? null : picked)) {
      _game.reactToCare('play', itemId: picked.isEmpty ? null : picked);
      _notify('Playtime made Mochi happy.');
    }
  }

  void _collect() {
    final amount = _state.collectIncome();
    if (amount != 0) _notify('Collected $amount coins.');
  }

  void _showIncome() {
    showDialog<void>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: _state,
        builder: (context, _) => AlertDialog(
          title: Text('Coin jar', style: _display(26)),
          content: Text(
            '${_state.bankedCoins} coins are ready to collect. The jar earns one coin every ${HomeState.incomeInterval.inSeconds} seconds, even while you’re away, and holds up to ${HomeState.incomeCap}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: _state.bankedCoins == 0
                  ? null
                  : () {
                      Navigator.pop(context);
                      _collect();
                    },
              child: const Text('Collect'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExpansion() async {
    final price = _state.expansionPrice;
    if (price == null) return;
    final next = _state.roomSize + 1;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: _state,
        builder: (context, _) => AlertDialog(
          title: Text('Room to grow', style: _display(26)),
          content: Text(
            'Unlock a $next × $next room for $price coins once Mochi’s bond reaches ${_state.expansionAffection}. Your furniture keeps its place.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: _state.canExpand
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text('Expand · $price coins'),
            ),
          ],
        ),
      ),
    );
    if (approved == true && mounted && _state.expand()) {
      _notify('Your room is now $next × $next.');
    }
  }

  Widget _roomPage(bool wide) {
    final room = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(
          title: 'Mochi’s room',
          trailing: _Tag(
            icon: Icons.grid_view_rounded,
            text: '${_state.roomSize} × ${_state.roomSize} room',
          ),
        ),
        const SizedBox(height: 16),
        _RoomStage(
          scene: _scene,
          activity: _game.activity,
          editing: _editing,
          editName: _placing == null ? null : itemsById[_placing]?.name,
          moving: _moving != null,
          onEdit: () => _setEditing(!_editing),
          onCancel: () => _setEditing(true),
          onStore: () {
            final moving = _moving;
            if (moving != null && _state.store(moving)) {
              _setEditing(true);
              _notify('Furniture returned to Storage.');
            }
          },
          onStorage: () => _selectTab(_Tab.storage),
        ),
      ],
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CarePanel(state: _state, onFeed: _feed, onPet: _pet, onPlay: _play),
        const SizedBox(height: 14),
        _IncomePanel(amount: _state.bankedCoins, onCollect: _collect),
        if (_state.expansionPrice != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showExpansion,
            icon: const Icon(Icons.open_in_full_rounded, size: 17),
            label: const Text('Expand the room'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        ],
      ],
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [room, const SizedBox(height: 18), details],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: room),
        const SizedBox(width: 24),
        SizedBox(
          width: 322,
          child: Padding(
            padding: const EdgeInsets.only(top: 62),
            child: details,
          ),
        ),
      ],
    );
  }

  Widget _shopPage() {
    final items = catalog.where(
      (item) => _filter == null || item.category == _filter,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          title: 'The Market',
          subtitle: 'Find something lovely for your little home.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('All items'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
            for (final category in ItemCategory.values)
              ChoiceChip(
                label: Text(_categoryLabel(category)),
                selected: _filter == category,
                onSelected: (value) =>
                    setState(() => _filter = value ? category : null),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _ItemGrid(
          children: [
            for (final item in items)
              _ItemTile(
                item: item,
                detail: 'Owned · ${_state.owned(item.id)}',
                action: FilledButton.tonalIcon(
                  onPressed: _state.coins < item.price
                      ? null
                      : () {
                          if (_state.buy(item.id)) {
                            _notify('${item.name} added to Storage.');
                          }
                        },
                  icon: const Icon(Icons.toll_outlined, size: 17),
                  label: Text('Buy · ${item.price}'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _storagePage() {
    final items = catalog.where((item) => _state.owned(item.id) > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          title: 'Storage',
          subtitle: 'Place furniture or use your supplies to care for Mochi.',
        ),
        const SizedBox(height: 20),
        if (items.isEmpty)
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your shelves are empty.', style: _display(22)),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => _selectTab(_Tab.shop),
                  child: const Text('Visit the Market'),
                ),
              ],
            ),
          )
        else
          _ItemGrid(
            children: [
              for (final item in items)
                _ItemTile(
                  item: item,
                  detail: 'In storage · ${_state.owned(item.id)}',
                  action: FilledButton.tonalIcon(
                    onPressed: () {
                      switch (item.category) {
                        case ItemCategory.food:
                          if (_state.feed(itemId: item.id)) {
                            _selectTab(_Tab.room);
                            _game.reactToCare('feed');
                            _notify('Mochi enjoyed the meal.');
                          } else {
                            _notify('Mochi is already full.');
                          }
                        case ItemCategory.toy:
                          if (_state.play(itemId: item.id)) {
                            _selectTab(_Tab.room);
                            _game.reactToCare('play', itemId: item.id);
                            _notify('Playtime made Mochi happy.');
                          } else {
                            _notify('Mochi needs a little rest first.');
                          }
                        case ItemCategory.furniture:
                        case ItemCategory.decor:
                          _startPlacement(item);
                      }
                    },
                    icon: Icon(switch (item.category) {
                      ItemCategory.food => Icons.restaurant_rounded,
                      ItemCategory.toy => Icons.toys_outlined,
                      _ => Icons.add_location_alt_outlined,
                    }, size: 17),
                    label: Text(switch (item.category) {
                      ItemCategory.food => 'Feed',
                      ItemCategory.toy => 'Play',
                      _ => 'Place · ${item.width} × ${item.depth}',
                    }),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _journalPage() {
    final objectives = _state.objectives;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          title: 'Journal',
          subtitle:
              'Care for Mochi, make the room your own, and collect rewards.',
        ),
        const SizedBox(height: 20),
        for (final daily in [true, false]) ...[
          Text(daily ? 'Daily tasks' : 'Milestones', style: _display(22)),
          const SizedBox(height: 10),
          _ItemGrid(
            children: [
              for (final objective in objectives.where(
                (goal) => goal.daily == daily,
              ))
                _ObjectiveTile(
                  objective: objective,
                  onClaim: () {
                    if (_state.claimObjective(objective.id)) {
                      _notify('Earned ${objective.reward} coins.');
                    }
                  },
                ),
            ],
          ),
          if (daily) const SizedBox(height: 22),
        ],
      ],
    );
  }

  Widget _scroll(Widget child, {required bool wide, required Key key}) {
    return SingleChildScrollView(
      key: key,
      padding: EdgeInsets.fromLTRB(
        wide ? 28 : 16,
        wide ? 26 : 18,
        wide ? 28 : 16,
        24,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1112),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _state,
          builder: (context, _) => Column(
            children: [
              _Header(coins: _state.coins, onCoins: _showIncome),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 850;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Offstage(
                          offstage: _tab != _Tab.room,
                          child: TickerMode(
                            enabled: _tab == _Tab.room,
                            child: _scroll(
                              _roomPage(wide),
                              wide: wide,
                              key: const PageStorageKey('room'),
                            ),
                          ),
                        ),
                        if (_tab != _Tab.room)
                          _scroll(
                            switch (_tab) {
                              _Tab.shop => _shopPage(),
                              _Tab.storage => _storagePage(),
                              _Tab.journal => _journalPage(),
                              _Tab.room => const SizedBox.shrink(),
                            },
                            wide: wide,
                            key: PageStorageKey(_tab),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _Navigation(tab: _tab, onSelect: _selectTab),
    );
  }
}
