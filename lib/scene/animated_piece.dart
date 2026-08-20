import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../game/game_controller.dart';
import 'piece_builder.dart';

enum PieceAnimState {
  spawning, // Dropping from above with bounce
  idle, // Floating hover & breathing
  celebrating, // Leaping and spinning on win
  movingToEat, // Traveling to loser position with wide open mouth
  chomping, // Snapping mouth shut, chewing, wobbling
  returningHome, // Flying back to original cell
  beingEaten, // Loser shaking in fear, shrinking into winner mouth
  eaten, // Completely disappeared
}

class AnimatedPiece {
  final int cellIndex;
  final CellState pieceType;
  final Node rootNode;
  final vm.Vector3 basePosition;

  PieceAnimState state = PieceAnimState.spawning;
  double stateTime = 0.0;
  double idleSeed = 0.0;

  // Spawning physics
  double spawnVelocity = 0.0;
  double currentY = 4.0;
  int bounceCount = 0;

  // Eating choreography parameters
  vm.Vector3 moveStartPos = vm.Vector3.zero();
  vm.Vector3 moveTargetPos = vm.Vector3.zero();
  double moveDuration = 0.6;
  VoidCallback? onActionDone;

  // Visual squash/stretch
  double scaleY = 1.0;
  double scaleXZ = 1.0;

  // Sub-nodes for animation
  Node? upperJawNode;
  Node? eyeLeftNode;
  Node? eyeRightNode;

  AnimatedPiece({
    required this.cellIndex,
    required this.pieceType,
    required this.rootNode,
  }) : basePosition = PieceBuilder.cellToWorldPosition(cellIndex) {
    idleSeed = cellIndex * 1.37 + (pieceType == CellState.x ? 0.0 : 2.5);
    upperJawNode = rootNode.getChildByName("UpperJaw");
    eyeLeftNode = rootNode.getChildByName("EyeLeft");
    eyeRightNode = rootNode.getChildByName("EyeRight");

    rootNode.position = vm.Vector3(basePosition.x, currentY, basePosition.z);
    rootNode.scale = vm.Vector3.all(1.0);
  }

  void update(double dt) {
    stateTime += dt;

    switch (state) {
      case PieceAnimState.spawning:
        _updateSpawning(dt);
        break;
      case PieceAnimState.idle:
        _updateIdle(dt);
        break;
      case PieceAnimState.celebrating:
        _updateCelebrating(dt);
        break;
      case PieceAnimState.movingToEat:
        _updateMovingToEat(dt);
        break;
      case PieceAnimState.chomping:
        _updateChomping(dt);
        break;
      case PieceAnimState.returningHome:
        _updateReturningHome(dt);
        break;
      case PieceAnimState.beingEaten:
        _updateBeingEaten(dt);
        break;
      case PieceAnimState.eaten:
        rootNode.visible = false;
        break;
    }
  }

  void _updateSpawning(double dt) {
    // Gravity acceleration
    const gravity = -32.0;
    spawnVelocity += gravity * dt;
    currentY += spawnVelocity * dt;

    if (currentY <= basePosition.y) {
      currentY = basePosition.y;
      if (bounceCount < 1) {
        // Single crisp elastic bounce
        spawnVelocity = -spawnVelocity * 0.4;
        bounceCount++;
        // Squish on impact
        scaleY = 0.7;
        scaleXZ = 1.3;
      } else {
        // Settle into idle
        currentY = basePosition.y;
        state = PieceAnimState.idle;
        stateTime = 0.0;
        scaleY = 1.0;
        scaleXZ = 1.0;
        onActionDone?.call();
        onActionDone = null;
      }
    }

    // Safety timeout: after 0.3s force finish spawn so turns are always snappy
    if (stateTime >= 0.3 && onActionDone != null) {
      currentY = basePosition.y;
      state = PieceAnimState.idle;
      scaleY = 1.0;
      scaleXZ = 1.0;
      onActionDone?.call();
      onActionDone = null;
    }

    // Recover squash & stretch
    scaleY += (1.0 - scaleY) * math.min(1.0, dt * 18.0);
    scaleXZ += (1.0 - scaleXZ) * math.min(1.0, dt * 18.0);

    rootNode.position = vm.Vector3(basePosition.x, currentY, basePosition.z);
    rootNode.scale = vm.Vector3(scaleXZ, scaleY, scaleXZ);
  }

  void _updateIdle(double dt) {
    final t = stateTime + idleSeed;

    // Smooth floating hover
    final hoverY = basePosition.y + math.sin(t * 3.5) * 0.05;
    rootNode.position = vm.Vector3(basePosition.x, hoverY, basePosition.z);

    // Subtle gentle breathing pulse
    final breathe = 1.0 + math.sin(t * 4.0) * 0.04;
    rootNode.scale = vm.Vector3(breathe, 1.0 / breathe, breathe);

    // Gentle look around with eyes
    if (eyeLeftNode != null && eyeRightNode != null) {
      final eyeYaw = math.sin(t * 1.5) * 0.2;
      final eyePitch = math.cos(t * 2.0) * 0.15;
      final eyeRot = vm.Quaternion.euler(eyeYaw, eyePitch, 0);
      eyeLeftNode!.rotation = eyeRot;
      eyeRightNode!.rotation = eyeRot;
    }
  }

  void _updateCelebrating(double dt) {
    final t = stateTime;

    // Jumping joyfully
    final jumpY = basePosition.y + math.max(0.0, math.sin(t * 6.0)) * 0.4;
    rootNode.position = vm.Vector3(basePosition.x, jumpY, basePosition.z);

    // Spinning around Y axis
    final spinAngle = t * 4.0;
    rootNode.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), spinAngle);

    // Energetic stretch
    final stretch = 1.1 + math.sin(t * 12.0) * 0.15;
    rootNode.scale = vm.Vector3(stretch, stretch, stretch);
  }

  void startEatingTrip(vm.Vector3 targetPos, VoidCallback onArrive) {
    state = PieceAnimState.movingToEat;
    stateTime = 0.0;
    moveStartPos = vm.Vector3.copy(rootNode.position);
    moveTargetPos = vm.Vector3(targetPos.x, targetPos.y + 0.15, targetPos.z);
    moveDuration = 0.65;
    onActionDone = onArrive;
  }

  void _updateMovingToEat(double dt) {
    final progress = math.min(1.0, stateTime / moveDuration);
    // Smooth ease in-out
    final ease = Curves.easeInOutCubic.transform(progress);

    // Parabolic jump arc
    final currentPos = vm.Vector3(
      moveStartPos.x + (moveTargetPos.x - moveStartPos.x) * ease,
      moveStartPos.y + (moveTargetPos.y - moveStartPos.y) * ease + math.sin(progress * math.pi) * 0.6,
      moveStartPos.z + (moveTargetPos.z - moveStartPos.z) * ease,
    );
    rootNode.position = currentPos;

    // Face movement direction
    final dir = moveTargetPos - moveStartPos;
    if (dir.length2 > 0.001) {
      final angleY = math.atan2(dir.x, dir.z);
      rootNode.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), angleY);
    }

    // Open mouth wide in anticipation!
    final mouthOpen = math.sin(progress * math.pi * 0.5) * 0.7; // up to ~40 deg
    if (upperJawNode != null) {
      upperJawNode!.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -mouthOpen);
    }

    // Grow hungrier and larger
    final hungryScale = 1.0 + progress * 0.35;
    rootNode.scale = vm.Vector3.all(hungryScale);

    if (progress >= 1.0) {
      state = PieceAnimState.chomping;
      stateTime = 0.0;
      onActionDone?.call();
      onActionDone = null;
    }
  }

  void startChomp({required VoidCallback onChompFinished}) {
    state = PieceAnimState.chomping;
    stateTime = 0.0;
    onActionDone = onChompFinished;
  }

  void _updateChomping(double dt) {
    const chompDuration = 0.6;
    final progress = math.min(1.0, stateTime / chompDuration);

    // Rapid chomp snapping cycle
    final chompCycle = math.sin(stateTime * 28.0) * math.exp(-stateTime * 4.0);
    if (upperJawNode != null) {
      upperJawNode!.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), chompCycle * 0.6);
    }

    // Wobble shake on head
    final shake = math.sin(stateTime * 35.0) * 0.08 * math.exp(-stateTime * 3.0);
    rootNode.position = vm.Vector3(moveTargetPos.x + shake, moveTargetPos.y + shake.abs(), moveTargetPos.z);

    // Big happy fat scale
    final bellyPulse = 1.35 + math.sin(stateTime * 12.0) * 0.1;
    rootNode.scale = vm.Vector3.all(bellyPulse);

    if (progress >= 1.0) {
      if (upperJawNode != null) {
        upperJawNode!.rotation = vm.Quaternion.identity();
      }
      onActionDone?.call();
      onActionDone = null;
    }
  }

  void startReturnHome(VoidCallback onReturned) {
    state = PieceAnimState.returningHome;
    stateTime = 0.0;
    moveStartPos = vm.Vector3.copy(rootNode.position);
    moveTargetPos = vm.Vector3(basePosition.x, basePosition.y, basePosition.z);
    moveDuration = 0.6;
    onActionDone = onReturned;
  }

  void _updateReturningHome(double dt) {
    final progress = math.min(1.0, stateTime / moveDuration);
    final ease = Curves.easeOutBack.transform(progress);

    final currentPos = vm.Vector3(
      moveStartPos.x + (moveTargetPos.x - moveStartPos.x) * ease,
      moveStartPos.y + (moveTargetPos.y - moveStartPos.y) * ease + math.sin(progress * math.pi) * 0.4,
      moveStartPos.z + (moveTargetPos.z - moveStartPos.z) * ease,
    );
    rootNode.position = currentPos;

    // Reset rotation to neutral facing forward
    rootNode.rotation = vm.Quaternion.identity();

    // Settle scale back to standard
    final curScale = 1.35 - ease * 0.35;
    rootNode.scale = vm.Vector3.all(curScale);

    if (progress >= 1.0) {
      state = PieceAnimState.celebrating;
      stateTime = 0.0;
      rootNode.position = basePosition;
      rootNode.scale = vm.Vector3.all(1.0);
      onActionDone?.call();
      onActionDone = null;
    }
  }

  void startBeingEaten(vm.Vector3 winnerPos) {
    state = PieceAnimState.beingEaten;
    stateTime = 0.0;
    moveStartPos = vm.Vector3.copy(rootNode.position);
    moveTargetPos = vm.Vector3(winnerPos.x, winnerPos.y + 0.1, winnerPos.z);
  }

  void _updateBeingEaten(double dt) {
    const eatDuration = 0.55;
    final progress = math.min(1.0, stateTime / eatDuration);

    // Tremble in fear!
    final tremble = math.sin(stateTime * 45.0) * 0.06;

    // Sucked into mouth trajectory
    final suckedX = moveStartPos.x + (moveTargetPos.x - moveStartPos.x) * progress + tremble;
    final suckedY = moveStartPos.y + (moveTargetPos.y - moveStartPos.y) * progress + tremble;
    final suckedZ = moveStartPos.z + (moveTargetPos.z - moveStartPos.z) * progress;

    rootNode.position = vm.Vector3(suckedX, suckedY, suckedZ);

    // Shrink rapidly to 0
    final curScale = math.max(0.0, 1.0 - progress);
    rootNode.scale = vm.Vector3.all(curScale);

    // Rapid panicked spin
    rootNode.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), stateTime * 18.0);

    if (progress >= 1.0) {
      state = PieceAnimState.eaten;
      rootNode.visible = false;
    }
  }
}

class AnimatedCrumbParticle {
  final Node node;
  vm.Vector3 velocity;
  double lifetime;
  double maxLifetime;

  AnimatedCrumbParticle({
    required this.node,
    required this.velocity,
    required this.maxLifetime,
  }) : lifetime = maxLifetime;

  bool update(double dt) {
    lifetime -= dt;
    if (lifetime <= 0) {
      node.visible = false;
      return false; // Dead
    }

    // Apply gravity
    velocity.y -= 12.0 * dt;
    node.position += velocity * dt;

    // Shrink over lifetime
    final progress = lifetime / maxLifetime;
    node.scale = vm.Vector3.all(progress * 0.8);
    return true;
  }
}
