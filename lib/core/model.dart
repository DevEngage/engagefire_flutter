

class EngageModel {
  static Map<String, EngageModel> instances = {};
  String path;
  EngageModel(this.path) {
    if (EngageModel.instances[path] == null)  {
      EngageModel.instances[path] = this;
    }
  }

  addModel() {

  }

  addSubCollection(_path) {
    
  }

  static getInstance(
    String path
  ) {
    if (EngageModel.instances[path] == null)  {
      EngageModel.instances[path] = EngageModel(path);
    }
    return EngageModel.instances[path];
  }

}