import 'package:flutter/material.dart';
import 'package:stendmobile/utils/haptic.dart';

void actionsDialog(BuildContext context, { String title = 'Confirmation', String content = 'Pas de texte', String haptic = 'warning', List<Widget> actions = const [] }) {
  if(haptic == 'warning') Haptic().warning();
  if(haptic == 'light') Haptic().light();
  if(haptic == 'error') Haptic().error();
  if(haptic == 'success') Haptic().success();

  showAdaptiveDialog(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Text(content)
      ),
      actions: actions
    )
  );
}

Future asyncActionsDialog(BuildContext context, { String title = 'Confirmation', String content = 'Pas de texte', String haptic = 'warning', List<Widget> actions = const [] }) async {
  if(haptic == 'warning') Haptic().warning();
  if(haptic == 'light') Haptic().light();
  if(haptic == 'error') Haptic().error();
  if(haptic == 'success') Haptic().success();

  return await showAdaptiveDialog(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Text(content)
      ),
      actions: actions
    )
  );
}