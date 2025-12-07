// Home scaffold: hosts Home, Alert and Setting pages with bottom nav (PageView + AppBottomNav)

import 'package:flutter/material.dart';
import 'home.dart';
import 'alert.dart';
import 'setting.dart';
import 'bottom_nav.dart';

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  final PageController _pc = PageController(initialPage: 1);
  int _index = 1;

  void _onTap(int i) {
    setState(() => _index = i);
    _pc.jumpToPage(i);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const AlertPageView(),
      const HomePageView(),
      const SettingPageView(),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView(
              controller: _pc,
              physics: const NeverScrollableScrollPhysics(),
              children: pages,
              onPageChanged: (i) => setState(() => _index = i),
            ),
          ),
          // bottom nav
          AppBottomNav(currentIndex: _index, onTap: _onTap),
        ]),
      ),
    );
  }
}