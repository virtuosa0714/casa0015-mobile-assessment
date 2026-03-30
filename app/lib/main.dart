import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:light/light.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A), // 星空背景色
      ),
      home: SplashScreen(),
    ),
  );
}

// ==========================================
// 数据模型与状态枚举
// ==========================================
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

enum FocusCoreState {
  workOptimal, // 工作中：环境健康（充能成功）
  workSuboptimal, // 工作中：环境恶劣（能量危机！）
  breakNormal, // 休息中（稳定状态）
}

// ==========================================
// 1. 启动引导页 (Splash Screen)
// ==========================================
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
            Icon(Icons.public, size: 80, color: Colors.cyanAccent), // 贴合星球主题
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

// ==========================================
// 2. 主界面 (Pomodoro UI)
// ==========================================
class PomodoroUI extends StatefulWidget {
  @override
  _PomodoroUIState createState() => _PomodoroUIState();
}

class _PomodoroUIState extends State<PomodoroUI> with TickerProviderStateMixin {
  // --- 基础配置 ---
  int _workMinutes = 25;
  int _breakMinutes = 5;
  int _totalSessions = 4;
  int _completedSessions = 0;

  late int _secondsRemaining;
  bool _isWorking = true;
  bool _isRunning = false;
  Timer? _timer;

  // --- 传感器监测 ---
  double _luxValue = 0;
  double _dbValue = 0;
  int _violationSeconds = 0;
  bool _isEnvWarning = false;
  static const double MIN_LUX = 300.0;
  static const double MAX_DB = 60.0;

  StreamSubscription? _lightSubscription;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  NoiseMeter? _noiseMeter;

  // --- 历史数据存储 ---
  List<EnvRecord> _currentSessionHistory = [];

  // --- 动画控制器 ---
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  late AnimationController _rotationController;
  late AnimationController _warningFlickerController;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = _workMinutes * 60;

    // 呼吸动画
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

    // 旋转与闪烁动画
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _warningFlickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  // --- 叙事状态机 ---
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

  // --- 核心功能方法 ---
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

    // 记录历史数据
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
        _showSnackBar(
          "⚠️ Environmental Energy Crisis! High noise or low light.",
        );
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

  void _handleSessionEnd() {
    _timer?.cancel();
    _stopMonitoring();
    setState(() => _isRunning = false);

    if (_isWorking) {
      _completedSessions++;
      if (_completedSessions < _totalSessions) {
        _isWorking = false;
        _secondsRemaining = _breakMinutes * 60;
        _showSnackBar("Planet Core Charged! Time for a break.");
      } else {
        _showSnackBar("Goal Achieved! Core fully powered!");
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

  // --- UI 构建 ---
  @override
  Widget build(BuildContext context) {
    double total = _isWorking ? _workMinutes * 60 : _breakMinutes * 60;
    double progress = total > 0 ? (_secondsRemaining / total) : 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics, color: Colors.cyanAccent),
            tooltip: "View Session History",
            onPressed: () {
              if (_currentSessionHistory.isEmpty) {
                _showSnackBar("No data collected yet. Start focusing!");
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SensorHistoryPage(
                    historyData: _currentSessionHistory,
                    minLux: MIN_LUX,
                    maxDb: MAX_DB,
                  ),
                ),
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
                    ],
                  ),
                ],
              ),
            ),
            _buildControlButtons(),
            const SizedBox(height: 30),
          ],
        ),
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

// ==========================================
// 3. 高级自定义绘图 (CustomPainter)
// ==========================================
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

// ==========================================
// 4. 传感器历史数据页面
// ==========================================
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
    double optimalPercentage = (optimalCount / historyData.length) * 100;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Core Charge History"),
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
