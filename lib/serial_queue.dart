library serial_queue;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:serial_queue/sleep.dart';

class SerialQueue<T extends _Task> {
  ///
  ///
  SerialQueue({this.log = false});

  bool log = false;

  ///
  final List<T> _task = [];

  ///
  Completer? _sleepCompleter;

  Completer? get sleepCompleter => _sleepCompleter;

  ///
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;
  final _disposeCompleter = Completer<void>();

  ///
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  ///
  void startQueue() async {
    if (_isRunning) {
      return;
    }
    _isRunning = true;
    for (;;) {
      if (_isDisposed) {
        for (var t in _task) {
          if (!t.isCompleted) {
            t._aborted();
          }
        }
        break;
      }
      if (_task.isEmpty) {
        if (_sleepCompleter == null && !_isDisposed) {
          _sleepCompleter = Completer<void>();
          await sleep(10);
          if (_isDisposed) {
            continue;
          }
          if (_task.isNotEmpty) {
            try {
              if (!(_sleepCompleter?.isCompleted ?? true)) {
                _sleepCompleter?.complete();
              }
            } catch (_) {}
            _sleepCompleter = null;
            continue;
          }
        }
        await _sleepCompleter?.future;
        _sleepCompleter = null;
        if(log){
          if (kDebugMode) {
            print('The queue is woken up and starts working');
          }
        }
      } else {
        _Task t = _task.removeAt(0);
        await t._do();
        await sleep(1);
      }
    }
    _disposeCompleter.complete();
    if(log){
      if (kDebugMode) {
        print('queue is closed');
      }
    }
  }

  ///
  void addTask(T task) {
    try {
      _task.add(task);
      if (!(sleepCompleter?.isCompleted ?? true)) {
        sleepCompleter?.complete();
      }
    } catch (_) {}
  }

  ///
  void addTaskToFirst(T task) {
    try {
      _task.insert(0, task);
      if (!(sleepCompleter?.isCompleted ?? true)) {
        sleepCompleter?.complete();
      }
    } catch (_) {}
  }

  ///
  Future<void> dispose([FutureOr<void> Function()? disposeTask]) async {
    _isDisposed = true;
    sleepCompleter?.complete();
    await _disposeCompleter.future;
    await disposeTask?.call();
  }
}

/// 实际任务处理类
/// 泛型R:返回数据类型
/// 泛型P:参数类型，可以是int、double、bool、String、map、list、dynamic、Object
class _Task<R, P> {
  ///
  ///
  ///
  _Task({
    required this.taskHandler,
    this.params,
  });

  /// 任务处理函数
  late HandleFunc<R, P> taskHandler;

  /// 任务处理函数参数
  P? params;

  final Completer<R> _completer = Completer<R>();

  Future<R> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  /// 队列中断
  void _aborted() {
    _completer.completeError('Queue aborted');
  }

  /// 供队列调度使用,
  Future<void> _do() async {
    try {
      var r = await taskHandler.call(params: params);
      _completer.complete(r);
    } catch (_) {
      _completer.completeError('Task exception');
    }
  }
}

///
typedef HandleFunc<R, P> = FutureOr<R> Function({P? params});

/// R:返回数据类型
/// P:参数类型，可以是null、int、double、bool、String、map、list、dynamic、Object
/// defaultReturn: 任务加入队列后，未执行，队列提前结束，任务异常中断的默认返回值
class Task<R, P> extends _Task<R, P> {
  ///
  ///
  Task.create({
    required HandleFunc<R, P> taskHandler,
    P? params,
  }) : super(taskHandler: taskHandler, params: params);
}

