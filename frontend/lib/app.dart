import 'package:material_ui/material_ui.dart';

/// Root widget of the Servora app.
class ServoraApp extends StatelessWidget {
  const ServoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Servora',
      home: Scaffold(body: Center(child: Text('Servora'))),
    );
  }
}
