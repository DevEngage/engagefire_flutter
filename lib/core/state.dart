import 'package:rxdart/rxdart.dart';

class EngageState {
  static Map<String, EngageState> instances = {};

  BehaviorSubject _subject;
  dynamic value;

  EngageState({this.value}) {
    _subject = BehaviorSubject.seeded(value);
  }

  ValueStream get stream$ => _subject.stream;
  dynamic get current => _subject.value;

  add(payload, [name]) { 
    if (name != null && current is List) {
      var index = value.indexWhere((item) => item['name'] == name || item['\$id'] == name);
      if (index > 0) value[index] = value;
    } else if (current is List) {
      value = [...current, payload];
    } else if (name != null && current is Map) {
      value[name] = payload;
    } else if (current is Map) {
      value = {...current, payload};
    } else {
      value = payload;
    }
    _subject.add(value);
  }

  repalce(payload) { 
    value = payload;
    _subject.add(value);
  }

  notifiy() {
    _subject.add(value);
  }

  static getState({path, stateValue}) {
    if (EngageState.instances[path] == null) {
      return EngageState.instances[path] = EngageState(value: stateValue);
    }
    return EngageState.instances[path];
  }
}
