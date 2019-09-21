import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

const String kTestString = 'Hello world!';

class EngageFiles {
  static var APP;
  static var STORAGE;
  FirebaseStorage storage;

  EngageFiles({storageBucket = 'gs://flutter-firebase-plugins.appspot.com'}) {
    if (storageBucket == null && EngageFiles.STORAGE == null) {
      EngageFiles.STORAGE = FirebaseStorage(
          app: EngageFiles.APP, storageBucket: 'gs://flutter-firebase-plugins.appspot.com');
    } else if (EngageFiles.STORAGE == null && storageBucket != null) {
      EngageFiles.STORAGE = FirebaseStorage(
                app: EngageFiles.APP, storageBucket: storageBucket);
    } 
    this.storage = EngageFiles.STORAGE;
  }

  Future<void> uploadFile() async {
    final String uuid = Uuid().v1();
    final Directory systemTempDir = Directory.systemTemp;
    final File file = await File('${systemTempDir.path}/foo$uuid.txt').create();
    await file.writeAsString(kTestString);
    assert(await file.readAsString() == kTestString);
    final StorageReference ref =
        storage.ref().child('text').child('foo$uuid.txt');
    final StorageUploadTask uploadTask = ref.putFile(
      file,
      StorageMetadata(
        contentLanguage: 'en',
        customMetadata: <String, String>{'activity': 'test'},
      ),
    );

    // setState(() {
    //   _tasks.add(uploadTask);
    // });
  }

  Future<void>_downloadFile(StorageReference ref) async {
    final String url = await ref.getDownloadURL();
    final String uuid = Uuid().v1();
    final http.Response downloadData = await http.get(url);
    final Directory systemTempDir = Directory.systemTemp;
    final File tempFile = File('${systemTempDir.path}/tmp$uuid.txt');
    if (tempFile.existsSync()) {
      await tempFile.delete();
    }
    await tempFile.create();
    assert(await tempFile.readAsString() == "");
    final StorageFileDownloadTask task = ref.writeToFile(tempFile);
    final int byteCount = (await task.future).totalByteCount;
    final String tempFileContents = await tempFile.readAsString();
    assert(tempFileContents == kTestString);
    assert(byteCount == kTestString.length);

    final String fileContents = downloadData.body;
    final String name = await ref.getName();
    final String bucket = await ref.getBucket();
    final String path = await ref.getPath();
    // _scaffoldKey.currentState.showSnackBar(SnackBar(
    //   content: Text(
    //     'Success!\n Downloaded $name \n from url: $url @ bucket: $bucket\n '
    //     'at path: $path \n\nFile contents: "$fileContents" \n'
    //     'Wrote "$tempFileContents" to tmp.txt',
    //     style: const TextStyle(color: Color.fromARGB(255, 0, 155, 0)),
    //   ),
    // ));
  }
}