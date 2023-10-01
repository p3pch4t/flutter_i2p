library flutter_i2p;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:dart_i2p/dart_i2p.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i2p/switch_platform.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm/core.dart';
import 'package:xterm/ui.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class I2pdEnsure extends StatefulWidget {
  static Future<Widget> checkAndRun({
    /// What to return when I2P is ready?
    required Widget app,

    /// Where are the binaries stored?
    required String binPath,

    /// Just check for the files existence or actually try to run them?
    /// leave null to make an inteligent choice depending on "stuff"
    bool? softCheck,
    List<I2pdBinaries> requiredBinaries = const [
      I2pdBinaries.i2pd,
      I2pdBinaries.keyinfo
    ],
  }) async {
    // WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final binPathOverride = prefs.getString("flutter_i2p.binPathOverride");
    if (binPathOverride != null && binPathOverride != "") {
      binPath = binPathOverride;
    }

    if (softCheck == false) {
      return I2pdEnsure(
        app: app,
        binPath: binPath,
        requiredBinaries: requiredBinaries,
      );
    }
    final lastChecked = prefs.getString("flutter_i2p.lastChecked");
    if (lastChecked == DART_I2P_VERSION) {
      print("skipping (lastChecked == DART_I2P_VERSION) - $lastChecked ");
      return app;
    }
    return I2pdEnsure(
      app: app,
      binPath: binPath,
      requiredBinaries: requiredBinaries,
    );
  }

  const I2pdEnsure({
    Key? key,
    required this.app,
    required this.binPath,
    required this.requiredBinaries,
  }) : super(key: key);

  final Widget app;
  final String binPath;
  final List<I2pdBinaries> requiredBinaries;
  @override
  State<I2pdEnsure> createState() => _I2pdEnsureState();
}

class _I2pdEnsureState extends State<I2pdEnsure> {
  String i2pdVersion = "";
  bool i2pdOk = true;
  String log = "";

  @override
  void initState() {
    super.initState();

    for (var bin in widget.requiredBinaries) {
      switch (bin) {
        case I2pdBinaries.i2pd:
          if (!File(p.join(widget.binPath, i2pdBinariesToString(bin)))
              .existsSync()) {
            setState(() {
              setState(() {
                i2pdOk = false;
                log += "\ni2pd not ok - it doesn't exist in ${widget.binPath}";
              });
            });
          } else {
            Process.run(
              p.join(widget.binPath, i2pdBinariesToString(bin)),
              ['--version'],
            ).then((value) {
              if (i2pdOk) {
                if (value.exitCode != 0) {
                  setState(() {
                    i2pdOk = false;
                    log +=
                        "\ni2pd not ok - ${value.exitCode}, ${value.stdout}, ${value.stderr}";
                  });
                }
              }
              setState(() {
                i2pdVersion = value.stdout;
              });
            });
          }
          break;
        case _:
          if (!File(p.join(widget.binPath, i2pdBinariesToString(bin)))
              .existsSync()) {
            setState(() {
              i2pdOk = false;
              log += "\n${widget.binPath}/${i2pdBinariesToString(bin)} missing";
            });
          }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("I2Pd config"),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const I2pConfigPage(),
              ));
            },
            icon: const Icon(Icons.settings),
          )
        ],
      ),
      body: Center(
        child: Column(
          children: [
            Text(i2pdVersion),
            Text(log),
            if (Platform.isWindows && !i2pdOk)
              ListView.builder(
                itemCount: I2pdBinaries.values.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  return DownloadExeButton(
                    bin: I2pdBinaries.values[index],
                    binPath: widget.binPath,
                    required: widget.requiredBinaries.contains(
                      I2pdBinaries.values[index],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: SizedBox(
        width: double.maxFinite,
        child: OutlinedButton(
          onPressed: !i2pdOk
              ? null
              : () async {
                  SharedPreferences.getInstance().then(
                    (prefs) => prefs.setString(
                        'flutter_i2p.lastChecked', DART_I2P_VERSION),
                  );
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => widget.app,
                    ),
                  );
                },
          child: const Text("Continue"),
        ),
      ),
    );
  }
}

class DownloadExeButton extends StatefulWidget {
  const DownloadExeButton({
    required this.bin,
    required this.binPath,
    required this.required,
    Key? key,
  }) : super(key: key);

  final I2pdBinaries bin;
  final String binPath;
  final bool required;
  @override
  _DownloadExeButtonState createState() => _DownloadExeButtonState();
}

class _DownloadExeButtonState extends State<DownloadExeButton> {
  bool isDownloading = false;
  late String binPath =
      p.join(widget.binPath, i2pdBinariesToString(widget.bin));
  late bool binExists = File(binPath).existsSync();
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: widget.required && !binExists
          ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
          : null,
      onPressed: isDownloading
          ? null
          : () async {
              final arch = Abi.current() == Abi.windowsX64 ? '64' : '32';
              final dlurl =
                  "https://git.mrcyjanek.net/p3pch4t/flutter_i2p_bins-prebuild/raw/branch/i2pd_2.49.0/windows/$arch/";
              setState(() {
                isDownloading = true;
              });
              Directory(widget.binPath).createSync(recursive: true);
              await http
                  .get(Uri.parse('$dlurl${i2pdBinariesToString(widget.bin)}'))
                  .then(
                (response) {
                  File(binPath).writeAsBytes(response.bodyBytes);
                },
              );
              setState(() {
                isDownloading = false;
                binExists = true;
              });
            },
      child: Text(
        "${binExists ? 'Update' : 'Download'} ${i2pdBinariesToString(widget.bin)}",
      ),
    );
  }
}

class I2pConfigPage extends StatefulWidget {
  const I2pConfigPage({Key? key, this.i2pdConf}) : super(key: key);
  final I2pdConf? i2pdConf;

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
    if (widget.i2pdConf?.logfile == null) {
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
      switch (getPlatform()) {
        OS.windows => "powershell.exe",
        _ => 'tail',
      },
      arguments: switch (getPlatform()) {
        OS.windows => [
            '-Command',
            'Get-Content',
            widget.i2pdConf!.logfile!,
            '-Wait' '-Tail' '100'
          ],
        _ => ['-f', widget.i2pdConf!.logfile!],
      },
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("I2P config"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.abc)),
              Tab(icon: Icon(Icons.directions_transit)),
            ],
          ),
        ),
        // flutter_i2p.binPathOverride
        body: TabBarView(
          children: [
            TerminalView(terminal),
            const Column(
              children: [
                TextViewSettings(dbKey: 'flutter_i2p.binPathOverride'),
                TextViewSettings(dbKey: 'flutter_i2p.lastChecked'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TextViewSettings extends StatefulWidget {
  const TextViewSettings({Key? key, required this.dbKey}) : super(key: key);

  @override
  final String dbKey;

  @override
  _TextViewSettingsState createState() => _TextViewSettingsState();
}

class _TextViewSettingsState extends State<TextViewSettings> {
  final tc = TextEditingController();

  late SharedPreferences prefs;

  @override
  void initState() {
    SharedPreferences.getInstance().then((value) {
      setState(() {
        tc.text = value.getString(widget.dbKey) ?? '';
        prefs = value;
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: tc,
        onChanged: (value) async {
          await prefs.setString(widget.dbKey, value);
          print('value updated: ${widget.dbKey}, $value');
        },
        decoration: InputDecoration(
          label: Text(widget.dbKey),
          hintText: widget.dbKey,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
