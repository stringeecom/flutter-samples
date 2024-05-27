import 'package:call_sample/stringee_wrapper/call/stringee_call_model.dart';
import 'package:call_sample/stringee_wrapper/widgets/stringee_incall_widget.dart';
import 'package:call_sample/stringee_wrapper/widgets/stringee_ringing_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    // TODO: - do something if
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<StringeeCallModel>(context, listen: true);

    return Scaffold(
      backgroundColor: Colors.white,
      body: !model.isInCall
          ? const StringeeRingingWidget()
          : const StringeeIncallWidget(),
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
