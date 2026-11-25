part of 'main.dart';

const _paper = Color(0xFFF8F3ED);
const _card = Color(0xFFFFFCF8);
const _ink = Color(0xFF30242E);
const _muted = Color(0xFF6D5A65);
const _wine = Color(0xFF7D3D65);
const _line = Color(0xFFE9DDD5);
const _rose = Color(0xFFF3E2E9);
const _gold = Color(0xFF96601E);
const _goldWash = Color(0xFFFFEECF);
const _sage = Color(0xFF486951);
const _sageWash = Color(0xFFE7EFE1);
const _lavender = Color(0xFF66508C);
const _lavenderWash = Color(0xFFEDE5F6);

TextStyle _display(double size) => TextStyle(
  fontFamily: 'Fraunces',
  fontSize: size,
  height: 1.06,
  letterSpacing: -.035 * size,
  color: _ink,
  fontVariations: const [FontVariation('wght', 580), FontVariation('SOFT', 30)],
);

TextStyle _label(double size, {Color color = _ink, double weight = 720}) =>
    TextStyle(
      fontSize: size,
      color: color,
      fontVariations: [FontVariation('wght', weight)],
    );

class _Header extends StatelessWidget {
  const _Header({required this.coins, required this.onCoins});

  final int coins;
  final VoidCallback onCoins;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1168),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _wine,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.pets_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Purrfect Home',
                      style: _display(24),
                      maxLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: 'Open coin jar',
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: _gold,
                      backgroundColor: _goldWash,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                    ),
                    onPressed: onCoins,
                    icon: const Icon(Icons.toll_rounded, size: 19),
                    label: Text(
                      '$coins coins',
                      style: _label(13, color: _gold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.trailing, this.subtitle});

  final String title;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width >= 850 ? 42.0 : 32.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(title, style: _display(size))),
            if (trailing case final widget?) ...[
              const SizedBox(width: 8),
              widget,
            ],
          ],
        ),
        if (subtitle case final text?) ...[
          const SizedBox(height: 8),
          Text(text, style: _label(15, color: _muted, weight: 520)),
        ],
      ],
    );
  }
}

class _Navigation extends StatelessWidget {
  const _Navigation({required this.tab, required this.onSelect});

  final _Tab tab;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Row(
                children: [
                  for (final destination in _Tab.values)
                    Expanded(
                      child: Semantics(
                        selected: tab == destination,
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => onSelect(destination),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tab == destination
                                        ? _rose
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Icon(
                                    tab == destination
                                        ? destination.selectedIcon
                                        : destination.icon,
                                    size: 22,
                                    color: tab == destination ? _wine : _muted,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  destination.label,
                                  style: _label(
                                    11.5,
                                    color: tab == destination ? _wine : _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.icon,
    required this.text,
    this.color = _wine,
    this.fill = _rose,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(text, style: _label(12, color: color)),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _card,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class _RoomStage extends StatelessWidget {
  const _RoomStage({
    required this.scene,
    required this.activity,
    required this.editing,
    required this.editName,
    required this.moving,
    required this.onEdit,
    required this.onCancel,
    required this.onStore,
    required this.onStorage,
  });

  final Widget scene;
  final ValueListenable<String> activity;
  final bool editing;
  final String? editName;
  final bool moving;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onStore;
  final VoidCallback onStorage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final height = (constraints.maxWidth * .83).clamp(254.0, 520.0);
            return Container(
              height: height,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5D2DF)),
                borderRadius: BorderRadius.circular(23),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const CustomPaint(painter: _StageBackground()),
                    Positioned.fill(top: 33, bottom: 9, child: scene),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: FilledButton.tonalIcon(
                        onPressed: onEdit,
                        style: FilledButton.styleFrom(
                          foregroundColor: editing ? Colors.white : _wine,
                          backgroundColor: editing ? _wine : _card,
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: Icon(
                          editing ? Icons.check_rounded : Icons.edit_outlined,
                          size: 17,
                        ),
                        label: Text(editing ? 'Done' : 'Edit room'),
                      ),
                    ),
                    if (!editing)
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: IgnorePointer(
                          child: ValueListenableBuilder<String>(
                            valueListenable: activity,
                            builder: (context, value, _) => _Tag(
                              icon: Icons.pets_rounded,
                              text: value,
                              fill: _card,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (editing) ...[
          const SizedBox(height: 9),
          _Panel(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                Text(
                  editName == null
                      ? 'Tap furniture to move it, or choose an item from Storage.'
                      : '${moving ? 'Moving' : 'Placing'} $editName. Tap a highlighted tile.',
                  style: _label(13, color: _muted, weight: 600),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (editName == null)
                      TextButton.icon(
                        onPressed: onStorage,
                        icon: const Icon(Icons.inventory_2_outlined, size: 17),
                        label: const Text('Open Storage'),
                      )
                    else
                      TextButton(
                        onPressed: onCancel,
                        child: const Text('Cancel'),
                      ),
                    if (moving)
                      TextButton.icon(
                        onPressed: onStore,
                        icon: const Icon(Icons.inventory_2_outlined, size: 17),
                        label: const Text('Put in Storage'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StageBackground extends CustomPainter {
  const _StageBackground();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final wash = const RadialGradient(
      center: Alignment(-.15, -.48),
      radius: 1.1,
      colors: [Color(0xFFFBEDF0), Color(0xFFE9D7E8), Color(0xFFE1CADF)],
      stops: [0, .61, 1],
    );
    canvas.drawRect(rect, Paint()..shader = wash.createShader(rect));
    final dot = Paint()..color = const Color(0x217D3D65);
    for (var y = 15.0; y < size.height; y += 20) {
      for (var x = 13.0; x < size.width; x += 20) {
        canvas.drawCircle(Offset(x, y), .85, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StageBackground oldDelegate) => false;
}

class _CarePanel extends StatelessWidget {
  const _CarePanel({
    required this.state,
    required this.onFeed,
    required this.onPet,
    required this.onPlay,
  });

  final HomeState state;
  final VoidCallback onFeed;
  final VoidCallback onPet;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: const Color(0xFFFFE5CB),
                  width: 49,
                  height: 49,
                  padding: const EdgeInsets.all(5),
                  child: Image.asset(
                    'assets/images/mochi.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Mochi', style: _display(29))),
              _Tag(
                icon: Icons.favorite_rounded,
                text: '${state.affection} bond',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Need(
            icon: Icons.restaurant_rounded,
            label: 'Fullness',
            value: 100 - state.hunger,
            color: _gold,
            fill: const Color(0xFFDA9E54),
            wash: _goldWash,
          ),
          _Need(
            icon: Icons.bolt_rounded,
            label: 'Energy',
            value: state.energy,
            color: _sage,
            fill: const Color(0xFF83A278),
            wash: _sageWash,
          ),
          _Need(
            icon: Icons.sentiment_satisfied_alt_rounded,
            label: 'Happiness',
            value: state.happiness,
            color: _lavender,
            fill: const Color(0xFF9E82BE),
            wash: _lavenderWash,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CareAction(
                  label: 'Feed',
                  icon: Icons.restaurant_rounded,
                  color: _gold,
                  fill: _goldWash,
                  onTap: onFeed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CareAction(
                  label: 'Pet',
                  icon: Icons.favorite_rounded,
                  color: _wine,
                  fill: _rose,
                  onTap: onPet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CareAction(
                  label: 'Play',
                  icon: Icons.toys_outlined,
                  color: _sage,
                  fill: _sageWash,
                  onTap: onPlay,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Need extends StatelessWidget {
  const _Need({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.fill,
    required this.wash,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final Color fill;
  final Color wash;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label, style: _label(12.5))),
                    Text('$value%', style: _label(12, color: color)),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: value / 100,
                  minHeight: 5,
                  color: fill,
                  backgroundColor: wash,
                  borderRadius: BorderRadius.circular(10),
                  semanticsLabel: label,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CareAction extends StatelessWidget {
  const _CareAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.fill,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(13);
    return Material(
      color: fill,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(height: 3),
              Text(label, style: _label(12, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncomePanel extends StatelessWidget {
  const _IncomePanel({required this.amount, required this.onCollect});

  final int amount;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: _goldWash,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.savings_outlined, color: _gold, size: 21),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Coin jar', style: _label(14)),
                Text(
                  amount == 1 ? '1 coin ready' : '$amount coins ready',
                  style: _label(11.5, color: _muted, weight: 550),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: amount > 0 ? onCollect : null,
            child: const Text('Collect'),
          ),
        ],
      ),
    );
  }
}

String _categoryLabel(ItemCategory category) => switch (category) {
  ItemCategory.food => 'Food',
  ItemCategory.toy => 'Toys',
  ItemCategory.furniture => 'Furniture',
  ItemCategory.decor => 'Décor',
};

class _ItemIcon extends StatelessWidget {
  const _ItemIcon({required this.item, this.size = 57});

  final CatalogItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (symbol, color, fill) = switch (item.id) {
      'kibble' => (Icons.rice_bowl_rounded, _gold, _goldWash),
      'salmon' => (Icons.set_meal_rounded, _wine, _rose),
      'yarn' => (Icons.sports_baseball_outlined, _lavender, _lavenderWash),
      'feather' => (Icons.auto_awesome_rounded, _wine, _rose),
      'bed' => (Icons.bed_rounded, _lavender, _lavenderWash),
      'scratcher' => (Icons.carpenter_rounded, _gold, _goldWash),
      'sofa' => (Icons.weekend_rounded, _wine, _rose),
      'plant' => (Icons.local_florist_rounded, _sage, _sageWash),
      'rug' => (Icons.dashboard_customize_rounded, _lavender, _lavenderWash),
      'shelf' => (Icons.shelves, _sage, _sageWash),
      _ => (Icons.inventory_2_rounded, _wine, _rose),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size * .27),
      ),
      child: Icon(symbol, color: color, size: size * .51),
    );
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final columns = constraints.maxWidth >= 850
            ? 3
            : constraints.maxWidth >= 580
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.detail,
    required this.action,
  });

  final CatalogItem item;
  final String detail;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ItemIcon(item: item),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: _display(20)),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: _label(13, color: _muted, weight: 520),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(detail, style: _label(12, color: _muted)),
              ),
              action,
            ],
          ),
        ],
      ),
    );
  }
}

class _ObjectiveTile extends StatelessWidget {
  const _ObjectiveTile({required this.objective, required this.onClaim});

  final Objective objective;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(objective.title, style: _display(22))),
              _Tag(
                icon: Icons.toll_rounded,
                text: '+${objective.reward}',
                color: _gold,
                fill: _goldWash,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            objective.description,
            style: _label(13, color: _muted, weight: 530),
          ),
          const SizedBox(height: 13),
          LinearProgressIndicator(
            value: objective.progress / objective.target,
            color: _wine,
            backgroundColor: _rose,
            borderRadius: BorderRadius.circular(10),
            semanticsLabel: objective.title,
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${objective.progress} / ${objective.target}',
                  style: _label(13, color: _muted),
                ),
              ),
              TextButton(
                onPressed: objective.ready && !objective.claimed
                    ? onClaim
                    : null,
                child: Text(objective.claimed ? 'Claimed' : 'Claim reward'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
