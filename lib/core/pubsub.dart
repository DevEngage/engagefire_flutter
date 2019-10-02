/*
* TODO:
* [ ] Finish localstorage integration
* */
class EngagePubsub {
  static var RETAIN = false;
  static var ID = 'EngageData';
  static var app;
  static var storage;
  static var ads;
  static var auth;
  static EngagePubsub instance;
  Map<String, List<Function>> listeners = {};
  var data = {};

  static init({app, storage, ads, auth}) {
    EngagePubsub.app = app;
    EngagePubsub.storage = storage;
    EngagePubsub.ads = ads;
    EngagePubsub.auth = auth;
  }

  subscribe([String what = 'all', Function listener]) {
    if (this.listeners[what] == null) this.listeners[what] = [];
    this.listeners[what].add(listener);
    if (what != 'all' && this.data[what] != null) {
      listener(this.data[what]);
    }
  }

  publish([var data, what = 'all']) {
    this.data[what] = data;
    if (what == 'all') {
      this.listeners.forEach((key, value) => value.forEach((Function listener) => listener(data)));
    } else {
      (this.listeners[what] ?? []).forEach((Function listener) => listener is Function ? listener(data) : null);
    }
  }

  unsubscribe(String what, Function listener) {
    if (listeners[what] == null) return;
    listeners[what].remove(listener);
  }

  get([String what = 'all']) {
    if (what == 'all') {
      return this.data;
    }
    return this.data[what];
  }

  set([var data, String what]) {
    if (what == null) return null;
    if (what == 'all') {
      return this.data = data;
    }
    return this.data[what] = data;
  }

  clear(var what) {
    if (what == null) return null;
    if (what == 'all') {
      return this.data = {};
    }
    return this.data[what] = {};
  }

  static getInstance() {
    return EngagePubsub.instance ??= EngagePubsub();
  }
}

var engagePubsub = EngagePubsub.getInstance();