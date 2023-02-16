import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pytorch_lite/pigeon.dart';
import 'dart:math' as math;

const TORCHVISION_NORM_MEAN_RGB = [0.485, 0.456, 0.406];
const TORCHVISION_NORM_STD_RGB = [0.229, 0.224, 0.225];

class PytorchLite {
  /*
  ///Sets pytorch model path and returns Model
  static Future<CustomModel> loadCustomModel(String path) async {
    String absPathModelPath = await _getAbsolutePath(path);
    int index = await ModelApi().loadModel(absPathModelPath, null, 0, 0);
    return CustomModel(index);
  }
   */

  ///Sets pytorch model path and returns Model
  static Future<ClassificationModel> loadClassificationModel(
      String path, int imageWidth, int imageHeight,
      {String? labelPath}) async {
    String absPathModelPath = await _getAbsolutePath(path);
    int index = await ModelApi()
        .loadModel(absPathModelPath, null, imageWidth, imageHeight);
    List<String> labels = [];
    if (labelPath != null) {
      if (labelPath.endsWith(".txt")) {
        labels = await _getLabelsTxt(labelPath);
      } else {
        labels = await _getLabelsCsv(labelPath);
      }
    }

    return ClassificationModel(index, labels);
  }

  ///Sets pytorch object detection model (path and lables) and returns Model
  static Future<ModelObjectDetection> loadObjectDetectionModel(
      String path, int numberOfClasses, int imageWidth, int imageHeight,
      {String? labelPath}) async {
    String absPathModelPath = await _getAbsolutePath(path);

    int index = await ModelApi()
        .loadModel(absPathModelPath, numberOfClasses, imageWidth, imageHeight);
    List<String> labels = [];
    if (labelPath != null) {
      if (labelPath.endsWith(".txt")) {
        labels = await _getLabelsTxt(labelPath);
      } else {
        labels = await _getLabelsCsv(labelPath);
      }
    }
    return ModelObjectDetection(index, imageWidth, imageHeight, labels);
  }

  static Future<String> _getAbsolutePath(String path) async {
    Directory dir = await getApplicationDocumentsDirectory();
    String dirPath = join(dir.path, path);
    ByteData data = await rootBundle.load(path);
    //copy asset to documents directory
    List<int> bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    //create non existant directories
    List split = path.split("/");
    String nextDir = "";
    for (int i = 0; i < split.length; i++) {
      if (i != split.length - 1) {
        nextDir += split[i];
        await Directory(join(dir.path, nextDir)).create();
        nextDir += "/";
      }
    }
    await File(dirPath).writeAsBytes(bytes);

    return dirPath;
  }
}

///get labels in csv format
///labels are separated by commas
Future<List<String>> _getLabelsCsv(String labelPath) async {
  String labelsData = await rootBundle.loadString(labelPath);
  return labelsData.split(",");
}

///get labels in txt format
///each line is a label
Future<List<String>> _getLabelsTxt(String labelPath) async {
  String labelsData = await rootBundle.loadString(labelPath);
  return labelsData.split("\n");
}

/*
class CustomModel {
  final int _index;

  CustomModel(this._index);

  ///predicts abstract number input
  Future<List?> getPrediction(
      List<double> input, List<int> shape, DType dtype) async {
    final List? prediction = await ModelApi().getPredictionCustom(
        _index, input, shape, dtype.toString().split(".").last);
    return prediction;
  }
}
*/
class ClassificationModel {
  final int _index;
  final List<String> labels;
  ClassificationModel(this._index, this.labels);

  ///predicts image and returns the supposed label belonging to it
  Future<String> getImagePrediction(Uint8List imageAsBytes,
      {List<double> mean = TORCHVISION_NORM_MEAN_RGB,
      List<double> std = TORCHVISION_NORM_STD_RGB}) async {
    // Assert mean std
    assert(mean.length == 3, "mean should have size of 3");
    assert(std.length == 3, "std should have size of 3");

    final List<double?>? prediction = await ModelApi().getImagePredictionList(
        _index, imageAsBytes, null, null, null, mean, std);

    double maxScore = double.negativeInfinity;
    int maxScoreIndex = -1;
    for (int i = 0; i < prediction!.length; i++) {
      if (prediction[i]! > maxScore) {
        maxScore = prediction[i]!;
        maxScoreIndex = i;
      }
    }

    return labels[maxScoreIndex];
  }

  Future<Map<String, dynamic>> getImagePredictionResult(Uint8List imageAsBytes,
      {List<double> mean = TORCHVISION_NORM_MEAN_RGB,
      List<double> std = TORCHVISION_NORM_STD_RGB}) async {
    // Assert mean std
    assert(mean.length == 3, "mean should have size of 3");
    assert(std.length == 3, "std should have size of 3");

    final List<double?>? prediction = await ModelApi().getImagePredictionList(
        _index, imageAsBytes, null, null, null, mean, std);

    // Get the index of the max score
    int maxScoreIndex = 0;
    for (int i = 1; i < prediction!.length; i++) {
      if (prediction[i]! > prediction[maxScoreIndex]!) {
        maxScoreIndex = i;
      }
    }

    //Getting sum of exp
    double sumExp = 0.0;
    for (var element in prediction) {
      sumExp = sumExp + math.exp(element!);
    }

    final predictionProbabilities =
        prediction.map((element) => math.exp(element!) / sumExp).toList();

    return {
      "label": labels[maxScoreIndex],
      "probability": predictionProbabilities[maxScoreIndex]
    };
  }

  ///predicts image but returns the raw net output
  Future<Map<String, List<double?>>> getImagePredictionListAndProbs(
      Uint8List imageAsBytes,
      {List<double> mean = TORCHVISION_NORM_MEAN_RGB,
      List<double> std = TORCHVISION_NORM_STD_RGB}) async {
    // Assert mean std
    assert(mean.length == 3, "Mean should have size of 3");
    assert(std.length == 3, "STD should have size of 3");
    final List<double?>? prediction = await ModelApi().getImagePredictionList(
        _index, imageAsBytes, null, null, null, mean, std);

    List<double?>? predictionProbabilities = [];

    //Getting sum of exp
    double? sumExp;
    for (var element in prediction!) {
      if (sumExp == null) {
        sumExp = exp(element!);
      } else {
        sumExp = sumExp + exp(element!);
      }
    }
    for (var element in prediction) {
      predictionProbabilities.add(exp(element!) / sumExp!);
    }

    Map<String, List<double?>> result = {
      'predList': prediction,
      'predListProba': predictionProbabilities,
    };

    return result;
  }

  ///predicts image but returns the raw net output
  Future<List<double?>?> getImagePredictionList(Uint8List imageAsBytes,
      {List<double> mean = TORCHVISION_NORM_MEAN_RGB,
      List<double> std = TORCHVISION_NORM_STD_RGB}) async {
    // Assert mean std
    assert(mean.length == 3, "Mean should have size of 3");
    assert(std.length == 3, "STD should have size of 3");
    final List<double?>? prediction = await ModelApi().getImagePredictionList(
        _index, imageAsBytes, null, null, null, mean, std);
    return prediction;
  }

  ///predicts image but returns the output as probabilities
  ///[image] takes the File of the image
  Future<List<double?>?> getImagePredictionListProbabilities(
      Uint8List imageAsBytes,
      {List<double> mean = TORCHVISION_NORM_MEAN_RGB,
      List<double> std = TORCHVISION_NORM_STD_RGB}) async {
    // Assert mean std
    assert(mean.length == 3, "Mean should have size of 3");
    assert(std.length == 3, "STD should have size of 3");
    List<double?>? prediction = await ModelApi().getImagePredictionList(
        _index, imageAsBytes, null, null, null, mean, std);
    List<double?>? predictionProbabilities = [];

    //Getting sum of exp
    double? sumExp;
    for (var element in prediction!) {
      if (sumExp == null) {
        sumExp = exp(element!);
      } else {
        sumExp = sumExp + exp(element!);
      }
    }
    for (var element in prediction) {
      predictionProbabilities.add(exp(element!) / sumExp!);
    }

    return predictionProbabilities;
  }

  ///predicts image and returns the supposed label belonging to it
  Future<String> getImagePredictionFromBytesList(
      List<Uint8List> imageAsBytesList, int imageWidth, int imageHeight,
      {List<double> mean = TORCHVISION_NORM_MEAN_RGB,
      List<double> std = TORCHVISION_NORM_STD_RGB}) async {
    // Assert mean std
    assert(mean.length == 3, "mean should have size of 3");
    assert(std.length == 3, "std should have size of 3");

    final List<double?>? prediction = await ModelApi().getImagePredictionList(
        _index, null, imageAsBytesList, imageWidth, imageHeight, mean, std);

    double maxScore = double.negativeInfinity;
    int maxScoreIndex = -1;
    for (int i = 0; i < prediction!.length; i++) {
      if (prediction[i]! > maxScore) {
        maxScore = prediction[i]!;
        maxScoreIndex = i;
      }
    }

    return labels[maxScoreIndex];
  }

  ///predicts image but returns the raw net output
  Future<List<double?>?> getImagePredictionListFromBytesList(
      List<Uint8List> imageAsBytesList, int imageWidth, int imageHeight,
      {List<double> mean = TORCHVISION_NORM_MEAN_RGB,
      List<double> std = TORCHVISION_NORM_STD_RGB}) async {
    // Assert mean std
    assert(mean.length == 3, "Mean should have size of 3");
    assert(std.length == 3, "STD should have size of 3");
    final List<double?>? prediction = await ModelApi().getImagePredictionList(
        _index, null, imageAsBytesList, imageWidth, imageHeight, mean, std);
    return prediction;
  }

  ///predicts image but returns the output as probabilities
  ///[image] takes the File of the image
  Future<List<double?>?> getImagePredictionListProbabilitiesFromBytesList(
      List<Uint8List> imageAsBytesList, int imageWidth, int imageHeight,
      {List<double> mean = TORCHVISION_NORM_MEAN_RGB,
      List<double> std = TORCHVISION_NORM_STD_RGB}) async {
    // Assert mean std
    assert(mean.length == 3, "Mean should have size of 3");
    assert(std.length == 3, "STD should have size of 3");
    List<double?>? prediction = await ModelApi().getImagePredictionList(
        _index, null, imageAsBytesList, imageWidth, imageHeight, mean, std);
    List<double?>? predictionProbabilities = [];

    //Getting sum of exp
    double? sumExp;
    for (var element in prediction!) {
      if (sumExp == null) {
        sumExp = exp(element!);
      } else {
        sumExp = sumExp + exp(element!);
      }
    }
    for (var element in prediction) {
      predictionProbabilities.add(exp(element!) / sumExp!);
    }

    return predictionProbabilities;
  }
}

class ModelObjectDetection {
  final int _index;
  final int imageWidth;
  final int imageHeight;
  final List<String> labels;

  ModelObjectDetection(
      this._index, this.imageWidth, this.imageHeight, this.labels);

  ///predicts image and returns the supposed label belonging to it
  Future<List<ResultObjectDetection?>> getImagePrediction(
      Uint8List imageAsBytes,
      {double minimumScore = 0.5,
      double IOUThershold = 0.5,
      int boxesLimit = 10}) async {
    List<ResultObjectDetection?> prediction = await ModelApi()
        .getImagePredictionListObjectDetection(_index, imageAsBytes, null, null,
            null, minimumScore, IOUThershold, boxesLimit);

    for (var element in prediction) {
      element?.className = labels[element.classIndex];
    }

    return prediction;
  }

  ///predicts image and returns the supposed label belonging to it
  Future<List<ResultObjectDetection?>> getImagePredictionFromBytesList(
      List<Uint8List> imageAsBytesList, int imageWidth, int imageHeight,
      {double minimumScore = 0.5,
      double IOUThershold = 0.5,
      int boxesLimit = 10}) async {
    List<ResultObjectDetection?> prediction = await ModelApi()
        .getImagePredictionListObjectDetection(_index, null, imageAsBytesList,
            imageWidth, imageHeight, minimumScore, IOUThershold, boxesLimit);

    for (var element in prediction) {
      element?.className = labels[element.classIndex];
    }

    return prediction;
  }

  ///predicts image but returns the raw net output
  Future<List<ResultObjectDetection?>> getImagePredictionList(
      Uint8List imageAsBytes,
      {double minimumScore = 0.5,
      double IOUThershold = 0.5,
      int boxesLimit = 10}) async {
    final List<ResultObjectDetection?> prediction = await ModelApi()
        .getImagePredictionListObjectDetection(_index, imageAsBytes, null, null,
            null, minimumScore, IOUThershold, boxesLimit);
    return prediction;
  }

  ///predicts image but returns the raw net output
  Future<List<ResultObjectDetection?>> getImagePredictionListFromBytesList(
      List<Uint8List> imageAsBytesList, int imageWidth, int imageHeight,
      {double minimumScore = 0.5,
      double IOUThershold = 0.5,
      int boxesLimit = 10}) async {
    final List<ResultObjectDetection?> prediction = await ModelApi()
        .getImagePredictionListObjectDetection(_index, null, imageAsBytesList,
            imageWidth, imageHeight, minimumScore, IOUThershold, boxesLimit);
    return prediction;
  }

  /*

   */
  Widget renderBoxesOnImage(
      File _image, List<ResultObjectDetection?> _recognitions,
      {Color? boxesColor, bool showPercentage = true}) {
    //if (_recognitions == null) return Cont;
    //if (_imageHeight == null || _imageWidth == null) return [];

    //double factorX = screen.width;
    //double factorY = _imageHeight / _imageWidth * screen.width;
    //boxesColor ??= Color.fromRGBO(37, 213, 253, 1.0);

    print(_recognitions.length);
    return LayoutBuilder(builder: (context, constraints) {
      debugPrint(
          'Max height: ${constraints.maxHeight}, max width: ${constraints.maxWidth}');
      double factorX = constraints.maxWidth;
      double factorY = constraints.maxHeight;
      return Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: factorX,
            height: factorY,
            child: Container(
                child: Image.file(
              _image,
              fit: BoxFit.fill,
            )),
          ),
          ..._recognitions.map((re) {
            if (re == null) {
              return Container();
            }
            Color usedColor;
            if (boxesColor == null) {
              //change colors for each label
              usedColor = Colors.primaries[
                  ((re.className ?? re.classIndex.toString()).length +
                          (re.className ?? re.classIndex.toString())
                              .codeUnitAt(0) +
                          re.classIndex) %
                      Colors.primaries.length];
            } else {
              usedColor = boxesColor;
            }

            print({
              "left": re.rect.left.toDouble() * factorX,
              "top": re.rect.top.toDouble() * factorY,
              "width": re.rect.width.toDouble() * factorX,
              "height": re.rect.height.toDouble() * factorY,
            });
            return Positioned(
              left: re.rect.left * factorX,
              top: re.rect.top * factorY - 20,
              //width: re.rect.width.toDouble(),
              //height: re.rect.height.toDouble(),

              //left: re?.rect.left.toDouble(),
              //top: re?.rect.top.toDouble(),
              //right: re.rect.right.toDouble(),
              //bottom: re.rect.bottom.toDouble(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 20,
                    alignment: Alignment.centerRight,
                    color: usedColor,
                    child: Text(
                      (re.className ?? re.classIndex.toString()) +
                          "_" +
                          (showPercentage
                              ? (re.score * 100).toStringAsFixed(2) + "%"
                              : ""),
                    ),
                  ),
                  Container(
                    width: re.rect.width.toDouble() * factorX,
                    height: re.rect.height.toDouble() * factorY,
                    decoration: BoxDecoration(
                        border: Border.all(color: usedColor, width: 3),
                        borderRadius: BorderRadius.all(Radius.circular(2))),
                    child: Container(),
                  ),
                ],
              ),
              /*
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  border: Border.all(
                    color: boxesColor!,
                    width: 2,
                  ),
                ),
                child: Text(
                  "${re.className ?? re.classIndex} ${(re.score * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    background: Paint()..color = boxesColor!,
                    color: Colors.white,
                    fontSize: 12.0,
                  ),
                ),
              ),*/
            );
          }).toList()
        ],
      );
    });
  }

/*
  ///predicts image and returns the supposed label belonging to it
  Future<String> getImagePrediction(
      File image, int width, int height, String labelPath,
      {List<double> mean = TORCHVISION_NORM_MEAN_RGB,
      List<double> std = TORCHVISION_NORM_STD_RGB}) async {
    // Assert mean std
    assert(mean.length == 3, "mean should have size of 3");
    assert(std.length == 3, "std should have size of 3");

    List<String> labels = [];
    if (labelPath.endsWith(".txt")) {
      labels = await _getLabelsTxt(labelPath);
    } else {
      labels = await _getLabelsCsv(labelPath);
    }

    List byteArray = image.readAsBytesSync();
    final List? prediction =
        await _channel.invokeListMethod("predictImage_ObjectDetection", {
      "index": _index,
      "image": byteArray,
      "width": width,
      "height": height,
      "mean": mean,
      "std": std
    });
    double maxScore = double.negativeInfinity;
    int maxScoreIndex = -1;
    for (int i = 0; i < prediction!.length; i++) {
      if (prediction[i] > maxScore) {
        maxScore = prediction[i];
        maxScoreIndex = i;
      }
    }
    return labels[maxScoreIndex];
  }

  ///predicts image but returns the raw net output
  Future<List?> getImagePredictionList(File image, int width, int height,
      {List<double> mean = TORCHVISION_NORM_MEAN_RGB,
      List<double> std = TORCHVISION_NORM_STD_RGB}) async {
    // Assert mean std
    assert(mean.length == 3, "Mean should have size of 3");
    assert(std.length == 3, "STD should have size of 3");
    final List? prediction =
        await _channel.invokeListMethod("predictImage_ObjectDetection", {
      "index": _index,
      "image": image.readAsBytesSync(),
      "width": width,
      "height": height,
      "mean": mean,
      "std": std
    });
    return prediction;
  }

 */
}
