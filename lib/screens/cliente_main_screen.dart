import 'package:flutter/material.dart';
import 'home_cliente_screen.dart';
import 'mis_servicios_screen.dart';
import 'mi_cuenta_screen.dart';
import 'package:tecnigo/widgets/app_drawer.dart';

class ClienteMainScreen extends StatefulWidget {
  const ClienteMainScreen({super.key});

  @override
  State<ClienteMainScreen> createState() => _ClienteMainScreenState();
}

class _ClienteMainScreenState extends State<ClienteMainScreen> {
  int pagina = 0;

  final paginas = const [
    HomeClienteScreen(),
    MisServiciosScreen(),
    MiCuentaScreen(),
  ];

  final titulos = const [
    "TecniGo",
    "Mis servicios",
    "Mi cuenta",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        onInicio: () => setState(() => pagina = 0),
        onMisServicios: () => setState(() => pagina = 1),
      ),

      appBar: AppBar(
        title: Text(titulos[pagina]),
      ),

      body: paginas[pagina],

      bottomNavigationBar: NavigationBar(
        selectedIndex: pagina,

        onDestinationSelected: (index) {
          setState(() {
            pagina = index;
          });
        },

        destinations: const [

          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: "Inicio",
          ),

          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: "Servicios",
          ),

          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: "Cuenta",
          ),
        ],
      ),
    );
  }
}