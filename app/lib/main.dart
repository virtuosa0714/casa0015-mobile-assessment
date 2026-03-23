import 'package:flutter/material.dart';
import 'dart:async';
import 'package:light/light.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: PomodoroUI(),
    ),
  );
}

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

  static const double MIN_LUX = 300.0; // Recommended min light for studying
  static const double MAX_DB = 60.0; // Recommended max noise for focusing

  StreamSubscription? _lightSubscription;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  NoiseMeter? _noiseMeter;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = _workMinutes * 60;
  }

  // --- Environment Logic ---
  Future<void> _startMonitoring() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      _lightSubscription = Light().lightSensorStream.listen((lux) {
        setState(() => _luxValue = lux.toDouble());
      });

      _noiseMeter = NoiseMeter();
      _noiseSubscription = _noiseMeter?.noise.listen((reading) {
        setState(() => _dbValue = reading.meanDecibel);
      });
    }
  }

  void _stopMonitoring() {
    _lightSubscription?.cancel();
    _noiseSubscription?.cancel();
    _violationSeconds = 0;
    _isEnvWarning = false;
    setState(() {
      _luxValue = 0;
      _dbValue = 0;
    });
  }

  void _checkEnvironment() {
    // Only check during work sessions
    if (!_isWorking) {
      _isEnvWarning = false;
      _violationSeconds = 0;
      return;
    }

    bool badLight = _luxValue < MIN_LUX;
    bool badNoise = _dbValue > MAX_DB;

    if (badLight || badNoise) {
      _violationSeconds++;
      // Trigger warning after 3 consecutive seconds of poor environment
      if (_violationSeconds >= 3) {
        if (!_isEnvWarning) {
          _isEnvWarning = true;
          _showSnackBar("⚠️ Environment Poor: Focus may be affected!");
        }
      }
    } else {
      // Reset if environment becomes good
      _violationSeconds = 0;
      _isEnvWarning = false;
    }
  }

  // --- Timer Controls ---
  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      _stopMonitoring();
    } else {
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
            _checkEnvironment();
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
    });
  }

  // --- UI Components ---
  @override
  Widget build(BuildContext context) {
    int total = _isWorking ? _workMinutes * 60 : _breakMinutes * 60;
    double progress = _secondsRemaining / total;

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSettings(),

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
                  _buildProgressDots(),
                  SizedBox(height: 50),
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

  Widget _buildTopSettings() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          _settingRow(
            "Rounds",
            "$_totalSessions",
            (d) => setState(
              () => _totalSessions = (_totalSessions + d).clamp(1, 10),
            ),
          ),
          _settingRow("Work Min", "$_workMinutes", (d) => _adjustTime(true, d)),
          _settingRow(
            "Break Min",
            "$_breakMinutes",
            (d) => _adjustTime(false, d),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(String label, String value, Function(int) onStep) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white54)),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.remove, size: 20),
              onPressed: _isRunning ? null : () => onStep(-1),
            ),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.add, size: 20),
              onPressed: _isRunning ? null : () => onStep(1),
            ),
          ],
        ),
      ],
    );
  }

  void _adjustTime(bool isWork, int delta) {
    setState(() {
      if (isWork) {
        _workMinutes = (_workMinutes + delta).clamp(1, 60);
        if (_isWorking) _secondsRemaining = _workMinutes * 60;
      } else {
        _breakMinutes = (_breakMinutes + delta).clamp(1, 30);
        if (!_isWorking) _secondsRemaining = _breakMinutes * 60;
      }
    });
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _totalSessions,
        (i) => Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < _completedSessions ? Colors.tealAccent : Colors.white10,
          ),
        ),
      ),
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

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
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
