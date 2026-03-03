import 'package:flutter/material.dart';
import 'dart:async';

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
  // 配置常量
  static const int workSeconds = 25 * 60; // 工作25分钟
  static const int breakSeconds = 5 * 60; // 休息5分钟

  // 状态变量
  int _totalSessions = 4; // 默认目标番茄数
  int _completedSessions = 0; // 已完成番茄数
  int _secondsRemaining = workSeconds;
  bool _isWorking = true; // 当前是工作还是休息
  bool _isRunning = false;
  Timer? _timer;

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _handleSessionEnd();
          }
        });
      });
    }
    setState(() => _isRunning = !_isRunning);
  }

  void _handleSessionEnd() {
    _timer?.cancel();
    setState(() => _isRunning = false);

    String message = "";
    if (_isWorking) {
      _completedSessions++;
      if (_completedSessions < _totalSessions) {
        _isWorking = false;
        _secondsRemaining = breakSeconds;
        message = "Well done! Take a break now.";
      } else {
        message = "Congratulations! You've completed all your goals!";
        _resetTimer();
        // 提前 return 防止显示两次提示
        Future.delayed(Duration.zero, () => _showSnackBar(message));
        return;
      }
    } else {
      _isWorking = true;
      _secondsRemaining = workSeconds;
      message = "Break finished, let's get back to work.";
    }

    // 使用 Future.delayed 确保在下一帧显示 SnackBar，避开上下文冲突
    Future.delayed(Duration.zero, () => _showSnackBar(message));
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = workSeconds;
      _completedSessions = 0;
      _isWorking = true;
      _isRunning = false;
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return; // 如果组件已经销毁，就不执行

    ScaffoldMessenger.of(context).clearSnackBars(); // 清除之前的提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating, // 悬浮样式在 Web 端更稳定
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 计算当前进度
    int total = _isWorking ? workSeconds : breakSeconds;
    double progress = (_secondsRemaining) / total;

    return Scaffold(
      backgroundColor: Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 40),
            // 1. 目标设置区域
            _buildSessionSetter(),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 状态标签
                  Text(
                    _isWorking ? "In concentration" : "On break",
                    style: TextStyle(
                      fontSize: 24,
                      color: _isWorking
                          ? Colors.tealAccent
                          : Colors.orangeAccent,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 30),

                  // 2. 倒计时圆环
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 260,
                        height: 260,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 10,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isWorking
                                ? Colors.tealAccent
                                : Colors.orangeAccent,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(_secondsRemaining),
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w200,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 40),
                  // 3. 进度指示（小圆点）
                  _buildProgressDots(),

                  SizedBox(height: 60),
                  // 4. 控制按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildActionButton(
                        onTap: _toggleTimer,
                        icon: _isRunning ? Icons.pause : Icons.play_arrow,
                        color: _isRunning ? Colors.white : Colors.tealAccent,
                      ),
                      SizedBox(width: 40),
                      _buildActionButton(
                        onTap: _resetTimer,
                        icon: Icons.refresh,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建顶部轮次选择器
  Widget _buildSessionSetter() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Target Round:", style: TextStyle(color: Colors.white70)),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove_circle_outline),
                onPressed: _isRunning
                    ? null
                    : () {
                        if (_totalSessions > 1)
                          setState(() => _totalSessions--);
                      },
              ),
              Text(
                "$_totalSessions",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline),
                onPressed: _isRunning
                    ? null
                    : () {
                        if (_totalSessions < 10)
                          setState(() => _totalSessions++);
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建底部的进度圆点
  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalSessions, (index) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 5),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < _completedSessions
                ? Colors.tealAccent
                : Colors.white10,
            border: Border.all(color: Colors.white24),
          ),
        );
      }),
    );
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Icon(icon, color: color, size: 36),
      ),
    );
  }
}
