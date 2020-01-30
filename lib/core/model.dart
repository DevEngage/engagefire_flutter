import 'package:engagefire/mobile.dart';

/* 
  TODO:
  [ ] detault functionality
  [ ] fields
  [ ] form builder
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

class EngageModel extends EngageDoc {
  String $name;
  bool $enableStream;
  bool $preload;
  // List fields;
  // String $defaultId;
  // String $templateName;
  
  EngageModel({
    name,
    path,
    enableStream,
    preload,
    // this.defaultId,
    // this.templateName,
  }): super(path: path) {
    $name = name;
    $enableStream = enableStream;
    $preload = preload;
  }

  Future $load() async {
    if ($enableStream) {

    }
    if (preload) {
      
    }
    return 
  }

  

}