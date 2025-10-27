import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";
import "package:provider/provider.dart";

import "../utils/game_controller.dart";
import "../utils/timer.dart";

class TimeoutScreen extends StatefulWidget {
  const TimeoutScreen({super.key});

  @override
  State<TimeoutScreen> createState() => _TimeoutScreenState();
}

class _TimeoutScreenState extends State<TimeoutScreen> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  DateTime? _startTime;
  bool _wasPaused = false;
  late TimerService _timerService;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    
    // Сохраняем ссылку на TimerService
    _timerService = context.read<TimerService>();
    
    // Приостанавливаем игровой таймер
    _wasPaused = _timerService.isPaused;
    if (!_wasPaused) {
      _timerService.pause();
    }
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    
    // Возобновляем игровой таймер если закрыли через кнопку "Назад"
    // (если закрыли через "Завершить", то возобновление уже произошло в _endTimeout)
    if (!_wasPaused && _timerService.isPaused) {
      // Используем post-frame callback для гарантированного выполнения после закрытия
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_timerService.isPaused) {
          // Перезапускаем таймер (это надежнее чем resume)
          _timerService.restart(paused: false);
        }
      });
    }
    
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  Future<void> _endTimeout(BuildContext context) async {
    final controller = context.read<GameController>();
    controller.addTimeout(_startTime!, DateTime.now());
    
    // Закрываем экран
    Navigator.pop(context);
    
    // Даем время на анимацию закрытия и перезапускаем таймер
    if (!_wasPaused) {
      await Future.delayed(const Duration(milliseconds: 300));
      // Перезапускаем таймер (это надежнее чем resume)
      _timerService.restart(paused: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Таймаут"),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.timer,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              _formatDuration(_elapsed),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _endTimeout(context),
              icon: const Icon(Icons.stop),
              label: const Text("Завершить таймаут"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

