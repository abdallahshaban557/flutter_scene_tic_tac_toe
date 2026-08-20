import 'package:flutter/material.dart';
import '../game/game_controller.dart';

class GameOverlay extends StatelessWidget {
  final GameController controller;
  final VoidCallback onNewGame;
  final VoidCallback onResetScores;
  final ValueChanged<int> onCellTapped;

  const GameOverlay({
    super.key,
    required this.controller,
    required this.onNewGame,
    required this.onResetScores,
    required this.onCellTapped,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // 1. Top Section: Header, Mode Selector, Scoreboard & Status Banner
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                const SizedBox(height: 8),
                _buildScoreboard(context),
                const SizedBox(height: 8),
                _buildStatusBanner(context),
              ],
            ),
          ),

          // 2. Corner Mini-Board HUD for quick visual reference & secondary tap
          Positioned(
            right: 16,
            bottom: 80,
            child: _buildMiniBoardHUD(context),
          ),

          // 3. Bottom Controls Bar
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildBottomControls(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE94560), Color(0xFF0F3460)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE94560).withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Text(
                    "3D",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  "TIC-TAC-TOE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Mode Switcher Toggle
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeTab(
                  title: "vs AI",
                  icon: Icons.smart_toy_outlined,
                  isSelected: controller.mode == GameMode.singlePlayer,
                  onTap: () => controller.setGameMode(GameMode.singlePlayer),
                ),
                _buildModeTab(
                  title: "2P",
                  icon: Icons.people_alt_outlined,
                  isSelected: controller.mode == GameMode.twoPlayer,
                  onTap: () => controller.setGameMode(GameMode.twoPlayer),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F3460) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF00ADB5) : Colors.white60,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreboard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Player X
          _buildScoreCard(
            label: "PLAYER X",
            score: controller.xScore,
            color: const Color(0xFFFF4D6D),
            isTurn: controller.currentTurn == CellState.x &&
                controller.status == GameStatus.playing,
          ),
          Container(
            height: 28,
            width: 1,
            color: Colors.white12,
          ),
          // Ties
          _buildScoreCard(
            label: "DRAWS",
            score: controller.tieScore,
            color: Colors.white60,
            isTurn: false,
          ),
          Container(
            height: 28,
            width: 1,
            color: Colors.white12,
          ),
          // Player O
          _buildScoreCard(
            label: controller.mode == GameMode.singlePlayer ? "AI (O)" : "PLAYER O",
            score: controller.oScore,
            color: const Color(0xFF00E5FF),
            isTurn: controller.currentTurn == CellState.o &&
                controller.status == GameStatus.playing,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard({
    required String label,
    required int score,
    required Color color,
    required bool isTurn,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isTurn ? FontWeight.bold : FontWeight.w500,
                color: isTurn ? color : Colors.white60,
                letterSpacing: 0.8,
              ),
            ),
            if (isTurn) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color,
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          "$score",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    Color bannerColor = const Color(0xFF0F3460);
    IconData bannerIcon = Icons.gamepad_outlined;

    if (controller.status == GameStatus.winningCelebration ||
        controller.status == GameStatus.eatingLosers) {
      bannerColor = controller.winResult?.winner == CellState.x
          ? const Color(0xFFFF4D6D)
          : const Color(0xFF00E5FF);
      bannerIcon = Icons.restaurant;
    } else if (controller.status == GameStatus.ended) {
      bannerColor = const Color(0xFF38A3A5);
      bannerIcon = Icons.emoji_events;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(bannerIcon, size: 16, color: bannerColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              controller.statusMessage,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                shadows: [
                  Shadow(
                    color: bannerColor.withValues(alpha: 0.8),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBoardHUD(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "GRID MAP",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 84,
            height: 84,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                final cell = controller.board[index];
                final isWinner =
                    controller.winResult?.winningIndices.contains(index) ?? false;
                final isTargetLoser =
                    controller.currentlyTargetedLoserIndex == index;

                Color cellBg = const Color(0xFF1A1A2E);
                Widget? content;

                if (cell == CellState.x) {
                  content = const Text(
                    "X",
                    style: TextStyle(
                      color: Color(0xFFFF4D6D),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                } else if (cell == CellState.o) {
                  content = const Text(
                    "O",
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }

                if (isWinner) {
                  cellBg = const Color(0xFF57CC99).withValues(alpha: 0.3);
                } else if (isTargetLoser) {
                  cellBg = Colors.red.withValues(alpha: 0.35);
                }

                return InkWell(
                  onTap: () => onCellTapped(index),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isWinner
                            ? const Color(0xFF57CC99)
                            : isTargetLoser
                                ? Colors.redAccent
                                : Colors.white10,
                      ),
                    ),
                    child: Center(child: content),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // New Game Button
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94560),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(
                "NEW GAME",
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              onPressed: onNewGame,
            ),
          ),
          const SizedBox(width: 12),

          // Reset Scores
          IconButton(
            icon: const Icon(Icons.restart_alt, color: Colors.white70),
            tooltip: "Reset Scores",
            onPressed: onResetScores,
          ),
        ],
      ),
    );
  }
}
