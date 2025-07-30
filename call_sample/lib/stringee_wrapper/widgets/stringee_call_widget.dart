import 'package:call_sample/stringee_wrapper/call/stringee_call_manager.dart';
import 'package:call_sample/stringee_wrapper/call/stringee_call_model.dart';
import 'package:call_sample/stringee_wrapper/stringee_wrapper.dart';
import 'package:call_sample/stringee_wrapper/widgets/stringee_incall_widget.dart';
import 'package:call_sample/stringee_wrapper/widgets/stringee_ringing_widget.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../common/common.dart';
import '../push_manager/android_push_manager.dart';

class StringeeCallWidget extends StatefulWidget {
  const StringeeCallWidget({super.key});

  @override
  State<StringeeCallWidget> createState() => _StringeeCallWidgetState();
}

class _StringeeCallWidgetState extends State<StringeeCallWidget>
    with WidgetsBindingObserver {
  StringeeCallModel? model;

  @override
  void initState() {
    super.initState();
    if (!isIOS) {
      AndroidPushManager().cancelIncomingCallNotification();
    }
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (model != null) {
      if (state == AppLifecycleState.detached) {
        if (model?.callState != CallState.ended &&
            model?.callState != CallState.busy &&
            model?.callState != CallState.incoming) {
          model?.hangupCall();
        }
        if (!isIOS) {
          AndroidPushManager().cancelIncomingCallNotification();
        }
      } else if (state == AppLifecycleState.resumed) {
        if (!isIOS) {
          AndroidPushManager().cancelIncomingCallNotification();
        }
      } else if (state == AppLifecycleState.paused) {
        if (!isIOS) {
          if (model?.callState == CallState.incoming) {
            AndroidPushManager().showIncomingCallNotification(
              model!.call.fromAlias!,
              model!.call.from!,
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _pop() {
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (model == null) {
      model = Provider.of<StringeeCallModel>(context, listen: true);

      if (model!.callState == CallState.ended && model!.isIncomingCall) {
        _pop();
      }

      if (mounted) {
        if (!isIOS) {
          StringeeWrapper().requestCallPermissions().then((value) {
            if (!mounted) {
              // Check mounted again after async gap
              return;
            }
            if (value) {
              if (model!.isIncomingCall) {
                if (AndroidPushManager().isRejectFromPush) {
                  model!.rejectCall();
                  AndroidPushManager().isRejectFromPush = false;
                } else if (AndroidPushManager().isAnswerFromPush) {
                  model!.answerCall();
                  AndroidPushManager().isAnswerFromPush = false;
                }
              } else {
                StringeeCallManager().makeCall(model!);
              }
            } else {
              Fluttertoast.showToast(
                msg: 'Please grant permission to handle a call',
                toastLength: Toast.LENGTH_SHORT,
              );
              if (model!.isIncomingCall) {
                model!.rejectCall();
              }
              _pop();
            }
          });
        } else {
          if (!model!.isIncomingCall && isIOS) {
            if (mounted) {
              StringeeCallManager().makeCall(model!);
            }
          }
        }
      }
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: model!.callState == CallState.incoming ||
                model!.callState == CallState.starting ||
                model!.callState == CallState.calling ||
                model!.callState == CallState.ringing
            ? const StringeeRingingWidget()
            : const StringeeIncallWidget(),
      ),
    );
  }
}

Widget dividerStatus = Container(
  margin: const EdgeInsets.only(top: 5.0),
  height: 2.0,
  width: 20.0,
  decoration: const BoxDecoration(
    color: Color.fromRGBO(64, 182, 73, 1.0),
  ),
);
