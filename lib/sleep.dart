import 'dart:async';

/// sleep util
Future sleep(int milliseconds, [FutureOr Function()? computation]) {
  return Future.delayed(Duration(milliseconds: milliseconds), computation);
}
