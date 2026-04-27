import 'dart:typed_data';

class PrinterDevice {
  final String name;
  final String address;

  PrinterDevice({required this.name, required this.address});
}

abstract class ThermalPrinterConnection {
  /// Connects to a printer using its address (MAC, IP, or USB Path)
  Future<bool> connect(String address);

  /// Sends a rasterized 1-bit image to the printer
  Future<bool> sendImage(Uint8List imageBytes);

  /// Disconnects from the current printer
  Future<void> disconnect();

  /// Scans for available printers of this connection type
  Future<List<PrinterDevice>> scan();
}
