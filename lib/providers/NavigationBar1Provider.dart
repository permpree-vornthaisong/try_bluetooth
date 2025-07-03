import 'package:flutter/material.dart';

class NavigationBar1Provider extends ChangeNotifier {
  int _currentPageIndex = 0;

  int get currentPageIndex => _currentPageIndex;

  void setCurrentPageIndex(int index) {
    _currentPageIndex = index;
    notifyListeners();
  }

  // You can add more navigation-related state and methods here
  // For example, navigation history, page-specific data, etc.
  
  List<String> get pageNames => ['Home', 'Notifications', 'Messages'];
  
  String get currentPageName => pageNames[_currentPageIndex];
}