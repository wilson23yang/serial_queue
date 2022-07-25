import 'package:flutter_test/flutter_test.dart';
import 'package:serial_queue/serial_queue.dart';
import 'package:serial_queue/sleep.dart';

/// 100个人在5台atm机上存钱
void main() async {
  bool useQueue = false;
  Bank bank = Bank(name: 'ABC', useQueue: useQueue);

  var team1 = bank.persons.sublist(0, 20);
  var team2 = bank.persons.sublist(20, 40);
  var team3 = bank.persons.sublist(40, 60);
  var team4 = bank.persons.sublist(60, 80);
  var team5 = bank.persons.sublist(80, 100);

  Future.delayed(const Duration(), () async {
    for (var person in team1) {
      await bank.atms[0]?.deposit(person!.accountNo, 100);
      await sleep(30);
    }
  });
  Future.delayed(const Duration(), () async {
    for (var person in team2) {
      await bank.atms[1]?.deposit(person!.accountNo, 100);
      await sleep(2);
    }
  });
  Future.delayed(const Duration(), () async {
    for (var person in team3) {
      await bank.atms[2]?.deposit(person!.accountNo, 100);
      await sleep(2);
    }
  });
  Future.delayed(const Duration(), () async {
    for (var person in team4) {
      await bank.atms[3]?.deposit(person!.accountNo, 100);
      await sleep(2);
    }
  });
  Future.delayed(const Duration(), () async {
    for (var person in team5) {
      await bank.atms[4]?.deposit(person!.accountNo, 100);
      await sleep(2);
    }
  });
  // Future.delayed(const Duration(milliseconds: 200), () async {
  //   bank.atms[0]!.hasError = true;
  //   await sleep(200);
  //   bank.atms[0]!.hasError = false;
  // });
  await sleep(3000);
  await bank.close();
}

///
class Person {
  Person({required this.accountNo});

  String accountNo;

  double money = 0;

  /// print
  void look() {
    //print('accountNo:$accountNo   money=$money');
  }
}

///
class ATM {
  Bank bank;
  String id;
  double money = 0;
  bool hasError = false;

  ATM({required this.bank, required this.id});

  Future<bool> deposit(String accountNo, double money) async {
    if (hasError) {
      return await bank.atmTimeout();
    }
    return await bank.atmDeposit(id, accountNo, money);
  }

  /// print
  void look() {
    print('ATM id:$id   money=$money');
  }
}

///
class Bank {
  double total = 0;

  var persons = <Person?>[];

  var atms = <ATM?>[];

  String name;
  bool useQueue = false;

  late SerialQueue queue;

  int orderId = 0;

  ///
  Bank({required this.name, this.useQueue = false}) {
    queue = SerialQueue(log: true)..startQueue();
    for (int i = 0; i < 5; i++) {
      atms.add(ATM(bank: this, id: 'id-$i'));
    }
    for (int i = 0; i < 100; i++) {
      persons.add(Person(accountNo: 'N@$i'));
    }
  }

  Future<bool> atmTimeout() {
    var task = Task<bool, String>.create(
      taskHandler: ({String? params}) {
        print(params);
        return false;
      },
      params: '-----------> ATM故障!!!',
    );
    queue.addTask(task);
    return task.future.onError((error, stackTrace) {
      print('$error');
      return false;
    });
  }

  ///
  Future<bool> atmDeposit(
      String fromAtmId, String accountNo, double money) async {
    if (useQueue) {
      var task = Task<bool, DepositInfo>.create(
          taskHandler: _atmDeposit,
          params: DepositInfo(
              fromAtmId: fromAtmId, accountNo: accountNo, money: money));
      queue.addTask(task);
      var r = await task.future.onError((error, stackTrace) {
        print('$error');
        return false;
      });
      return r;
    } else {
      return _atmDeposit(
          params: DepositInfo(
              fromAtmId: fromAtmId, accountNo: accountNo, money: money));
    }
  }

  ///
  Future<bool> _atmDeposit({DepositInfo? params}) async {
    print(
        'orderId:${orderId++}     fromAtmId:${params!.fromAtmId}  ${params.accountNo}  ${params.money}');
    await sleep(2);
    var atm = atms.firstWhere((atm) => atm?.id == params.fromAtmId,
        orElse: () => null);
    if (atm == null) {
      return false;
    }
    var person = persons.firstWhere((p) => p?.accountNo == params.accountNo,
        orElse: () => null);
    if (person == null) {
      return false;
    }
    double t = total;
    double atmT = atm.money;
    await sleep(2);
    person.money += params.money;
    atmT += params.money;
    t += params.money;
    await sleep(1);
    total = t;
    atm.money = atmT;
    return true;
  }

  /// print
  void look() {
    print('Bank name:$name   total=$total');

    for (var atm in atms) {
      atm!.look();
    }

    for (var p in persons) {
      p!.look();
    }
  }

  Future<void> close() async {
    await queue.dispose(() {
      print('---------------------银行结算信息---------------------');
      look();
    });
  }
}

class DepositInfo {
  String fromAtmId;
  String accountNo;
  double money;

  DepositInfo(
      {required this.fromAtmId, required this.accountNo, required this.money});
}
