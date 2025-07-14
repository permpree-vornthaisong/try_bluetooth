import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/DisplayHomeProvider.dart';
import 'package:try_bluetooth/providers/FormulaProvider.dart';
import 'package:try_bluetooth/providers/SettingProvider.dart';

class DisplayHomePage extends StatefulWidget {
  const DisplayHomePage({Key? key}) : super(key: key);

  @override
  State<DisplayHomePage> createState() => _DisplayHomePageState();
}

class _DisplayHomePageState extends State<DisplayHomePage>
    with WidgetsBindingObserver {
  final ValueNotifier<bool> isAutoSaveActive = ValueNotifier(false);
  bool _isWeightSaved = false;
  List<double> _lastWeights = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<FormulaProvider>(context, listen: false);
      provider.initialize(context);
      final displayProvider = Provider.of<DisplayHomeProvider>(
        context,
        listen: false,
      );
      isAutoSaveActive.value =
          displayProvider.isAutoSaveMode; // ซิงโครไนซ์สถานะเริ่มต้น
      displayProvider.initialize(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final settingProvider = Provider.of<SettingProvider>(
      context,
      listen: false,
    );
    settingProvider.removeListener(_onWeightChange);
    isAutoSaveActive.dispose();
    super.dispose();
  }

  void toggleAutoSave(SettingProvider settingProvider) {
    final displayProvider = Provider.of<DisplayHomeProvider>(
      context,
      listen: false,
    );

    // If currently active, stop auto save
    if (isAutoSaveActive.value) {
      settingProvider.removeListener(_onWeightChange);
      _lastWeights.clear();
      _isWeightSaved = false;
      displayProvider.setAutoSaveMode(false);
      isAutoSaveActive.value = false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto save stopped'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Validation checks before starting auto save
    if (settingProvider.connectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect to a device first'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (displayProvider.selectedFormula == null ||
        displayProvider.selectedFormula == DisplayHomeProvider.readonlyValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid formula first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Start auto save
    settingProvider.addListener(_onWeightChange);
    displayProvider.setAutoSaveMode(true);
    isAutoSaveActive.value = true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Auto save started - weights will be saved automatically when stable',
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _onWeightChange() {
    if (!isAutoSaveActive.value) return;

    final settingProvider = Provider.of<SettingProvider>(
      context,
      listen: false,
    );
    final newWeight = settingProvider.currentRawValue ?? 0.0;

    _lastWeights.add(newWeight);
    if (_lastWeights.length > 10) _lastWeights.removeAt(0);

    if (_isWeightSaved) {
      if (newWeight <= 0.00) {
        _isWeightSaved = false;
      }
      return;
    }

    if (_lastWeights.length == 10 &&
        _lastWeights.every((w) => (w - _lastWeights.first).abs() < 0.01) &&
        newWeight >= 0.01) {
      _saveWeightData(
        Provider.of<DisplayHomeProvider>(context, listen: false),
        Provider.of<FormulaProvider>(context, listen: false),
        settingProvider,
      );
      _isWeightSaved = true;
    }
  }

  Map<String, dynamic> _parseWeightData(String rawData) {
    if (rawData.length < 13) return {};

    String status = rawData.substring(0, 1);
    bool isStable = status == 'S';
    String weightStr = rawData.substring(1, 7);
    double weight = double.tryParse(weightStr) ?? 0.0;
    String tareStr = rawData.substring(8, 14);
    double tare = double.tryParse(tareStr) ?? 0.0;

    return {
      'status': status,
      'isStable': isStable,
      'weight': weight,
      'tare': tare,
      'rawData': rawData,
    };
  }

  Future<void> _saveWeightData(
    DisplayHomeProvider displayProvider,
    FormulaProvider formulaProvider,
    SettingProvider settingProvider,
  ) async {
    if (displayProvider.selectedFormula == null ||
        displayProvider.selectedFormula == DisplayHomeProvider.readonlyValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a formula first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (settingProvider.currentRawValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No weight data available'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final selectedFormulaName = displayProvider.selectedFormula!;
    final tableName =
        'formula_${selectedFormulaName.toLowerCase().replaceAll(' ', '_')}';
    final currentWeight = double.parse(
      settingProvider.currentRawValue!.toStringAsFixed(2),
    );

    final existingColumns = await formulaProvider.getTableColumns(tableName);
    bool hasWeightColumn = existingColumns.any(
      (col) => col.toLowerCase().contains('weight'),
    );
    String weightColumnName = 'weight';

    if (!hasWeightColumn) {
      final addColumnSuccess = await formulaProvider.addColumnToTable(
        tableName,
        'weight',
        'REAL',
      );
      if (!addColumnSuccess) throw Exception('Failed to add weight column');
    } else {
      weightColumnName = existingColumns.firstWhere(
        (col) => col.toLowerCase().contains('weight'),
      );
    }

    final Map<String, dynamic> dataToInsert = {weightColumnName: currentWeight};
    final success = await formulaProvider.createRecord(
      tableName: tableName,
      data: dataToInsert,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Weight ${currentWeight.toStringAsFixed(2)} kg saved to $selectedFormulaName!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      throw Exception('Database save failed');
    }
  }

  Widget _buildAutoSaveIndicator() {
    return ValueListenableBuilder<bool>(
      valueListenable: isAutoSaveActive,
      builder: (context, active, _) {
        if (!active) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.autorenew, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              const Text(
                'AUTO SAVE ON',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Display Home'),
        backgroundColor: Color(0xFF5A9B9E),
        // actions: [
        //   IconButton(
        //     onPressed: () => showCreateCustomerDialog(context),
        //     icon: const Icon(Icons.add),
        //     tooltip: 'Create New Formula',
        //   ),
        // ],
      ),
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 60,
            color: const Color(0xFF5A9B9E),
            child: Row(
              children: [
                Expanded(
                  child: Consumer<SettingProvider>(
                    builder: (context, settingProvider, _) {
                      final isConnected =
                          settingProvider.connectedDevice != null;
                      return Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isConnected ? Colors.green : Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isConnected ? Icons.check_circle : Icons.circle,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isConnected ? 'Connected' : 'Connect',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Consumer<DisplayHomeProvider>(
                    builder: (context, provider, child) {
                      final currentValue = provider.selectedFormula;
                      final availableItems = provider.availableFormulas;

                      String? validValue = currentValue;
                      if (currentValue != null &&
                          !availableItems.any(
                            (item) => item['value'] == currentValue,
                          )) {
                        validValue = DisplayHomeProvider.readonlyValue;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          provider.setSelectedFormula(
                            DisplayHomeProvider.readonlyValue,
                          );
                        });
                      }

                      return Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButton<String>(
                          value: validValue,
                          isExpanded: true,
                          underline: Container(),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey,
                          ),
                          items:
                              availableItems.map((formula) {
                                final isReadonly =
                                    formula['isReadonly'] == true;
                                return DropdownMenuItem<String>(
                                  value: formula['value'] as String,
                                  child: Row(
                                    children: [
                                      Icon(
                                        isReadonly
                                            ? Icons.visibility_off
                                            : Icons.calculate,
                                        size: 16,
                                        color:
                                            isReadonly
                                                ? Colors.grey
                                                : Colors.blue,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          isReadonly
                                              ? 'Read only'
                                              : formula['name'] as String,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                isReadonly
                                                    ? Colors.grey
                                                    : Colors.black,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              provider.setSelectedFormula(newValue);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Consumer<SettingProvider>(
                    builder: (context, settingProvider, child) {
                      return Row(
                        children: [
                          Expanded(
                            child: _buildButton(
                              'TARE',
                              onPressed: () async {
                                if (settingProvider.connectedDevice != null) {
                                  BluetoothCharacteristic? writeCharacteristic;
                                  for (var serviceEntry
                                      in settingProvider
                                          .characteristics
                                          .entries) {
                                    for (var char in serviceEntry.value) {
                                      if (char.properties.write ||
                                          char
                                              .properties
                                              .writeWithoutResponse) {
                                        writeCharacteristic = char;
                                        break;
                                      }
                                    }
                                    if (writeCharacteristic != null) break;
                                  }
                                  if (writeCharacteristic != null) {
                                    String message = "TARE";
                                    List<int> data = message.codeUnits;
                                    await settingProvider.writeCharacteristic(
                                      writeCharacteristic,
                                      data,
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildButton(
                              'ZERO',
                              onPressed: () async {
                                if (settingProvider.connectedDevice != null) {
                                  BluetoothCharacteristic? writeCharacteristic;
                                  for (var serviceEntry
                                      in settingProvider
                                          .characteristics
                                          .entries) {
                                    for (var char in serviceEntry.value) {
                                      if (char.properties.write ||
                                          char
                                              .properties
                                              .writeWithoutResponse) {
                                        writeCharacteristic = char;
                                        break;
                                      }
                                    }
                                    if (writeCharacteristic != null) break;
                                  }
                                  if (writeCharacteristic != null) {
                                    String message = "ZERO";
                                    List<int> data = message.codeUnits;
                                    await settingProvider.writeCharacteristic(
                                      writeCharacteristic,
                                      data,
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    flex: 2,
                    child: Consumer<SettingProvider>(
                      builder: (context, settingProvider, _) {
                        Map<String, dynamic> parsed = {};
                        if (settingProvider.rawReceivedText != null &&
                            settingProvider.rawReceivedText!.isNotEmpty) {
                          parsed = _parseWeightData(
                            settingProvider.rawReceivedText!,
                          );
                        }
                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D3E50),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Auto save indicator
                              _buildAutoSaveIndicator(),
                              if (isAutoSaveActive.value)
                                const SizedBox(height: 8),

                              Text(
                                'kg',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                settingProvider.currentRawValue != null
                                    ? settingProvider.currentRawValue!
                                        .toStringAsFixed(2)
                                    : '0.00',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 64,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (parsed.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        parsed['isStable'] == true
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          parsed['isStable'] == true
                                              ? Colors.green.withOpacity(0.5)
                                              : Colors.orange.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        parsed['isStable'] == true
                                            ? Icons.check_circle
                                            : Icons.pending,
                                        size: 16,
                                        color:
                                            parsed['isStable'] == true
                                                ? Colors.green[300]
                                                : Colors.orange[300],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        parsed['isStable'] == true
                                            ? 'STABLE'
                                            : 'UNSTABLE',
                                        style: TextStyle(
                                          color:
                                              parsed['isStable'] == true
                                                  ? Colors.green[300]
                                                  : Colors.orange[300],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (parsed['tare'] != null &&
                                    parsed['tare'] > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tare: ${(parsed['tare'] as double).toStringAsFixed(2)} kg',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Raw: ${parsed['rawData']}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Consumer3<
                    DisplayHomeProvider,
                    FormulaProvider,
                    SettingProvider
                  >(
                    builder: (
                      context,
                      displayProvider,
                      formulaProvider,
                      settingProvider,
                      _,
                    ) {
                      return SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: _buildButton(
                          'SAVE WEIGHT',
                          backgroundColor: const Color(0xFF4CAF50),
                          onPressed: () async {
                            await _saveWeightData(
                              displayProvider,
                              formulaProvider,
                              settingProvider,
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<bool>(
                    valueListenable: isAutoSaveActive,
                    builder: (context, active, _) {
                      return Consumer<SettingProvider>(
                        builder: (context, settingProvider, _) {
                          return SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: _buildButton(
                              active ? 'STOP AUTO SAVE' : 'START AUTO SAVE',
                              backgroundColor:
                                  active ? Colors.red : const Color(0xFF2196F3),
                              onPressed: () => toggleAutoSave(settingProvider),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    String text, {
    Color? backgroundColor,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              onPressed == null
                  ? Colors.grey
                  : (backgroundColor ?? const Color(0xFF2D3E50)),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
