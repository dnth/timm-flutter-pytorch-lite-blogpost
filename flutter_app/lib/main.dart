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
  late ModelObjectDetection _objectModel;
  String? _imagePrediction;
  String? _predictionConfidence;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool objectDetection = false;
  List<ResultObjectDetection?> objDetect = [];

  int inferenceTime = 0;

  final stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  //load your model
  Future loadModel() async {
    String pathImageModel = "assets/models/torchscript_edgenext_xx_small.pt";
    try {
      _imageModel = await PytorchLite.loadClassificationModel(
          pathImageModel, 224, 224,
          labelPath: "assets/labels/label_classification_paddy.txt");
    } on PlatformException {
      print("only supported for android");
    }
  }

  Future runClassification() async {
    stopwatch.start();
    objDetect = [];
    //pick an image
    final PickedFile? image =
        await _picker.getImage(source: ImageSource.gallery);

    //get prediction
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

    stopwatch.stop();
    print("Inference time");
    inferenceTime = stopwatch.elapsedMilliseconds;
    print(inferenceTime);
    print("ms");
    stopwatch.reset();
  }

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
                      Text("Inference time: $inferenceTime ms",
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
            ],
          ),
        ),
      ),
    );
  }
}
