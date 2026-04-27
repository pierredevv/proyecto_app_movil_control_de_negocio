import 'dart:typed_data';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'thermal_printer_connection.dart';

class BluetoothPrinterConnection implements ThermalPrinterConnection {
  @override
  Future<List<PrinterDevice>> scan() async {
    try {
      final List<BluetoothInfo> pairedDevices = await PrintBluetoothThermal.pairedBluetooths;
      return pairedDevices.map((d) => PrinterDevice(name: d.name, address: d.macAdress)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> connect(String address) async {
    try {
      // Return true if already connected to this address
      bool isConnected = await PrintBluetoothThermal.connectionStatus;
      if (isConnected) {
        // We don't have a way to check WHICH MAC is connected natively in the plugin easily,
        // but assuming it's the one we want.
        // We could disconnect first, but to avoid delay we just return true.
        // For robustness, maybe we should disconnect and reconnect.
        await disconnect();
      }
      return await PrintBluetoothThermal.connect(macPrinterAddress: address);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> sendImage(Uint8List imageBytes) async {
    try {
      bool isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) return false;

      // The print_bluetooth_thermal package expects raw ESC/POS bytes.
      // Since we are generating a rasterized ESC/POS image payload beforehand (including init/cut commands),
      // we can just send those raw bytes directly.
      bool success = await PrintBluetoothThermal.writeBytes(imageBytes);
      return success;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
  }
}
