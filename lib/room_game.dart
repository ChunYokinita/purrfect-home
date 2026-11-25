import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import 'home_state.dart';

typedef RoomCell = math.Point<int>;

enum _CatAction {
  idle('Taking it easy'),
  walk('Exploring the room'),
  play('In a playful mood'),
  sleep('Having a little nap'),
  sit('Watching the window'),
  scratch('Using the scratcher'),
  feed('Enjoying a snack'),
  pet('Purring happily');

  const _CatAction(this.label);
  final String label;
}

class RoomGame extends FlameGame with TapCallbacks {
  RoomGame(this.state, {required this.onCellTap, required this.onCatTap});

  final HomeState state;
  final ValueChanged<RoomCell> onCellTap;
  final VoidCallback onCatTap;
  final activity = ValueNotifier(_CatAction.idle.label);

  static const _tileX = 36.0;
  static const _tileY = 15.0;
  static const _wallHeight = 105.0;
  static const _ink = Color(0xff63434e);
  final _random = math.Random();
  final _route = Queue<RoomCell>();

  Image? _catSheet;
  Picture? _room;
  int _paintedSize = 0;
  bool _editing = false;
  String? _previewItem;
  String? _movingId;
  RoomCell _cell = const RoomCell(2, 2);
  double _catX = 2.5;
  double _catY = 2.5;
  bool _facesLeft = true;
  bool _initialized = false;
  _CatAction _action = _CatAction.idle;
  _CatAction _arrivalAction = _CatAction.idle;
  String? _targetFurniture;
  String? _careToy;
  double _seconds = 0;
  double _actionAge = 0;
  double _actionLength = 3.2;

  bool get _hasUsableSize => size.x > 0 && size.y > 0;

  double get _sceneScale => math.max(
    0.01,
    math.min(
      (size.x - 24) / (state.roomSize * _tileX * 2),
      (size.y - 18) / (_wallHeight + state.roomSize * _tileY * 2 + 22),
    ),
  );

  Offset get _sceneOrigin => Offset(
    size.x / 2,
    (size.y - (_wallHeight + state.roomSize * _tileY * 2 + 12) * _sceneScale) /
            2 +
        _wallHeight * _sceneScale,
  );

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _catSheet = await images.load('cat.png');
  }

  @override
  void onRemove() {
    _room?.dispose();
    _room = null;
    super.onRemove();
  }

  void setEditMode(bool enabled, {String? itemId, String? movingId}) {
    if (enabled && !_editing && _targetFurniture != null) {
      _route.clear();
      _targetFurniture = null;
      _returnToCell();
      _begin(_CatAction.idle, 1.2);
    }
    _editing = enabled;
    _previewItem = itemId;
    _movingId = movingId;
  }

  void reactToCare(String action, {String? itemId}) {
    _route.clear();
    _targetFurniture = null;
    _careToy = action == 'play' ? itemId : null;
    _returnToCell();
    switch (action) {
      case 'feed':
        _begin(_CatAction.feed, 2.7);
      case 'pet':
        _begin(_CatAction.pet, 2.6);
      case 'play':
        _begin(_CatAction.play, 3.2);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!_hasUsableSize) return;
    final screen = event.canvasPosition;
    final local = (Offset(screen.x, screen.y) - _sceneOrigin) / _sceneScale;
    if (_editing) {
      if (_previewItem == null) {
        final props = _sortedFurniture().reversed;
        for (final placement in props) {
          if (!placement.item.walkable &&
              _propHitBox(placement).contains(local)) {
            onCellTap(RoomCell(placement.x, placement.y));
            return;
          }
        }
      }
      final x = (local.dy / _tileY + local.dx / _tileX) / 2;
      final y = (local.dy / _tileY - local.dx / _tileX) / 2;
      final tile = RoomCell(x.floor(), y.floor());
      if (_inRoom(tile)) onCellTap(tile);
    } else if (_catBounds().inflate(6).contains(local)) {
      onCatTap();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final step = dt.clamp(0.0, .12).toDouble();
    _seconds += step;
    if (!_initialized) {
      _initialized = true;
      if (!_walkable(_cell)) {
        final open = _openCells();
        if (open.isNotEmpty) _cell = open.first;
      }
      _returnToCell();
    }
    if (_editing) return;
    if (!_walkable(_cell)) {
      final open = _openCells();
      if (open.isNotEmpty) {
        open.sort((a, b) => _distance(a, _cell).compareTo(_distance(b, _cell)));
        _cell = open.first;
        _returnToCell();
        _route.clear();
        _targetFurniture = null;
        _begin(_CatAction.idle, 1.2);
      }
    }
    _actionAge += step;
    if (_action == _CatAction.walk) {
      _walk(step);
    } else if (_actionAge >= _actionLength) {
      _finishActivity();
      _chooseActivity();
    }
  }

  void _walk(double dt) {
    if (_route.isEmpty) {
      _arrive();
      return;
    }
    final next = _route.first;
    if (!_walkable(next)) {
      _route.clear();
      _returnToCell();
      _targetFurniture = null;
      _begin(_CatAction.idle, .5);
      return;
    }
    final dx = next.x + .5 - _catX;
    final dy = next.y + .5 - _catY;
    final length = math.sqrt(dx * dx + dy * dy);
    final stride = dt * 1.45;
    if (length <= stride) {
      _cell = _route.removeFirst();
      _returnToCell();
      if (_route.isEmpty) _arrive();
      return;
    }
    _facesLeft = dx - dy < 0;
    _catX += dx / length * stride;
    _catY += dy / length * stride;
  }

  void _returnToCell() {
    _catX = _cell.x + .5;
    _catY = _cell.y + .5;
  }

  void _begin(_CatAction action, double length) {
    _action = action;
    _actionAge = 0;
    _actionLength = length;
    activity.value = action.label;
  }

  void _arrive() {
    final prop = _activeProp;
    if (prop != null && _arrivalAction == _CatAction.scratch) {
      _facesLeft =
          _project(prop.x + .5, prop.y + .5).dx < _project(_catX, _catY).dx;
    }
    switch (_arrivalAction) {
      case _CatAction.sleep:
        _begin(_CatAction.sleep, 7.5);
      case _CatAction.sit:
        _begin(_CatAction.sit, 4.0);
      case _CatAction.scratch:
        _begin(_CatAction.scratch, 3.2);
      case _CatAction.play:
        _begin(_CatAction.play, 3.0);
      default:
        _begin(_CatAction.idle, 1.6 + _random.nextDouble() * 2);
    }
  }

  void _finishActivity() {
    if (_action == _CatAction.sleep) {
      state.rest(energy: _targetFurniture == null ? 5 : 12);
    }
    if (_action == _CatAction.scratch ||
        (_action == _CatAction.play && _targetFurniture != null)) {
      state.amuse();
    }
    _targetFurniture = null;
    _careToy = null;
  }

  void _chooseActivity() {
    if (state.energy < 53) {
      if (!_approachFurniture(CatInteraction.sleep, _CatAction.sleep)) {
        _begin(_CatAction.sleep, 7.5);
      }
      return;
    }
    if (state.happiness < 65 || _random.nextInt(4) == 0) {
      if (_approachFurniture(CatInteraction.play, _CatAction.play) ||
          _approachFurniture(CatInteraction.scratch, _CatAction.scratch)) {
        return;
      }
    }
    if (_random.nextInt(3) == 0) {
      // The window is on the wall along the room's x axis.
      for (final x in [state.roomSize ~/ 2, 1, state.roomSize - 2]) {
        if (_travel(RoomCell(x, 0), _CatAction.sit)) return;
      }
    }
    if (state.hunger > 78 && _random.nextBool()) {
      _begin(_CatAction.idle, 3.5);
      return;
    }
    final open = _openCells()..shuffle(_random);
    for (final destination in open) {
      if (destination != _cell && _travel(destination, _CatAction.idle)) return;
    }
    _begin(_CatAction.idle, 3.5);
  }

  bool _approachFurniture(CatInteraction interaction, _CatAction action) {
    final furniture = state.placements.where(
      (placement) => placement.item.interaction == interaction,
    );
    for (final prop in furniture) {
      final candidates = <RoomCell>[];
      if (prop.item.walkable) {
        final center = RoomCell(
          prop.x + prop.item.width ~/ 2,
          prop.y + prop.item.depth ~/ 2,
        );
        if (_travel(center, action, furniture: prop.id)) return true;
      }
      for (var x = prop.x; x < prop.x + prop.item.width; x++) {
        candidates.add(RoomCell(x, prop.y + prop.item.depth));
        candidates.add(RoomCell(x, prop.y - 1));
      }
      for (var y = prop.y; y < prop.y + prop.item.depth; y++) {
        candidates.add(RoomCell(prop.x + prop.item.width, y));
        candidates.add(RoomCell(prop.x - 1, y));
      }
      candidates.sort(
        (a, b) => _distance(a, _cell).compareTo(_distance(b, _cell)),
      );
      for (final candidate in candidates) {
        if (_travel(candidate, action, furniture: prop.id)) return true;
      }
    }
    return false;
  }

  bool _travel(RoomCell target, _CatAction action, {String? furniture}) {
    if (!_walkable(target)) return false;
    final frontier = Queue<RoomCell>()..add(_cell);
    final visited = <RoomCell, RoomCell?>{_cell: null};
    while (frontier.isNotEmpty && !visited.containsKey(target)) {
      final current = frontier.removeFirst();
      for (final offset in const [
        RoomCell(1, 0),
        RoomCell(-1, 0),
        RoomCell(0, 1),
        RoomCell(0, -1),
      ]) {
        final next = RoomCell(current.x + offset.x, current.y + offset.y);
        if (!visited.containsKey(next) && _walkable(next)) {
          visited[next] = current;
          frontier.addLast(next);
        }
      }
    }
    if (!visited.containsKey(target)) return false;
    _route.clear();
    for (
      RoomCell? step = target;
      step != null && step != _cell;
      step = visited[step]
    ) {
      _route.addFirst(step);
    }
    _targetFurniture = furniture;
    _arrivalAction = action;
    if (_route.isEmpty) {
      _arrive();
    } else {
      _begin(_CatAction.walk, 0);
    }
    return true;
  }

  int _distance(RoomCell a, RoomCell b) =>
      (a.x - b.x).abs() + (a.y - b.y).abs();

  bool _inRoom(RoomCell tile) =>
      tile.x >= 0 &&
      tile.y >= 0 &&
      tile.x < state.roomSize &&
      tile.y < state.roomSize;

  bool _walkable(RoomCell tile) =>
      _inRoom(tile) &&
      (state.placementAt(tile.x, tile.y)?.item.walkable ?? true);

  List<RoomCell> _openCells() => [
    for (var y = 0; y < state.roomSize; y++)
      for (var x = 0; x < state.roomSize; x++)
        if (_walkable(RoomCell(x, y))) RoomCell(x, y),
  ];

  static Offset _project(double x, double y, [double z = 0]) =>
      Offset((x - y) * _tileX, (x + y) * _tileY - z);

  List<Placement> _sortedFurniture() =>
      state.placements.toList()
        ..sort((a, b) => _propDepth(a).compareTo(_propDepth(b)));

  double _propDepth(Placement placement) =>
      placement.x +
      placement.y +
      (placement.item.width + placement.item.depth) * .5;

  Placement? get _activeProp {
    if (_targetFurniture == null) return null;
    for (final prop in state.placements) {
      if (prop.id == _targetFurniture) return prop;
    }
    return null;
  }

  Offset _catAnchor() {
    final prop = _activeProp;
    if (prop != null && _action == _CatAction.sleep) {
      return _project(
        prop.x + prop.item.width * .54,
        prop.y + prop.item.depth * .55,
        prop.itemId == 'sofa' ? 26 : 15,
      );
    }
    return _project(_catX, _catY);
  }

  Rect _catBounds() {
    final anchor = _catAnchor();
    const side = 61.0;
    return Rect.fromLTWH(
      anchor.dx - side / 2,
      anchor.dy - side + 9,
      side,
      side,
    );
  }

  Rect _propHitBox(Placement prop) {
    final anchor = _project(
      prop.x + prop.item.width / 2,
      prop.y + prop.item.depth / 2,
    );
    final tall = switch (prop.itemId) {
      'plant' || 'scratcher' => 45.0,
      'shelf' => 63.0,
      'sofa' => 36.0,
      'bed' => 19.0,
      _ => 10.0,
    };
    final wide = (prop.item.width + prop.item.depth) * _tileX * .7;
    return Rect.fromLTRB(
      anchor.dx - wide / 2,
      anchor.dy - tall,
      anchor.dx + wide / 2,
      anchor.dy + 10,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!_hasUsableSize) return;
    final origin = _sceneOrigin;
    final scale = _sceneScale;
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    if (_room == null || _paintedSize != state.roomSize) {
      _room?.dispose();
      final recorder = PictureRecorder();
      _drawRoom(Canvas(recorder), state.roomSize.toDouble());
      _room = recorder.endRecording();
      _paintedSize = state.roomSize;
    }
    canvas.drawPicture(_room!);
    final props = _sortedFurniture();
    for (final prop in props.where((prop) => prop.item.walkable)) {
      _drawFurniture(canvas, prop);
    }
    if (_editing) _drawPlacementGuide(canvas);
    final activeProp = _activeProp;
    final catDepth = activeProp != null && _action == _CatAction.sleep
        ? _propDepth(activeProp) + .05
        : _catX + _catY;
    var drewCat = false;
    for (final prop in props.where((prop) => !prop.item.walkable)) {
      if (!drewCat && catDepth < _propDepth(prop)) {
        _drawCat(canvas);
        drewCat = true;
      }
      _drawFurniture(canvas, prop);
    }
    if (!drewCat) _drawCat(canvas);
    canvas.restore();
  }

  void _drawPlacementGuide(Canvas canvas) {
    for (var x = 0; x < state.roomSize; x++) {
      for (var y = 0; y < state.roomSize; y++) {
        final occupied = state.placementAt(x, y);
        final selected = occupied != null && occupied.id == _movingId;
        final valid =
            _previewItem != null &&
            state.canPlace(_previewItem!, x, y, movingId: _movingId);
        final appearance = selected
            ? const Color(0xff8b4670)
            : valid
            ? const Color(0xff57785e)
            : const Color(0xff725255);
        final tile = _floorCell(x + .05, y + .05, .9, .9);
        _shape(
          canvas,
          tile,
          appearance.withValues(
            alpha: selected
                ? .34
                : valid
                ? .24
                : .06,
          ),
          outline: appearance.withValues(
            alpha: selected
                ? .92
                : valid
                ? .70
                : .36,
          ),
          width: selected ? 2.4 : 1.0,
        );
        if (valid) {
          final center = _project(x + .5, y + .5);
          _line(canvas, [
            center - const Offset(4, 0),
            center + const Offset(4, 0),
          ], appearance);
          _line(canvas, [
            center - const Offset(0, 3),
            center + const Offset(0, 3),
          ], appearance);
        }
      }
    }
  }

  void _drawCat(Canvas canvas) {
    final image = _catSheet;
    if (image == null) return;
    final anchor = _catAnchor();
    final bounds = _catBounds();
    final sleeping = _action == _CatAction.sleep;
    final frame = switch (_action) {
      _CatAction.walk => (0, 2, 5.6),
      _CatAction.play => (1, 0, 3.0),
      _CatAction.sleep => (1, 2, 1.1),
      _CatAction.sit || _CatAction.pet => (2, 0, 1.4),
      _CatAction.scratch => (2, 2, 3.6),
      _CatAction.idle || _CatAction.feed => (0, 0, 1.1),
    };
    final column = frame.$2 + (_actionAge * frame.$3).floor() % 2;
    final width = image.width / 4;
    final height = image.height / 3;
    final frameRect = Rect.fromLTWH(
      width * column,
      height * frame.$1,
      width,
      height,
    );
    _oval(
      canvas,
      Rect.fromCenter(
        center: anchor + const Offset(0, 2),
        width: 42,
        height: 10,
      ),
      const Color(0x41654c4d),
    );
    final propPosition = anchor + Offset(_facesLeft ? -28 : 28, 2);
    if (_action == _CatAction.feed) _drawFoodBowl(canvas, propPosition);
    if (_action == _CatAction.play) {
      switch (_careToy) {
        case 'yarn':
          _drawYarn(canvas, propPosition);
        case 'feather':
          _drawFeather(canvas, propPosition);
      }
    }
    final bounce = _action == _CatAction.walk
        ? -math.sin(_actionAge * 16).abs() * 1.8
        : _action == _CatAction.play
        ? -math.sin(_actionAge * 8).abs() * 3.2
        : 0.0;
    canvas.save();
    canvas.translate(anchor.dx, bounce);
    if (!_facesLeft) canvas.scale(-1, 1);
    canvas.drawImageRect(
      image,
      frameRect,
      bounds.shift(Offset(-anchor.dx, 0)),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    if (sleeping) {
      final float = math.sin(_seconds * 2.5) * 2;
      final p = anchor + Offset(20, -49 + float);
      _line(
        canvas,
        [
          p,
          p + const Offset(7, 0),
          p + const Offset(0, 6),
          p + const Offset(7, 6),
        ],
        const Color(0xff865b80),
        width: 1.8,
      );
      final q = p + const Offset(10, -9);
      _line(
        canvas,
        [
          q,
          q + const Offset(5, 0),
          q + const Offset(0, 4),
          q + const Offset(5, 4),
        ],
        const Color(0xffa77b9c),
        width: 1.3,
      );
    } else if (_action == _CatAction.pet || _action == _CatAction.feed) {
      final float = math.sin(_seconds * 4) * 3;
      _heart(canvas, anchor + Offset(20, -50 + float), const Color(0xffc76a85));
    }
  }

  void _heart(Canvas canvas, Offset p, Color color) {
    final path = Path()
      ..moveTo(p.dx, p.dy + 7)
      ..cubicTo(p.dx - 13, p.dy, p.dx - 5, p.dy - 8, p.dx, p.dy - 2)
      ..cubicTo(p.dx + 5, p.dy - 8, p.dx + 13, p.dy, p.dx, p.dy + 7)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  List<Offset> _floorCell(
    double x,
    double y,
    double width,
    double depth, [
    double lift = 0,
  ]) => [
    _project(x, y, lift),
    _project(x + width, y, lift),
    _project(x + width, y + depth, lift),
    _project(x, y + depth, lift),
  ];

  void _shape(
    Canvas canvas,
    List<Offset> points,
    Color fill, {
    Color? outline,
    double width = 1,
  }) {
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, Paint()..color = fill);
    if (outline != null) {
      canvas.drawPath(path, _stroke(outline, width));
    }
  }

  Paint _stroke(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..strokeWidth = width
    ..color = color;

  void _line(
    Canvas canvas,
    List<Offset> points,
    Color color, {
    double width = 1,
  }) {
    final path = Path()..addPolygon(points, false);
    canvas.drawPath(path, _stroke(color, width));
  }

  void _oval(Canvas canvas, Rect box, Color color, {Color? outline}) {
    canvas.drawOval(box, Paint()..color = color);
    if (outline != null) canvas.drawOval(box, _stroke(outline, 1));
  }

  void _rounded(
    Canvas canvas,
    Rect box,
    double radius,
    Color color, {
    Color? outline,
  }) {
    final rect = RRect.fromRectAndRadius(box, Radius.circular(radius));
    canvas.drawRRect(rect, Paint()..color = color);
    if (outline != null) canvas.drawRRect(rect, _stroke(outline, 1));
  }

  void _drawRoom(Canvas canvas, double n) {
    final floor = _floorCell(0, 0, n, n);
    _shape(canvas, [
      for (final p in floor) p + const Offset(0, 15),
    ], const Color(0x206b5361));
    _shape(
      canvas,
      [
        floor[1],
        floor[2],
        floor[2] + const Offset(0, 11),
        floor[1] + const Offset(0, 11),
      ],
      const Color(0xffb47a66),
      outline: _ink,
      width: 1.3,
    );
    _shape(
      canvas,
      [
        floor[2],
        floor[3],
        floor[3] + const Offset(0, 11),
        floor[2] + const Offset(0, 11),
      ],
      const Color(0xffc58e76),
      outline: _ink,
      width: 1.3,
    );
    _paintFloorboards(canvas, n);
    _wall(canvas, n, left: true);
    _wall(canvas, n, left: false);
    _line(
      canvas,
      [_project(0, n, 3), const Offset(0, -3), _project(n, 0, 3)],
      const Color(0xffa78383),
      width: 3.6,
    );
    _line(canvas, [floor[1], floor[2], floor[3]], _ink, width: 1.5);
  }

  void _paintFloorboards(Canvas canvas, double n) {
    const boards = [
      Color(0xffe8b991),
      Color(0xffeec39d),
      Color(0xffe6b48e),
      Color(0xffebbe97),
      Color(0xffecc39f),
    ];
    const seam = Color(0xffce9d87);
    for (var row = 0; row < n * 2; row++) {
      final y = row / 2;
      var start = 0.0;
      var end = row.isEven ? .95 : 1.7;
      var index = 0;
      while (start < n) {
        end = math.min(end, n);
        _shape(
          canvas,
          _floorCell(start, y, end - start, .5),
          boards[(row * 11 + index * 3) % boards.length],
          outline: seam,
          width: .65,
        );
        if (end - start > .6) {
          final grain = y + .15 + (index % 3) * .07;
          _line(
            canvas,
            [
              _project(start + .19, grain),
              _project((start + end) * .5, grain + .024),
              _project(end - .23, grain),
            ],
            const Color(0xffdbac90),
            width: .65,
          );
        }
        start = end;
        end += 1.45 + ((row + index) % 3) * .22;
        index++;
      }
    }
  }

  void _wall(Canvas canvas, double n, {required bool left}) {
    final width = n * _tileX;
    final wall = Rect.fromLTWH(0, 0, width, _wallHeight);
    canvas.save();
    canvas.translate(0, -_wallHeight);
    canvas.transform(
      Float64List.fromList([
        left ? -1 : 1,
        _tileY / _tileX,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
      ]),
    );
    final plaster = left ? const Color(0xffdcb1b7) : const Color(0xffecd0c5);
    final stripe = left ? const Color(0xffe7bec2) : const Color(0xfff3dbd0);
    final panels = left ? const Color(0xffbd8d9d) : const Color(0xffd7a9aa);
    canvas.drawRect(wall, Paint()..color = plaster);
    canvas.save();
    canvas.clipRect(wall);
    for (var x = 6.0; x < width; x += 13) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 4, 74), Paint()..color = stripe);
    }
    canvas.restore();
    canvas.drawRect(Rect.fromLTWH(0, 74, width, 31), Paint()..color = panels);
    for (var x = 9.0; x < width - 17; x += 24) {
      _rounded(
        canvas,
        Rect.fromLTWH(x, 80, 15, 18),
        1.6,
        panels,
        outline: plaster.withValues(alpha: .77),
      );
    }
    _line(
      canvas,
      [const Offset(0, 74), Offset(width, 74)],
      plaster,
      width: 3.1,
    );
    _line(canvas, [const Offset(0, 4), Offset(width, 4)], stripe, width: 4.1);
    canvas.drawRect(wall, _stroke(_ink.withValues(alpha: .77), 1.35));
    if (left) {
      _artwork(canvas, width * .52);
    } else {
      _window(canvas, width * .54);
    }
    canvas.restore();
  }

  void _artwork(Canvas canvas, double wallX) {
    _line(canvas, [
      Offset(wallX - 12, 31),
      Offset(wallX, 18),
      Offset(wallX + 12, 31),
    ], const Color(0xff8c6571));
    _oval(
      canvas,
      Rect.fromCenter(center: Offset(wallX, 18), width: 4, height: 4),
      const Color(0xff9e765e),
    );
    final center = Offset(wallX, 44);
    _oval(
      canvas,
      Rect.fromCenter(
        center: center + const Offset(2, 3),
        width: 44,
        height: 43,
      ),
      const Color(0x32865668),
    );
    _oval(
      canvas,
      Rect.fromCenter(center: center, width: 43, height: 43),
      const Color(0xffbc856e),
      outline: _ink,
    );
    _oval(
      canvas,
      Rect.fromCenter(center: center, width: 34, height: 34),
      const Color(0xffffe9cf),
      outline: const Color(0xffe2ab91),
    );
    _line(
      canvas,
      [
        center + const Offset(-4, 10),
        center + const Offset(0, 1),
        center + const Offset(5, -9),
      ],
      const Color(0xff718365),
      width: 1.2,
    );
    _leaf(
      canvas,
      center + const Offset(-4, 1),
      10,
      5,
      .65,
      const Color(0xff839369),
    );
    _leaf(
      canvas,
      center + const Offset(6, 1),
      10,
      5,
      -.71,
      const Color(0xff8b9d73),
    );
    _leaf(
      canvas,
      center + const Offset(1, -5),
      9,
      5,
      .80,
      const Color(0xffabb27c),
    );
    _oval(
      canvas,
      Rect.fromCircle(center: center + const Offset(7, -9), radius: 3),
      const Color(0xffd89598),
    );
    _sparkle(canvas, Offset(wallX + 30, 35), 4.6, const Color(0xfffce4bc));
    _sparkle(canvas, Offset(wallX + 37, 47), 2.6, const Color(0xfffce4bc));
  }

  void _window(Canvas canvas, double widthCenter) {
    final frame = Rect.fromCenter(
      center: Offset(widthCenter, 44),
      width: 71,
      height: 60,
    );
    _rounded(
      canvas,
      frame.shift(const Offset(3, 4)),
      5,
      const Color(0x45856273),
    );
    _rounded(canvas, frame, 5, const Color(0xff9b748c), outline: _ink);
    final view = frame.deflate(5);
    _rounded(canvas, view, 2, const Color(0xffbad3cf));
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(view, const Radius.circular(2)));
    _oval(
      canvas,
      Rect.fromCircle(center: view.topLeft + const Offset(43, 13), radius: 8),
      const Color(0xffffdd9d),
    );
    _oval(
      canvas,
      Rect.fromCenter(
        center: view.topLeft + const Offset(15, 11),
        width: 18,
        height: 4,
      ),
      const Color(0xffeff0dc),
    );
    final hills = Path()
      ..moveTo(view.left, view.top + 29)
      ..quadraticBezierTo(
        view.left + 12,
        view.top + 19,
        view.left + 28,
        view.top + 36,
      )
      ..quadraticBezierTo(
        view.left + 49,
        view.top + 25,
        view.right,
        view.top + 28,
      )
      ..lineTo(view.right, view.bottom)
      ..lineTo(view.left, view.bottom)
      ..close();
    canvas.drawPath(hills, Paint()..color = const Color(0xff89aaa3));
    _oval(
      canvas,
      Rect.fromCenter(
        center: view.bottomRight + const Offset(-3, 1),
        width: 55,
        height: 31,
      ),
      const Color(0xff71978a),
    );
    _oval(
      canvas,
      Rect.fromCenter(
        center: view.bottomLeft + const Offset(7, 4),
        width: 50,
        height: 26,
      ),
      const Color(0xff7ea28e),
    );
    canvas.restore();
    _line(
      canvas,
      [Offset(frame.center.dx, view.top), Offset(frame.center.dx, view.bottom)],
      const Color(0xffa67e94),
      width: 3,
    );
    _line(
      canvas,
      [Offset(view.left, frame.center.dy), Offset(view.right, frame.center.dy)],
      const Color(0xffa67e94),
      width: 3,
    );
    _line(
      canvas,
      [
        frame.bottomLeft - const Offset(5, 1),
        frame.bottomRight + const Offset(5, -1),
      ],
      const Color(0xff795a74),
      width: 4,
    );
    _line(
      canvas,
      [
        frame.bottomLeft - const Offset(6, 3),
        frame.bottomRight + const Offset(6, -3),
      ],
      const Color(0xffc99eae),
      width: 2.2,
    );

    final curtain = Path()
      ..moveTo(frame.left - 5, frame.top + 3)
      ..lineTo(frame.left + 12, frame.top + 3)
      ..quadraticBezierTo(
        frame.left + 12,
        frame.top + 22,
        frame.left + 5,
        frame.top + 35,
      )
      ..lineTo(frame.left + 8, frame.bottom - 1)
      ..quadraticBezierTo(
        frame.left,
        frame.bottom + 3,
        frame.left - 8,
        frame.bottom,
      )
      ..quadraticBezierTo(
        frame.left - 4,
        frame.top + 29,
        frame.left - 5,
        frame.top + 3,
      )
      ..close();
    for (final mirrored in [false, true]) {
      canvas.save();
      if (mirrored) {
        canvas.translate(frame.center.dx * 2, 0);
        canvas.scale(-1, 1);
      }
      canvas.drawPath(curtain, Paint()..color = const Color(0xfff2bdb6));
      canvas.drawPath(curtain, _stroke(const Color(0xffba8b99), .9));
      _line(canvas, [
        Offset(frame.left + 3, frame.top + 7),
        Offset(frame.left + 1, frame.top + 28),
        Offset(frame.left - 2, frame.top + 37),
      ], const Color(0xffdfa5aa));
      _line(
        canvas,
        [
          Offset(frame.left - 6, frame.top + 38),
          Offset(frame.left + 5, frame.top + 38),
        ],
        const Color(0xffb17a89),
        width: 1.7,
      );
      canvas.restore();
    }
    _line(
      canvas,
      [frame.topLeft - const Offset(9, 0), frame.topRight + const Offset(9, 0)],
      const Color(0xff8f667d),
      width: 2.6,
    );
  }

  void _leaf(
    Canvas canvas,
    Offset point,
    double width,
    double height,
    double angle,
    Color color,
  ) {
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate(angle);
    _oval(
      canvas,
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      color,
    );
    canvas.restore();
  }

  void _sparkle(Canvas canvas, Offset p, double radius, Color color) {
    _shape(canvas, [
      p + Offset(0, -radius),
      p + Offset(radius * .23, -radius * .23),
      p + Offset(radius, 0),
      p + Offset(radius * .23, radius * .23),
      p + Offset(0, radius),
      p + Offset(-radius * .23, radius * .23),
      p + Offset(-radius, 0),
      p + Offset(-radius * .23, -radius * .23),
    ], color);
  }

  void _drawFurniture(Canvas canvas, Placement prop) {
    final x = prop.x.toDouble();
    final y = prop.y.toDouble();
    final w = prop.item.width.toDouble();
    final d = prop.item.depth.toDouble();
    final center = _project(x + w * .5, y + d * .5);
    switch (prop.itemId) {
      case 'rug':
        _drawRug(canvas, x, y, w, d);
      case 'bed':
        _drawBed(canvas, x, y, w, d);
      case 'plant':
        _drawPlant(canvas, center);
      case 'scratcher':
        _drawScratcher(canvas, x, y, center);
      case 'sofa':
        _drawSofa(canvas, x, y, w, d);
      case 'shelf':
        _drawShelf(canvas, x, y, w, d);
      default:
        _drawCrate(canvas, x, y, w, d);
    }
  }

  void _box(
    Canvas canvas,
    double x,
    double y,
    double w,
    double d,
    double height, {
    required Color top,
    required Color left,
    required Color right,
    double lift = 0,
    Color outline = _ink,
  }) {
    final upper = _floorCell(x, y, w, d, lift + height);
    final base = _floorCell(x, y, w, d, lift);
    _shape(
      canvas,
      [upper[1], upper[2], base[2], base[1]],
      right,
      outline: outline,
    );
    _shape(
      canvas,
      [upper[2], upper[3], base[3], base[2]],
      left,
      outline: outline,
    );
    _shape(canvas, upper, top, outline: outline);
  }

  void _propShadow(Canvas canvas, double x, double y, double w, double d) {
    _shape(
      canvas,
      _floorCell(x + .12, y + .15, w - .08, d - .1),
      const Color(0x406b4344),
    );
  }

  void _drawRug(Canvas canvas, double x, double y, double w, double d) {
    final origin = _project(x + .12, y + .12);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.transform(
      Float64List.fromList([
        1,
        _tileY / _tileX,
        0,
        0,
        -1,
        _tileY / _tileX,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
      ]),
    );
    final frame = Rect.fromLTWH(0, 0, (w - .24) * _tileX, (d - .24) * _tileX);
    const mauve = Color(0xffac7187);
    _rounded(
      canvas,
      frame.shift(const Offset(2, 2)),
      9,
      const Color(0x52855457),
    );
    for (var x = 8.0; x < frame.width - 5; x += 4.6) {
      _line(
        canvas,
        [Offset(x, -3.6), Offset(x, 3.6)],
        const Color(0xffdfb0a9),
        width: 1.7,
      );
      _line(
        canvas,
        [Offset(x, frame.height - 3), Offset(x, frame.height + 4)],
        const Color(0xffdfb0a9),
        width: 1.7,
      );
    }
    _rounded(canvas, frame, 9, mauve, outline: const Color(0xff8d596f));
    _rounded(canvas, frame.deflate(4.0), 7, const Color(0xfff0b6ad));
    _rounded(
      canvas,
      frame.deflate(7.0),
      5,
      const Color(0xffc78c9c),
      outline: mauve,
    );
    _rounded(
      canvas,
      frame.deflate(11.0),
      4,
      const Color(0xffd9a1a8),
      outline: const Color(0xffeab6ad),
    );
    final center = frame.center;
    _shape(canvas, [
      center + const Offset(-14, 0),
      center + const Offset(0, -14),
      center + const Offset(14, 0),
      center + const Offset(0, 14),
    ], const Color(0xffedbdac));
    _sparkle(canvas, center, 8, mauve);
    _sparkle(
      canvas,
      center + const Offset(-17, -17),
      4,
      const Color(0xffefbdaf),
    );
    _sparkle(canvas, center + const Offset(17, 17), 4, const Color(0xffefbdaf));
    canvas.restore();
  }

  void _drawBed(Canvas canvas, double x, double y, double w, double d) {
    _propShadow(canvas, x, y, w, d);
    _box(
      canvas,
      x + .08,
      y + .08,
      w - .15,
      d - .13,
      11,
      top: const Color(0xffb682a0),
      left: const Color(0xffa37191),
      right: const Color(0xff895f80),
    );
    _box(
      canvas,
      x + .13,
      y + .12,
      w - .24,
      d - .21,
      4,
      lift: 11,
      top: const Color(0xffefd5c8),
      left: const Color(0xffc899b0),
      right: const Color(0xffb789a6),
      outline: const Color(0xff936d86),
    );
    _box(
      canvas,
      x + .13,
      y + .12,
      .47,
      d - .21,
      7,
      lift: 11,
      top: const Color(0xfff4e3ce),
      left: const Color(0xffdcc4bf),
      right: const Color(0xffcaaeb8),
      outline: const Color(0xffaa8295),
    );
    _box(
      canvas,
      x + .71,
      y + .11,
      w - .84,
      d - .19,
      4,
      lift: 12,
      top: const Color(0xffd899aa),
      left: const Color(0xffc1869d),
      right: const Color(0xffac718c),
      outline: const Color(0xff9f6685),
    );
    for (var step = 0.86; step < w - .16; step += .19) {
      _line(
        canvas,
        [
          _project(x + step, y + .19, 16.1),
          _project(x + step, y + d - .14, 16.1),
        ],
        const Color(0xffefb3b6),
        width: .75,
      );
    }
    for (var step = .28; step < d - .2; step += .21) {
      _line(
        canvas,
        [
          _project(x + .76, y + step, 16.2),
          _project(x + w - .2, y + step, 16.2),
        ],
        const Color(0xffe8a8af),
        width: .65,
      );
    }
    _sparkle(
      canvas,
      _project(x + .35, y + d * .52, 18.2),
      3.8,
      const Color(0xffceaab3),
    );
  }

  void _drawPlant(Canvas canvas, Offset p) {
    _oval(
      canvas,
      Rect.fromCenter(center: p + const Offset(3, 1), width: 32, height: 11),
      const Color(0x42634745),
    );
    _shape(
      canvas,
      [
        p + const Offset(-12, -17),
        p + const Offset(12, -17),
        p + const Offset(8, -2),
        p + const Offset(3, 1),
        p + const Offset(-6, 0),
        p + const Offset(-9, -4),
      ],
      const Color(0xffcb8a75),
      outline: _ink,
    );
    _line(
      canvas,
      [p + const Offset(-7, -13), p + const Offset(-4, -4)],
      const Color(0xffefad8d),
      width: 1.8,
    );
    _oval(
      canvas,
      Rect.fromCenter(center: p + const Offset(0, -17), width: 25, height: 9),
      const Color(0xffe5a78a),
      outline: _ink,
    );
    _oval(
      canvas,
      Rect.fromCenter(center: p + const Offset(0, -17), width: 19, height: 5),
      const Color(0xff785746),
    );
    const stems = Color(0xff5e7660);
    _line(
      canvas,
      [
        p + const Offset(0, -18),
        p + const Offset(-3, -27),
        p + const Offset(-9, -35),
      ],
      stems,
      width: 1.7,
    );
    _line(
      canvas,
      [
        p + const Offset(0, -18),
        p + const Offset(5, -29),
        p + const Offset(12, -36),
      ],
      stems,
      width: 1.4,
    );
    _line(
      canvas,
      [p + const Offset(0, -18), p + const Offset(0, -42)],
      stems,
      width: 1.4,
    );
    _leaf(
      canvas,
      p + const Offset(-1, -42),
      9,
      15,
      -.25,
      const Color(0xff819666),
    );
    _leaf(
      canvas,
      p + const Offset(-10, -35),
      17,
      8,
      .55,
      const Color(0xff718662),
    );
    _leaf(
      canvas,
      p + const Offset(10, -34),
      15,
      7,
      -.65,
      const Color(0xff8d9e70),
    );
    _leaf(
      canvas,
      p + const Offset(-10, -26),
      14,
      7,
      .27,
      const Color(0xff9ba779),
    );
    _leaf(
      canvas,
      p + const Offset(8, -25),
      14,
      7,
      -.32,
      const Color(0xff728c68),
    );
    _line(
      canvas,
      [p + const Offset(-1, -46), p + const Offset(0, -39)],
      const Color(0xffa7b781),
      width: .8,
    );
  }

  void _drawScratcher(Canvas canvas, double x, double y, Offset p) {
    _propShadow(canvas, x + .13, y + .13, .73, .73);
    _box(
      canvas,
      x + .14,
      y + .14,
      .72,
      .72,
      4,
      top: const Color(0xffd79699),
      left: const Color(0xffb87f92),
      right: const Color(0xff9e6a85),
    );
    _rounded(
      canvas,
      Rect.fromLTWH(p.dx - 6, p.dy - 42, 12, 38),
      4,
      const Color(0xffd4ab87),
      outline: _ink,
    );
    for (var step = 10.0; step < 41; step += 3.2) {
      _line(
        canvas,
        [p + Offset(-5, -step), p + Offset(4.5, -step + 1.5)],
        const Color(0xffb48a73),
        width: .9,
      );
    }
    _oval(
      canvas,
      Rect.fromCenter(center: p + const Offset(0, -42), width: 14, height: 7),
      const Color(0xffe2bea1),
      outline: const Color(0xffad807c),
    );
    final sway = math.sin(_seconds * 2.4) * 3.0;
    final ball = p + Offset(11 + sway, -24);
    _line(canvas, [p + const Offset(5, -42), ball], const Color(0xff896778));
    _oval(
      canvas,
      Rect.fromCircle(center: ball, radius: 4.5),
      const Color(0xffd892a8),
      outline: const Color(0xff936882),
    );
  }

  void _drawSofa(Canvas canvas, double x, double y, double w, double d) {
    _propShadow(canvas, x, y, w, d);
    _box(
      canvas,
      x + .07,
      y + .09,
      w - .12,
      d - .14,
      13,
      top: const Color(0xffe5b493),
      left: const Color(0xffc99580),
      right: const Color(0xffb47d72),
    );
    _box(
      canvas,
      x + .09,
      y + .10,
      w - .18,
      .22,
      17,
      lift: 13,
      top: const Color(0xffedc3a0),
      left: const Color(0xffd9a890),
      right: const Color(0xffbf8c83),
    );
    _box(
      canvas,
      x + .28,
      y + .32,
      w - .56,
      d - .46,
      6,
      lift: 13,
      top: const Color(0xffeec7a8),
      left: const Color(0xffdcad96),
      right: const Color(0xffc59184),
      outline: const Color(0xffa87978),
    );
    for (final side in [.09, w - .29]) {
      _box(
        canvas,
        x + side,
        y + .28,
        .20,
        d - .4,
        10,
        lift: 13,
        top: const Color(0xffedbf9d),
        left: const Color(0xffdba78c),
        right: const Color(0xffc08e7e),
      );
    }
    final pillow = _project(x + w - .48, y + .39, 23);
    canvas.save();
    canvas.translate(pillow.dx, pillow.dy);
    canvas.rotate(-.34);
    _rounded(
      canvas,
      const Rect.fromLTWH(-8, -5, 16, 11),
      3,
      const Color(0xffb2be9f),
      outline: const Color(0xff859880),
    );
    _sparkle(canvas, const Offset(1, 0), 2.7, const Color(0xffe3e9c4));
    canvas.restore();
  }

  void _drawShelf(Canvas canvas, double x, double y, double w, double d) {
    _propShadow(canvas, x, y, w, d);
    const top = Color(0xffc58d73);
    const left = Color(0xffad7466);
    const right = Color(0xff8c615e);
    for (final lift in [2.0, 20.0, 38.0]) {
      _box(
        canvas,
        x + .10,
        y + .11,
        w - .2,
        d * .68,
        4,
        lift: lift,
        top: top,
        left: left,
        right: right,
      );
    }
    for (final dx in [x + .10, x + w - .22]) {
      _box(
        canvas,
        dx,
        y + .11,
        .12,
        d * .69,
        40,
        top: top,
        left: left,
        right: right,
      );
    }
    const bookColors = [
      Color(0xffa9b897),
      Color(0xffc09aae),
      Color(0xffd6ac89),
      Color(0xffb0a1b6),
    ];
    for (var index = 0; index < bookColors.length; index++) {
      final bookX = x + .33 + index * .15;
      final cloth = bookColors[index];
      _box(
        canvas,
        bookX,
        y + .42,
        .11,
        .21,
        10.0 + (index % 2) * 3,
        lift: 24,
        top: cloth,
        left: cloth,
        right: const Color(0xff916e71),
        outline: const Color(0xff815e69),
      );
    }
    final vase = _project(x + w * .52, y + .40, 43);
    _oval(
      canvas,
      Rect.fromCenter(
        center: vase + const Offset(0, -5),
        width: 13,
        height: 13,
      ),
      const Color(0xffe5b0a4),
      outline: _ink,
    );
    _rounded(
      canvas,
      Rect.fromCenter(center: vase + const Offset(0, -11), width: 6, height: 5),
      1.5,
      const Color(0xffdfa59f),
      outline: const Color(0xffa06f79),
    );
    _line(canvas, [
      vase + const Offset(0, -12),
      vase + const Offset(4, -21),
    ], const Color(0xff72876d));
    _leaf(
      canvas,
      vase + const Offset(5, -20),
      7,
      3,
      -.65,
      const Color(0xff9aa377),
    );
  }

  void _drawYarn(Canvas canvas, Offset p) {
    _oval(
      canvas,
      Rect.fromCenter(center: p + const Offset(2, 0), width: 27, height: 7),
      const Color(0x36634745),
    );
    const thread = Color(0xff8d647f);
    final end = Path()
      ..moveTo(p.dx + 6, p.dy - 2)
      ..quadraticBezierTo(p.dx + 20, p.dy + 4, p.dx + 17, p.dy - 2)
      ..quadraticBezierTo(p.dx + 13, p.dy - 8, p.dx + 22, p.dy - 7);
    canvas.drawPath(end, _stroke(thread, 1.2));
    _oval(
      canvas,
      Rect.fromCircle(center: p + const Offset(0, -5), radius: 8.5),
      const Color(0xffc08aa5),
      outline: thread,
    );
    for (var index = -1; index <= 1; index++) {
      final left = p + Offset(-6 + index * 2, -8);
      final curve = Path()
        ..moveTo(left.dx, left.dy)
        ..quadraticBezierTo(
          p.dx + index * 4,
          p.dy - 10,
          p.dx + 3 + index * 2,
          p.dy + 1,
        );
      canvas.drawPath(curve, _stroke(const Color(0xffe3aac0), .9));
    }
  }

  void _drawFoodBowl(Canvas canvas, Offset p) {
    _oval(
      canvas,
      Rect.fromCenter(center: p + const Offset(1, 1), width: 25, height: 8),
      const Color(0x36634745),
    );
    _oval(
      canvas,
      Rect.fromCenter(center: p, width: 22, height: 10),
      const Color(0xff99aa98),
      outline: const Color(0xff6f887b),
    );
    _oval(
      canvas,
      Rect.fromCenter(center: p + const Offset(0, -3), width: 22, height: 8),
      const Color(0xffc0c9a9),
      outline: const Color(0xff6f887b),
    );
    _oval(
      canvas,
      Rect.fromCenter(center: p + const Offset(0, -3), width: 17, height: 4),
      const Color(0xff976e58),
    );
    for (final dx in [-4.5, 0.0, 4.5]) {
      _oval(
        canvas,
        Rect.fromCircle(center: p + Offset(dx, -4.5), radius: 1.7),
        const Color(0xffbf936e),
      );
    }
  }

  void _drawFeather(Canvas canvas, Offset p) {
    _oval(
      canvas,
      Rect.fromCenter(center: p + const Offset(0, 1), width: 41, height: 8),
      const Color(0x36634745),
    );
    _line(
      canvas,
      [p + const Offset(-18, 3), p + const Offset(1, -6)],
      const Color(0xff825d69),
      width: 2.7,
    );
    _line(canvas, [
      p + const Offset(1, -6),
      p + const Offset(10, -8),
    ], const Color(0xffa77a8a));
    _leaf(
      canvas,
      p + const Offset(15, -10),
      17,
      8,
      -.35,
      const Color(0xffdd95a6),
    );
    _leaf(
      canvas,
      p + const Offset(12, -14),
      13,
      6,
      -.81,
      const Color(0xffb484a3),
    );
    _line(
      canvas,
      [p + const Offset(9, -8), p + const Offset(20, -12)],
      const Color(0xffedacb5),
      width: .85,
    );
  }

  void _drawCrate(Canvas canvas, double x, double y, double w, double d) {
    _propShadow(canvas, x + .12, y + .12, w - .2, d - .2);
    _box(
      canvas,
      x + .16,
      y + .20,
      w - .30,
      d - .39,
      13,
      top: const Color(0xffd8ac85),
      left: const Color(0xffbc876f),
      right: const Color(0xffa57263),
    );
  }
}
