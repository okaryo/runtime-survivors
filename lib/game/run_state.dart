import 'dart:math';
import 'dart:math' as math show log;

import 'package:flame/components.dart';

import '../audio/sound_cue.dart';
import 'combat_entities.dart';
import 'spawn_director.dart';
import 'build.dart';
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
  final director = const SpawnDirector();
  final Set<int> seenEnemies = {};
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
  double shieldTimer = 0;
  double dynamicTimer = 0;
  double dynamicCooldown = 0;
  int? _lastTargetKind;
  TypingPolicy? get typingPolicy => _stats.policy;
  bool get dynamicBoostActive => _stats.dynamicBoost;
  double get telegraphBonus =>
      typingPolicy == TypingPolicy.staticTyping ? 0.45 : 0;
  bool get shieldReady => rank(Upgrade.nullSafety) > 0 && shieldTimer <= 0;
  static const featureSlots = 4;
  int get featureCount =>
      upgrades.keys.where((u) => u.isFeature && rank(u) > 0).length;
  double get projectileSpeed => _stats.projectileSpeed;
  double invulnerability = 0;
  double _nextRush = 45;
  double _rushUntil = 0;
  double _nextElite = 75;
  int rushCount = 0;
  int eliteCount = 0;

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

  void resetToSetup() => _initialize(null, RunPhase.ready);

  void start({TypingPolicy? policy}) => _initialize(policy, RunPhase.running);

  void _initialize(TypingPolicy? policy, RunPhase initialPhase) {
    _stats.policy = policy;
    _stats.dynamicBoost = false;
    dynamicTimer = 0;
    dynamicCooldown = 0;
    _lastTargetKind = null;
    phase = initialPhase;
    player.setZero();
    movement.setZero();
    enemies.clear();
    instructions.clear();
    experience.clear();
    effects.clear();
    objects.clear();
    projectiles.clear();
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
    shieldTimer = 0;
    invulnerability = 0;
    _nextRush = 45;
    _rushUntil = 0;
    _nextElite = 75;
    rushCount = 0;
    eliteCount = 0;
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

  void _checkLevel() {
    if (phase != RunPhase.running || xp < nextLevelXp) return;
    xp -= nextLevelXp;
    level++;
    phase = RunPhase.choosing;
    movement.setZero();
    final available = Upgrade.values
        .where(
          (u) =>
              (u.maxRank == null || rank(u) < u.maxRank!) &&
              (!u.isFeature || rank(u) > 0 || featureCount < featureSlots),
        )
        .toList();
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
        available.firstWhere((u) => !firstTwo.contains(u)),
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
      policy: typingPolicy,
      dynamicBoost: dynamicBoostActive,
    );
    final after = BuildStats.snapshot(
      {...upgrades, upgrade: rank(upgrade) + 1},
      policy: typingPolicy,
      dynamicBoost: dynamicBoostActive,
    );
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
    if (phase != RunPhase.choosing || !choices.contains(upgrade)) return;
    if ((upgrade.maxRank != null && rank(upgrade) >= upgrade.maxRank!) ||
        (upgrade.isFeature &&
            rank(upgrade) == 0 &&
            featureCount >= featureSlots)) {
      return;
    }
    final prediction = preview(upgrade);
    upgrades[upgrade] = rank(upgrade) + 1;
    health = prediction.afterHealth;
    if (upgrade == Upgrade.nullSafety) {
      shieldTimer = min(shieldTimer, _stats.shieldCooldown);
    }
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
    shieldTimer = max(0, shieldTimer - dt);
    dynamicTimer = max(0, dynamicTimer - dt);
    dynamicCooldown = max(0, dynamicCooldown - dt);
    _stats.dynamicBoost = dynamicTimer > 0;
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
    if (elapsed >= _nextElite) {
      _spawn(kind: 3, radius: min(spawnRadius, 420));
      _nextElite += 90;
      eliteCount++;
      log(const RunLog('log.elite'));
      cues.add(SoundCue.warning);
    }
    _spawnTimer -= dt;
    if (_spawnTimer <= 0 && enemies.length < 240) {
      _spawn();
      _spawnTimer = max(0.18, 0.70 - elapsed / 600) * (isRush ? 0.55 : 1);
    }
    final children = <TaskEnemy>[];
    for (final enemy in enemies) {
      if (!enemy.alive) continue;
      enemy.flash = max(0, enemy.flash - dt);
      final delta = player - enemy.position;
      if (enemy.kind == 3) {
        _updateElite(enemy, delta, dt);
      } else if (enemy.kind == 4 || enemy.kind == 5) {
        _updateSpecialist(enemy, delta, dt, children);
      } else if (delta.length2 > 0) {
        enemy.position.add(delta.normalized() * enemy.speed * dt);
      }
      if (enemy.position.distanceTo(player) < enemy.radius + 13 &&
          invulnerability <= 0) {
        _damagePlayer(
          enemy.kind == 3
              ? 22
              : enemy.kind == 2
              ? 15
              : 9,
        );
        if (phase == RunPhase.lost) return;
      }
    }
    enemies.addAll(children);
    _updateProjectiles(dt);
    if (phase == RunPhase.lost) return;
    _updateObjects(dt);
    _attackTimer -= dt;
    if (_attackTimer <= 0) {
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
      if (targets.isNotEmpty) _observeTarget(targets.first.kind);
      for (final target in targets.take(targetCount)) {
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
      if (delta.length <= projectileSpeed * dt + shot.target.radius) {
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
        shot.position.add(delta.normalized() * projectileSpeed * dt);
      }
    }
    instructions.removeWhere((shot) => shot.life <= 0);
    instructions.addAll(chained);
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
        _gcTimer = 3;
      }
    }
    enemies.removeWhere((enemy) => !enemy.alive);
    // Keep the endless arena bounded in memory when the player outruns tasks.
    enemies.removeWhere(
      (enemy) =>
          enemy.kind != 3 &&
          enemy.position.distanceTo(player) > spawnRadius * 2.2,
    );
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
                      enemy.position.distanceTo(object.position) <= 235,
                )
                .toList()
              ..sort(
                (a, b) => a.position
                    .distanceToSquared(object.position)
                    .compareTo(b.position.distanceToSquared(object.position)),
              );
        if (targets.isNotEmpty) {
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

  void _observeTarget(int kind) {
    if (typingPolicy == TypingPolicy.dynamicTyping &&
        _lastTargetKind != null &&
        _lastTargetKind != kind &&
        dynamicCooldown <= 0) {
      dynamicTimer = 3;
      dynamicCooldown = 6;
      _stats.dynamicBoost = true;
      effects.add(RunEffect(player.clone(), radius: 40));
    }
    _lastTargetKind = kind;
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
    invulnerability = 0.65;
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
          if (invulnerability <= 0 && shieldReady) {
            shieldTimer = _stats.shieldCooldown;
            effects.add(RunEffect(player.clone(), pulse: true, radius: 35));
            cues.add(SoundCue.pulse);
          } else {
            _damagePlayer(shot.damage);
          }
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
    final ranged = enemy.kind == 4;
    if (enemy.telegraphRemaining > 0) {
      enemy.telegraphRemaining = max(0, enemy.telegraphRemaining - dt);
      if (enemy.telegraphRemaining == 0) {
        if (ranged && projectiles.where((s) => s.hostile).length < 96) {
          projectiles.add(
            LinearProjectile(
              enemy.position.clone(),
              enemy.chargeDirection * 180,
              damage: 11,
            ),
          );
        } else if (!ranged) {
          final owned = enemies
              .where((e) => e.alive && identical(e.owner, enemy))
              .length;
          final count = min(
            3,
            min(6 - owned, 236 - enemies.length - children.length),
          );
          for (var i = 0; i < count; i++) {
            final angle = i * pi * 2 / 3 + elapsed;
            children.add(
              TaskEnemy(
                enemy.position + Vector2(cos(angle), sin(angle)) * 32,
                health: 12 + elapsed / 30,
                summoned: true,
                owner: enemy,
              ),
            );
          }
        }
        enemy.attackCooldown = ranged ? 2.6 : 5.5;
      }
      return;
    }
    // Specialists can be approached: retreat is slower than player movement.
    if (delta.length > (ranged ? 240 : 280)) {
      enemy.position.add(delta.normalized() * enemy.speed * dt);
    } else if (ranged && delta.length > 1 && delta.length < 150) {
      enemy.position.add(delta.normalized() * -enemy.speed * dt);
    }
    enemy.attackCooldown -= dt;
    if (enemy.attackCooldown <= 0 && delta.length > 1 && delta.length < 430) {
      enemy.chargeDirection.setFrom(delta.normalized());
      enemy.telegraphRemaining = (ranged ? 0.9 : 1.2) + telegraphBonus;
    }
  }

  void _updateElite(TaskEnemy enemy, Vector2 delta, double dt) {
    if (enemy.telegraphRemaining > 0) {
      enemy.telegraphRemaining = max(0, enemy.telegraphRemaining - dt);
      if (enemy.telegraphRemaining == 0) enemy.chargeRemaining = 0.7;
    } else if (enemy.chargeRemaining > 0) {
      enemy.position.add(enemy.chargeDirection * 460 * dt);
      enemy.chargeRemaining = max(0, enemy.chargeRemaining - dt);
      if (enemy.chargeRemaining == 0) enemy.chargeCooldown = 2.8;
    } else {
      if (delta.length2 > 0) {
        enemy.position.add(delta.normalized() * enemy.speed * dt);
      }
      enemy.chargeCooldown -= dt;
      if (enemy.chargeCooldown <= 0 && delta.length > 1 && delta.length < 450) {
        enemy.chargeDirection.setFrom(delta.normalized());
        enemy.telegraphRemaining = 0.9 + telegraphBonus;
      }
    }
  }

  void _spawn({double? radius, int? kind}) {
    if (enemies.length >= (kind == 3 ? 240 : 236)) return;
    final angle = random.nextDouble() * pi * 2;
    kind ??= director.choose(elapsed, enemies, random);
    enemies.add(
      TaskEnemy(
        player + Vector2(cos(angle), sin(angle)) * (radius ?? spawnRadius),
        kind: kind,
        health: kind == 3
            ? 240 + elapsed * 1.6
            : (22 + elapsed / 18) *
                  (kind == 2
                      ? 3
                      : kind == 5
                      ? 2.5
                      : kind == 4
                      ? 1.5
                      : 1),
      ),
    );
    seenEnemies.add(kind);
  }

  void _damage(TaskEnemy enemy, double damage) {
    if (!enemy.alive) return;
    enemy.health -= damage;
    enemy.flash = 0.12;
    if (!enemy.alive) {
      kills++;
      cues.add(SoundCue.kill);
      experience.add(
        Experience(
          enemy.position.clone(),
          enemy.summoned
              ? 1
              : enemy.kind == 3
              ? 45
              : enemy.kind == 2
              ? 9
              : 4,
        ),
      );
      effects.add(RunEffect(enemy.position.clone()));
    }
  }
}
