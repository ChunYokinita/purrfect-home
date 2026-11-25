import 'package:flutter_test/flutter_test.dart';
import 'package:purrfect_home/home_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('care changes needs, consumes food, and builds affection', () {
    var now = DateTime(2026, 11, 25, 12);
    final state = HomeState.fresh(clock: () => now);
    addTearDown(state.dispose);

    expect(state.feed(), isTrue);
    expect(state.hunger, 26);
    expect(state.owned('kibble'), 2);
    expect(state.feed(), isTrue);
    expect(state.feed(), isFalse);
    expect(state.hunger, 0);
    expect(state.owned('kibble'), 1);

    expect(state.pet(), isTrue);
    expect(state.pet(), isFalse);
    now = now.add(const Duration(seconds: 5));
    state.syncTime();
    expect(state.canPet, isTrue);
    expect(state.pet(), isTrue);

    expect(state.play(itemId: 'feather'), isFalse);
    expect(state.play(itemId: 'yarn'), isTrue);
    expect(state.owned('yarn'), 1);
    expect(state.energy, 68);
    expect(state.hunger, 4);
    expect(state.happiness, 100);
    expect(state.affection, 19);
  });

  test('buying, placing, moving, and storing preserve inventory', () {
    final state = HomeState.fresh();
    addTearDown(state.dispose);

    expect(state.buy('sofa'), isTrue);
    expect(state.coins, 29);
    expect(state.buy('scratcher'), isFalse);
    expect(state.owned('sofa'), 1);
    expect(state.place('sofa', 4, 4), isFalse);
    expect(state.place('sofa', 2, 0), isFalse);
    expect(state.place('sofa', 1, 2), isFalse);
    expect(state.place('yarn', 0, 0), isFalse);
    expect(state.place('sofa', 0, 4), isTrue);
    expect(state.owned('sofa'), 0);

    final sofa = state.placementAt(1, 4)!;
    expect(sofa.itemId, 'sofa');
    expect(state.move(sofa.id, 1, 3), isFalse);
    expect(state.placementAt(0, 4), same(sofa));
    expect(state.move(sofa.id, 1, 4), isTrue);
    expect(state.placementAt(0, 4), isNull);
    expect(state.placementAt(2, 4)?.id, sofa.id);
    expect(state.store(sofa.id), isTrue);
    expect(state.store(sofa.id), isFalse);
    expect(state.owned('sofa'), 1);
    expect(state.placementAt(2, 4), isNull);
  });

  test('play without a toy skips the owned toy bonus', () {
    final state = HomeState.fresh();
    addTearDown(state.dispose);

    expect(state.owned('yarn'), 1);
    expect(state.play(), isTrue);
    expect(state.happiness, 77);
    expect(state.play(itemId: 'yarn'), isTrue);
    expect(state.happiness, 95);
  });

  test('passive income carries partial intervals and caps long absences', () {
    var now = DateTime(2026, 11, 25, 12);
    final state = HomeState.fresh(clock: () => now);
    addTearDown(state.dispose);

    now = now.add(const Duration(seconds: 29));
    state.syncTime();
    expect(state.bankedCoins, 0);
    now = now.add(const Duration(seconds: 1));
    state.syncTime();
    expect(state.bankedCoins, 1);
    expect(state.coins, 95);

    now = now.add(const Duration(days: 7));
    state.syncTime();
    expect(state.bankedCoins, HomeState.incomeCap);
    expect(state.hunger, 100);
    expect(state.energy, 0);
    expect(state.happiness, 0);
    expect(state.collectIncome(), HomeState.incomeCap);
    expect(state.collectIncome(), 0);
    expect(state.coins, 215);
    expect(state.rest(), isTrue);
    expect(state.amuse(), isTrue);
    expect(state.energy, 4);
    expect(state.happiness, 2);
  });

  test('daily tasks reset at midnight while milestones stay claimed', () {
    var now = DateTime(2026, 11, 25, 23, 59, 58);
    final state = HomeState.fresh(clock: () => now);
    addTearDown(state.dispose);

    expect(state.claimObjective('play'), isFalse);
    expect(state.play(), isTrue);
    expect(state.play(), isTrue);
    expect(state.claimObjective('play'), isTrue);
    expect(state.claimObjective('play'), isFalse);
    expect(state.move('p3', 0, 0), isTrue);
    expect(state.claimObjective('decorate'), isTrue);

    now = now.add(const Duration(seconds: 2));
    state.syncTime();
    final objectives = {for (final goal in state.objectives) goal.id: goal};
    expect(objectives['play']?.claimed, isFalse);
    expect(objectives['play']?.progress, 0);
    expect(objectives['decorate']?.claimed, isTrue);
    expect(state.coins, 142);
  });

  test('two expansions unlock new cells in sequence', () {
    var now = DateTime(2026, 11, 25, 12);
    final state = HomeState.fresh(clock: () => now);
    addTearDown(state.dispose);

    expect(state.expand(), isFalse);
    expect(state.canPlace('plant', 5, 5), isFalse);
    state.feed();
    state.feed();
    state.pet();
    state.play();
    state.play();
    expect(state.affection, 21);
    expect(state.expand(), isTrue);
    expect(state.roomSize, 6);
    expect(state.canPlace('plant', 5, 5), isTrue);
    expect(state.expansionPrice, 195);
    state.claimObjective('expand');
    state.claimObjective('feed');
    state.claimObjective('play');
    now = now.add(const Duration(hours: 1));
    expect(state.collectIncome(), 120);
    expect(state.expand(), isFalse);

    for (var count = 0; count < 15; count++) {
      expect(state.pet(), isTrue);
      now = now.add(const Duration(seconds: 5));
    }
    expect(state.expand(), isTrue);
    expect(state.roomSize, 7);
    expect(state.canPlace('plant', 6, 6), isTrue);
    expect(state.expansionPrice, isNull);
    expect(state.expand(), isFalse);
  });

  test('reloading keeps progress and accrues offline time once', () async {
    SharedPreferences.setMockInitialValues({});
    var now = DateTime(2026, 11, 25, 12);
    final original = await HomeState.load(clock: () => now, startTimer: false);

    original.feed();
    original.feed();
    original.pet();
    original.play();
    original.play();
    original.claimObjective('play');
    original.expand();
    original.move('p1', 4, 5);
    original.buy('salmon');
    now = now.add(const Duration(seconds: 15));
    await original.save();
    original.dispose();

    now = now.add(const Duration(seconds: 15));
    final reopened = await HomeState.load(clock: () => now, startTimer: false);
    expect(reopened.affection, 21);
    expect(reopened.energy, 58);
    expect(reopened.hunger, 8);
    expect(reopened.roomSize, 6);
    expect(reopened.placementAt(5, 5)?.id, 'p1');
    expect(reopened.owned('salmon'), 1);
    expect(reopened.coins, 9);
    expect(reopened.claimObjective('play'), isFalse);
    expect(reopened.collectIncome(), 1);
    await reopened.save();
    reopened.dispose();

    final reopenedAgain = await HomeState.load(
      clock: () => now,
      startTimer: false,
    );
    addTearDown(reopenedAgain.dispose);
    expect(reopenedAgain.coins, 10);
    expect(reopenedAgain.collectIncome(), 0);
  });
}
