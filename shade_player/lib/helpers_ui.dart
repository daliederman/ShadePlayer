// Store helper functions for UI

import 'package:flutter/material.dart';

String formatDuration(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return "$minutes:$seconds";
}

//Unused
/*
class ShadeMainPage extends StatefulWidget {
  const ShadeMainPage({super.key, required this.title});
  final String title;

  @override
  State<ShadeMainPage> createState() => _ShadeMainPageState();
}

class _ShadeMainPageState extends State<ShadeMainPage> {
  int indexPage = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
      switch (indexPage) {
        case 0:
          page = PageLibrary();
        case 1:
          page = PageSettings();
        default:
          throw UnimplementedError('No widget for index: $indexPage');
      }

      return LayoutBuilder(builder: (context, constraints) {
        return Scaffold(
          body:Row(
            children: [
              //SafeArea(child: child)
            ],
          )
        );
      });
  }
}

class PageLibrary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    

    //  implement build
    throw UnimplementedError();
  }
}

class PageSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    

    // implement build
    throw UnimplementedError();
  }
}
*/