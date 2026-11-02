import 'dart:math';

import 'package:flame/components.dart';

import '../audio/sound_cue.dart';

enum RunPhase { ready, running, choosing, paused, won, lost }

enum Upgrade {
  garbageCollection,
  concurrency,
  oop,
  functional,
  memory,
  clock,
  cache,
  compiler,
}

extension UpgradeInfo on Upgrade {
  String get symbol => switch (this) {
    Upgrade.garbageCollection => 'GC',
    Upgrade.concurrency => '&&',
    Upgrade.oop => '{}',
    Upgrade.functional => 'λ',
    Upgrade.memory => 'MEM',
    Upgrade.clock => 'Hz',
    Upgrade.cache => r'$',
    Upgrade.compiler => '-O',
  };

  bool get isFeature => switch (this) {
    Upgrade.garbageCollection ||
    Upgrade.concurrency ||
    Upgrade.oop ||
    Upgrade.functional => true,
    _ => false,
  };
}

class RunLog {
  const RunLog(this.key, {this.args = const {}, this.upgrade});
  final String key;
  final Map<String, Object> args;
  final Upgrade? upgrade;
}

class TaskEnemy {
  TaskEnemy(this.position, {this.kind = 0, this.health = 22})
    : maxHealth = health;
  final Vector2 position;
  final int kind;
  double health;
  final double maxHealth;
  double flash = 0;
  double chargeCooldown = 2.2;
  double telegraphRemaining = 0;
  double chargeRemaining = 0;
  final chargeDirection = Vector2.zero();
  bool get alive => health > 0;
  double get radius => kind == 3
      ? 25
      : kind == 2
      ? 18
      : 13;
  double get speed => switch (kind) {
    1 => 103,
    2 => 40,
    3 => 62,
    _ => 57,
  };
}

enum InstructionKind { base, object, chain }

class Instruction {
  Instruction(
    this.position,
    this.target,
    this.damage, {
    this.kind = InstructionKind.base,
    this.jumps = 0,
    Set<TaskEnemy>? visited,
  }) : visited = visited ?? {target};
  final Vector2 position;
  final TaskEnemy target;
  final double damage;
  final InstructionKind kind;
  final int jumps;
  final Set<TaskEnemy> visited;
  double life = 1.5;
}

class RuntimeObject {
  RuntimeObject(this.index, Vector2 player) : position = player.clone();
  final int index;
  final Vector2 position;
  double attackTimer = 0;
}

class Experience {
  Experience(this.position, this.value);
  final Vector2 position;
  final int value;
}

class RunEffect {
  RunEffect(this.position, {this.pulse = false, this.radius = 22});
  final Vector2 position;
  final bool pulse;
  final double radius;
  double life = 0.5;
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
  final Set<int> seenEnemies = {};
  final Set<Upgrade> seenUpgrades = {};
  final Map<Upgrade, int> upgrades = {};
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
  double get maxHealth =>
      100 + 25.0 * rank(Upgrade.memory) - 5.0 * rank(Upgrade.oop);
  double get speed => 185.0 * pow(1.12, rank(Upgrade.clock));
  double get pickupRadius => 66 + 35.0 * rank(Upgrade.cache);
  double get attackRange =>
      300 + 20.0 * rank(Upgrade.cache) - 15.0 * rank(Upgrade.functional);
  double get objectDamage => 16 + rank(Upgrade.oop) * 4.0;
  double get objectInterval => 0.9;
  double get chainRadius => 155;
  double get attackDamage =>
      24.0 *
      pow(1.25, rank(Upgrade.compiler)) *
      pow(0.88, rank(Upgrade.concurrency));
  double get attackInterval => 0.62 + rank(Upgrade.garbageCollection) * 0.08;
  int get targetCount => 1 + rank(Upgrade.concurrency);
  double get gcRadius => 115 + rank(Upgrade.garbageCollection) * 18.0;
  String get timeLabel {
    final seconds = elapsed.floor();
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void start() {
    phase = RunPhase.running;
    player.setZero();
    movement.setZero();
    enemies.clear();
    instructions.clear();
    experience.clear();
    effects.clear();
    objects.clear();
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
    invulnerability = 0;
    _nextRush = 45;
    _rushUntil = 0;
    _nextElite = 75;
    rushCount = 0;
    eliteCount = 0;
    events.clear();
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
    final available =
        Upgrade.values.where((u) => !u.isFeature || rank(u) < 4).toList()
          ..shuffle(random);
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

  void choose(Upgrade upgrade) {
    if (phase != RunPhase.choosing || !choices.contains(upgrade)) return;
    upgrades[upgrade] = rank(upgrade) + 1;
    if (upgrade == Upgrade.memory) health = min(maxHealth, health + 35);
    if (upgrade == Upgrade.garbageCollection) _gcTimer = min(_gcTimer, 0.6);
    health = min(health, maxHealth);
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
    if (elapsed >= _nextRush) {
      rushCount++;
      _rushUntil = elapsed + 9;
      _nextRush += 45;
      for (var i = 0; i < 18 + rushCount * 3; i++) {
        _spawn();
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
    for (final enemy in enemies) {
      enemy.flash = max(0, enemy.flash - dt);
      final delta = player - enemy.position;
      if (enemy.kind == 3) {
        _updateElite(enemy, delta, dt);
      } else if (delta.length2 > 0) {
        enemy.position.add(delta.normalized() * enemy.speed * dt);
      }
      if (enemy.position.distanceTo(player) < enemy.radius + 13 &&
          invulnerability <= 0) {
        health = max(
          0,
          health -
              (enemy.kind == 3
                  ? 22
                  : enemy.kind == 2
                  ? 15
                  : 9),
        );
        invulnerability = 0.65;
        cues.add(SoundCue.hit);
        if (health <= 0) {
          phase = RunPhase.lost;
          movement.setZero();
          log(const RunLog('log.lost'));
          cues.add(SoundCue.end);
          return;
        }
      }
    }
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
    final chained = <Instruction>[];
    for (final shot in instructions) {
      shot.life -= dt;
      if (!shot.target.alive) {
        shot.life = 0;
        continue;
      }
      final delta = shot.target.position - shot.position;
      if (delta.length <= 640 * dt + shot.target.radius) {
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
        shot.position.add(delta.normalized() * 640 * dt);
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
          _damage(enemy, 22 + rank(Upgrade.garbageCollection) * 14.0);
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
        enemy.telegraphRemaining = 0.9;
      }
    }
  }

  void _spawn({double? radius, int? kind}) {
    if (enemies.length >= (kind == 3 ? 240 : 236)) return;
    final angle = random.nextDouble() * pi * 2;
    kind ??= elapsed > 45 && random.nextDouble() < 0.2
        ? 2
        : (elapsed > 20 && random.nextDouble() < 0.3 ? 1 : 0);
    enemies.add(
      TaskEnemy(
        player + Vector2(cos(angle), sin(angle)) * (radius ?? spawnRadius),
        kind: kind,
        health: kind == 3
            ? 240 + elapsed * 1.6
            : (22 + elapsed / 18) * (kind == 2 ? 3 : 1),
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
          enemy.kind == 3
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
