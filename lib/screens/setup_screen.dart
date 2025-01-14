import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:power_diyala/data_helper/data_manager.dart';
import 'package:power_diyala/screens/main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:power_diyala/data_helper/database_helper.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  SetupScreenState createState() => SetupScreenState();
}

class SetupScreenState extends State<SetupScreen> {
  final Logger logger =
      kDebugMode ? Logger() : Logger(printer: PrettyPrinter());
  int _currentStep = 0;
  bool _permissionGranted = false; // Track permission status
  bool _dbReplaced = false; // Track database replacement status
  bool _dataLoadedCorrectly = false; // Track if data loaded correctly
  bool _isSetupComplete = false; // Track if setup is complete
  bool _isLoading = true;

  List<Map<String, dynamic>> _dataFromDatabase = [];

  @override
  void initState() {
    super.initState();
    _loadSetupState();
  }

  Future<void> _loadSetupState() async {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    final isSetupComplete = await prefs.getBool('isSetupComplete') ?? false;
    final permissionGranted = await prefs.getBool('permissionGranted') ?? false;
    final dbReplaced = await prefs.getBool('dbReplaced') ?? false;
    final dataLoadedCorrectly =
        await prefs.getBool('dataLoadedCorrectly') ?? false;
    setState(() {
      _isSetupComplete = isSetupComplete;
      _permissionGranted = permissionGranted;
      _dbReplaced = dbReplaced;
      _dataLoadedCorrectly = dataLoadedCorrectly;
    });
    // If setup is already complete, load data directly
    if (_isSetupComplete) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSetupState() async {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();

    await prefs.setBool('isSetupComplete', _isSetupComplete);
    await prefs.setBool('permissionGranted', _permissionGranted);
    await prefs.setBool('dbReplaced', _dbReplaced);
    await prefs.setBool('dataLoadedCorrectly', _dataLoadedCorrectly);
  }

  List<Step> _getSteps() {
    return [
      Step(
        title: const Text('Permission Request'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('We need permission to manage external storage.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final localContext = context; // Capture the BuildContext

                // Request external storage permission
                await DBHelper.requestManageExternalStoragePermission(
                    localContext);

                // Check permission status
                var status = await Permission.manageExternalStorage.status;
                if (!localContext.mounted) return;
                if (status.isGranted) {
                  setState(() {
                    _permissionGranted = true; // Update permission status
                    _currentStep++; // Move to next step
                  });
                } else {
                  logger.e("Manage external storage permission not granted.");
                  showDialog(
                      context: localContext,
                      builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  20), // Round all corners
                              child: Container(
                                color: Theme.of(context).cardColor,
                                child: SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.5,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            height: 120,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .tertiary,
                                          ),
                                          const Column(
                                            children: [
                                              Icon(Icons.warning,
                                                  color: Colors.white,
                                                  size: 32),
                                              SizedBox(height: 8),
                                              Text(
                                                'OOPs...',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Permission Denied!',
                                                style: TextStyle(
                                                    color: Colors.white),
                                              )
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 30),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .tertiary,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 8, 16, 8),
                                          child: const Text(
                                            'Try again',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ));
                }
              },
              child: const Text('Request Permission'),
            ),
          ],
        ),
        isActive: true,
      ),
      Step(
        title: const Text('Choose and Replace Database'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Please select a database file to replace the existing one.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final localContext = context; // Capture the BuildContext

                // Delete existing database before selecting a new one
                try {
                  await DatabaseHelper
                      .deleteDatabase(); // Delete existing database
                  if (!localContext.mounted) return;

                  // Proceed to pick and replace the database and capture the result
                  bool fileSelected =
                      await DBHelper.pickAndReplaceDatabase(localContext);

                  // Check if the data loaded correctly after replacement
                  bool isDataValid =
                      await DBHelper.checkDatabaseData(fileSelected);

                  if (isDataValid) {
                    setState(() {
                      _dbReplaced = true; // Update database replacement status
                      _dataLoadedCorrectly = true; // Update data loading status
                      _currentStep++; // Move to next step after successful operation
                    });

                    // Load data from the newly replaced database
                    _dataFromDatabase = await DatabaseHelper.loadInfoData();
                  } else {
                    logger.e("Database replaced but data validation failed.");
                    if (!localContext.mounted) return;
                    showDialog(
                        context: localContext,
                        builder: (context) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                    20), // Round all corners
                                child: Container(
                                  color: Theme.of(context).cardColor,
                                  child: SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * 0.5,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              height: 120,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .tertiary,
                                            ),
                                            const Column(
                                              children: [
                                                Icon(Icons.warning,
                                                    color: Colors.white,
                                                    size: 32),
                                                SizedBox(height: 8),
                                                Text(
                                                  'OOPs...',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Data Validation Failed!',
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                )
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 30),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .tertiary,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.fromLTRB(
                                                16, 8, 16, 8),
                                            child: const Text(
                                              'Try again',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ));
                  }
                } catch (e) {
                  logger.e("Failed to delete or replace the database: $e");
                  if (!localContext.mounted) return;
                  showDialog(
                    context: localContext,
                    builder: (context) => AlertDialog(
                      title: const Text('Database Operation Failed'),
                      content: const Text(
                          'Failed to delete or replace the database. Please try again.'),
                      actions: [
                        TextButton(
                          child: const Text('OK'),
                          onPressed: () => Navigator.of(localContext).pop(),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Text('Select Database'),
            )
          ],
        ),
        isActive: _permissionGranted, // Only active if permission is granted
      ),
      Step(
        title: const Text('Data Overview'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version:'),
            if (_dataFromDatabase.isEmpty)
              const Text('No data loaded.')
            else
              ..._dataFromDatabase.map((data) => ListTile(
                    title: Text(data['last_update'] ?? 'Unknown'),
                  )),
          ],
        ),
        isActive: _dbReplaced &&
            _dataLoadedCorrectly, // Only active if db replaced and data loaded correctly
      ),
    ];
  }

  void _onStepContinue() async {
    if (_currentStep == 0 && !_permissionGranted) return;

    if (_currentStep == 1 && (!_dbReplaced || !_dataLoadedCorrectly)) return;

    if (_currentStep < _getSteps().length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      setState(() {
        _isSetupComplete = true;
      });

      await _saveSetupState();
      await DataManager().loadAllData();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(
        'Setup',
        style: Theme.of(context).textTheme.titleLarge,
      )),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          child: Stepper(
            currentStep: _currentStep,
            steps: _getSteps(),
            onStepContinue: _onStepContinue,
            onStepCancel: _onStepCancel,
            controlsBuilder: (BuildContext context, ControlsDetails details) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: const Text('Next'),
                  ),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ],
              );
            },
            type: StepperType.vertical,
          ),
        ),
      ),
    );
  }
}
