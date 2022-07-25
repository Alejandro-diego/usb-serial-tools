import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';


class HomePage extends StatefulWidget {
   const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage>  createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  UsbPort? _port;
  String _status = "Idle";
  List<Widget> _ports = [];
  final List<Widget> _serialData = [];

  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;
  UsbDevice? _device;

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  Future<bool> _connectTo(device) async {
    _serialData.clear();

    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }

    if (_transaction != null) {
      _transaction!.dispose();
      _transaction = null;
    }

    if (_port != null) {
      _port!.close();
      _port = null;
    }

    if (device == null) {
      _device = null;
      setState(() {
        _status = "Disconnected";
      });
      return true;
    }

    _port = await device.create();
    if (await (_port!.open()) != true) {
      setState(
        () {
          _status = "Failed to open port";
        },
      );
      return false;
    }
    _device = device;

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
        115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(
        _port!.inputStream as Stream<Uint8List>, Uint8List.fromList([13, 10]));

    _subscription = _transaction!.stream.listen(
      (String line) {
        setState(
          () {
            _serialData.add(Text(line));
            if (_serialData.length > 20) {
              _serialData.removeAt(0);
            }
          },
        );
      },
    );

    setState(
      () {
        _status = "Connected";
      },
    );
    return true;
  }

  void _getPorts() async {
    _ports = [];
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (!devices.contains(_device)) {
      _connectTo(null);
    }
   

    for (var device in devices) {
      _ports.add(
        ListTile(
          leading: const Icon(Icons.usb),
          title: Text(device.productName!),
          //subtitle: Text(device.manufacturerName!),
          trailing: ElevatedButton(
            child: Text(_device == device ? "Disconnect" : "Connect"),
            onPressed: () {
              _connectTo(_device == device ? null : device).then(
                (res) {
                  _getPorts();
                },
              );
            },
          ),
        ),
      );
    }

    
  }

  @override
  void initState() {
    super.initState();

    UsbSerial.usbEventStream!.listen(
      (UsbEvent event) {
        _getPorts();
      },
    );

    _getPorts();
  }

  @override
  void dispose() {
    super.dispose();
    _connectTo(null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IOTech Serial Tool '),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Text(
                  _ports.isNotEmpty
                      ? "Available Serial Ports"
                      : "No serial devices available",
                  style: Theme.of(context).textTheme.headline6),
              ..._ports,
              Text('Status: $_status\n'),
              Text('info: ${_port.toString()}\n'),
              Column(
                children: [
                  SizedBox(
                    height: 150,
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: Column(
                      children: [
                        TextField(
                          controller: _ssidController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Ssid',
                          ),
                        ),
                        const Spacer(),
                        TextField(
                          controller: _passController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Pass',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _port == null
                    ? null
                    : () async {
                        if (_port == null) {
                          return;
                        }
                        String data =
                          "${_ssidController.text},${_passController.text},";
                        //    "${_ssidController.text},${_passController.text},\r\n";
                        await _port!.write(
                          Uint8List.fromList(data.codeUnits),
                        );
                      
                        _ssidController.text = "";
                        _passController.text = "";
                      },
                child: const Text("Send"),
              ),
              Text("Result Data", style: Theme.of(context).textTheme.headline6),
              Container(
                width: double.infinity,
                height: 400,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._serialData,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
