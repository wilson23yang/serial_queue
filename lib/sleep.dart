import 'dart:async';

Future sleep(int milliseconds, [FutureOr Function()? computation]){
  return Future.delayed(Duration(milliseconds: milliseconds), computation);
}