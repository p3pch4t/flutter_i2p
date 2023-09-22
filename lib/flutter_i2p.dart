library flutter_i2p;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_i2p/dart_i2p.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/core.dart';
import 'package:xterm/ui.dart';

class I2pConfigPage extends StatefulWidget {
  const I2pConfigPage({Key? key, required this.i2pdConf}) : super(key: key);
  final I2pdConf i2pdConf;

  @override
  State<I2pConfigPage> createState() => _I2pConfigPageState();
}

class _I2pConfigPageState extends State<I2pConfigPage> {
  final terminal = Terminal();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then(
      (_) {
        if (mounted) unawaited(initLogView());
      },
    );
  }

  Future<void> initLogView() async {
    int curIndex = 0;
    if (widget.i2pdConf.logfile == null) {
      terminal.write(
        "CRIT: i2p.i2pdConf.logfile is null, we have no evidence "
        "i2pd logging anything.",
      );
      return;
    }

    // TODO(mrcyjanek): I'm fully aware how much this adds to the app
    // But after spending way too much time on trying to get this to work I'll
    // just remain happy with this solution.
    // This is temorary, and should be replaced, but is rather non-blocking
    // and on a not-so-important list.
    final pty = Pty.start(
      'tail',
      arguments: ['-f', widget.i2pdConf.logfile!],
      columns: terminal.viewWidth,
      rows: terminal.viewHeight,
    );

    pty.output
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(terminal.write);

    pty.exitCode.then((code) {
      terminal.write('the process exited with exit code $code');
    });

    terminal.onOutput = (data) {
      pty.write(const Utf8Encoder().convert(data));
    };

    terminal.onResize = (w, h, pw, ph) {
      pty.resize(h, w);
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("I2P config"),
      ),
      body: TerminalView(terminal),
    );
  }
}
