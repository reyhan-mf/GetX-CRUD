import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Callback function untuk foreground task
@pragma('vm:entry-point')
void startStopwatchCallback() {
  FlutterForegroundTask.setTaskHandler(StopwatchTaskHandler());
}

class StopwatchTaskHandler extends TaskHandler {
  Timer? _timer;
  Timer? _syncTimer;
  int _elapsedTime = 0;
  bool _isRunning = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    developer.log('🚀 Foreground Service STARTED', name: 'ForegroundService');

    // Load saved state
    await _loadState();

    if (_isRunning) {
      _startTimer();
    }

    // Start sync timer untuk broadcast state ke app
    _startSyncTimer();
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    // Update notification every 5 seconds
    if (_isRunning) {
      String formattedTime = _formatTime(_elapsedTime);

      FlutterForegroundTask.updateService(
        notificationTitle: '⏱️ Stopwatch Running',
        notificationText: 'Time: $formattedTime',
      );

      developer.log('⏱️ Service Update: $formattedTime (${_elapsedTime}ms)',
          name: 'ForegroundService');
    } else {
      FlutterForegroundTask.updateService(
        notificationTitle: '⏱️ Stopwatch Stopped',
        notificationText: 'Time: ${_formatTime(_elapsedTime)}',
      );
    }
  }

  @override
  void onReceiveData(Object data) async {
    developer.log('📨 Service received: $data', name: 'ForegroundService');

    if (data is Map) {
      switch (data['action']) {
        case 'start':
          _isRunning = true;
          _startTimer();
          await _saveState();
          developer.log('▶️ Service: Timer STARTED', name: 'ForegroundService');
          break;

        case 'stop':
          _isRunning = false;
          _stopTimer();
          await _saveState();
          developer.log('⏸️ Service: Timer STOPPED', name: 'ForegroundService');
          break;

        case 'reset':
          _isRunning = false;
          _elapsedTime = 0;
          _stopTimer();
          await _saveState();
          _broadcastStateToApp();
          developer.log('🔄 Service: Timer RESET', name: 'ForegroundService');
          break;

        case 'sync_from_app':
          // Sinkronisasi dari app ke service
          if (data['elapsed_time'] != null) {
            _elapsedTime = data['elapsed_time'];
            _isRunning = data['is_running'] ?? false;

            if (_isRunning && !(_timer?.isActive ?? false)) {
              _startTimer();
            } else if (!_isRunning && (_timer?.isActive ?? false)) {
              _stopTimer();
            }

            await _saveState();
            developer.log(
                '🔄 Service synced from app: ${_elapsedTime}ms, running: $_isRunning',
                name: 'ForegroundService');
          }
          break;

        case 'request_sync':
          // App meminta state terkini dari service
          _broadcastStateToApp();
          break;
      }
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    developer.log('🔘 Notification button pressed: $id',
        name: 'ForegroundService');

    switch (id) {
      case 'start_stop':
        if (_isRunning) {
          onReceiveData({'action': 'stop'});
        } else {
          onReceiveData({'action': 'start'});
        }
        break;
      case 'reset':
        onReceiveData({'action': 'reset'});
        break;
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    developer.log('💀 Foreground Service DESTROYED', name: 'ForegroundService');
    _stopTimer();
    _syncTimer?.cancel();
    await _saveState();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      _elapsedTime += 10;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _startSyncTimer() {
    // Timer untuk broadcast state setiap detik saat running
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRunning) {
        _broadcastStateToApp();
      }
    });
  }

  void _broadcastStateToApp() {
    // Kirim state ke app melalui sendDataToMain
    FlutterForegroundTask.sendDataToMain({
      'type': 'state_update',
      'elapsed_time': _elapsedTime,
      'is_running': _isRunning,
      'formatted_time': _formatTime(_elapsedTime),
    });
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('stopwatch_elapsed_time', _elapsedTime);
      await prefs.setBool('stopwatch_is_running', _isRunning);
      await prefs.setInt(
          'stopwatch_last_save', DateTime.now().millisecondsSinceEpoch);
      developer.log('💾 State saved: ${_elapsedTime}ms, running: $_isRunning',
          name: 'ForegroundService');
    } catch (e) {
      developer.log('❌ Failed to save state: $e', name: 'ForegroundService');
    }
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _elapsedTime = prefs.getInt('stopwatch_elapsed_time') ?? 0;
      _isRunning = prefs.getBool('stopwatch_is_running') ?? false;
      int lastSave = prefs.getInt('stopwatch_last_save') ?? 0;

      // Calculate time passed since last save if timer was running
      if (_isRunning && lastSave > 0) {
        int timePassed = DateTime.now().millisecondsSinceEpoch - lastSave;
        _elapsedTime += timePassed;
        developer.log('🔄 Restored from background: +${timePassed}ms',
            name: 'ForegroundService');
      }

      developer.log('📂 State loaded: ${_elapsedTime}ms, running: $_isRunning',
          name: 'ForegroundService');
    } catch (e) {
      developer.log('❌ Failed to load state: $e', name: 'ForegroundService');
    }
  }

  String _formatTime(int totalMilliseconds) {
    int minutes = totalMilliseconds ~/ 60000;
    int seconds = (totalMilliseconds % 60000) ~/ 1000;
    int milliseconds = (totalMilliseconds % 1000) ~/ 10;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}:'
        '${milliseconds.toString().padLeft(2, '0')}';
  }
}
