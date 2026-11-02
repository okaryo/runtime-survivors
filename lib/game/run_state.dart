import 'dart:math';
import 'dart:math' as math show log;

import 'package:flame/components.dart';

import '../audio/sound_cue.dart';
import 'combat_entities.dart';
import 'spawn_director.dart';
import 'build.dart';
import 'deadlock_encounter.dart';
import 'ability_runtime.dart';
export 'combat_entities.dart';
export 'build.dart';

enum RunPhase { ready, running, choosing, paused, won, lost }

class RunLog {
  const RunLog(this.key, {this.args = const {}, this.upgrade});
  final String key;
  final Map<String, Object> args;
  final Upgrade? upgrade;
}

/// Deterministic simulation, independent of the render loop and Flutter UI.
class RunState {
  RunState({Random? random}) : random = random ?? Random();
  static const duration = 300.0;
  final Random random;
  RunPhase phase = RunPhase.ready;
  final player = Vector2.zero();
  final movement = Vector2.zero();
  final List<TaskEnemy> enemies = [];
  final List<Instruction> instructions = [];
  final List<Experience> experience = [];
  final List<RunEffect> effects = [];
  final List<RuntimeObject> objects = [];
  final List<LinearProjectile> projectiles = [];
  final List<DangerZone> hazards = [];
  final abilities = AbilityRuntime();
  final List<DeadlockEncounter> deadlocks = [];
  Iterable<LockBarrier> get lockBarriers => deadlocks.expand((e) => e.barriers);
  static const instructionLimit = 384;
  final director = const SpawnDirector();
  final Set<int> seenEnemies = {};
  final Set<int> _introduced = {};
  final Set<Upgrade> seenUpgrades = {};
  final Map<Upgrade, int> upgrades = {};
  late final BuildStats _stats = BuildStats.live(upgrades);
  final List<RunLog> events = [const RunLog('log.ready')];
  final Set<SoundCue> cues = {};
  List<Upgrade> choices = [];
  double elapsed = 0;
  double health = 100;
  int level = 1;
  int xp = 0;
  int kills = 0;
  double spawnRadius = 580;
  double _spawnTimer = 0;
  double _attackTimer = 0;
  double _gcTimer = 3;
  double _patternTimer = 0;
  static const featureSlots = 4;
  static const infraSlots = 4;
  int get featureCount =>
      upgrades.keys.where((u) => u.isFeature && rank(u) > 0).length;
  int get infraCount =>
      upgrades.keys.where((u) => !u.isFeature && rank(u) > 0).length;
  double get projectileSpeed => _stats.projectileSpeed;
  double invulnerability = 0;
  double _nextRush = 45;
  double _rushUntil = 0;
  double _nextDeadlock = 75;
  int rushCount = 0;
  int deadlockCount = 0;

  bool get isRush => phase != RunPhase.ready && elapsed < _rushUntil;
  double get secondsToRush => max(0, _nextRush - elapsed);

  int rank(Upgrade upgrade) => upgrades[upgrade] ?? 0;
  int get nextLevelXp => 12 + (level - 1) * 7;
  double get maxHealth => _stats.maxHealth;
  double get speed => _stats.speed;
  double get pickupRadius => _stats.pickupRadius;
  double get attackRange => _stats.attackRange;
  double get objectDamage => _stats.objectDamage;
  double get objectInterval => _stats.objectInterval;
  double get chainRadius => _stats.chainRadius;
  double get attackDamage => _stats.attackDamage;
  double get attackInterval => _stats.attackInterval;
  double get gcRadius => _stats.gcRadius;
  double get gcDamage => _stats.gcDamage;
  int get targetCount => _stats.targetCount;
  String get timeLabel {
    final seconds = elapsed.floor();
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void resetToSetup() => _initialize(RunPhase.ready);

  void start() => _initialize(RunPhase.running);

  void _initialize(RunPhase initialPhase) {
    _stats.jitOptimized = false;
    phase = initialPhase;
    player.setZero();
    movement.setZero();
    enemies.clear();
    _introduced.clear();
    instructions.clear();
    experience.clear();
    effects.clear();
    objects.clear();
    projectiles.clear();
    hazards.clear();
    deadlocks.clear();
    abilities.reset();
    upgrades.clear();
    choices = [];
    elapsed = 0;
    health = 100;
    level = 1;
    xp = 0;
    kills = 0;
    _spawnTimer = 0;
    _attackTimer = 0;
    _gcTimer = 3;
    _patternTimer = 0;
    invulnerability = 0;
    _nextRush = 45;
    _rushUntil = 0;
    _nextDeadlock = 75;
    rushCount = 0;
    deadlockCount = 0;
    events.clear();
    if (initialPhase == RunPhase.ready) {
      log(const RunLog('log.ready'));
      cues.clear();
      return;
    }
    log(const RunLog('log.start'));
    cues
      ..clear()
      ..add(SoundCue.start);
    for (var i = 0; i < 6; i++) {
      _spawn(radius: 240 + random.nextDouble() * 100);
    }
  }

  void log(RunLog message) {
    events.insert(0, message);
    if (events.length > 4) events.removeLast();
  }

  void pause() {
    if (phase != RunPhase.running) return;
    phase = RunPhase.paused;
    movement.setZero();
  }

  void resume() {
    if (phase == RunPhase.paused) phase = RunPhase.running;
  }

  void addExperience(int amount) {
    xp += amount;
    _checkLevel();
  }

  bool canUpgrade(Upgrade upgrade) =>
      upgrade.isAvailable &&
      rank(upgrade) < upgrade.maxRank &&
      (upgrade.requiresAny.isEmpty ||
          upgrade.requiresAny.any((required) => rank(required) > 0)) &&
      (rank(upgrade) > 0 ||
          (upgrade.isFeature
              ? featureCount < featureSlots
              : infraCount < infraSlots));

  void _checkLevel() {
    if (phase != RunPhase.running || xp < nextLevelXp) return;
    final available = Upgrade.values.where(canUpgrade).toList();
    if (available.isEmpty) {
      // A fully capped build must not get stuck on an empty choice screen.
      while (xp >= nextLevelXp) {
        xp -= nextLevelXp;
        level++;
        health = min(maxHealth, health + 35);
      }
      log(const RunLog('log.maintenance'));
      cues.add(SoundCue.levelUp);
      return;
    }
    xp -= nextLevelXp;
    level++;
    phase = RunPhase.choosing;
    movement.setZero();
    // Weighted sampling without replacement; later choices favor invested features.
    final keys = {
      for (final u in available)
        u:
            -math.log(max(0.000001, random.nextDouble())) /
            (level >= 5 && rank(u) > 0 && u.isFeature ? 2.5 : 1.0),
    };
    available.sort((a, b) => keys[a]!.compareTo(keys[b]!));
    final features = available.where((u) => u.isFeature).toList();
    final infrastructure = available.where((u) => !u.isFeature).toList();
    if (features.isNotEmpty && infrastructure.isNotEmpty) {
      final firstTwo = [features.first, infrastructure.first];
      choices = [
        ...firstTwo,
        ...available.where((u) => !firstTwo.contains(u)).take(1),
      ]..shuffle(random);
    } else {
      choices = available.take(3).toList();
    }
    log(RunLog('log.level', args: {'level': level}));
    cues.add(SoundCue.levelUp);
  }

  /// Predicts an acquisition without mutating combat, RNG, ranks or HP.
  UpgradePreview preview(Upgrade upgrade) {
    final before = BuildStats.snapshot(
      upgrades,
      jitOptimized: _stats.jitOptimized,
    );
    final after = BuildStats.snapshot({
      ...upgrades,
      upgrade: rank(upgrade) + 1,
    }, jitOptimized: _stats.jitOptimized);
    return UpgradePreview(
      upgrade: upgrade,
      before: before,
      after: after,
      beforeHealth: health,
      afterHealth: min(
        after.maxHealth,
        health + (upgrade == Upgrade.memory ? 35 : 0),
      ),
    );
  }

  void choose(Upgrade upgrade) {
    if (phase != RunPhase.choosing || !choices.contains(upgrade)) {
      return;
    }
    if (!canUpgrade(upgrade)) return;
    final prediction = preview(upgrade);
    upgrades[upgrade] = rank(upgrade) + 1;
    health = prediction.afterHealth;
    if (upgrade == Upgrade.garbageCollection) _gcTimer = min(_gcTimer, 0.6);
    seenUpgrades.add(upgrade);
    log(RunLog('log.upgrade', args: {'rank': rank(upgrade)}, upgrade: upgrade));
    cues.add(SoundCue.select);
    choices = [];
    phase = RunPhase.running;
    _checkLevel();
  }

  void update(double dt) {
    if (phase != RunPhase.running || dt <= 0) return;
    // Clamp long frames; hidden tabs must not fast-forward combat.
    dt = min(dt, 0.05);
    elapsed = min(duration, elapsed + dt);
    if (elapsed >= duration) {
      phase = RunPhase.won;
      movement.setZero();
      log(const RunLog('log.won'));
      cues.add(SoundCue.end);
      return;
    }
    if (movement.length2 > 0) {
      player.add(movement.normalized() * speed * dt);
    }
    invulnerability = max(0, invulnerability - dt);
    _updateAbilities(dt);
    if (elapsed >= _nextRush) {
      rushCount++;
      _rushUntil = elapsed + 9;
      _nextRush += 45;
      for (var i = 0; i < 18 + rushCount * 3; i++) {
        _spawn(kind: random.nextBool() ? 0 : 1);
      }
      log(const RunLog('log.rush'));
      cues.add(SoundCue.warning);
    }
    if (elapsed >= _nextDeadlock) {
      if (!deadlocks.any((e) => e.core.alive)) {
        _spawn(kind: 3, radius: min(spawnRadius * 0.55, 260));
        deadlockCount++;
        log(const RunLog('log.deadlock'));
        cues.add(SoundCue.warning);
      }
      _nextDeadlock += 90;
    }
    _spawnTimer -= dt;
    if (_spawnTimer <= 0 && enemies.length < 240) {
      _spawn();
      _spawnTimer = max(0.18, 0.70 - elapsed / 600) * (isRush ? 0.55 : 1);
    }
    _updateHazards(dt);
    if (phase == RunPhase.lost) return;
    _updateEnemyStatuses();
    for (final encounter in deadlocks) {
      enemies.addAll(encounter.advance(dt, player));
    }
    deadlocks.removeWhere((e) => !e.core.alive);
    for (final barrier in lockBarriers.where((b) => !b.warning)) {
      if (crossesCircle(barrier.from, barrier.to, player, 17)) {
        _damagePlayer(16);
      }
    }
    if (phase == RunPhase.lost) return;
    final children = <TaskEnemy>[];
    for (final enemy in enemies) {
      if (!enemy.alive) continue;
      enemy.flash = max(0, enemy.flash - dt);
      final delta = player - enemy.position;
      if (enemy.type == EnemyType.deadlock ||
          enemy.type == EnemyType.lockNode) {
        // Encounter positions and links are advanced together above.
      } else if (enemy.type == EnemyType.rpc ||
          enemy.type == EnemyType.forkBomb) {
        _updateSpecialist(enemy, delta, dt, children);
      } else if (enemy.type == EnemyType.batch && enemy.owner?.alive == true) {
        enemy.position.setFrom(enemy.owner!.position + enemy.formationOffset);
      } else if (delta.length2 > 0) {
        enemy.position.add(
          delta.normalized() * enemy.speed * enemy.movementMultiplier * dt,
        );
      }
      // Nodes become dangerous through their warned links, not on appearance.
      if (enemy.type != EnemyType.lockNode &&
          enemy.position.distanceTo(player) < enemy.radius + 13 &&
          invulnerability <= 0) {
        _damagePlayer(enemy.type == EnemyType.deadlock ? 22 : 9);
        if (phase == RunPhase.lost) return;
      }
    }

    enemies.addAll(children);
    _updateProjectiles(dt);
    if (phase == RunPhase.lost) return;
    _updateObjects(dt);
    _attackTimer -= dt;
    if (_attackTimer <= 0 && abilities.gcPause <= 0) {
      final targets =
          enemies
              .where(
                (e) => e.alive && e.position.distanceTo(player) <= attackRange,
              )
              .toList()
            ..sort(
              (a, b) => a.position
                  .distanceToSquared(player)
                  .compareTo(b.position.distanceToSquared(player)),
            );
      if (targets.isNotEmpty && rank(Upgrade.jitCompilation) > 0) {
        final wasOptimized = abilities.jitOptimized;
        abilities.recordExecution();
        _stats.jitOptimized = abilities.jitOptimized;
        if (!wasOptimized && abilities.jitOptimized) {
          effects.add(RunEffect(player.clone(), radius: 70, optimized: true));
          cues.add(SoundCue.select);
          log(const RunLog('log.optimized'));
        }
      }
      for (final target in targets.take(targetCount)) {
        if (instructions.length >= instructionLimit) break;
        instructions.add(
          Instruction(
            player.clone(),
            target,
            attackDamage,
            jumps: rank(Upgrade.functional),
          ),
        );
      }
      _attackTimer = targets.isEmpty ? 0 : attackInterval;
    }
    _patternTimer -= dt;
    if (rank(Upgrade.patternMatching) > 0 && _patternTimer <= 0) {
      final target = _nearestEnemy(player, attackRange);
      if (target != null && projectiles.where((s) => !s.hostile).length < 12) {
        final delta = target.position - player;
        final direction = delta.length2 > 0
            ? delta.normalized()
            : Vector2(1, 0);
        projectiles.add(
          LinearProjectile(
            player.clone(),
            direction * projectileSpeed,
            damage: _stats.patternDamage,
            hostile: false,
            radius: _stats.patternRadius,
            life: 1.2,
          ),
        );
        _patternTimer = _stats.patternInterval;
      }
    }
    final chained = <Instruction>[];
    for (final shot in instructions) {
      shot.life -= dt;
      if (!shot.target.alive) {
        shot.life = 0;
        continue;
      }
      final delta = shot.target.position - shot.position;
      final shotSpeed = shot.kind == InstructionKind.cached
          ? min(1600.0, projectileSpeed * 1.5)
          : projectileSpeed;
      if (delta.length <= shotSpeed * dt + shot.target.radius) {
        _damage(shot.target, shot.damage);
        if (shot.jumps > 0) {
          final candidates =
              enemies
                  .where(
                    (enemy) =>
                        enemy.alive &&
                        !shot.visited.contains(enemy) &&
                        enemy.position.distanceTo(shot.target.position) <=
                            chainRadius,
                  )
                  .toList()
                ..sort(
                  (a, b) => a.position
                      .distanceToSquared(shot.target.position)
                      .compareTo(
                        b.position.distanceToSquared(shot.target.position),
                      ),
                );
          if (candidates.isNotEmpty) {
            final next = candidates.first;
            chained.add(
              Instruction(
                shot.target.position.clone(),
                next,
                shot.damage * 0.7,
                kind: InstructionKind.chain,
                jumps: shot.jumps - 1,
                visited: {...shot.visited, next},
              ),
            );
          }
        }
        shot.life = 0;
      } else {
        shot.position.add(delta.normalized() * shotSpeed * dt);
      }
    }
    instructions.removeWhere((shot) => shot.life <= 0);
    instructions.addAll(
      chained.take(max(0, instructionLimit - instructions.length)),
    );
    if (rank(Upgrade.garbageCollection) > 0) {
      _gcTimer -= dt;
      if (_gcTimer <= 0) {
        effects.add(RunEffect(player.clone(), pulse: true, radius: gcRadius));
        cues.add(SoundCue.pulse);
        for (final enemy in enemies.where(
          (e) => e.alive && e.position.distanceTo(player) <= gcRadius,
        )) {
          _damage(enemy, gcDamage);
        }
        _gcTimer = _stats.gcInterval;
        abilities.gcPause = _stats.gcPause;
      }
    }
    enemies.removeWhere((enemy) => !enemy.alive);
    // Keep the endless arena bounded in memory when the player outruns tasks.
    enemies.removeWhere((enemy) {
      if (enemy.type == EnemyType.deadlock ||
          enemy.type == EnemyType.lockNode) {
        return false;
      }
      final distant = enemy.position.distanceTo(player) > spawnRadius * 2.2;
      if (distant) enemy.health = 0;
      return distant;
    });
    var earned = 0;
    experience.removeWhere((gem) {
      final distance = gem.position.distanceTo(player);
      if (distance < 20) {
        earned += gem.value;
        return true;
      }
      if (distance < pickupRadius) {
        final delta = player - gem.position;
        gem.position.add(delta.normalized() * min(distance, 350 * dt));
      }
      return distance > spawnRadius * 3;
    });
    if (earned > 0) {
      cues.add(SoundCue.pickup);
      addExperience(earned);
    }
    for (final effect in effects) {
      effect.life -= dt;
    }
    effects.removeWhere((effect) => effect.life <= 0);
  }

  void _updateAbilities(double dt) {
    abilities.advance(dt);
    if (rank(Upgrade.lazyEvaluation) > 0 &&
        abilities.fieldTimer <= 0 &&
        abilities.fields.length < 3) {
      abilities.fields.add(
        SlowField(
          player.clone(),
          _stats.slowRadius,
          _stats.slowMultiplier,
          damage: _stats.lazyDamage,
        ),
      );
      abilities.fieldTimer = _stats.lazyInterval;
    }
    for (final field in abilities.fields) {
      if (!field.triggered &&
          field.arming <= 0 &&
          enemies.any(
            (e) =>
                e.alive &&
                e.position.distanceTo(field.position) <= field.radius * 0.65,
          )) {
        field.triggered = true;
        field.remaining = 1.5;
        effects.add(
          RunEffect(field.position.clone(), pulse: true, radius: field.radius),
        );
        cues.add(SoundCue.pulse);
        for (final enemy in enemies.where(
          (e) =>
              e.alive && e.position.distanceTo(field.position) <= field.radius,
        )) {
          _damage(enemy, field.damage);
        }
      }
    }
    if (rank(Upgrade.ownership) > 0 && abilities.ownershipTimer <= 0) {
      _pulse(_stats.ownershipRadius, _stats.ownershipDamage, healing: true);
      abilities.ownershipTimer = _stats.ownershipInterval;
    }
    if (rank(Upgrade.memoization) > 0 && abilities.memoTimer <= 0) {
      final candidates =
          enemies
              .where(
                (e) => e.alive && e.position.distanceTo(player) <= attackRange,
              )
              .toList()
            ..sort((a, b) {
              final cacheOrder =
                  (abilities.cachedInputs.contains(b.inputSignature) ? 1 : 0)
                      .compareTo(
                        abilities.cachedInputs.contains(a.inputSignature)
                            ? 1
                            : 0,
                      );
              return cacheOrder != 0
                  ? cacheOrder
                  : a.position
                        .distanceToSquared(player)
                        .compareTo(b.position.distanceToSquared(player));
            });
      if (candidates.isNotEmpty && instructions.length < instructionLimit) {
        final target = candidates.first;
        final cached = abilities.cachedInputs.contains(target.inputSignature);
        instructions.add(
          Instruction(
            player.clone(),
            target,
            _stats.memoDamage * (cached ? 1.8 : 1),
            kind: cached ? InstructionKind.cached : InstructionKind.object,
          ),
        );
        abilities.memoTimer = _stats.memoInterval;
      }
    }
  }

  void _pulse(double radius, double damage, {bool healing = false}) {
    effects.add(
      RunEffect(player.clone(), pulse: true, radius: radius, healing: healing),
    );
    for (final enemy in enemies.where(
      (e) => e.alive && e.position.distanceTo(player) <= radius,
    )) {
      _damage(enemy, damage);
    }
  }

  void _updateHazards(double dt) {
    for (final hazard in hazards) {
      hazard.remaining -= dt;
      if (hazard.remaining <= 0) {
        effects.add(RunEffect(hazard.position.clone(), radius: hazard.radius));
        if (player.distanceTo(hazard.position) <= hazard.radius + 13) {
          _damagePlayer(hazard.damage);
        }
      }
    }
    hazards.removeWhere(
      (h) =>
          h.remaining <= 0 || h.position.distanceTo(player) > spawnRadius * 2.2,
    );
  }

  void _updateEnemyStatuses() {
    for (final enemy in enemies) {
      var slow = 1.0;
      for (final field in abilities.fields.where((f) => f.triggered)) {
        if (field.position.distanceToSquared(enemy.position) <=
            field.radius * field.radius) {
          slow = min(slow, field.multiplier);
        }
      }
      // Deadlock movement retains a floor; slow effects never stack.
      if (enemy.type == EnemyType.deadlock) slow = max(0.8, slow);
      enemy.movementMultiplier = slow;
    }
  }

  void _updateObjects(double dt) {
    while (objects.length < rank(Upgrade.oop)) {
      objects.add(RuntimeObject(objects.length, player));
    }
    for (final object in objects) {
      final angle = elapsed * 1.2 + object.index * pi * 2 / objects.length;
      object.position.setFrom(
        player + Vector2(cos(angle), sin(angle)) * (72 + object.index * 8),
      );
      object.attackTimer -= dt;
      if (object.attackTimer <= 0) {
        final targets =
            enemies
                .where(
                  (enemy) =>
                      enemy.alive &&
                      enemy.position.distanceTo(object.position) <=
                          _stats.objectRange,
                )
                .toList()
              ..sort(
                (a, b) => a.position
                    .distanceToSquared(object.position)
                    .compareTo(b.position.distanceToSquared(object.position)),
              );
        if (targets.isNotEmpty && instructions.length < instructionLimit) {
          instructions.add(
            Instruction(
              object.position.clone(),
              targets.first,
              objectDamage,
              kind: InstructionKind.object,
            ),
          );
          object.attackTimer = objectInterval;
        }
      }
    }
  }

  TaskEnemy? _nearestEnemy(Vector2 origin, double range) {
    TaskEnemy? result;
    var distance = range * range;
    for (final enemy in enemies) {
      final d = enemy.position.distanceToSquared(origin);
      if (enemy.alive && d <= distance) {
        result = enemy;
        distance = d;
      }
    }
    return result;
  }

  void _damagePlayer(double damage) {
    if (invulnerability > 0) return;
    health = max(0, health - damage);
    invulnerability = _stats.hitInvulnerability;
    cues.add(SoundCue.hit);
    if (health <= 0) {
      phase = RunPhase.lost;
      movement.setZero();
      log(const RunLog('log.lost'));
      cues.add(SoundCue.end);
    }
  }

  void _updateProjectiles(double dt) {
    for (final shot in projectiles) {
      final from = shot.position.clone();
      shot.life -= dt;
      shot.position.add(shot.velocity * dt);
      if (shot.hostile) {
        if (crossesCircle(from, shot.position, player, shot.radius + 13)) {
          _damagePlayer(shot.damage);
          shot.life = 0;
        }
      } else {
        for (final enemy in enemies) {
          if (enemy.alive &&
              !shot.hit.contains(enemy) &&
              crossesCircle(
                from,
                shot.position,
                enemy.position,
                enemy.radius + shot.radius,
              )) {
            shot.hit.add(enemy);
            _damage(enemy, shot.damage);
          }
        }
      }
    }
    projectiles.removeWhere(
      (shot) =>
          shot.life <= 0 ||
          shot.position.distanceTo(player) > spawnRadius * 2.2,
    );
  }

  void _updateSpecialist(
    TaskEnemy enemy,
    Vector2 delta,
    double dt,
    List<TaskEnemy> children,
  ) {
    final ranged = enemy.type == EnemyType.rpc;
    final root = enemy.owner ?? enemy;
    final canFork = !ranged && root.alive && enemy.generation < 2;
    if (enemy.telegraphRemaining > 0) {
      enemy.telegraphRemaining = max(0, enemy.telegraphRemaining - dt);
      if (enemy.telegraphRemaining == 0) {
        if (ranged) {
          final count = 1 + enemy.retryCount;
          for (var i = 0; i < count; i++) {
            if (projectiles.where((s) => s.hostile).length >= 96) break;
            final angle =
                atan2(enemy.chargeDirection.y, enemy.chargeDirection.x) +
                (i - (count - 1) / 2) * 0.22;
            projectiles.add(
              LinearProjectile(
                enemy.position.clone(),
                Vector2(cos(angle), sin(angle)) * 180,
                damage: 11,
              ),
            );
          }
          enemy.retryCount = min(2, enemy.retryCount + 1);
          enemy.attackCooldown = 2.8 + enemy.retryCount * 0.6;
        } else if (canFork) {
          final owned =
              enemies
                  .where(
                    (e) => e.alive && e.summoned && identical(e.owner, root),
                  )
                  .length +
              children.where((e) => identical(e.owner, root)).length;
          final count = min(
            enemy.summoned ? 1 : 2,
            min(6 - owned, 232 - enemies.length - children.length),
          );
          for (var i = 0; i < count; i++) {
            final angle = elapsed + i * pi;
            children.add(
              TaskEnemy(
                enemy.position + Vector2(cos(angle), sin(angle)) * 28,
                kind: EnemyType.forkBomb.index,
                health: 12 + elapsed / 35,
                summoned: true,
                owner: root,
                generation: enemy.generation + 1,
              ),
            );
          }
          enemy.attackCooldown = 5;
        }
      }
      return;
    }
    if (delta.length >
        (ranged
            ? 240
            : enemy.summoned
            ? 0
            : 260)) {
      enemy.position.add(
        delta.normalized() * enemy.speed * enemy.movementMultiplier * dt,
      );
    } else if (ranged && delta.length > 1 && delta.length < 150) {
      enemy.position.add(delta.normalized() * -enemy.speed * dt);
    }
    enemy.attackCooldown -= dt;
    if (enemy.attackCooldown <= 0 &&
        delta.length > 1 &&
        delta.length < 430 &&
        (ranged || canFork)) {
      enemy.chargeDirection.setFrom(delta.normalized());
      enemy.telegraphRemaining = ranged ? 0.65 : 1.1;
    }
  }

  void _spawn({double? radius, int? kind}) {
    final angle = random.nextDouble() * pi * 2;
    kind ??= director.choose(elapsed, enemies, random, introduced: _introduced);
    final type = EnemyType.values[kind];
    if (type == EnemyType.deadlock && deadlocks.any((e) => e.core.alive)) {
      return;
    }
    final count = type == EnemyType.batch
        ? 4
        : type == EnemyType.deadlock
        ? 4
        : 1;
    if (enemies.length + count > (type == EnemyType.deadlock ? 240 : 232)) {
      return;
    }
    final position =
        player + Vector2(cos(angle), sin(angle)) * (radius ?? spawnRadius);
    final leader = TaskEnemy(
      position,
      kind: kind,
      inputVariant: random.nextInt(3),
      health: type == EnemyType.deadlock
          ? 820 + elapsed * 2
          : (22 + elapsed / 18) *
                (type == EnemyType.forkBomb
                    ? 2.5
                    : type == EnemyType.rpc
                    ? 1.6
                    : type == EnemyType.batch
                    ? 1.15
                    : 1),
    );
    enemies.add(leader);
    if (type == EnemyType.deadlock) {
      final encounter = DeadlockEncounter(leader);
      deadlocks.add(encounter);
      enemies.addAll(encounter.rebuild());
    } else if (type == EnemyType.batch) {
      final direction = (position - player).normalized();
      for (var i = 1; i < 4; i++) {
        final offset = direction * (32.0 * i);
        enemies.add(
          TaskEnemy(
            position + offset,
            kind: kind,
            owner: leader,
            inputVariant: (leader.inputVariant + i) % 3,
            health: leader.maxHealth,
          )..formationOffset.setFrom(offset),
        );
      }
    }
    seenEnemies.add(kind);
    _introduced.add(kind);
  }

  void _damage(TaskEnemy enemy, double damage) {
    if (!enemy.alive) return;
    final encounter = deadlocks
        .where((e) => identical(e.core, enemy))
        .firstOrNull;
    enemy.health -= damage * (encounter?.damageMultiplier ?? 1);
    enemy.flash = 0.12;
    if (!enemy.alive) {
      kills++;
      if (rank(Upgrade.memoization) > 0 && enemy.cacheable) {
        abilities.cachedInputs.add(enemy.inputSignature);
      }
      if (rank(Upgrade.ownership) > 0 &&
          !enemy.summoned &&
          enemy.type != EnemyType.lockNode &&
          health < maxHealth &&
          player.distanceToSquared(enemy.position) <=
              _stats.ownershipRadius * _stats.ownershipRadius) {
        final healed = abilities.claimHealing(
          min(_stats.ownershipHeal, maxHealth - health),
          _stats.ownershipCap,
        );
        health += healed;
        if (healed > 0) {
          effects.add(RunEffect(player.clone(), healing: true, radius: 28));
        }
      }
      if (enemy.type == EnemyType.lockNode) {
        final owner = deadlocks
            .where((e) => identical(e.core, enemy.owner))
            .firstOrNull;
        owner?.breakDependency();
      }
      if (encounter != null) {
        for (final node in encounter.nodes) {
          node.health = 0;
        }
      }
      cues.add(SoundCue.kill);
      experience.add(
        Experience(
          enemy.position.clone(),
          enemy.type == EnemyType.lockNode
              ? 3
              : enemy.summoned
              ? 1
              : enemy.kind == 3
              ? 45
              : 4,
        ),
      );
      effects.add(RunEffect(enemy.position.clone()));
    }
  }
}
