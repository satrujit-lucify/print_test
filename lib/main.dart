import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Bluetooth Printer Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHome(),
    );
  }
}

class MyHome extends StatefulWidget {
  const MyHome({super.key});

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  bool isPermissionGranted = false;
  List<BluetoothInfo> devices = [];
  BluetoothInfo? connectedDevice;
  String? connectingToDevice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermissions());
  }

  Future<void> _checkPermissions() async {
    // Request all required Bluetooth permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ].request();

    // Check if all necessary permissions are granted
    bool allGranted = statuses.values.every((status) => status.isGranted);

    setState(() {
      isPermissionGranted = allGranted;
    });

    if (isPermissionGranted) {
      // Check if Bluetooth is enabled
      final bool isBluetoothEnabled =
          await PrintBluetoothThermal.bluetoothEnabled;
      debugPrint("Bluetooth Enabled: $isBluetoothEnabled");

      if (!isBluetoothEnabled) {
        debugPrint("Bluetooth is disabled. Please enable it.");
      }
    } else {
      debugPrint("Required permissions are not granted.");
    }
  }

  Future<void> pairedBluetooths() async {
    debugPrint("Getting paired Bluetooth devices");
    final result = await PrintBluetoothThermal.pairedBluetooths;
    setState(() {
      devices = result;
    });

    if (result.isEmpty) {
      debugPrint("No Bluetooth devices found");
    } else {
      for (BluetoothInfo info in result) {
        debugPrint("Device Name: ${info.name}");
      }
    }
  }

  Future<bool> connect(BluetoothInfo device) async {
    setState(() {
      connectingToDevice = device.macAdress;
    });
    bool result = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.macAdress);
    if (result) {
      setState(() {
        connectedDevice = device;
      });
    }
    setState(() {
      connectingToDevice = null;
    });
    return result;
  }

  Future<void> printTest() async {
    if (connectedDevice == null) {
      debugPrint("No device connected");
      return;
    }

    bool connectionStatus = await PrintBluetoothThermal.connectionStatus;
    if (connectionStatus) {
      List<int> ticket = await generateTestTicket();
      final result = await PrintBluetoothThermal.writeBytes(ticket);
      debugPrint("Print result: $result");
    } else {
      debugPrint("Printer not connected.");
    }
  }

  Future<List<int>> generateTestTicket() async {
    List<int> bytes = [];
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);

    bytes += generator.setGlobalFont(PosFontType.fontA);
    bytes += generator.reset();

    bytes += generator.text(
        'Regular: aA bB cC dD eE fF gG hH iI jJ kK lL mM nN oO pP qQ rR sS tT uU vV wW xX yY zZ',
        styles: const PosStyles());
    bytes += generator.text('Special 1: ñÑ àÀ èÈ éÉ üÜ çÇ ôÔ',
        styles: const PosStyles(codeTable: 'CP1252'));
    bytes += generator.text(
      'Special 2: blåbærgrød',
      styles: const PosStyles(codeTable: 'CP1252'),
    );

    bytes += generator.text('Bold text', styles: const PosStyles(bold: true));
    bytes +=
        generator.text('Reverse text', styles: const PosStyles(reverse: true));
    bytes += generator.text('Underlined text',
        styles: const PosStyles(underline: true), linesAfter: 1);
    bytes += generator.text('Align left',
        styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Align center',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Align right',
        styles: const PosStyles(align: PosAlign.right), linesAfter: 1);

    bytes += generator.row([
      PosColumn(
        text: 'col3',
        width: 3,
        styles: const PosStyles(align: PosAlign.center, underline: true),
      ),
      PosColumn(
        text: 'col6',
        width: 6,
        styles: const PosStyles(align: PosAlign.center, underline: true),
      ),
      PosColumn(
        text: 'col3',
        width: 3,
        styles: const PosStyles(align: PosAlign.center, underline: true),
      ),
    ]);

    final List<int> barData = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 4];
    bytes += generator.barcode(Barcode.upcA(barData));

    bytes += generator.qrcode('example.com');
    bytes += generator.text('Text size 50%',
        styles: const PosStyles(fontType: PosFontType.fontB));
    bytes += generator.text('Text size 100%',
        styles: const PosStyles(fontType: PosFontType.fontA));
    bytes += generator.text('Text size 200%',
        styles: const PosStyles(
            height: PosTextSize.size2, width: PosTextSize.size2));

    bytes += generator.feed(2);
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(isPermissionGranted
              ? 'Permissions Granted'
              : 'Permissions Not Granted'),
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: isPermissionGranted && connectedDevice != null
                  ? () async {
                      await printTest();
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.bluetooth),
              onPressed: isPermissionGranted
                  ? () async {
                      await pairedBluetooths();
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await _checkPermissions();
              },
            ),
          ]),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ...devices.map(
              (device) => ListTile(
                trailing: connectingToDevice == device.macAdress
                    ? const CircularProgressIndicator()
                    : connectedDevice?.macAdress == device.macAdress
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                title: Text(device.name),
                subtitle: Text(device.macAdress),
                onTap: () async {
                  await connect(device);
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isPermissionGranted
                      ? () async {
                          await pairedBluetooths();
                        }
                      : null,
                  child: const Text('Get Paired Devices'),
                ),
                if (connectedDevice != null)
                  OutlinedButton(
                    onPressed: isPermissionGranted
                        ? () async {
                            await printTest();
                          }
                        : null,
                    child: const Text('Print'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
