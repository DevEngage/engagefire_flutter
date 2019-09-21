import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_crop/image_crop.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:network_to_file_image/network_to_file_image.dart';

/* 
  TODO: 
  [X] camera and gallery picker
  [ ] 
 */
class EngageFiles {
  static var APP;
  static var STORAGE;
  FirebaseStorage storage;

  final cropKey = GlobalKey<CropState>();
  File _file;
  File _sample;
  File _lastCropped;

  @override
  void dispose() {
    _file?.delete();
    _sample?.delete();
    _lastCropped?.delete();
  }

  EngageFiles(storageBucket, app) {
    this.storage = EngageFiles.init(storageBucket, app);
  }

  static init(storageBucket, app) {
    EngageFiles.APP = app;
    return EngageFiles.STORAGE = FirebaseStorage(
                app: EngageFiles.APP, storageBucket: storageBucket);
  }

  generateUuid() {
    return Uuid().v1();
  }

  getImage(url, file) {
    return Image(image: NetworkToFileImage(url: url, file: file, debug: true));
  }

  Future<File> createFile(String name, dynamic content) async {
    final Directory systemTempDir = Directory.systemTemp;
    final File file = await File('${systemTempDir.path}/$name').create();
    await file.writeAsString(content);
    return file;
  }

  Future<void> uploadFile(File file, String path) async {
    final String type = file.path.split('.')[file.path.length - 1];
    final String name = file.path.split('.')[file.path.length - 2] ?? generateUuid();
    final StorageReference ref = storage.ref().child(path).child('$name.$type');
    final StorageUploadTask uploadTask = ref.putFile(
      file,
      StorageMetadata(
        contentLanguage: 'en',
        // customMetadata: <String, String>{'activity': 'test'},
      ),
    );
    return uploadTask;
    // setState(() {
    //   _tasks.add(uploadTask);
    // });
  }

  Future<void>_downloadFile(StorageReference ref) async {
    final String url = await ref.getDownloadURL();
    final http.Response downloadData = await http.get(url);
    final String fileContents = downloadData.body;
    final String name = await ref.getName();
    final String bucket = await ref.getBucket();
    final String path = await ref.getPath();
    return {
      url,
      fileContents,
      name,
      bucket,
      path,
    };
    // _scaffoldKey.currentState.showSnackBar(SnackBar(
    //   content: Text(
    //     'Success!\n Downloaded $name \n from url: $url @ bucket: $bucket\n '
    //     'at path: $path \n\nFile contents: "$fileContents" \n'
    //     'Wrote "$tempFileContents" to tmp.txt',
    //     style: const TextStyle(color: Color.fromARGB(255, 0, 155, 0)),
    //   ),
    // ));
  }


  /* IMAGE */

  Future<File> takePic([ImageSource source = ImageSource.camera]) async  {
    return ImagePicker.pickImage(source: source);
  }

  Future<File> pickImage([ImageSource source = ImageSource.gallery]) async  {
    return ImagePicker.pickImage(source: source);
  }

  getImagePage(context) {
    return _sample == null ? buildOpeningImage(context) : buildCroppingImage(context);
  }

  Widget buildOpeningImage(context) {
    return Center(child: buildOpenImage(context));
  }

  Widget buildCroppingImage(context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: Crop.file(_sample, key: cropKey),
        ),
        Container(
          padding: const EdgeInsets.only(top: 20.0),
          alignment: AlignmentDirectional.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              FlatButton(
                child: Text(
                  'Crop Image',
                  style: Theme.of(context)
                      .textTheme
                      .button
                      .copyWith(color: Colors.white),
                ),
                onPressed: () => cropImage(context),
              ),
              buildOpenImage(context),
            ],
          ),
        )
      ],
    );
  }

  Widget buildOpenImage(context) {
    return FlatButton(
      child: Text(
        'Open Image',
        style: Theme.of(context).textTheme.button.copyWith(color: Colors.white),
      ),
      onPressed: () => openImage(context),
    );
  }

  Future<void> openImage(context) async {
    final file = await ImagePicker.pickImage(source: ImageSource.gallery);
    final sample = await ImageCrop.sampleImage(
      file: file,
      preferredSize: context.size.longestSide.ceil(),
    );

    _sample?.delete();
    _file?.delete();

    _sample = sample;
    _file = file;
  }

  Future<void> cropImage(context) async {
    final scale = cropKey.currentState.scale;
    final area = cropKey.currentState.area;
    if (area == null) {
      // cannot crop, widget is not setup
      return;
    }

    // scale up to use maximum possible number of pixels
    // this will sample image in higher resolution to make cropped image larger
    final sample = await ImageCrop.sampleImage(
      file: _file,
      preferredSize: (2000 / scale).round(),
    );

    final file = await ImageCrop.cropImage(
      file: sample,
      area: area,
    );

    sample.delete();

    _lastCropped?.delete();
    _lastCropped = file;

    debugPrint('$file');
  }


}