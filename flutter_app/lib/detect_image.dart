import 'package:flutter/services.dart';
import 'package:pytorch_lite/pytorch_lite.dart';

//load your model
Future loadModel(imageModel, objectModel) async {
  String pathImageModel = "assets/models/model_classification.pt";
  //String pathCustomModel = "assets/models/custom_model.ptl";
  String pathObjectDetectionModel = "assets/models/best.torchscript";
  try {
    imageModel = await PytorchLite.loadClassificationModel(
        pathImageModel, 224, 224,
        labelPath: "assets/labels/label_classification_imageNet.txt");
    //_customModel = await PytorchLite.loadCustomModel(pathCustomModel);
    objectModel = await PytorchLite.loadObjectDetectionModel(
        pathObjectDetectionModel, 1, 640, 640,
        labelPath: "assets/labels/labels_objectDetection_pistol.txt");
  } on PlatformException {
    print("only supported for android");
  }
}
