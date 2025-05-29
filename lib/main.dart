// lib/main.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const CatchTheBallApp());
}

class CatchTheBallApp extends StatelessWidget {
  const CatchTheBallApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catch the Ball',
      theme: ThemeData.dark(),
      home: const GamePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({Key? key}) : super(key: key);

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Timer? _spawnTimer;
  final Random _rand = Random();
  final List<Ball> _balls = [];

  // Game state
  double _bucketX = 0.5;       // 0..1 normalized
  int _score = 0;
  int _level = 0;
  bool _running = false;
  bool _gameOver = false;

  // Timing
  Duration _lastTick = Duration.zero;
  Size _screenSize = Size.zero;

  // Layout constants
  static const double _ballSize = 30;
  static const double _bucketWidth = 80;
  static const double _bucketHeight = 80;
  static const double _bucketBottom = 20;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_updateGame);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _spawnTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    if (_running) return;
    setState(() {
      _running = true;
      _gameOver = false;
      _score = 0;
      _level = 0;
      _balls.clear();
    });
    _lastTick = Duration.zero;
    _ticker.start();
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      setState(() => _balls.add(Ball(x: _rand.nextDouble())));
    });
  }

  void _endGame() {
    _ticker.stop();
    _spawnTimer?.cancel();
    setState(() {
      _running = false;
      _gameOver = true;
    });
  }

  void _updateGame(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMilliseconds / 1000;
    _lastTick = elapsed;

    // Move balls
    final speedMultiplier = 1.0 + _level * 0.2;
    for (var ball in _balls) {
      ball.y += ball.speed * speedMultiplier * dt;
    }

    // Collision & removal
    _balls.removeWhere((ball) {
      final ballY = ball.y * (_screenSize.height - _ballSize);
      final ballCenterX = ball.x * (_screenSize.width - _ballSize) + _ballSize/2;
      final bucketLeft = _bucketX * (_screenSize.width - _bucketWidth);
      final bucketTop = _screenSize.height - _bucketHeight - _bucketBottom;

      final hitVert = ballY + _ballSize >= bucketTop;
      final hitHoriz = ballCenterX >= bucketLeft
          && ballCenterX <= bucketLeft + _bucketWidth;
      final caught = hitVert && hitHoriz;

      if (caught) {
        _score++;
        if (_score >= (_level + 1) * 10) {
          _level++;
          if (_level > 5) _endGame();
        }
      }
      return caught || ballY > _screenSize.height;
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        if (!_running) return;
        setState(() {
          _bucketX += d.delta.dx / _screenSize.width;
          _bucketX = _bucketX.clamp(0.0, 1.0);
        });
      },
      child: Stack(
        children: [
          // Balls
          for (var ball in _balls)
            Positioned(
              left: ball.x * (_screenSize.width - _ballSize),
              top:  ball.y * (_screenSize.height - _ballSize),
              child: const Icon(Icons.circle, color: Colors.red, size: _ballSize),
            ),

          // Bucket
          Positioned(
            left: _bucketX * (_screenSize.width - _bucketWidth),
            bottom: _bucketBottom,
            child: Image.asset(
              'assets/images/bucket.png',
              width:  _bucketWidth,
              height: _bucketHeight,
            ),
          ),

          // Score & Level
          Positioned(
            top: 40,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Score: $_score',
                    style: const TextStyle(fontSize: 24, color: Colors.red)),
                Text('Level: $_level',
                    style: const TextStyle(fontSize: 18, color: Colors.red)),
              ],
            ),
          ),

          // Start overlay
          if (!_running && !_gameOver)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                    ),
                    child: const Text('START', style: TextStyle(fontSize: 24)),
                  ),
                ),
              ),
            ),

          // Game Over / Congratulations overlay
          if (_gameOver)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '🎉 Congratulations! 🎉',
                        style: TextStyle(
                            fontSize: 32,
                            color: Colors.yellow,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You reached level $_level',
                        style: const TextStyle(
                            fontSize: 24, color: Colors.red),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _startGame,  // ← restart here
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: const Text('RESTART', style: TextStyle(fontSize: 20)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class Ball {
  double x;
  double y = 0;
  late final double speed;
  Ball({required this.x}) {
    speed = 0.5 + Random().nextDouble();
  }
}
