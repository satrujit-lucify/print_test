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
      title: 'Flutter Demo',
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkPermissions(),
    );
  }

  Future<void> _checkPermissions() async {
    bool bluetoothGranted = await Permission.bluetooth.isGranted;
    bool nearbyDevicesGranted = await Permission.nearbyWifiDevices.isGranted;

    if (!bluetoothGranted /*|| !bluetoothConnectGranted || !bluetoothScanGranted */ ||
        !nearbyDevicesGranted) {
      await [
        Permission.bluetooth,
        Permission.nearbyWifiDevices,
      ].request();
    }

    // Update permission state
    setState(() {
      isPermissionGranted =
          bluetoothGranted && /* bluetoothConnectGranted && bluetoothScanGranted && */
              nearbyDevicesGranted;
    });

    // Check if Bluetooth is enabled
    final bool isBluetoothEnabled =
        await PrintBluetoothThermal.bluetoothEnabled;
    debugPrint("Bluetooth Enabled: $isBluetoothEnabled");
  }

  Future<void> pairedBluetooths() async {
    debugPrint("Getting paired Bluetooth devices");
    final result = await PrintBluetoothThermal.pairedBluetooths;
    if (result.isEmpty) {
      debugPrint("No Bluetooth devices found");
    } else {
      for (BluetoothInfo info in result) {
        debugPrint("Device Name: ${info.name}");
      }
    }
    setState(() {
      devices = result;
    });
  }

  Future<bool> connect(BluetoothInfo device) async {
    bool result =
        await PrintBluetoothThermal.connect(macPrinterAddress: device.macAdress);
    if (result) {
      setState(() {
        connectedDevice = device;
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isPermissionGranted
            ? 'Permissions granted'
            : 'Permissions not granted'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ...devices.map(
              (device) => ListTile(
                trailing: connectedDevice?.macAdress == device.macAdress ? const Icon(Icons.check_circle, color: Colors.green): null,
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
                      : null, // Disable button if permissions are not granted
                  child: const Text('Get Paired Devices'),
                ),
                if (connectedDevice != null) ...[
                OutlinedButton(
                  onPressed: isPermissionGranted
                      ? () async {
                          await printTest();
                        }
                      : null, // Disable button if permissions are not granted
                  child: const Text('Print'),
                ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}


Future<void> printTest() async {
    bool conecctionStatus = await PrintBluetoothThermal.connectionStatus;
    if (conecctionStatus) {
      List<int> ticket = await testTicket();
      final result = await PrintBluetoothThermal.writeBytes(ticket);
      print("print result: $result");
    } else {
      //no connected
    }
}

Future<List<int>> testTicket() async {
    List<int> bytes = [];
    // Using default profile
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    //bytes += generator.setGlobalFont(PosFontType.fontA);
    bytes += generator.reset();

    bytes += generator.text('Regular: aA bB cC dD eE fF gG hH iI jJ kK lL mM nN oO pP qQ rR sS tT uU vV wW xX yY zZ', styles: const PosStyles());
    bytes += generator.text('Special 1: ñÑ àÀ èÈ éÉ üÜ çÇ ôÔ', styles: const PosStyles(codeTable: 'CP1252'));
    bytes += generator.text(
      'Special 2: blåbærgrød',
      styles: const PosStyles(codeTable: 'CP1252'),
    );

    bytes += generator.text('Bold text', styles: const PosStyles(bold: true));
    bytes += generator.text('Reverse text', styles: const PosStyles(reverse: true));
    bytes += generator.text('Underlined text', styles: const PosStyles(underline: true), linesAfter: 1);
    bytes += generator.text('Align left', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Align center', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Align right', styles: const PosStyles(align: PosAlign.right), linesAfter: 1);

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

    //barcode
    final List<int> barData = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 4];
    bytes += generator.barcode(Barcode.upcA(barData));

    //QR code
    bytes += generator.qrcode('example.com');

    bytes += generator.text(
      'Text size 50%',
      styles: const PosStyles(
        fontType: PosFontType.fontB,
      ),
    );
    bytes += generator.text(
      'Text size 100%',
      styles: const PosStyles(
        fontType: PosFontType.fontA,
      ),
    );
    bytes += generator.text(
      'Text size 200%',
      styles: const PosStyles(
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += generator.feed(2);
    //bytes += generator.cut();
    return bytes;
}
