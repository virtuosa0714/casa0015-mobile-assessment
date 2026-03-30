import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:light/light.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const double MIN_LUX = 300.0;
const double MAX_DB = 60.0;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: SplashScreen(),
    ),
  );
}

class EnvRecord {
  final int second;
  final double lux;
  final double db;
  final bool isOptimal;
  EnvRecord({
    required this.second,
    required this.lux,
    required this.db,
    required this.isOptimal,
  });
}

enum FocusCoreState { workOptimal, workSuboptimal, breakNormal }

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2500), () {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => PomodoroUI()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E3C72)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.public, size: 80, color: Colors.cyanAccent),
            SizedBox(height: 20),
            Text(
              "Focus Sphere",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Monitor. Focus. Connect.",
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            SizedBox(height: 50),
            CircularProgressIndicator(color: Colors.cyanAccent),
          ],
        ),
      ),
    );
  }
}

class PomodoroUI extends StatefulWidget {
  @override
  _PomodoroUIState createState() => _PomodoroUIState();
}

class _PomodoroUIState extends State<PomodoroUI> with TickerProviderStateMixin {
  int _workMinutes = 25;
  int _breakMinutes = 5;
  int _totalSessions = 4;
  int _completedSessions = 0;

  late int _secondsRemaining;
  bool _isWorking = true;
  bool _isRunning = false;
  Timer? _timer;

  double _luxValue = 0;
  double _dbValue = 0;
  int _violationSeconds = 0;
  bool _isEnvWarning = false;

  StreamSubscription? _lightSubscription;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  NoiseMeter? _noiseMeter;

  List<EnvRecord> _currentSessionHistory = [];

  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  late AnimationController _rotationController;
  late AnimationController _warningFlickerController;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = _workMinutes * 60;

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _breathingAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.05,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_breathingController);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _warningFlickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  FocusCoreState get _currentCoreState {
    if (!_isWorking) return FocusCoreState.breakNormal;
    if (_isEnvWarning) return FocusCoreState.workSuboptimal;
    return FocusCoreState.workOptimal;
  }

  void _updateCoreNarrativeExperience() {
    if (!_isRunning) {
      _rotationController.stop();
      _breathingController.stop();
      _warningFlickerController.stop();
      return;
    }
    switch (_currentCoreState) {
      case FocusCoreState.workOptimal:
        _rotationController.duration = const Duration(seconds: 5);
        _rotationController.repeat();
        _breathingController.duration = const Duration(seconds: 2);
        _breathingController.repeat();
        _warningFlickerController.reset();
        break;
      case FocusCoreState.workSuboptimal:
        _rotationController.duration = const Duration(seconds: 2);
        _rotationController.repeat();
        _breathingController.duration = const Duration(seconds: 1);
        _breathingController.repeat();
        _warningFlickerController.repeat(reverse: true);
        break;
      case FocusCoreState.breakNormal:
        _rotationController.duration = const Duration(seconds: 10);
        _rotationController.repeat();
        _breathingController.duration = const Duration(seconds: 4);
        _breathingController.repeat();
        _warningFlickerController.reset();
        break;
    }
  }

  Future<void> _startMonitoring() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      _lightSubscription = Light().lightSensorStream.listen((lux) {
        if (mounted) setState(() => _luxValue = lux.toDouble());
      });
      _noiseMeter = NoiseMeter();
      _noiseSubscription = _noiseMeter?.noise.listen((reading) {
        if (mounted) setState(() => _dbValue = reading.meanDecibel);
      });
    }
  }

  void _stopMonitoring() {
    _lightSubscription?.cancel();
    _noiseSubscription?.cancel();
    _violationSeconds = 0;
    if (mounted) {
      setState(() {
        _isEnvWarning = false;
        _luxValue = 0;
        _dbValue = 0;
      });
    }
  }

  void _checkAndRecordEnvironment() {
    if (!_isWorking) {
      _isEnvWarning = false;
      _violationSeconds = 0;
      return;
    }

    bool badLight = _luxValue < MIN_LUX;
    bool badNoise = _dbValue > MAX_DB;
    bool isOptimal = !badLight && !badNoise;

    int secondsElapsed = (_workMinutes * 60) - _secondsRemaining;
    _currentSessionHistory.add(
      EnvRecord(
        second: secondsElapsed,
        lux: _luxValue,
        db: _dbValue,
        isOptimal: isOptimal,
      ),
    );

    if (badLight || badNoise) {
      _violationSeconds++;
      if (_violationSeconds >= 3 && !_isEnvWarning) {
        setState(() => _isEnvWarning = true);
        _updateCoreNarrativeExperience();
      }
    } else {
      _violationSeconds = 0;
      if (_isEnvWarning) {
        setState(() => _isEnvWarning = false);
        _updateCoreNarrativeExperience();
      }
    }
  }

  void _toggleTimer() {
    setState(() => _isRunning = !_isRunning);
    if (_isRunning) {
      if (_secondsRemaining == _workMinutes * 60 && _isWorking) {
        _currentSessionHistory.clear();
      }
      _startMonitoring();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
            _checkAndRecordEnvironment();
          } else {
            _handleSessionEnd();
          }
        });
      });
    } else {
      _timer?.cancel();
      _stopMonitoring();
    }
    _updateCoreNarrativeExperience();
  }

  Future<void> _uploadSessionToCloud() async {
    if (_currentSessionHistory.isEmpty) return;

    double totalLux = 0;
    double totalDb = 0;
    int optimalCount = 0;
    List<Map<String, dynamic>> rawDataList = [];

    for (var record in _currentSessionHistory) {
      totalLux += record.lux;
      totalDb += record.db;
      if (record.isOptimal) optimalCount++;

      rawDataList.add({
        'second': record.second,
        'lux': record.lux,
        'db': record.db,
        'isOptimal': record.isOptimal,
      });
    }

    int count = _currentSessionHistory.length;
    double avgLux = totalLux / count;
    double avgDb = totalDb / count;
    double optimalPercentage = (optimalCount / count) * 100;

    try {
      await FirebaseFirestore.instance.collection('focus_sessions').add({
        'timestamp': FieldValue.serverTimestamp(),
        'durationMinutes': _workMinutes,
        'avgLux': avgLux,
        'avgDb': avgDb,
        'optimalPercentage': optimalPercentage,
        'rawHistory': rawDataList,
      });
    } catch (e) {
      debugPrint("Error uploading to Firebase: $e");
    }
  }

  void _showCongratsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E3C72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, color: Colors.cyanAccent, size: 80),
                const SizedBox(height: 20),
                const Text(
                  "Goal Achieved!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  "Incredible work! You have successfully completed all $_totalSessions focus sessions and fully charged the Focus Planet.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      "AWESOME",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleSessionEnd() async {
    _timer?.cancel();
    _stopMonitoring();
    setState(() => _isRunning = false);

    if (_isWorking) {
      _showSnackBar("Uploading session data to cloud...");
      await _uploadSessionToCloud();

      _completedSessions++;
      if (_completedSessions < _totalSessions) {
        _isWorking = false;
        _secondsRemaining = _breakMinutes * 60;
        _showSnackBar("Data Saved! Planet Core Charged! Time for a break.");
      } else {
        _showCongratsDialog();
        _resetTimer();
        return;
      }
    } else {
      _isWorking = true;
      _secondsRemaining = _workMinutes * 60;
      _currentSessionHistory.clear();
      _showSnackBar("Break over. Back to charging the core!");
    }
    _updateCoreNarrativeExperience();
  }

  void _resetTimer() {
    _timer?.cancel();
    _stopMonitoring();
    setState(() {
      _isWorking = true;
      _secondsRemaining = _workMinutes * 60;
      _completedSessions = 0;
      _isRunning = false;
      _currentSessionHistory.clear();
    });
    _updateCoreNarrativeExperience();
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatTime(int sec) {
    return "${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopMonitoring();
    _breathingController.dispose();
    _rotationController.dispose();
    _warningFlickerController.dispose();
    super.dispose();
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E3C72),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Focus Settings",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSettingRow("Work Time (min)", _workMinutes, (val) {
                    setModalState(() => _workMinutes = val);
                    setState(() {
                      _workMinutes = val;
                      if (!_isRunning && _isWorking)
                        _secondsRemaining = _workMinutes * 60;
                    });
                  }),
                  _buildSettingRow("Break Time (min)", _breakMinutes, (val) {
                    setModalState(() => _breakMinutes = val);
                    setState(() {
                      _breakMinutes = val;
                      if (!_isRunning && !_isWorking)
                        _secondsRemaining = _breakMinutes * 60;
                    });
                  }),
                  _buildSettingRow("Total Sessions", _totalSessions, (val) {
                    setModalState(() => _totalSessions = val);
                    setState(() => _totalSessions = val);
                  }),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingRow(String label, int value, Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.cyanAccent,
                ),
                onPressed: () => onChanged(math.max(1, value - 1)),
              ),
              SizedBox(
                width: 30,
                child: Center(
                  child: Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.cyanAccent,
                ),
                onPressed: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double total = _isWorking ? _workMinutes * 60 : _breakMinutes * 60;
    double progress = total > 0 ? (_secondsRemaining / total) : 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.settings, color: Colors.white70),
          tooltip: "Adjust Times",
          onPressed: _showSettingsSheet,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync, color: Colors.cyanAccent),
            tooltip: "View Cloud History",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CloudHistoryPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(seconds: 2),
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _getNarrativeMainColor().withOpacity(
                            _isEnvWarning ? 0.2 : 0.08,
                          ),
                          blurRadius: 100,
                          spreadRadius: _isEnvWarning ? 10 : 0,
                        ),
                      ],
                    ),
                  ),
                  ScaleTransition(
                    scale: _breathingAnimation,
                    child: RotationTransition(
                      turns: _rotationController,
                      child: Container(
                        width: 280,
                        height: 280,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: CustomPaint(
                          painter: FocusPlanetCorePainter(
                            progress: progress,
                            mainColor: _getNarrativeMainColor(),
                            state: _currentCoreState,
                            warningFlickerValue:
                                _warningFlickerController.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getNarrativeStatusText(),
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 3,
                          color: Colors.white60,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatTime(_secondsRemaining),
                        style: const TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w100,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "SESSION $_completedSessions / $_totalSessions",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            _buildRealTimeSensors(),
            const SizedBox(height: 30),

            _buildControlButtons(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeSensors() {
    bool lightWarning = _luxValue < MIN_LUX && _isWorking && _isRunning;
    bool noiseWarning = _dbValue > MAX_DB && _isWorking && _isRunning;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _sensorBadge(Icons.light_mode, "${_luxValue.toInt()} lx", lightWarning),
        const SizedBox(width: 20),
        _sensorBadge(Icons.volume_up, "${_dbValue.toInt()} dB", noiseWarning),
      ],
    );
  }

  Widget _sensorBadge(IconData icon, String value, bool isWarning) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isWarning
            ? Colors.redAccent.withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWarning
              ? Colors.redAccent.withOpacity(0.8)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isWarning ? Colors.redAccent : Colors.cyanAccent,
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isWarning ? Colors.redAccent : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Color _getNarrativeMainColor() {
    switch (_currentCoreState) {
      case FocusCoreState.workOptimal:
        return Colors.cyanAccent;
      case FocusCoreState.workSuboptimal:
        return Colors.redAccent;
      case FocusCoreState.breakNormal:
        return Colors.orangeAccent;
    }
  }

  String _getNarrativeStatusText() {
    switch (_currentCoreState) {
      case FocusCoreState.workOptimal:
        return "CHARGING PLANET";
      case FocusCoreState.workSuboptimal:
        return "ENERGY CRISIS!";
      case FocusCoreState.breakNormal:
        return "CORE STABLE (REST)";
    }
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionBtn(
          _toggleTimer,
          _isRunning ? Icons.pause : Icons.play_arrow,
          _isRunning ? Colors.white : Colors.cyanAccent,
        ),
        const SizedBox(width: 40),
        _actionBtn(_resetTimer, Icons.refresh, Colors.white38),
      ],
    );
  }

  Widget _actionBtn(VoidCallback onTap, IconData icon, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }
}

class FocusPlanetCorePainter extends CustomPainter {
  final double progress;
  final Color mainColor;
  final FocusCoreState state;
  final double warningFlickerValue;

  FocusPlanetCorePainter({
    required this.progress,
    required this.mainColor,
    required this.state,
    required this.warningFlickerValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final Paint trackPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, trackPaint);

    final double sweepAngle = 2 * math.pi * progress;
    final double startAngle = -math.pi / 2;

    final Paint progressPaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    if (state == FocusCoreState.workSuboptimal) {
      progressPaint.color = Colors.redAccent.withOpacity(
        0.5 + 0.5 * warningFlickerValue,
      );
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    final double coreX = center.dx + radius * math.cos(startAngle + sweepAngle);
    final double coreY = center.dy + radius * math.sin(startAngle + sweepAngle);

    final Paint corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint coreGlowPaint = Paint()
      ..color = mainColor.withOpacity(
        state == FocusCoreState.workSuboptimal ? 0.8 : 0.4,
      )
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        state == FocusCoreState.workSuboptimal ? 15 : 6,
      );

    canvas.drawCircle(Offset(coreX, coreY), 15, coreGlowPaint);
    canvas.drawCircle(Offset(coreX, coreY), 8, corePaint);
  }

  @override
  bool shouldRepaint(covariant FocusPlanetCorePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.state != state ||
        (state == FocusCoreState.workSuboptimal &&
            oldDelegate.warningFlickerValue != warningFlickerValue);
  }
}

class SensorHistoryPage extends StatelessWidget {
  final List<EnvRecord> historyData;
  final double minLux;
  final double maxDb;

  SensorHistoryPage({
    required this.historyData,
    required this.minLux,
    required this.maxDb,
  });

  @override
  Widget build(BuildContext context) {
    int optimalCount = historyData.where((data) => data.isOptimal).length;
    double optimalPercentage = historyData.isEmpty
        ? 0
        : (optimalCount / historyData.length) * 100;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Session Detail Chart"),
        backgroundColor: const Color(0xFF1E3C72),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 80,
                        width: 80,
                        child: CircularProgressIndicator(
                          value: optimalPercentage / 100,
                          backgroundColor: Colors.white10,
                          color: Colors.cyanAccent,
                          strokeWidth: 8,
                        ),
                      ),
                      Text(
                        "${optimalPercentage.toStringAsFixed(1)}%",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Stable Energy Flow",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyanAccent,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          "Time spent in healthy light and noise levels.",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Light History (Lux)",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: LineChart(_buildChartData(true)),
            ),
            const SizedBox(height: 30),
            const Text(
              "Noise History (dB)",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: LineChart(_buildChartData(false)),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChartData(bool isLight) {
    if (historyData.isEmpty) return LineChartData();
    List<FlSpot> spots = historyData
        .map((d) => FlSpot(d.second.toDouble(), isLight ? d.lux : d.db))
        .toList();
    Color chartColor = isLight ? Colors.yellowAccent : Colors.blueAccent;
    double limit = isLight ? minLux : maxDb;

    return LineChartData(
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 22),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: chartColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: chartColor.withOpacity(0.2),
          ),
        ),
      ],
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: limit,
            color: Colors.redAccent,
            strokeWidth: 1,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              labelResolver: (line) => isLight ? 'Min 300' : 'Max 60',
            ),
          ),
        ],
      ),
    );
  }
}

class CloudHistoryPage extends StatelessWidget {
  Future<void> _clearAllHistory(BuildContext context) async {
    try {
      var collection = FirebaseFirestore.instance.collection('focus_sessions');
      var snapshots = await collection.get();
      for (var doc in snapshots.docs) {
        await doc.reference.delete();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All cloud history cleared!"),
            backgroundColor: Colors.cyanAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error clearing history: $e");
    }
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3C72),
        title: const Text(
          "Clear History?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "This will permanently delete all your focus sessions from the cloud. Are you sure?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "CANCEL",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllHistory(context);
            },
            child: const Text(
              "CLEAR ALL",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Cloud Session History"),
        backgroundColor: const Color(0xFF1E3C72),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: "Clear All History",
            onPressed: () => _showClearConfirmDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('focus_sessions')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            );
          if (snapshot.hasError)
            return Center(
              child: Text(
                "Error fetching data: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No cloud records yet. Finish a session to upload!",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          final sessions = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              var data = sessions[index].data() as Map<String, dynamic>;
              double optimalPct = data['optimalPercentage'] ?? 0.0;
              double avgLux = data['avgLux'] ?? 0.0;
              double avgDb = data['avgDb'] ?? 0.0;
              int duration = data['durationMinutes'] ?? 0;

              String timeString = "Unknown Time";
              if (data['timestamp'] != null) {
                DateTime dt = (data['timestamp'] as Timestamp).toDate();
                timeString =
                    "${dt.month}/${dt.day}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
              }

              Color scoreColor = optimalPct > 80
                  ? Colors.cyanAccent
                  : (optimalPct > 50 ? Colors.orangeAccent : Colors.redAccent);

              return GestureDetector(
                onTap: () {
                  if (data['rawHistory'] != null) {
                    List<dynamic> rawList = data['rawHistory'];
                    List<EnvRecord> historyList = rawList
                        .map(
                          (e) => EnvRecord(
                            second: e['second'] ?? 0,
                            lux: (e['lux'] ?? 0).toDouble(),
                            db: (e['db'] ?? 0).toDouble(),
                            isOptimal: e['isOptimal'] ?? false,
                          ),
                        )
                        .toList();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SensorHistoryPage(
                          historyData: historyList,
                          minLux: MIN_LUX,
                          maxDb: MAX_DB,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "No detailed chart data available for this older session.",
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 60,
                            width: 60,
                            child: CircularProgressIndicator(
                              value: optimalPct / 100,
                              backgroundColor: Colors.white10,
                              color: scoreColor,
                              strokeWidth: 6,
                            ),
                          ),
                          Text(
                            "${optimalPct.toInt()}%",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "$duration Min Session",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  timeString,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.light_mode,
                                  size: 14,
                                  color: Colors.yellowAccent.withOpacity(0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Avg ${avgLux.toInt()} lx",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Icon(
                                  Icons.volume_up,
                                  size: 14,
                                  color: Colors.blueAccent.withOpacity(0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Avg ${avgDb.toInt()} dB",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white38),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
