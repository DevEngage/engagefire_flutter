


/* 
  TODO:
  [ ] 

  {
    name: 'userCollection',
    defaultId: 'jlkasdhf893',
    templateName: '{userId}'
    class: UserModel,
    path: 'users/userId/collection',
    stream: true,
    preload: true,
    filters: {
      name: 'filter'
    },
    resolve: {
      
    },

    // v2
    fields: [
      {
        name: '',
        default: '',
        relation: '',

      }
    ]
  }

 */

import 'package:engagefire/mobile.dart';

class EngageModel<T> {
  String name;
  String defaultId;
  String templateName;
  String path;
  T wrapper;
  bool stream;
  bool preload;
  
  EngageModel({
    this.name,
    this.defaultId,
    this.templateName,
    this.path,
    this.wrapper,
    this.stream,
    this.preload,
  });

  _init() {
    EngageFirestore.getInstance(path);
  }

  

}