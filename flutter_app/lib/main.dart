import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'pytorch_lite_model.dart';
import 'package:empty_widget/empty_widget.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ClassificationModel? _imageModel;
  String? _imagePrediction;
  String? _predictionConfidence;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  int? _inferenceTime;

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
    //pick an image
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      stopwatch.start();

      // run inference
      var result = await _imageModel!
          .getImagePredictionResult(await File(image.path).readAsBytes());

      stopwatch.stop();

      setState(() {
        _imagePrediction = result['label'];
        _predictionConfidence =
            (result['probability'] * 100).toStringAsFixed(2);
        _image = File(image.path);
        _inferenceTime = stopwatch.elapsedMilliseconds;
      });

      stopwatch.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Paddy Disease Classifier')),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.camera),
          onPressed: runClassification,
        ),
        body: Container(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Center(
                child: Visibility(
                  visible: _imagePrediction != null,
                  child: Card(
                    margin: const EdgeInsets.all(8.0),
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(12)),
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.outline)),
                    child: SizedBox(
                      width: 300,
                      height: 80,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text("Disease: $_imagePrediction",
                                style: const TextStyle(fontSize: 18)),
                            Text("Confidence: $_predictionConfidence %",
                                style: const TextStyle(fontSize: 18)),
                            Text("Inference time: $_inferenceTime ms",
                                style: const TextStyle(fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _image == null
                    ? EmptyWidget(
                        image: null,
                        packageImage: PackageImage.Image_3,
                        title: 'No image',
                        subTitle: 'Select an image',
                        titleTextStyle: const TextStyle(
                          fontSize: 20,
                          color: Color(0xff9da9c7),
                          fontWeight: FontWeight.w500,
                        ),
                        subtitleTextStyle: const TextStyle(
                          fontSize: 18,
                          color: Color(0xffabb8d6),
                        ),
                      )
                    : Image.file(_image!),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Linkify(
                  onOpen: (link) async {
                    if (await canLaunch(link.url)) {
                      await launch(link.url);
                    } else {
                      throw 'Could not launch $link';
                    }
                  },
                  text: "Made by https://dicksonneoh.com",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
