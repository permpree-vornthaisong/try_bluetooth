import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'FormulaProvider.dart';

class DisplayHomeProvider extends ChangeNotifier {
  FormulaProvider? _formulaProvider;
  List<Map<String, dynamic>> _availableFormulas = [];
  String? _selectedFormula;

  // Constants for readonly option
  static const String readonlyValue = 'readonly';
  static const String readonlyDisplayName = '-- Select Formula (Read Only) --';

  List<Map<String, dynamic>> get availableFormulas => _getFormulasWithReadonly();
  String? get selectedFormula => _selectedFormula;

  // Helper getter to get formula names only for backward compatibility
  List<String> get availableFormulaNames => 
      _getFormulasWithReadonly().map((formula) => formula['value'] as String).toList();

  // Get formulas with readonly option at the top
  List<Map<String, dynamic>> _getFormulasWithReadonly() {
    final readonlyOption = {
      'id': -1,
      'name': readonlyDisplayName,
      'value': readonlyValue,
      'columnCount': 0,
      'description': 'Read-only mode - no formula selected',
      'isReadonly': true,
    };

    return [readonlyOption, ..._availableFormulas];
  }

  Future<void> initialize(BuildContext context) async {
    _formulaProvider = Provider.of<FormulaProvider>(context, listen: false);
    _formulaProvider?.addListener(_onFormulaProviderChanged);
    _loadFormulaNames();
  }

  void _onFormulaProviderChanged() {
    _loadFormulaNames();
  }

  void _loadFormulaNames() {
    if (_formulaProvider?.isInitialized == true) {
      final newFormulas = _formulaProvider!.getFormulaDropdownItems();
      
      // ตรวจสอบว่า formula ที่เลือกอยู่ยังมีอยู่หรือไม่
      if (_selectedFormula != null && 
          _selectedFormula != readonlyValue &&
          !newFormulas.any((formula) => formula['value'] == _selectedFormula)) {
        // ถ้า formula ที่เลือกถูกลบแล้ว ให้ reset เป็น readonly
        _selectedFormula = readonlyValue;
        debugPrint('📝 [DisplayHomeProvider] Selected formula was deleted, reset to readonly');
      }
      
      _availableFormulas = newFormulas;
      
      // Default selection - set to readonly if no previous selection
      if (_selectedFormula == null) {
        _selectedFormula = readonlyValue;
      }
      
      debugPrint('📝 [DisplayHomeProvider] Loaded ${_availableFormulas.length} formulas (+ readonly option)');
      notifyListeners();
    }
  }

  void setSelectedFormula(String? formula) {
    _selectedFormula = formula;
    debugPrint('📝 [DisplayHomeProvider] Selected formula: $formula');
    notifyListeners();
  }

  // Helper method to get formula details by name
  Map<String, dynamic>? getSelectedFormulaDetails() {
    if (_selectedFormula == null || _selectedFormula == readonlyValue) return null;
    
    try {
      return _availableFormulas.firstWhere(
        (formula) => formula['value'] == _selectedFormula,
      );
    } catch (e) {
      debugPrint('❌ [DisplayHomeProvider] Formula details not found for: $_selectedFormula');
      // ถ้าไม่เจอ formula ให้ reset เป็น readonly
      _selectedFormula = readonlyValue;
      notifyListeners();
      return null;
    }
  }

  // Helper method to get the table name for the selected formula
  String? getSelectedFormulaTableName() {
    if (_selectedFormula == null || _selectedFormula == readonlyValue) return null;
    return 'formula_${_selectedFormula!.toLowerCase().replaceAll(' ', '_')}';
  }

  // Helper method to get column count for selected formula
  int? getSelectedFormulaColumnCount() {
    final details = getSelectedFormulaDetails();
    return details?['columnCount'] as int?;
  }

  // Helper method to get description for selected formula
  String? getSelectedFormulaDescription() {
    final details = getSelectedFormulaDetails();
    return details?['description'] as String?;
  }

  // Helper method to check if any formulas are available
  bool get hasFormulas => _availableFormulas.isNotEmpty;

  // Helper method to check if currently in readonly mode
  bool get isReadonlyMode => _selectedFormula == readonlyValue || _selectedFormula == null;

  // Helper method to check if a valid formula is selected
  bool get hasValidFormulaSelected => 
      _selectedFormula != null && 
      _selectedFormula != readonlyValue && 
      _availableFormulas.any((f) => f['value'] == _selectedFormula);

  // Helper method to get formula ID by name
  int? getFormulaId(String formulaName) {
    if (formulaName == readonlyValue) return null;
    
    try {
      final formula = _availableFormulas.firstWhere(
        (f) => f['value'] == formulaName,
      );
      return formula['id'] as int?;
    } catch (e) {
      debugPrint('❌ [DisplayHomeProvider] Formula ID not found for: $formulaName');
      return null;
    }
  }

  // Helper method to validate current selection
  void validateCurrentSelection() {
    if (_selectedFormula != null && 
        _selectedFormula != readonlyValue &&
        !_availableFormulas.any((f) => f['value'] == _selectedFormula)) {
      debugPrint('⚠️ [DisplayHomeProvider] Current selection is invalid, resetting to readonly');
      _selectedFormula = readonlyValue;
      notifyListeners();
    }
  }

  // Helper method to reset to readonly
  void resetToReadonly() {
    _selectedFormula = readonlyValue;
    debugPrint('🔄 [DisplayHomeProvider] Reset to readonly mode');
    notifyListeners();
  }

  @override
  void dispose() {
    _formulaProvider?.removeListener(_onFormulaProviderChanged);
    debugPrint('🧹 [DisplayHomeProvider] Disposing DisplayHomeProvider');
    super.dispose();
  }
}