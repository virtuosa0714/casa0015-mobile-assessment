import 'package:flutter/material.dart';
import 'dart:async';
import 'package:light/light.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart'; // 新增图表库

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF121212),
      ),
      // 将首页改为启动引导页
      home: SplashScreen(),
    ),
  );
}

// ==========================================
// 数据模型：用于存储每秒的环境数据
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
    // 2.5秒后跳转到主界面
    Timer(Duration(milliseconds: 2500), () {
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF121212), Color(0xFF1E3C72)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 80, color: Colors.tealAccent),
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
            CircularProgressIndicator(color: Colors.tealAccent),
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

class _PomodoroUIState extends State<PomodoroUI> {
  // --- Configuration ---
  int _workMinutes = 25;
  int _breakMinutes = 5;
  int _totalSessions = 4;
  int _completedSessions = 0;

  late int _secondsRemaining;
  bool _isWorking = true;
  bool _isRunning = false;
  Timer? _timer;

  // --- Environment Monitoring & Thresholds ---
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

  @override
  void initState() {
    super.initState();
    _secondsRemaining = _workMinutes * 60;
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
    _isEnvWarning = false;
    if (mounted) {
      setState(() {
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

    // 警告逻辑
    if (badLight || badNoise) {
      _violationSeconds++;
      if (_violationSeconds >= 3) {
        if (!_isEnvWarning) {
          _isEnvWarning = true;
          _showSnackBar("⚠️ Environment Poor: Focus may be affected!");
        }
      }
    } else {
      _violationSeconds = 0;
      _isEnvWarning = false;
    }
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      _stopMonitoring();
    } else {
      // 每次重新开始专注时，清空历史记录（如果您希望暂停后继续，可以去掉这一行）
      if (_secondsRemaining == _workMinutes * 60 && _isWorking) {
        _currentSessionHistory.clear();
      }

      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
            _checkAndRecordEnvironment(); // 更新并记录
          } else {
            _handleSessionEnd();
          }
        });
      });
      _startMonitoring().catchError((e) => debugPrint("Sensor Error: $e"));
    }
    setState(() => _isRunning = !_isRunning);
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
        _showSnackBar("Great job! Time for a break.");
      } else {
        _showSnackBar("Goal Achieved! You're amazing!");
        _resetTimer();
        return;
      }
    } else {
      _isWorking = true;
      _secondsRemaining = _workMinutes * 60;
      _currentSessionHistory.clear(); // 新专注周期清空记录
      _showSnackBar("Break over. Back to focus!");
    }
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
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // ... [此处保留您原有的 UI Components，如 _buildTopSettings, _settingRow, _adjustTime 等] ...

  // 为了缩短代码长度，这里省略了您之前写过的 _buildTopSettings 等无需改动的辅助 UI 方法，
  // 我们重点修改 build 方法以加入“查看历史”按钮

  @override
  Widget build(BuildContext context) {
    int total = _isWorking ? _workMinutes * 60 : _breakMinutes * 60;
    double progress = _secondsRemaining / total;

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 查看历史数据按钮
          IconButton(
            icon: Icon(Icons.analytics, color: Colors.tealAccent),
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
            // Persistent Warning Banner
            if (_isEnvWarning)
              Container(
                width: double.infinity,
                color: Colors.redAccent,
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "SUBOPTIMAL ENVIRONMENT DETECTED",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),

            if (_isRunning) _buildEnvPanel(),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isWorking ? "FOCUSING" : "RESTING",
                    style: TextStyle(
                      fontSize: 18,
                      letterSpacing: 5,
                      color: _isEnvWarning
                          ? Colors.redAccent
                          : (_isWorking
                                ? Colors.tealAccent
                                : Colors.orangeAccent),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 30),
                  _buildCircularTimer(progress),
                  SizedBox(height: 40),
                  _buildControlButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvPanel() {
    bool lightAlert = _luxValue < MIN_LUX;
    bool noiseAlert = _dbValue > MAX_DB;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      padding: EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: _isEnvWarning
            ? Colors.red.withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: _isEnvWarning
            ? Border.all(color: Colors.redAccent.withOpacity(0.5))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _envInfo(
            Icons.light_mode,
            "${_luxValue.toInt()} lx",
            "Min 300",
            lightAlert,
          ),
          _envInfo(
            Icons.volume_up,
            "${_dbValue.toInt()} dB",
            "Max 60",
            noiseAlert,
          ),
        ],
      ),
    );
  }

  Widget _envInfo(IconData icon, String value, String label, bool isBad) {
    return Column(
      children: [
        Icon(icon, size: 18, color: isBad ? Colors.redAccent : Colors.white38),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isBad ? Colors.redAccent : Colors.white,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white24)),
      ],
    );
  }

  Widget _buildCircularTimer(double progress) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 260,
          height: 260,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(
              _isEnvWarning
                  ? Colors.redAccent
                  : (_isWorking ? Colors.tealAccent : Colors.orangeAccent),
            ),
          ),
        ),
        Text(
          _formatTime(_secondsRemaining),
          style: TextStyle(fontSize: 64, fontWeight: FontWeight.w100),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionBtn(
          _toggleTimer,
          _isRunning ? Icons.pause : Icons.play_arrow,
          _isRunning ? Colors.white : Colors.tealAccent,
        ),
        SizedBox(width: 40),
        _actionBtn(_resetTimer, Icons.refresh, Colors.white38),
      ],
    );
  }

  Widget _actionBtn(VoidCallback onTap, IconData icon, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Icon(icon, color: color, size: 32),
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
    super.dispose();
  }
}

// ==========================================
// 3. 传感器历史数据页面 (Sensor History Page)
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
    // 计算适合学习的比例
    int optimalCount = historyData.where((data) => data.isOptimal).length;
    double optimalPercentage = (optimalCount / historyData.length) * 100;

    return Scaffold(
      appBar: AppBar(
        title: Text("Session History"),
        backgroundColor: Color(0xFF1E3C72),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 比例统计卡片
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
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
                          color: Colors.tealAccent,
                          strokeWidth: 8,
                        ),
                      ),
                      Text(
                        "${optimalPercentage.toStringAsFixed(1)}%",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Optimal Study Time",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.tealAccent,
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
            SizedBox(height: 30),

            // 亮度折线图
            Text(
              "Light History (Lux)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Container(
              height: 200,
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: LineChart(_buildLightChart()),
            ),
            SizedBox(height: 30),

            // 噪音折线图
            Text(
              "Noise History (dB)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Container(
              height: 200,
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: LineChart(_buildNoiseChart()),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildLightChart() {
    List<FlSpot> spots = historyData
        .map((d) => FlSpot(d.second.toDouble(), d.lux))
        .toList();

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
          color: Colors.yellowAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.yellowAccent.withOpacity(0.2),
          ),
        ),
      ],
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: minLux,
            color: Colors.redAccent,
            strokeWidth: 1,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              labelResolver: (line) => 'Min 300',
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildNoiseChart() {
    List<FlSpot> spots = historyData
        .map((d) => FlSpot(d.second.toDouble(), d.db))
        .toList();

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
          color: Colors.blueAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.blueAccent.withOpacity(0.2),
          ),
        ),
      ],
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: maxDb,
            color: Colors.redAccent,
            strokeWidth: 1,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              labelResolver: (line) => 'Max 60',
            ),
          ),
        ],
      ),
    );
  }
}
