import 'dart:async';
import 'dart:isolate';

abstract class TaskRunner {
  SendPort? _enqueuePort;
  final List<TaskMessage> _pendingTaskList = [];
  bool _isRunning = false;
  bool _isDisposed = false;
  Isolate? _isol;

  static runnerFunc(SendPort initPort,
      {required dynamic Function(TaskMessage msg) onMessage}) {
    final recvPort = ReceivePort();

    recvPort.listen((rawMessage) async {
      final msg = rawMessage as TaskMessage;
      final res = await onMessage(msg);
      msg.resolve(res);
    });

    initPort.send(recvPort.sendPort);
  }

  _run() async {
    if (_isRunning || _isDisposed) {
      return;
    }
    _isRunning = true;

    ReceivePort initPort = ReceivePort();

    initPort.listen((message) {
      initPort.close();
      final enqueueTaskPort = message as SendPort;

      while (_pendingTaskList.isNotEmpty) {
        final msg = _pendingTaskList.removeAt(0);
        enqueueTaskPort.send(msg);
      }

      this._enqueuePort = enqueueTaskPort;
    });

    _isol = await Isolate.spawn(getRunnerFunc(), initPort.sendPort);
    if (_isDisposed) {
      _isol?.kill(priority: Isolate.immediate);
      _isol = null;
    }
  }

  Function(SendPort initPort) getRunnerFunc();

  _enqueue(TaskMessage msg) {
    if (_isDisposed) {
      return;
    }
    _run();
    final p = _enqueuePort;
    if (p == null) {
      _pendingTaskList.add(msg);
    } else {
      p.send(msg);
    }
  }

  dispose() {
    _isDisposed = true;
    _isol?.kill(priority: Isolate.immediate);
    _isol = null;
  }

  Future<dynamic> exec(String type) {
    if (_isDisposed) {
      return Future.error(Exception("task runner is disposed"));
    }
    final c = ReceivePort();
    _enqueue(TaskMessage(type, c.sendPort));
    return c.first;
  }
}

class TestTaskRunner extends TaskRunner {
  static x() {
    final runner = TestTaskRunner();
    int counter = 0;
    Stream.periodic(Duration(seconds: 4), (x) {}).listen((event) async {
      final res = await runner.exec("type $counter");
      print("DONE $res");
      counter += 1;
    });
  }

  static _exec(SendPort initPort) {
    TaskRunner.runnerFunc(
      initPort,
      onMessage: (msg) async {
        print("processing ${msg.type}");
        await Future.delayed(Duration(seconds: 1));
        return "xxxxxx ${msg.type}";
      },
    );
  }

  @override
  Function(SendPort initPort) getRunnerFunc() {
    return _exec;
  }
}

class TaskMessage {
  final String type;
  final SendPort onComplete;
  final Object? args;

  const TaskMessage(this.type, this.onComplete, {this.args});

  resolve(Object args) {
    this.onComplete.send(args);
  }
}
