import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:pytorch_lite/pigeon.dart';
import 'package:pytorch_lite/pytorch_lite.dart';

import 'package:empty_widget/empty_widget.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ClassificationModel? _imageModel;
  //CustomModel? _customModel;
  late ModelObjectDetection _objectModel;
  String? _imagePrediction;
  String? _predictionConfidence;
  List? _prediction;
  File? _image;
  ImagePicker _picker = ImagePicker();
  bool objectDetection = false;
  List<ResultObjectDetection?> objDetect = [];

  final stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  //load your model
  Future loadModel() async {
    String pathImageModel = "assets/models/model_edgenextxxs.pt";
    //String pathCustomModel = "assets/models/custom_model.ptl";
    // String pathObjectDetectionModel = "assets/models/best.torchscript";
    try {
      _imageModel = await PytorchLite.loadClassificationModel(
          pathImageModel, 224, 224,
          labelPath: "assets/labels/label_classification_paddy.txt");
      //_customModel = await PytorchLite.loadCustomModel(pathCustomModel);
      // _objectModel = await PytorchLite.loadObjectDetectionModel(
      //     pathObjectDetectionModel, 1, 640, 640,
      //     labelPath: "assets/labels/labels_objectDetection_pistol.txt");
    } on PlatformException {
      print("only supported for android");
    }
  }

  //run an image model
  Future runObjectDetectionWithoutLabels() async {
    //pick a random image
    final PickedFile? image =
        await _picker.getImage(source: ImageSource.gallery);
    objDetect = await _objectModel
        .getImagePredictionList(await File(image!.path).readAsBytes());
    objDetect.forEach((element) {
      print({
        "score": element?.score,
        "className": element?.className,
        "class": element?.classIndex,
        "rect": {
          "left": element?.rect.left,
          "top": element?.rect.top,
          "width": element?.rect.width,
          "height": element?.rect.height,
          "right": element?.rect.right,
          "bottom": element?.rect.bottom,
        },
      });
    });
    setState(() {
      //this.objDetect = objDetect;
      _image = File(image.path);
    });
  }

  Future runObjectDetection() async {
    stopwatch.start();

    //pick a random image
    final PickedFile? image =
        await _picker.getImage(source: ImageSource.gallery);
    objDetect = await _objectModel.getImagePrediction(
        await File(image!.path).readAsBytes(),
        minimumScore: 0.3,
        IOUThershold: 0.3);
    objDetect.forEach((element) {
      print({
        "score": element?.score,
        "className": element?.className,
        "class": element?.classIndex,
        "rect": {
          "left": element?.rect.left,
          "top": element?.rect.top,
          "width": element?.rect.width,
          "height": element?.rect.height,
          "right": element?.rect.right,
          "bottom": element?.rect.bottom,
        },
      });
    });
    setState(() {
      //this.objDetect = objDetect;
      _image = File(image.path);
    });

    stopwatch.stop();
    print("Inference time");
    print(stopwatch.elapsedMilliseconds);
    print("ms");
    stopwatch.reset();
  }

  Future runClassification() async {
    objDetect = [];
    //pick a random image
    final PickedFile? image =
        await _picker.getImage(source: ImageSource.gallery);
    //get prediction
    //labels are 1000 random english words for show purposes
    _imagePrediction = await _imageModel!
        .getImagePrediction(await File(image!.path).readAsBytes());

    List<double?>? predictionList = await _imageModel!.getImagePredictionList(
      await File(image.path).readAsBytes(),
    );

    print(predictionList);
    List<double?>? predictionListProbabilites =
        await _imageModel!.getImagePredictionListProbabilities(
      await File(image.path).readAsBytes(),
    );
    //Gettting the highest Probability
    double maxScoreProbability = double.negativeInfinity;
    double sumOfProbabilites = 0;
    int index = 0;
    for (int i = 0; i < predictionListProbabilites!.length; i++) {
      if (predictionListProbabilites[i]! > maxScoreProbability) {
        maxScoreProbability = predictionListProbabilites[i]!;
        sumOfProbabilites = sumOfProbabilites + predictionListProbabilites[i]!;
        index = i;
      }
    }
    print(predictionListProbabilites);
    print(index);
    print(sumOfProbabilites);
    print(maxScoreProbability);
    _predictionConfidence = (maxScoreProbability * 100).toStringAsFixed(2);

    setState(() {
      //this.objDetect = objDetect;
      _image = File(image.path);
    });
  }

/*
  //run a custom model with number inputs
  Future runCustomModel() async {
    _prediction = await _customModel!
        .getPrediction([1, 2, 3, 4], [1, 2, 2], DType.float32);

    setState(() {});
  }
*/

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Paddy Disease Classifier'),
        ),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.camera),
          onPressed: runClassification,
        ),
        body: Container(
          padding: EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Center(
                child: Visibility(
                  visible: _imagePrediction != null,
                  child: Column(
                    children: [
                      Text("Disease: $_imagePrediction",
                          style: TextStyle(fontSize: 20)),
                      Text("Confidence: $_predictionConfidence %",
                          style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: objDetect.isNotEmpty
                    ? _image == null
                        ? EmptyWidget(
                            image: null,
                            packageImage: PackageImage.Image_3,
                            title: 'No image',
                            // subTitle: 'Select an image or upload your own',
                            titleTextStyle: const TextStyle(
                              fontSize: 15,
                              color: Color(0xff9da9c7),
                              fontWeight: FontWeight.w500,
                            ),
                            subtitleTextStyle: const TextStyle(
                              fontSize: 14,
                              color: Color(0xffabb8d6),
                            ),
                          )
                        : _objectModel.renderBoxesOnImage(_image!, objDetect)
                    : _image == null
                        ? EmptyWidget(
                            image: null,
                            packageImage: PackageImage.Image_3,
                            title: 'No image',
                            // subTitle: 'Select an image or upload your own',
                            titleTextStyle: const TextStyle(
                              fontSize: 15,
                              color: Color(0xff9da9c7),
                              fontWeight: FontWeight.w500,
                            ),
                            subtitleTextStyle: const TextStyle(
                              fontSize: 14,
                              color: Color(0xffabb8d6),
                            ),
                          )
                        : Image.file(_image!),
              ),

              /*
              Center(
                child: TextButton(
                  onPressed: runImageModel,
                  child: Row(
                    children: [

                      Icon(
                        Icons.add_a_photo,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              */

              // TextButton(
              //   onPressed: runClassification,
              //   style: TextButton.styleFrom(
              //     backgroundColor: Colors.blue,
              //   ),
              //   child: const Text(
              //     "Run Classification",
              //     style: TextStyle(
              //       color: Colors.white,
              //     ),
              //   ),
              // ),
              // TextButton(
              //   onPressed: runObjectDetection,
              //   style: TextButton.styleFrom(
              //     backgroundColor: Colors.blue,
              //   ),
              //   child: const Text(
              //     "Infer with YOLOv5-Nano",
              //     style: TextStyle(
              //       color: Colors.white,
              //     ),
              //   ),
              // ),
              // TextButton(
              //   onPressed: runObjectDetectionWithoutLabels,
              //   style: TextButton.styleFrom(
              //     backgroundColor: Colors.blue,
              //   ),
              //   child: const Text(
              //     "Run object detection without labels",
              //     style: TextStyle(
              //       color: Colors.white,
              //     ),
              //   ),
              // ),
              // Center(
              //   child: Visibility(
              //     visible: _prediction != null,
              //     child: Text(_prediction != null ? "${_prediction![0]}" : ""),
              //   ),
              // )
            ],
          ),
        ),
      ),
    );
  }
}
