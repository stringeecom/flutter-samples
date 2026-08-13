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

/// Full-screen call UI that switches between ringing and in-call states.
class StringeeCallWidget extends StatefulWidget {
  /// Creates the built-in call UI.
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
    if (model != null && state == AppLifecycleState.detached) {
      if (model?.callState != CallState.ended &&
          model?.callState != CallState.busy &&
          model?.callState != CallState.incoming) {
        await model?.hangupCall();
      }
      if (!isIOS) {
        await AndroidPushManager().cancelIncomingCallNotification();
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
          StringeeWrapper().requestCallPermissions().then((value) async {
            if (!mounted) {
              // Check mounted again after async gap
              return;
            }
            if (value) {
              if (model!.isIncomingCall) {
                if (AndroidPushManager().isRejectFromPush) {
                  AndroidPushManager().isRejectFromPush = false;
                  await model!.rejectCall();
                } else if (AndroidPushManager().isAnswerFromPush) {
                  AndroidPushManager().isAnswerFromPush = false;
                  await model!.answerCall();
                }
              } else {
                await StringeeCallManager().makeCall(model!);
              }
            } else {
              Fluttertoast.showToast(
                msg: 'Please grant permission to handle a call',
                toastLength: Toast.LENGTH_SHORT,
              );
              if (model!.isIncomingCall) {
                await model!.rejectCall();
              } else {
                StringeeCallManager().clear(model!);
              }
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

/// Short status divider shared by ringing and connected call layouts.
Widget dividerStatus = Container(
  margin: const EdgeInsets.only(top: 5.0),
  height: 2.0,
  width: 20.0,
  decoration: const BoxDecoration(color: Color.fromRGBO(64, 182, 73, 1.0)),
);
