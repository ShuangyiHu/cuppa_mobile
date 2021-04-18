/*
 *******************************************************************************
 Package:  cuppa_mobile
 Class:    timer.dart
 Author:   Nathan Cosgray | https://www.nathanatos.com
 -------------------------------------------------------------------------------
 Copyright (c) 2017-2021 Nathan Cosgray. All rights reserved.

 This source code is licensed under the BSD-style license found in LICENSE.txt.
 *******************************************************************************
*/

// Cuppa timer widgets and logic
// - Build interface and interactivity
// - Start, confirm, cancel timers
// - Notification channels for platform code

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quick_actions/quick_actions.dart';
import 'main.dart';
import 'prefs.dart';
import 'platform_adaptive.dart';

class TimerWidget extends StatefulWidget {
  @override
  _TimerWidgetState createState() => new _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  // Cup images
  static final String cupImageDefault = 'images/Cuppa_hires_default.png';
  static final String cupImageBegin = 'images/Cuppa_hires_light.png';
  static final String cupImageEnd = 'images/Cuppa_hires_dark.png';

  // State variables
  bool _timerActive = false;
  Tea _whichActive;
  String _cupImage = cupImageDefault;
  int _timerSeconds = 0;
  DateTime _timerEndTime;
  Timer _timer;

  // Notification channels
  static const platform =
      const MethodChannel('com.nathanatos.Cuppa/notification');
  Future<Null> _sendNotification(int secs, String title, String text) async {
    try {
      platform.invokeMethod('setupNotification', <String, dynamic>{
        'secs': secs,
        'title': title,
        'text': text,
      });
    } on PlatformException {
      return;
    }
  }

  Future<Null> _cancelNotification() async {
    try {
      platform.invokeMethod('cancelNotification');
    } on PlatformException {
      return;
    }
  }

  // Confirmation dialog
  Future<bool> _confirmTimer() {
    if (_timerActive) {
      return showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return PlatformAdaptiveDialog(
              platform: appPlatform,
              title: Text(confirmTitle),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(confirmMessageLine1),
                    Text(confirmMessageLine2),
                  ],
                ),
              ),
              buttonTextTrue: confirmYes,
              buttonTextFalse: confirmNo,
            );
          });
    } else {
      return Future.value(true);
    }
  }

  // Timer functions
  void _decrementTimer(Timer t) {
    setState(() {
      _timerSeconds = _timerEndTime.difference(new DateTime.now()).inSeconds;
      if (_timerSeconds <= 5) _cupImage = cupImageEnd;
      if (_timerSeconds <= 0) {
        _timerActive = false;
        _whichActive = null;
        _cupImage = cupImageDefault;
        _timerSeconds = 0;
        _timer.cancel();
        Prefs.clearNextAlarm();
      }
    });
  }

  void _setTimer(Tea tea, [int secs = 0]) {
    setState(() {
      if (!_timerActive) _timerActive = true;
      _whichActive = tea;
      if (secs == 0) {
        // Set up new timer
        _timerSeconds = tea.brewTime;
        _sendNotification(
            _timerSeconds, teaTimerTitle, tea.fullName + teaTimerText);
      } else {
        // Resume timer from stored prefs
        _timerSeconds = secs;
      }
      _cupImage = cupImageBegin;
      _timer = new Timer.periodic(new Duration(seconds: 1), _decrementTimer);
      _timerEndTime =
          new DateTime.now().add(new Duration(seconds: _timerSeconds + 1));
      Prefs.setNextAlarm(tea.name, _timerEndTime);
    });
  }

  void _checkNextAlarm() {
    Prefs.getNextAlarm();
    if (DateTime.tryParse(Prefs.nextAlarm) != null) {
      Duration diff =
          DateTime.parse(Prefs.nextAlarm).difference(DateTime.now());
      if (diff.inSeconds > 0) {
        if (Prefs.nextTeaName == tea1.name) _setTimer(tea1, diff.inSeconds);
        if (Prefs.nextTeaName == tea2.name) _setTimer(tea2, diff.inSeconds);
        if (Prefs.nextTeaName == tea3.name) _setTimer(tea3, diff.inSeconds);
      } else {
        Prefs.clearNextAlarm();
      }
    } else {
      Prefs.clearNextAlarm();
    }
  }

  // Button handlers
  void _handleTapboxTea1Changed(bool newValue) async {
    if (_whichActive != tea1) if (await _confirmTimer()) _setTimer(tea1);
  }

  void _handleTapboxTea2Changed(bool newValue) async {
    if (_whichActive != tea2) if (await _confirmTimer()) _setTimer(tea2);
  }

  void _handleTapboxTea3Changed(bool newValue) async {
    if (_whichActive != tea3) if (await _confirmTimer()) _setTimer(tea3);
  }

  void _handleTapboxCancelPressed(bool newValue) {
    setState(() {
      _timerActive = false;
      _whichActive = null;
      _timerEndTime = new DateTime.now();
      _decrementTimer(_timer);
      _cancelNotification();
      Prefs.clearNextAlarm();
    });
  }

  void _refreshTeas() {
    setState(() {
      // Load user tea steep times
      Prefs.getTeas();
    });

    // Add quick action shortcuts
    final QuickActions quickActions = QuickActions();
    quickActions.setShortcutItems(<ShortcutItem>[
      ShortcutItem(
        type: 'shortcutTea1',
        localizedTitle: tea1.fullName,
        icon: tea1.shortcutIcon,
      ),
      ShortcutItem(
        type: 'shortcutTea2',
        localizedTitle: tea2.fullName,
        icon: tea2.shortcutIcon,
      ),
      ShortcutItem(
        type: 'shortcutTea3',
        localizedTitle: tea3.fullName,
        icon: tea3.shortcutIcon,
      ),
    ]);
  }

  @override
  void initState() {
    super.initState();

    _refreshTeas();

    // Check for an existing timer and resume if needed
    _checkNextAlarm();

    // Handle quick action selection
    final QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) async {
      if (shortcutType != null) {
        switch (shortcutType) {
          case 'shortcutTea1':
            {
              if (await _confirmTimer()) _setTimer(tea1);
            }
            break;
          case 'shortcutTea2':
            {
              if (await _confirmTimer()) _setTimer(tea2);
            }
            break;
          case 'shortcutTea3':
            {
              if (await _confirmTimer()) _setTimer(tea3);
            }
            break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Styles
    double scaleFactor = MediaQuery.of(context).size.height < 600.0 ? 0.7 : 1.0;
    final TextStyle timerStyle = Theme.of(context).textTheme.headline2.copyWith(
        color: Colors.white,
        fontSize: 100.0 * scaleFactor,
        fontWeight: FontWeight.bold);

    _refreshTeas();

    return Scaffold(
        appBar: new PlatformAdaptiveAppBar(
            title: new Text(appTitle),
            platform: appPlatform,
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.of(context)
                      .pushNamed("/prefs")
                      .then((value) => setState(() {}));
                },
              ),
            ]),
        body: new Container(
          child: new Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              new SizedBox(
                child: new Container(
                  padding: const EdgeInsets.fromLTRB(48.0, 24.0, 48.0, 24.0),
                  child: new Container(
                    decoration: new BoxDecoration(
                      color: Colors.green,
                      borderRadius:
                          const BorderRadius.all(const Radius.circular(12.0)),
                    ),
                    child: new Center(
                      child: new Text(
                        _formatTimer(_timerSeconds),
                        style: timerStyle,
                      ),
                    ),
                  ),
                ),
              ),
              new Expanded(
                child: new Container(
                  padding: const EdgeInsets.fromLTRB(48.0, 0.0, 48.0, 0.0),
                  child: new Image.asset(
                    _cupImage,
                    height: 240.0 * scaleFactor,
                    fit: BoxFit.fitWidth,
                    gaplessPlayback: true,
                  ),
                ),
              ),
              new SizedBox(
                child: new Container(
                  margin: const EdgeInsets.all(24.0),
                  child: new Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      new TeaButton(
                          name: tea1.buttonName,
                          active: _whichActive == tea1 ? true : false,
                          fade: !_timerActive || _whichActive == tea1
                              ? false
                              : true,
                          buttonColor: tea1.getThemeColor(context),
                          onPressed: _handleTapboxTea1Changed),
                      new TeaButton(
                          name: tea2.buttonName,
                          active: _whichActive == tea2 ? true : false,
                          fade: !_timerActive || _whichActive == tea2
                              ? false
                              : true,
                          buttonColor: tea2.getThemeColor(context),
                          onPressed: _handleTapboxTea2Changed),
                      new TeaButton(
                          name: tea3.buttonName,
                          active: _whichActive == tea3 ? true : false,
                          fade: !_timerActive || _whichActive == tea3
                              ? false
                              : true,
                          buttonColor: tea3.getThemeColor(context),
                          onPressed: _handleTapboxTea3Changed),
                    ],
                  ),
                ),
              ),
              new SizedBox(
                child: new Container(
                  margin: const EdgeInsets.only(bottom: 24.0),
                  child: new Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      new CancelButton(
                        active: _timerActive ? true : false,
                        onPressed: _handleTapboxCancelPressed,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ));
  }
}

class TeaButton extends StatelessWidget {
  TeaButton({
    this.name,
    this.active = false,
    this.fade = false,
    this.buttonColor,
    this.onPressed,
  });

  final String name;
  final bool active;
  final bool fade;
  final Color buttonColor;

  final ValueChanged<bool> onPressed;
  void _handleTap() {
    onPressed(!active);
  }

  @override
  Widget build(BuildContext context) {
    return new AnimatedOpacity(
      opacity: fade ? 0.4 : 1.0,
      duration: new Duration(milliseconds: 400),
      child: new GestureDetector(
        onTap: _handleTap,
        child: new Container(
          decoration: new BoxDecoration(
            color: active ? buttonColor : Colors.transparent,
            borderRadius: const BorderRadius.all(const Radius.circular(2.0)),
          ),
          child: new Container(
            margin: const EdgeInsets.all(8.0),
            child: new Column(
              children: [
                new Icon(
                  Icons.timer,
                  color: active ? Colors.white : buttonColor,
                  size: 64.0,
                ),
                new Text(
                  name,
                  style: new TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                    color: active ? Colors.white : buttonColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CancelButton extends StatelessWidget {
  CancelButton({Key key, this.active: false, @required this.onPressed})
      : super(key: key);

  final bool active;
  final ValueChanged<bool> onPressed;

  void _handleTap() {
    onPressed(!active);
  }

  Widget build(BuildContext context) {
    return new IconButton(
        icon: new Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            new Icon(Icons.cancel,
                color: active ? Colors.blue : Theme.of(context).buttonColor),
            new Text(
              cancelButton,
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.w400,
                color: active ? Colors.blue : Theme.of(context).buttonColor,
              ),
            ),
          ],
        ),
        padding: const EdgeInsets.all(0.0),
        onPressed: active ? _handleTap : null);
  }
}

String _formatTimer(s) {
  // Build the time format string
  int mins = (s / 60).floor();
  int secs = s - (mins * 60);
  String secsString = secs.toString();
  if (secs < 10) secsString = '0' + secsString;
  return mins.toString() + ':' + secsString;
}
