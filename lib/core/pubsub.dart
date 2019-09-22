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
  static EngagePubsub instance;
  Map<String, List> listeners = {};
  var data = {};

  static init({app, storage, ads}) {
    EngagePubsub.app = app;
    EngagePubsub.storage = storage;
    EngagePubsub.ads = ads;
  }

  subscribe([String what = 'all', var listener]) {
    if (this.listeners[what] == null) this.listeners[what] = [];
    this.listeners[what].add(listener);
    if (what != 'all' && this.data[what]) {
      listener(this.data[what]);
    }
  }

  publish([var data, what = 'all']) {
    this.data[what] = data;
    if (what == 'all') {
      this.listeners.forEach((key, value) => value.forEach((var listener) => listener(data)));
    } else {
      this.listeners[what].forEach((var listener) => listener(data));
    }
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