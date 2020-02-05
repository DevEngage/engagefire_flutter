
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/material.dart';

/* 
  TODO: 
  [ ] mezmorize
  [ ] path
  [ ] load
  [ ] wrapper
 */ 

ValueNotifier<T> engageList<T>([T initialData]) {
  // First, call the useState hook. It will create a ValueNotifier for you that
  // rebuilds the Widget whenever the value changes.
  final result = useState<T>(initialData);

  // Next, call the useValueChanged hook to print the state whenever it changes
  useValueChanged(result.value, (T _, T __) {
    print(result.value);
  });

  return result;
}

ValueNotifier<T> engageListStream<T>([T initialData]) {
  // First, call the useState hook. It will create a ValueNotifier for you that
  // rebuilds the Widget whenever the value changes.
  final result = useState<T>(initialData);

  // Next, call the useValueChanged hook to print the state whenever it changes
  useValueChanged(result.value, (T _, T __) {
    print(result.value);
  });

  return result;
}

ValueNotifier<T> engageDoc<T>({T initialData, wrapper, useMemoized = true}) {
  // First, call the useState hook. It will create a ValueNotifier for you that
  // rebuilds the Widget whenever the value changes.

  if (initialData == null && wrapper != null) {
    initialData = wrapper(); // useMemoized
  }
  
  final result = useState<T>(initialData);


  // Next, call the useValueChanged hook to print the state whenever it changes
  useValueChanged(result.value, (T _, T __) {
    print(result.value);
  });

  return result;
}

ValueNotifier<T> engageDocStream<T>([T initialData]) {
  // First, call the useState hook. It will create a ValueNotifier for you that
  // rebuilds the Widget whenever the value changes.
  final result = useState<T>(initialData);

  // Next, call the useValueChanged hook to print the state whenever it changes
  useValueChanged(result.value, (T _, T __) {
    print(result.value);
  });

  return result;
}