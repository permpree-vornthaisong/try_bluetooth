// providers/navigation_provider.dart
import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  final List<Widget> _pages;

  NavigationProvider(this._pages);

  int get selectedIndex => _selectedIndex;
  Widget get currentPage => _pages[_selectedIndex];

  void changeTab(int index) {
    if (index != _selectedIndex) {
      _selectedIndex = index;
      notifyListeners();
    }
  }
}