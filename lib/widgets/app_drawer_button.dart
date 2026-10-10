import 'package:flutter/material.dart';

import 'app_bar_action_button.dart';

class AppDrawerButton extends StatelessWidget {
  const AppDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Center(
        child: AppBarActionButton(
          icon: const Icon(Icons.menu),
          tooltip: 'เปิดเมนู',
          onPressed: () {
            // แท็บมี Scaffold ซ้อนกัน จึงต้องหา Scaffold ที่เป็นเจ้าของ drawer.
            context.visitAncestorElements((element) {
              if (element is StatefulElement &&
                  element.state is ScaffoldState) {
                final scaffold = element.state as ScaffoldState;
                if (scaffold.hasDrawer) {
                  scaffold.openDrawer();
                  return false;
                }
              }
              return true;
            });
          },
        ),
      ),
    );
  }
}
