// ignore_for_file: library_private_types_in_public_api

library flutter_i2p;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:dart_i2p/dart_i2p.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i2p/switch_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      debugPrint("skipping (lastChecked == DART_I2P_VERSION) - $lastChecked ");
      return app;
    }
    return I2pdEnsure(
      app: app,
      binPath: binPath,
      requiredBinaries: requiredBinaries,
    );
  }

  const I2pdEnsure({
    super.key,
    required this.app,
    required this.binPath,
    required this.requiredBinaries,
  });

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
                        "\n${widget.binPath} - i2pd not ok - exitCode: ${value.exitCode}, stdout: ${value.stdout}, stderr: ${value.stderr}";
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
            if ((Platform.isWindows || Platform.isLinux) && !i2pdOk)
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
    super.key,
  });

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
              String distPath = switch (getPlatform()) {
                OS.windows =>
                  "windows/${Abi.current() == Abi.windowsX64 ? '64' : '32'}",
                OS.linux => switch (Abi.current()) {
                    Abi.linuxArm => "linux_arm",
                    Abi.linuxArm64 => "linux_arm64",
                    Abi.linuxIA32 => "linux_i386",
                    Abi.linuxX64 => "linux_amd64",
                    _ => "unknown",
                  },
                _ => "",
              };
              final dlurl =
                  "https://git.mrcyjanek.net/p3pch4t/flutter_i2p_bins-prebuild/raw/branch/i2pd_2.49.0/$distPath/";
              setState(() {
                isDownloading = true;
              });
              Directory(widget.binPath).createSync(recursive: true);
              await http
                  .get(Uri.parse('$dlurl${i2pdBinariesToString(widget.bin)}'))
                  .then(
                (response) {
                  File(binPath).writeAsBytes(response.bodyBytes, flush: true);
                  if (getPlatform() == OS.linux) {
                    Process.run("chmod", ["+x", binPath]);
                  }
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
  const I2pConfigPage({super.key, this.i2pdConf});
  final I2pdConf? i2pdConf;

  @override
  State<I2pConfigPage> createState() => _I2pConfigPageState();
}

class _I2pConfigPageState extends State<I2pConfigPage> {
  @override
  void initState() {
    super.initState();
  }

  String log = "Loading...";

  Future<void> initLogView() async {
    if (widget.i2pdConf?.logfile == null) {
      setState(() {
        log = "CRIT: i2p.i2pdConf.logfile is null, we have no evidence "
            "i2pd logging anything.";
      });
      return;
    }

    File(widget.i2pdConf!.logfile!).readAsString().then((value) {
      setState(() {
        log = value;
      });
    });
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
            SelectableText(
              log,
              style: const TextStyle(fontFamily: "monospace"),
            ),
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
  const TextViewSettings({super.key, required this.dbKey});

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
          debugPrint('value updated: ${widget.dbKey}, $value');
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
