import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';

final box = GetStorage();
String iconLib = box.read('iconLib') ?? 'Material';

void showSnackBar(BuildContext context, String message, { String icon = 'info', bool useCupertino = false }) {
  Color textColor = useCupertino ? Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black : Theme.of(context).colorScheme.secondary;
  Color iconColor = useCupertino ? icon == 'error' ? Colors.red : icon == 'warning' ? Colors.orange : icon == 'success' ? Colors.green : textColor : textColor;

  late IconData iconData;
  if(icon == 'error'){
    iconData = iconLib == 'Lucide' ? LucideIcons.xCircle : iconLib == 'Lucide (alt)' ? LucideIcons.xCircle : iconLib == 'iOS' ? CupertinoIcons.exclamationmark_circle : Icons.error;
  } else if(icon == 'warning'){
    iconData = iconLib == 'Lucide' ? LucideIcons.alertTriangle : iconLib == 'Lucide (alt)' ? LucideIcons.alertTriangle : iconLib == 'iOS' ? CupertinoIcons.exclamationmark_triangle : Icons.warning;
  } else if(icon == 'success'){
    iconData = iconLib == 'Lucide' ? LucideIcons.checkCircle2 : iconLib == 'Lucide (alt)' ? LucideIcons.checkCircle2 : iconLib == 'iOS' ? CupertinoIcons.checkmark_circle : Icons.check;
  } else {
    iconData = iconLib == 'Lucide' ? LucideIcons.info : iconLib == 'Lucide (alt)' ? LucideIcons.info : iconLib == 'iOS' ? CupertinoIcons.info_circle : Icons.info;
  }

  final snackBar = SnackBar(
    content: Row(
      children: [
        Icon(iconData, color: iconColor),
        const SizedBox(width: 12),
        Flexible(
          child: Text(message, style: TextStyle(color: textColor, fontWeight: FontWeight.w500))
        ),
      ],
    ),
    behavior: SnackBarBehavior.floating,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(15)),
    ),
    duration: Duration(milliseconds: message.length * 70 > 2500 ? message.length * 70 : 2500),
    backgroundColor: useCupertino ? Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[200] : Theme.of(context).colorScheme.onSecondary,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);

  List recentsSnackbar = box.read('recentsSnackbar') ?? [];
  if(recentsSnackbar.length > 10){
    recentsSnackbar.removeAt(0);
  }
  recentsSnackbar.add({
    'message': message,
    'icon': icon,
    'date': DateTime.now().toString()
  });
  box.write('recentsSnackbar', recentsSnackbar);
}