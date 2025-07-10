import 'package:flutter/material.dart';

class BottomNavigationBarProvider extends ChangeNotifier {
  int selectedIndex = 0;

  void changeIndex(int index) {
    if (selectedIndex != index) {
      selectedIndex = index;
      notifyListeners();
    }
  }
}