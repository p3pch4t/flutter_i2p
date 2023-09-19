library flutter_i2p;

import 'package:flutter/material.dart';

class I2pConfigPage extends StatelessWidget {
  const I2pConfigPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("I2P config"),
      ),
      body: const Center(
        child: Text("I2pd config is not currently available."),
      ),
    );
  }
}
