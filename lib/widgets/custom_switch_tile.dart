import 'package:flutter/material.dart';

class CustomSwitchTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const CustomSwitchTile({
    required this.title,
    this.subtitle = '',
    required this.value,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  CustomSwitchTileState createState() => CustomSwitchTileState();
}

class CustomSwitchTileState extends State<CustomSwitchTile> {
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
          title: Text(widget.title),
          subtitle: widget.subtitle.isEmpty ? null : Text(widget.subtitle),
          trailing: Switch.adaptive(
            value: widget.value,
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
  }
}
