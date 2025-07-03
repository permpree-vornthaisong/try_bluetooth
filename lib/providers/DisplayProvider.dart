import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'SettingProvider.dart';

class DisplayProvider extends ChangeNotifier {
  // Message management
  List<String> _receivedMessages = [];
  bool _autoScroll = true;
  int _maxMessages = 100;
  
  // Scroll controller
  ScrollController? _scrollController;
  
  // Subscriptions
  StreamSubscription? _settingProviderSubscription;
  SettingProvider? _settingProvider;
  
  // Track last processed values to avoid duplicates
  Map<String, List<int>> _lastProcessedValues = {};

  // Getters
  List<String> get receivedMessages => _receivedMessages;
  bool get autoScroll => _autoScroll;
  int get messageCount => _receivedMessages.length;
  int get maxMessages => _maxMessages;

  // Scroll controller getter/setter
  ScrollController? get scrollController => _scrollController;
  
  void setScrollController(ScrollController controller) {
    _scrollController = controller;
  }

  // Initialize with SettingProvider
  void initializeWithSettingProvider(SettingProvider settingProvider) {
    _settingProvider = settingProvider;
    
    // Listen to setting provider changes
    _settingProvider!.addListener(_onSettingProviderChanged);
  }

  void _onSettingProviderChanged() {
    if (_settingProvider != null) {
      _updateReceivedMessages(_settingProvider!);
    }
  }

  void _updateReceivedMessages(SettingProvider provider) {
    bool hasNewData = false;
    
    // Check for new data from all characteristics
    provider.characteristicValues.forEach((uuid, value) {
      if (value is List<int> && value.isNotEmpty) {
        // Check if this is new data
        if (!_lastProcessedValues.containsKey(uuid) || 
            !listEquals(_lastProcessedValues[uuid], value)) {
          
          _lastProcessedValues[uuid] = List<int>.from(value);
          
          try {
            String receivedText = String.fromCharCodes(value).trim();
            String timestamp = _formatTimestamp();
            
            // Try to parse weight value for better display
            double? weightValue = _parseWeightFromText(receivedText);
            String displayMessage;
            
            if (weightValue != null) {
              displayMessage = '[$timestamp] Weight: ${weightValue.toStringAsFixed(2)} kg (Raw: $receivedText)';
            } else {
              displayMessage = '[$timestamp] $receivedText';
            }
            
            // Add only if it's different from the last message
            if (_receivedMessages.isEmpty || _receivedMessages.last != displayMessage) {
              _receivedMessages.add(displayMessage);
              hasNewData = true;
              
              // Limit to last maxMessages to prevent memory issues
              if (_receivedMessages.length > _maxMessages) {
                _receivedMessages.removeAt(0);
              }
            }
          } catch (e) {
            // If not valid ASCII, show as hex
            String hexData = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
            String timestamp = _formatTimestamp();
            String newMessage = '[$timestamp] HEX: $hexData';
            
            if (_receivedMessages.isEmpty || _receivedMessages.last != newMessage) {
              _receivedMessages.add(newMessage);
              hasNewData = true;
              
              if (_receivedMessages.length > _maxMessages) {
                _receivedMessages.removeAt(0);
              }
            }
          }
        }
      }
    });

    if (hasNewData) {
      notifyListeners();
      if (_autoScroll) {
        _scrollToBottom();
      }
    }
  }

  // Helper method to parse weight from text like "Weight: 7393.00 kg"
  double? _parseWeightFromText(String text) {
    try {
      // Look for pattern like "Weight: 7393.00 kg" or similar
      RegExp weightPattern = RegExp(r'Weight:\s*([+-]?\d+\.?\d*)', caseSensitive: false);
      Match? match = weightPattern.firstMatch(text);
      
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
      
      // If no "Weight:" pattern, try to extract any number from the text
      RegExp numberPattern = RegExp(r'([+-]?\d+\.?\d*)');
      match = numberPattern.firstMatch(text);
      
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  String _formatTimestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
           '${now.minute.toString().padLeft(2, '0')}:'
           '${now.second.toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    if (_scrollController != null && _scrollController!.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController!.animateTo(
          _scrollController!.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  // Public methods
  void clearAllMessages() {
    _receivedMessages.clear();
    _lastProcessedValues.clear();
    notifyListeners();
  }

  void toggleAutoScroll() {
    _autoScroll = !_autoScroll;
    notifyListeners();
    
    if (_autoScroll) {
      _scrollToBottom();
    }
  }

  void setMaxMessages(int maxMessages) {
    _maxMessages = maxMessages;
    
    // Trim existing messages if needed
    while (_receivedMessages.length > _maxMessages) {
      _receivedMessages.removeAt(0);
    }
    
    notifyListeners();
  }

  void scrollToBottom() {
    _scrollToBottom();
  }

  // Add manual message (for testing or custom input)
  void addManualMessage(String message) {
    String timestamp = _formatTimestamp();
    String newMessage = '[$timestamp] MANUAL: $message';
    
    _receivedMessages.add(newMessage);
    
    if (_receivedMessages.length > _maxMessages) {
      _receivedMessages.removeAt(0);
    }
    
    notifyListeners();
    
    if (_autoScroll) {
      _scrollToBottom();
    }
  }

  // Filter messages by type
  List<String> getMessagesByType(String type) {
    switch (type.toLowerCase()) {
      case 'hex':
        return _receivedMessages.where((msg) => msg.contains('HEX:')).toList();
      case 'ascii':
        return _receivedMessages.where((msg) => !msg.contains('HEX:') && !msg.contains('MANUAL:')).toList();
      case 'manual':
        return _receivedMessages.where((msg) => msg.contains('MANUAL:')).toList();
      default:
        return _receivedMessages;
    }
  }

  // Search messages
  List<String> searchMessages(String query) {
    if (query.isEmpty) return _receivedMessages;
    
    return _receivedMessages.where((msg) => 
      msg.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  // Export messages as string
  String exportMessages() {
    return _receivedMessages.join('\n');
  }

  // Get statistics
  Map<String, int> getMessageStats() {
    int hexCount = getMessagesByType('hex').length;
    int asciiCount = getMessagesByType('ascii').length;
    int manualCount = getMessagesByType('manual').length;
    
    return {
      'total': _receivedMessages.length,
      'hex': hexCount,
      'ascii': asciiCount,
      'manual': manualCount,
    };
  }

  @override
  void dispose() {
    _settingProviderSubscription?.cancel();
    _settingProvider?.removeListener(_onSettingProviderChanged);
    _scrollController?.dispose();
    super.dispose();
  }
}