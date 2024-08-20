import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:stendmobile/utils/haptic.dart';

class SettingsDropdownButton extends StatefulWidget {
  final String value;
  final bool hapticOnOpen;
  final bool useCupertino;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const SettingsDropdownButton({
    required this.value,
    required this.hapticOnOpen,
    required this.useCupertino,
    required this.items,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  SettingsDropdownButtonState createState() => SettingsDropdownButtonState();
}

class SettingsDropdownButtonState extends State<SettingsDropdownButton> {
  @override
  Widget build(BuildContext context) {
    Color? backgroundColor = widget.useCupertino ? Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[200] : Theme.of(context).colorScheme.onSecondary;
    Color? overlayColor = widget.useCupertino ? Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[300] : Theme.of(context).colorScheme.secondaryContainer;
    List<String> items = [...widget.items];

    // empêcher la value de ne pas faire parti des items (sinon tt crash)
    if (!widget.items.contains(widget.value)) items.insert(0, widget.value);

    return DropdownButton2<String>(
      value: widget.value,
      onMenuStateChange: (bool isOpen) => isOpen && widget.hapticOnOpen ? Haptic().light() : null,
      dropdownStyleData: DropdownStyleData(
        isOverButton: true,
        offset: const Offset(0, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          color: backgroundColor,
        ),
      ),
      menuItemStyleData: MenuItemStyleData(
        overlayColor: MaterialStatePropertyAll(overlayColor),
      ),
      underline: Padding(
        padding: const EdgeInsets.only(left: 12, right: 2, top: 2),
        child: Container(
          height: 1.0,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFBDBDBD),
                width: 0.0,
              ),
            ),
          ),
        ),
      ),
      onChanged: widget.onChanged,
      items: items
          .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
    );
  }
}
