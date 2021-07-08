import 'dart:async';
import 'dart:isolate';

abstract class TaskRunner {
  SendPort? _enqueuePort;
  final List<TaskMessage> _pendingTaskList = [];
  bool _isRunning = false;
  bool _isDisposed = false;
  Isolate? _isol;

  static runnerFunc(SendPort onComplete, {required dynamic Function(TaskMessage msg) processMessage}) {
    final recvPort = ReceivePort();

    recvPort.listen((rawMessage) async {
      final msg = rawMessage as TaskMessage;
      if (msg.onComplete != null) {
        final res = await processMessage(msg);
        msg.resolve(res);
      }else{
        await processMessage(msg);
      }
    });
    scheduleMicrotask(() {
      onComplete.send(recvPort.sendPort);
    });
  }

  setup({required Function(SetupMessage message) initIsolate, Object? setupArgs}) async {
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

    final setupMgs = SetupMessage(initPort.sendPort, setupArgs);

    final errPort = ReceivePort();
    final exitPort = ReceivePort();

    errPort.listen((message) {
      print(message);
    });

    exitPort.listen((message) {
      errPort.close();
      dispose();
    });

    _isol = await Isolate.spawn(initIsolate, setupMgs,
        errorsAreFatal: false, onError: errPort.sendPort, onExit: exitPort.sendPort);
    if (_isDisposed) {
      _isol?.kill(priority: Isolate.immediate);
      _isol = null;
    }
  }

  _enqueue(TaskMessage msg) {
    if (_isDisposed) {
      return;
    }
    final p = _enqueuePort;
    if (p == null) {
      _pendingTaskList.add(msg);
    } else {
      p.send(msg);
    }
  }

  // send a message to the isolate without requiring for a reply
  emit(String type, {Object? args}) {
    _enqueue(TaskMessage(type, args: args));
  }

  // send a message to the isolate and wait until we get a reply back
  Future<dynamic> exec(String type, {Object? args}) {
    if (_isDisposed) {
      return Future.error(Exception("task runner is disposed"));
    }
    final c = ReceivePort();
    _enqueue(TaskMessage(type, args: args, onComplete: c.sendPort));
    return c.first;
  }

  bool dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _isol?.kill(priority: Isolate.immediate);
      _isol = null;
      return true;
    }
    return false;
  }
}

class TaskMessage {
  final String type;
  final SendPort? onComplete;
  final Object? args;

  const TaskMessage(this.type, {this.args, this.onComplete});

  resolve(Object args) {
    this.onComplete?.send(args);
  }
}

class SetupMessage {
  final SendPort onComplete;
  final Object? args;

  const SetupMessage(this.onComplete, this.args);
}
