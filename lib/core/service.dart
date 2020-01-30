

import 'package:engagefire/core/firestore.dart';
import 'package:engagefire/mobile.dart';

class EngageFilter {
  String name;
  Map filter; // 'userId.isEqual.default': value 
  bool preloadList;

  EngageFilter({
    this.name,
    this.filter,
    this.preloadList = false
  });

  Map toMap() {
    return filter;
  }
}

/* 
  TODO:
  [ ] pagination
  [ ] 
 */ 

class EngageService<T> extends EngageFirestore {
  String name;
  dynamic wrapper;
  bool enableStream;
  bool preloadList;
  EngageFilter filters;
  int limit;
  Map defaults;
  List<T> items = [];
  List resolve;
  Stream<T> stream$;
  
  EngageService({
    this.name,
    path,
    this.wrapper = EngageDoc,
    this.enableStream,
    this.preloadList,
    this.filters,
    this.defaults,
    this.limit,
  }): super(path);

  Future load() async {
    if (preloadList) {
      items = await getItems();
    }
    if (enableStream) {
      stream$ = super.stream(limit: limit, filter: filters.toMap(), wrapper: wrapper);
    }
  }

  Future<List> getItems() async {
    return super.getList(resolve: resolve, filter: filters.toMap(), wrapper: wrapper, limit: limit);
  }

  // service logic
  static Map<String, EngageService> $services;

  static Future addServices(List<EngageService> services) async {
    List<Future> list = services.map((dynamic service) => service.load());
    await Future.wait(list);
    services.forEach((item) => EngageService.$services[item.name] = item);
    return $services;
  }

  static $(serviceName) {
    return EngageService.$services[serviceName];
  }

}