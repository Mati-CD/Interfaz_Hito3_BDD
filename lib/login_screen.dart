import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:interfaz_hito3_bdd/postgres_database.dart';
import 'package:interfaz_hito3_bdd/dashboard_screen.dart';

class RutFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Limpiar el string: mantener solo dígitos y K/k
    var text = newValue.text.replaceAll(RegExp(r'[^0-9kK]'), '');

    // Limitar al máximo de 9 dígitos/caracteres válidos para un RUT
    if (text.length > 9) {
      text = text.substring(0, 9);
    }

    if (text.isEmpty) {
      return const TextEditingValue();
    }

    String formatted = '';

    if (text.length == 1) {
      formatted = text.toUpperCase();
    } else {
      final dv = text.substring(text.length - 1).toUpperCase();
      final numberPart = text.substring(0, text.length - 1);

      final buffer = StringBuffer();
      int count = 0;
      for (int i = numberPart.length - 1; i >= 0; i--) {
        buffer.write(numberPart[i]);
        count++;
        if (count == 3 && i > 0) {
          buffer.write('.');
          count = 0;
        }
      }

      final reversedNumber = buffer.toString().split('').reversed.join('');
      formatted = '$reversedNumber-$dv';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _rutController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _encargados = [];
  bool _isLoading = false;
  bool _loadingEncargados = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEncargados();
  }

  @override
  void dispose() {
    _rutController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadEncargados() async {
    try {
      final list = await PostgresDatabase.getTodosEncargados();
      setState(() {
        _encargados = list;
        _loadingEncargados = false;
      });
    } catch (e) {
      setState(() {
        _loadingEncargados = false;
      });
      print('❌ Error cargando encargados: $e');
    }
  }

  void _login() async {
    final rut = _rutController.text.trim();
    if (rut.isEmpty) {
      setState(() => _errorMessage = 'Por favor, ingrese un RUT.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await PostgresDatabase.login(rut);
      setState(() => _isLoading = false);

      if (user != null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              rutEncargado: user['rut_encargado'],
              nombreEncargado: user['nombre_encargado'],
            ),
          ),
        );
      } else {
        setState(() => _errorMessage = 'RUT no registrado como encargado.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Error de conexión: No se pudo conectar a la base de datos local.\n(Asegúrate de ejecutar en Windows Desktop con -d windows)';
      });
      print('❌ Error de login: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt, size: 80, color: Colors.blue),
                  const SizedBox(height: 20),
                  const Text(
                    'Mega Electric',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Sistema de Monitoreo CMG',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),

                  // Campo de Login con Autocompletado, autoformateo e interacción no tosca
                  _loadingEncargados
                      ? const CircularProgressIndicator()
                      : RawAutocomplete<Map<String, dynamic>>(
                          focusNode: _focusNode,
                          textEditingController: _rutController,
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (_encargados.isEmpty) {
                              return const Iterable<
                                Map<String, dynamic>
                              >.empty();
                            }

                            final query = textEditingValue.text
                                .replaceAll(RegExp(r'[^0-9kK]'), '')
                                .toLowerCase();
                            final nameQuery = textEditingValue.text
                                .trim()
                                .toLowerCase();

                            // Si está vacío, mostrar todos los encargados disponibles
                            if (query.isEmpty && nameQuery.isEmpty) {
                              return _encargados;
                            }

                            // Filtrar tanto por RUT como por nombre
                            return _encargados.where((e) {
                              final cleanRut = e['rut_encargado']
                                  .toString()
                                  .replaceAll(RegExp(r'[^0-9kK]'), '')
                                  .toLowerCase();
                              final name = e['nombre_encargado']
                                  .toString()
                                  .toLowerCase();
                              return cleanRut.contains(query) ||
                                  name.contains(nameQuery);
                            });
                          },
                          displayStringForOption:
                              (Map<String, dynamic> option) {
                                return option['rut_encargado'] as String;
                              },
                          onSelected: (Map<String, dynamic> option) {
                            _rutController.text =
                                option['rut_encargado'] as String;
                            // Se eliminó el inicio de sesión automático al seleccionar, requiere confirmación del botón
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return Focus(
                              onKeyEvent: (FocusNode node, KeyEvent event) {
                                // Interceptar el Tab para autocompletar la primera opción disponible
                                if (event is KeyDownEvent &&
                                    event.logicalKey ==
                                        LogicalKeyboardKey.tab) {
                                  final query = controller.text
                                      .replaceAll(RegExp(r'[^0-9kK]'), '')
                                      .toLowerCase();
                                  final nameQuery = controller.text
                                      .trim()
                                      .toLowerCase();

                                  if (_encargados.isNotEmpty) {
                                    final filtered = _encargados.where((e) {
                                      final cleanRut = e['rut_encargado']
                                          .toString()
                                          .replaceAll(RegExp(r'[^0-9kK]'), '')
                                          .toLowerCase();
                                      final name = e['nombre_encargado']
                                          .toString()
                                          .toLowerCase();
                                      return cleanRut.contains(query) ||
                                          name.contains(nameQuery);
                                    }).toList();

                                    if (filtered.isNotEmpty) {
                                      final matched = filtered.first;
                                      final rut =
                                          matched['rut_encargado'] as String;

                                      // Si el texto en el campo aún no es idéntico al RUT sugerido, autocompletamos y consumimos el evento
                                      if (controller.text != rut) {
                                        controller.text = rut;
                                        controller.selection =
                                            TextSelection.collapsed(
                                              offset: rut.length,
                                            );
                                        return KeyEventResult
                                            .handled; // Detiene la navegación por foco
                                      }
                                    }
                                  }
                                }
                                return KeyEventResult
                                    .ignored; // Permite el comportamiento por defecto (avanzar foco al botón)
                              },
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                inputFormatters: [RutFormatter()],
                                keyboardType: TextInputType.visiblePassword,
                                decoration: InputDecoration(
                                  labelText: 'RUT Encargado',
                                  errorText: _errorMessage,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.badge),
                                  suffixIcon: controller.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            controller.clear();
                                            setState(
                                              () => _errorMessage = null,
                                            );
                                          },
                                        )
                                      : null,
                                ),
                                onTap: () {
                                  // Forzar la visualización de la lista al hacer click
                                  if (controller.text.isEmpty) {
                                    controller.text = '';
                                  }
                                },
                                onSubmitted: (value) {
                                  onFieldSubmitted();
                                  _login();
                                },
                              ),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 6.0,
                                borderRadius: BorderRadius.circular(12),
                                clipBehavior: Clip.antiAlias,
                                child: Container(
                                  width:
                                      336, // Ancho adecuado para la lista desplegable en el centro
                                  color: Theme.of(context).cardColor,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 220,
                                    ),
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      separatorBuilder: (context, index) =>
                                          const Divider(height: 1),
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            final Map<String, dynamic> option =
                                                options.elementAt(index);
                                            return ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: Colors.blue
                                                    .withAlpha(26),
                                                child: const Icon(
                                                  Icons.person,
                                                  color: Colors.blue,
                                                  size: 18,
                                                ),
                                              ),
                                              title: Text(
                                                option['nombre_encargado']
                                                    as String,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              subtitle: Text(
                                                option['rut_encargado']
                                                    as String,
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Ingresar',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
