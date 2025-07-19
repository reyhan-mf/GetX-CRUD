import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';

import 'services/stopwatch_service.dart';

class StopwatchController extends GetxController {
  var elapsedTime = 0.obs;
  var isRunning = false.obs;
  var lastPauseTime = 0.obs;
  var isForegroundServiceEnabled = false.obs;
  var isServiceRunning = false.obs;
  Timer? _timer;
  Timer? _debugTimer;
  Timer? _backgroundKeepAlive;
  Timer? _syncTimer;

  bool _isReceivingFromService = false; // Flag untuk mencegah loop

  @override
  void onInit() {
    super.onInit();
    developer.log('🚀 StopwatchController initialized', name: 'Stopwatch');

    _initForegroundService();
    _setupServiceListener();

    // Worker yang akan tetap berjalan di background
    ever(isRunning, (bool running) {
      if (!_isReceivingFromService) {
        // Hindari loop saat menerima dari service
        if (running) {
          _startTimer();
          _startDebugTimer();
          _startBackgroundKeepAlive();
          if (isForegroundServiceEnabled.value && isServiceRunning.value) {
            _sendToForegroundService({'action': 'start'});
          }
          developer.log('▶️ Stopwatch STARTED - Background worker active',
              name: 'Stopwatch');
        } else {
          _stopTimer();
          _stopDebugTimer();
          _stopBackgroundKeepAlive();
          if (isForegroundServiceEnabled.value && isServiceRunning.value) {
            _sendToForegroundService({'action': 'stop'});
          }
          developer.log('⏸️ Stopwatch STOPPED', name: 'Stopwatch');
        }
      }
    });

    // Worker untuk memantau perubahan waktu dengan persistence
    ever(elapsedTime, (int time) {
      // Log setiap 1 detik untuk tidak spam console
      if (time % 1000 == 0 && isRunning.value && !_isReceivingFromService) {
        developer.log('⏱️ Elapsed: $formattedTime (${time}ms)',
            name: 'Stopwatch');
        _saveStateToMemory();

        // Sync ke service jika berbeda
        _syncToService();
      }
    });

    // Start sync timer
    _startSyncTimer();
  }

  void _setupServiceListener() {
    try {
      // Setup listener untuk menerima data dari service
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
      developer.log('✅ Service listener setup complete', name: 'Stopwatch');
    } catch (e) {
      developer.log('❌ Failed to setup service listener: $e',
          name: 'Stopwatch');
    }
  }

  void _onReceiveTaskData(Object data) {
    if (data is Map && data['type'] == 'state_update') {
      _isReceivingFromService = true;

      int serviceElapsed = data['elapsed_time'] ?? 0;
      bool serviceRunning = data['is_running'] ?? false;

      // Update hanya jika berbeda untuk menghindari conflict
      if (elapsedTime.value != serviceElapsed) {
        elapsedTime.value = serviceElapsed;
        developer.log(
            '🔄 Synced elapsed time from service: ${serviceElapsed}ms',
            name: 'Stopwatch-Sync');
      }

      if (isRunning.value != serviceRunning) {
        isRunning.value = serviceRunning;
        developer.log('🔄 Synced running state from service: $serviceRunning',
            name: 'Stopwatch-Sync');
      }

      Future.delayed(const Duration(milliseconds: 100), () {
        _isReceivingFromService = false;
      });
    }
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (isServiceRunning.value) {
        // Request sync dari service
        _sendToForegroundService({'action': 'request_sync'});
      }
    });
  }

  void _syncToService() {
    if (isServiceRunning.value && !_isReceivingFromService) {
      _sendToForegroundService({
        'action': 'sync_from_app',
        'elapsed_time': elapsedTime.value,
        'is_running': isRunning.value,
      });
    }
  }

  Future<void> _initForegroundService() async {
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'stopwatch_channel',
          channelName: 'Stopwatch Service',
          channelDescription: 'Keeps stopwatch running in background',
          channelImportance: NotificationChannelImportance.HIGH,
          priority: NotificationPriority.HIGH,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(5000),
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: false,
        ),
      );

      isForegroundServiceEnabled.value = true;
      developer.log('✅ Foreground service initialized', name: 'Stopwatch');
    } catch (e) {
      developer.log('❌ Failed to init foreground service: $e',
          name: 'Stopwatch');
    }
  }

  Future<void> startForegroundService() async {
    if (!isForegroundServiceEnabled.value) return;

    bool isActive = await FlutterForegroundTask.isRunningService;
    if (isActive) {
      isServiceRunning.value = true;
      return;
    }

    ServiceRequestResult result = await FlutterForegroundTask.startService(
      notificationTitle: '⏱️ Stopwatch Service',
      notificationText: 'Stopwatch is ready to run in background',
      notificationIcon: null,
      notificationButtons: [
        const NotificationButton(
          id: 'start_stop',
          text: 'Start/Stop',
        ),
        const NotificationButton(
          id: 'reset',
          text: 'Reset',
        ),
      ],
      callback: startStopwatchCallback,
    );

    isServiceRunning.value = true;
    // Sync current state ke service
    Future.delayed(const Duration(milliseconds: 500), () {
      _syncToService();
    });

    developer.log('🚀 Foreground service start result: $result',
        name: 'Stopwatch');
  }

  Future<void> stopForegroundService() async {
    ServiceRequestResult result = await FlutterForegroundTask.stopService();
    isServiceRunning.value = false;
    developer.log('🛑 Foreground service stop result: $result',
        name: 'Stopwatch');
  }

  void _sendToForegroundService(Map<String, dynamic> data) {
    FlutterForegroundTask.sendDataToTask(data);
  }

  void _handleAppStateChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        developer.log('🔄 App going to background - Timer will continue!',
            name: 'Stopwatch-Background');
        if (isRunning.value) {
          lastPauseTime.value = DateTime.now().millisecondsSinceEpoch;
          developer.log(
              '⚡ Background mode: Timer still RUNNING with GetX worker!',
              name: 'Stopwatch-Background');
        }
        break;
      case AppLifecycleState.resumed:
        developer.log('🔄 App resumed from background',
            name: 'Stopwatch-Background');
        if (isRunning.value && lastPauseTime.value > 0) {
          int backgroundTime =
              DateTime.now().millisecondsSinceEpoch - lastPauseTime.value;
          developer.log('⏰ Background duration: ${backgroundTime}ms',
              name: 'Stopwatch-Background');
        }
        break;
      default:
        break;
    }
  }

  void _saveStateToMemory() {
    // Simpan state ke memory untuk recovery (simplified version)
    try {
      developer.log(
          '💾 Saving state: ${elapsedTime.value}ms, running: ${isRunning.value}',
          name: 'Stopwatch-State');
    } catch (e) {
      developer.log('⚠️ Failed to save state: $e', name: 'Stopwatch-State');
    }
  }

  void _startBackgroundKeepAlive() {
    // Timer untuk mempertahankan proses di background
    _backgroundKeepAlive = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Aktivitas minimal untuk menjaga worker tetap hidup
      if (isRunning.value) {
        developer.log('💓 Background heartbeat - Worker alive!',
            name: 'Stopwatch-KeepAlive');
      }
    });
  }

  void _stopBackgroundKeepAlive() {
    _backgroundKeepAlive?.cancel();
    developer.log('💤 Background keep-alive stopped',
        name: 'Stopwatch-KeepAlive');
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      elapsedTime.value += 10;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _startDebugTimer() {
    // Debug timer untuk log setiap 5 detik saat berjalan
    _debugTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (isRunning.value) {
        developer.log(
            '🔄 Background Status: RUNNING | Time: $formattedTime | Total MS: ${elapsedTime.value}',
            name: 'Stopwatch-Debug');
        developer.log(
            '📱 App State: ${Get.context != null ? "FOREGROUND" : "BACKGROUND"}',
            name: 'Stopwatch-Debug');
      }
    });
  }

  void _stopDebugTimer() {
    _debugTimer?.cancel();
    developer.log('🛑 Debug timer stopped', name: 'Stopwatch-Debug');
  }

  void start() {
    isRunning.value = true;
    if (isForegroundServiceEnabled.value && isServiceRunning.value) {
      _sendToForegroundService({'action': 'start'});
    }
    developer.log('🎬 START button pressed', name: 'Stopwatch-UI');
  }

  void stop() {
    isRunning.value = false;
    if (isForegroundServiceEnabled.value && isServiceRunning.value) {
      _sendToForegroundService({'action': 'stop'});
    }
    developer.log('🛑 STOP button pressed | Final time: $formattedTime',
        name: 'Stopwatch-UI');
  }

  void reset() {
    stop();
    elapsedTime.value = 0;
    if (isForegroundServiceEnabled.value && isServiceRunning.value) {
      _sendToForegroundService({'action': 'reset'});
    }
    developer.log('🔄 RESET button pressed | Time cleared',
        name: 'Stopwatch-UI');
  }

  String get formattedTime {
    int totalMilliseconds = elapsedTime.value;
    int minutes = totalMilliseconds ~/ 60000;
    int seconds = (totalMilliseconds % 60000) ~/ 1000;
    int milliseconds = (totalMilliseconds % 1000) ~/ 10;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}:'
        '${milliseconds.toString().padLeft(2, '0')}';
  }

  @override
  void onClose() {
    developer.log('💀 StopwatchController disposing...', name: 'Stopwatch');
    _timer?.cancel();
    _debugTimer?.cancel();
    _backgroundKeepAlive?.cancel();
    _syncTimer?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    developer.log('🗑️ All timers cancelled and controller disposed',
        name: 'Stopwatch');
    super.onClose();
  }
}

class StopWatch extends StatefulWidget {
  const StopWatch({super.key});

  @override
  State<StopWatch> createState() => _StopWatchState();
}

class _StopWatchState extends State<StopWatch> with WidgetsBindingObserver {
  late StopwatchController controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = Get.put(StopwatchController());
    developer.log('📱 StopWatch widget initialized',
        name: 'Stopwatch-Lifecycle');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    developer.log('📱 StopWatch widget disposed', name: 'Stopwatch-Lifecycle');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    controller._handleAppStateChange(state);
    switch (state) {
      case AppLifecycleState.resumed:
        developer.log('🔄 App RESUMED - Back to foreground',
            name: 'Stopwatch-Lifecycle');
        break;
      case AppLifecycleState.paused:
        developer.log('⏸️ App PAUSED - Going to background',
            name: 'Stopwatch-Lifecycle');
        if (controller.isRunning.value) {
          developer.log('⚡ GetX Worker: Timer CONTINUES in background!',
              name: 'Stopwatch-Lifecycle');
        }
        break;
      case AppLifecycleState.inactive:
        developer.log('💤 App INACTIVE', name: 'Stopwatch-Lifecycle');
        break;
      case AppLifecycleState.detached:
        developer.log('🔌 App DETACHED - Being terminated',
            name: 'Stopwatch-Lifecycle');
        developer.log('💀 All workers will be destroyed!',
            name: 'Stopwatch-Lifecycle');
        break;
      case AppLifecycleState.hidden:
        developer.log('👁️ App HIDDEN', name: 'Stopwatch-Lifecycle');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Stopwatch',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display waktu
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[700]!, width: 2),
              ),
              child: Obx(() => Text(
                    controller.formattedTime,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  )),
            ),

            const SizedBox(height: 50),

            // Tombol kontrol
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Tombol Reset
                ElevatedButton(
                  onPressed: () => controller.reset(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Reset',
                    style: TextStyle(fontSize: 18),
                  ),
                ),

                // Tombol Start/Stop
                Obx(() => ElevatedButton(
                      onPressed: () {
                        if (controller.isRunning.value) {
                          controller.stop();
                        } else {
                          controller.start();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: controller.isRunning.value
                            ? Colors.red[600]
                            : Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        controller.isRunning.value ? 'Stop' : 'Start',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )),
              ],
            ),

            const SizedBox(height: 30),

            // Status indicator
            Obx(() => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: controller.isRunning.value
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: controller.isRunning.value
                          ? Colors.green
                          : Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            controller.isRunning.value
                                ? Icons.play_arrow
                                : Icons.pause,
                            color: controller.isRunning.value
                                ? Colors.green
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            controller.isRunning.value
                                ? 'Berjalan di Background'
                                : 'Terhenti',
                            style: TextStyle(
                              color: controller.isRunning.value
                                  ? Colors.green
                                  : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (controller.isServiceRunning.value) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield,
                                color: Colors.purple, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Protected by Service',
                              style: TextStyle(
                                color: Colors.purple[300],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ]
                    ],
                  ),
                )),

            const SizedBox(height: 20),

            // Debug info
            Container(
              padding: const EdgeInsets.all(15),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.bug_report, color: Colors.blue, size: 20),
                  const SizedBox(height: 8),
                  const Text(
                    'Debug Console Active',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cek VS Code Debug Console\nuntuk melihat log background',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blue[300],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // Foreground Service Control
            Obx(() => Container(
                  padding: const EdgeInsets.all(15),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: controller.isForegroundServiceEnabled.value
                        ? Colors.purple.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: controller.isForegroundServiceEnabled.value
                            ? Colors.purple.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.security,
                            color: controller.isForegroundServiceEnabled.value
                                ? Colors.purple
                                : Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Foreground Service',
                            style: TextStyle(
                              color: controller.isForegroundServiceEnabled.value
                                  ? Colors.purple[300]
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed:
                                controller.isForegroundServiceEnabled.value
                                    ? () => controller.startForegroundService()
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              'Start Service',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          ElevatedButton(
                            onPressed:
                                controller.isForegroundServiceEnabled.value
                                    ? () => controller.stopForegroundService()
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              'Stop Service',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.isForegroundServiceEnabled.value
                            ? controller.isServiceRunning.value
                                ? '✅ Service aktif\n🔄 Timer sinkron dengan notification\n💀 Tetap jalan meski app di-kill'
                                : '⚠️ Service ready, tekan Start Service\n🔄 Untuk protection saat app terminate'
                            : '❌ Service tidak tersedia',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: controller.isForegroundServiceEnabled.value
                              ? controller.isServiceRunning.value
                                  ? Colors.purple[200]
                                  : Colors.orange[200]
                              : Colors.grey,
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 15),

            // Background capability info
            Container(
              padding: const EdgeInsets.all(15),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.settings_backup_restore,
                          color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'GetX Background Worker',
                        style: TextStyle(
                          color: Colors.green[300],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '✅ Berjalan saat minimize app\n❌ Berhenti saat swipe/kill app\n⚡ Ever worker tetap aktif di background',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green[200],
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
