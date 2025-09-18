import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Widget _currentPage = Container();
  String _currentTitle = 'Trang chủ';

  void _selectPage(String pageName, Widget pageWidget) {
    setState(() {
      _currentTitle = pageName;
      _currentPage = pageWidget;
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      drawer: AppDrawer(onPageSelected: _selectPage),
      body: _currentPage,
    );
  }
}
