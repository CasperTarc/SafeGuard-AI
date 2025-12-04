// ScreamInference
// Core:
// 1. Load and close TFLite interpreter.
// 2. Preparing model input from raw PCM (normalize int16 -> float32 / quantize int8) and run inference.
// 3. Run inference, and return model score (0 - 1).
// 4. MFCC already trained inside the TFLite (model_raw_input.tflite (float32) & model_raw_input_quant.tflite (int8)).

import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class ScreamInference {
  Interpreter? _interpreter;
  bool _isQuantized = false;
  double _inputScale = 1.0;
  int _inputZeroPoint = 0;
  List<int> _inputShape = <int>[];
  List<int> _outputShape = <int>[];

  ScreamInference();

  /// Load TFLite model from asset path (as listed in pubspec.yaml).
  Future<void> loadModel(String assetPath) async {
    _interpreter?.close();
    _interpreter = await Interpreter.fromAsset(assetPath);

    // Inspect input tensor. type is TensorType (not TfLiteType).
    final inputTensor = _interpreter!.getInputTensor(0);
    _inputShape = inputTensor.shape;
    final t = inputTensor.type; // TensorType enum

    // quantized if uint8/int8
    _isQuantized = (t == TensorType.uint8 || t == TensorType.int8);

    // Try to read quantization parameters in a version-robust way:
    // Some tflite_flutter versions expose quantizationParameters or quantization (dynamic).
    dynamic qParams;
    try {
      qParams = (inputTensor as dynamic).quantizationParameters ?? (inputTensor as dynamic).quantization;
    } catch (_) {
      qParams = null;
    }

    // qParams might have fields like scales / scale or zeroPoints / zeroPoint depending on TF Lite version.
    _inputScale = 1.0;
    _inputZeroPoint = 0;
    if (qParams != null) {
      try {
        if (qParams.scales != null && qParams.scales is List && qParams.scales.isNotEmpty) {
          _inputScale = (qParams.scales[0] as num).toDouble();
        } else if ((qParams.scale ?? qParams.scales) != null) {
          _inputScale = (qParams.scale ?? qParams.scales) as double;
        }
      } catch (_) {}
      try {
        if (qParams.zeroPoints != null && qParams.zeroPoints is List && qParams.zeroPoints.isNotEmpty) {
          _inputZeroPoint = (qParams.zeroPoints[0] as num).toInt();
        } else if ((qParams.zeroPoint ?? qParams.zeroPoints) != null) {
          _inputZeroPoint = (qParams.zeroPoint ?? qParams.zeroPoints) as int;
        }
      } catch (_) {}
    }

    // Output shape (assume scalar / [1,1])
    final outTensor = _interpreter!.getOutputTensor(0);
    _outputShape = outTensor.shape;
  }

  /// Predict from int16 PCM samples (mono). Shorter arrays will be zero-padded to the model input length.
  Future<double> predictFromInt16(List<int> int16Samples) async {
    if (_interpreter == null) {
      throw Exception('Interpreter not loaded. Call loadModel() first.');
    }

    final int targetLen = _determineInputLength();

    // Normalize int16 -> float32 in approx [-1,1].
    final Float32List floatInput = Float32List(targetLen);
    for (int i = 0; i < targetLen; i++) {
      final int v = (i < int16Samples.length) ? int16Samples[i] : 0;
      floatInput[i] = v / 32768.0;
    }

    dynamic inputForInterpreter;
    if (_isQuantized) {
      // Convert float -> int8 using quant params (fallback to symmetric mapping if scale==0)
      final Int8List q = Int8List(targetLen);
      final double scale = (_inputScale == 0.0) ? (1.0 / 128.0) : _inputScale;
      final int zp = _inputZeroPoint;
      for (int i = 0; i < targetLen; i++) {
        int qv = (floatInput[i] / scale + zp).round();
        if (qv < -128) qv = -128;
        if (qv > 127) qv = 127;
        q[i] = qv;
      }
      inputForInterpreter = _wrapInputBuffer(q);
    } else {
      inputForInterpreter = _wrapInputBuffer(floatInput);
    }

    // output container (model returns scalar score)
    var output = List.generate(1, (_) => List.filled(1, 0.0));

    _interpreter!.run(inputForInterpreter, output);

    final dynamic raw = output[0][0];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  int _determineInputLength() {
    if (_inputShape.isEmpty) return 16000;
    if (_inputShape.length == 2) return _inputShape[1];
    return _inputShape.last;
  }

  dynamic _wrapInputBuffer(TypedData buffer) {
    // If the model expects a batch dim [1,N] return as [buffer], otherwise raw buffer.
    if (_inputShape.length == 2) return [buffer];
    return buffer;
  }

  Future<void> close() async {
    _interpreter?.close();
    _interpreter = null;
  }
}