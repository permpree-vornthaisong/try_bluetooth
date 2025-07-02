import 'package:flutter/material.dart';

class WeightCalibrationProvider extends ChangeNotifier {
  bool _isConnected = false;
  List<double> _weights = [];

  bool get isConnected => _isConnected;
  List<double> get weights => List.unmodifiable(_weights);



  void connect() {
    _isConnected = true;
    notifyListeners();
  }

  void disconnect() {
    _isConnected = false;
    notifyListeners();
  }

  void addWeight(double weight) {
    if (_weights.length >= 10) {
      _weights.removeAt(0);
    }
    _weights.add(weight);
    notifyListeners();
  }
}