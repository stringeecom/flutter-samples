import 'package:call_sample/stringee_wrapper/widgets/call_button_answer.dart';
import 'package:call_sample/stringee_wrapper/widgets/call_button_end.dart';
import 'package:call_sample/stringee_wrapper/widgets/sc_calling_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../call/stringee_call_model.dart';
import 'stringee_avatar_widget.dart';
import 'stringee_call_widget.dart';

class StringeeRingingWidget extends StatelessWidget {
  const StringeeRingingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<StringeeCallModel>();
    return SCCallingWidget(
      body: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(20.0),
            bottomLeft: Radius.circular(20.0),
          ),
          color: Color.fromRGBO(26, 87, 141, 1.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 64,
                    width: double.maxFinite,
                  ),
                  Text(
                    model.callState.name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15.0,
                    ),
                  ),
                  dividerStatus,
                  Container(
                    margin: const EdgeInsets.only(top: 15.0),
                    child: Text(
                      model.callee ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Center(child: StringeeAvatarWidget(text: model.callee)),
            ),
          ],
        ),
      ),
      bottom: model.isIncomingCall
          ? _buildIncomingCallActions(model)
          : _buildOutgoingCallActions(model),
    );
  }

  Widget _buildIncomingCallActions(StringeeCallModel model) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _btnReject(model),
        _btnAnswer(model),
      ],
    );
  }

  Widget _buildOutgoingCallActions(StringeeCallModel model) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [_btnEnd(model)],
    );
  }

  Widget _btnAnswer(StringeeCallModel model) {
    return CallButtonAnswer(
      onPressed: () {
        model.answerCall();
      },
    );
  }

  Widget _btnReject(StringeeCallModel model) {
    return CallButtonEnd(
      onPressed: () {
        model.rejectCall();
      },
    );
  }

  Widget _btnEnd(StringeeCallModel model) {
    return CallButtonEnd(
      onPressed: () {
        model.hangupCall();
      },
    );
  }
}
