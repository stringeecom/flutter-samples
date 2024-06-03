import 'package:call_sample/stringee_wrapper/call/stringee_call_model.dart';
import 'package:call_sample/stringee_wrapper/widgets/stringee_incall_widget.dart';
import 'package:call_sample/stringee_wrapper/widgets/stringee_ringing_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/common.dart';

class StringeeCallWidget extends StatefulWidget {
  const StringeeCallWidget({super.key});

  @override
  State<StringeeCallWidget> createState() => _StringeeCallWidgetState();
}

class _StringeeCallWidgetState extends State<StringeeCallWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // TODO: - do something with call on app lifecycle state
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<StringeeCallModel>(context, listen: true);
    if (model.callState == CallState.ended && model.isIncomingCall) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: model.callState == CallState.incoming ||
                model.callState == CallState.starting ||
                model.callState == CallState.calling ||
                model.callState == CallState.ringing
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
