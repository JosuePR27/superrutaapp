import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MiSuperApp());
}

// ==================== MODELOS DE DATOS ====================
class Producto {
  String nombre;
  int pasillo;

  Producto({required this.nombre, required this.pasillo});

  Map<String, dynamic> toJson() => {'nombre': nombre, 'pasillo': pasillo};
  factory Producto.fromJson(Map<String, dynamic> json) =>
      Producto(nombre: json['nombre'], pasillo: json['pasillo']);
}

class Tienda {
  String nombre;
  List<Producto> inventario;

  Tienda({required this.nombre, required this.inventario});

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'inventario': inventario.map((p) => p.toJson()).toList()
      };
  factory Tienda.fromJson(Map<String, dynamic> json) {
    var list = json['inventario'] as List;
    List<Producto> prodList = list.map((i) => Producto.fromJson(i)).toList();
    return Tienda(nombre: json['nombre'], inventario: prodList);
  }
}

class RutaActiva {
  String nombreTienda;
  List<Producto> pendientes;
  List<Producto> agregados;

  RutaActiva({required this.nombreTienda, required this.pendientes, required this.agregados});

  Map<String, dynamic> toJson() => {
        'nombreTienda': nombreTienda,
        'pendientes': pendientes.map((p) => p.toJson()).toList(),
        'agregados': agregados.map((p) => p.toJson()).toList(),
      };

  factory RutaActiva.fromJson(Map<String, dynamic> json) {
    return RutaActiva(
      nombreTienda: json['nombreTienda'],
      pendientes: (json['pendientes'] as List).map((i) => Producto.fromJson(i)).toList(),
      agregados: (json['agregados'] as List).map((i) => Producto.fromJson(i)).toList(),
    );
  }
}

// ==================== APLICACIÓN PRINCIPAL ====================
class MiSuperApp extends StatelessWidget {
  const MiSuperApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const PantallaTiendas(),
    );
  }
}

// ==================== PANTALLA 1: LISTA DE TIENDAS ====================
class PantallaTiendas extends StatefulWidget {
  const PantallaTiendas({super.key});
  @override
  State<PantallaTiendas> createState() => _PantallaTiendasState();
}

class _PantallaTiendasState extends State<PantallaTiendas> {
  List<Tienda> misTiendas = [];
  RutaActiva? _rutaPendiente;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();

    // Cargar Tiendas
    final String? tiendasString = prefs.getString('guardado_tiendas');
    if (tiendasString != null) {
      final List<dynamic> jsonDecodificado = jsonDecode(tiendasString);
      misTiendas = jsonDecodificado.map((t) => Tienda.fromJson(t)).toList();
    } else {
      // Inventario por defecto la primera vez
      misTiendas = [
        Tienda(nombre: 'Súper Ejemplo', inventario: [
          Producto(nombre: 'Manzanas', pasillo: 1),
          Producto(nombre: 'Jabón', pasillo: 2),
          Producto(nombre: 'Arroz', pasillo: 3),
        ])
      ];
    }

    // Cargar Ruta Pendiente
    final String? rutaString = prefs.getString('ruta_pendiente');
    setState(() {
      if (rutaString != null) {
        _rutaPendiente = RutaActiva.fromJson(jsonDecode(rutaString));
      } else {
        _rutaPendiente = null;
      }
      _cargando = false;
    });
  }

  Future<void> _guardarTiendas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guardado_tiendas', jsonEncode(misTiendas.map((t) => t.toJson()).toList()));
  }

  void _eliminarTienda(int index) {
    setState(() {
      misTiendas.removeAt(index);
    });
    _guardarTiendas();
  }

  void _editarTienda(int index, String nuevoNombre) {
    if (nuevoNombre.trim().isEmpty) return;
    setState(() {
      misTiendas[index].nombre = nuevoNombre;
    });
    _guardarTiendas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Supermercados'), centerTitle: true),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_rutaPendiente != null)
                  Card(
                    color: Colors.amber[900],
                    margin: const EdgeInsets.all(12),
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_fill, color: Colors.white),
                      title: const Text('Ruta Pendiente', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Tienda: ${_rutaPendiente!.nombreTienda}'),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PantallaModoNavegacion(
                                tiendaNombre: _rutaPendiente!.nombreTienda,
                                rutaRestaurada: _rutaPendiente!,
                              ),
                            ),
                          );
                          _cargarDatos();
                        },
                        child: const Text('Reanudar'),
                      ),
                    ),
                  ),
                Expanded(
                  child: misTiendas.isEmpty
                      ? const Center(child: Text('Presiona + para añadir tu primer supermercado'))
                      : ListView.builder(
                          itemCount: misTiendas.length,
                          itemBuilder: (context, index) {
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: const Icon(Icons.storefront, color: Colors.blueAccent),
                                title: Text(misTiendas[index].nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${misTiendas[index].inventario.length} productos registrados'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'editar') {
                                          _mostrarDialogoTienda(context, tiendaAEditar: misTiendas[index], index: index);
                                        } else if (value == 'eliminar') {
                                          _eliminarTienda(index);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar nombre')])),
                                        const PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
                                      ],
                                    ),
                                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                  ],
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => PantallaDetalleTienda(tienda: misTiendas[index])),
                                  );
                                  _guardarTiendas();
                                  _cargarDatos();
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _mostrarDialogoTienda(context),
      ),
    );
  }

  void _mostrarDialogoTienda(BuildContext context, {Tienda? tiendaAEditar, int? index}) {
    final controller = TextEditingController(text: tiendaAEditar?.nombre ?? '');
    final esEdicion = tiendaAEditar != null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(esEdicion ? 'Editar Nombre de Tienda' : 'Nueva Tienda'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Ej. Walmart...'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
              onPressed: () {
                if (esEdicion) {
                  _editarTienda(index!, controller.text);
                } else {
                  if (controller.text.isNotEmpty) {
                    setState(() => misTiendas.add(Tienda(nombre: controller.text, inventario: [])));
                    _guardarTiendas();
                  }
                }
                Navigator.pop(context);
              },
              child: const Text('Guardar'))
        ],
      ),
    );
  }
}

// ==================== PANTALLA 2: GESTIÓN Y SELECCIÓN ====================
class PantallaDetalleTienda extends StatefulWidget {
  final Tienda tienda;
  const PantallaDetalleTienda({super.key, required this.tienda});
  @override
  State<PantallaDetalleTienda> createState() => _PantallaDetalleTiendaState();
}

class _PantallaDetalleTiendaState extends State<PantallaDetalleTienda> {
  final List<Producto> _productosAComprar = [];

  @override
  void initState() {
    super.initState();
    // --- NUEVO: Ordena el inventario alfabéticamente apenas entras a la tienda ---
    _ordenarInventarioAlfabeticamente();
  }

  // Función auxiliar para no repetir código de ordenamiento
  void _ordenarInventarioAlfabeticamente() {
    widget.tienda.inventario.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
  }

  void _agregarProductoAlInventario(String nombre, int pasillo) {
    setState(() {
      widget.tienda.inventario.add(Producto(nombre: nombre, pasillo: pasillo));
      _ordenarInventarioAlfabeticamente();
    });
  }

  void _editarProducto(Producto producto, String nuevoNombre, int nuevoPasillo) {
    setState(() {
      producto.nombre = nuevoNombre;
      producto.pasillo = nuevoPasillo;
      _ordenarInventarioAlfabeticamente();
    });
  }

  void _eliminarProducto(Producto producto) {
    setState(() {
      widget.tienda.inventario.remove(producto);
      _productosAComprar.remove(producto);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventario = widget.tienda.inventario;

    return Scaffold(
      appBar: AppBar(title: Text(widget.tienda.nombre), centerTitle: true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              'Selecciona los productos para comprar hoy o desliza a la izquierda para eliminar:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: inventario.isEmpty
                ? const Center(child: Text('No hay productos en esta tienda.'))
                : ListView.builder(
                    itemCount: inventario.length,
                    itemBuilder: (context, i) {
                      final prod = inventario[i];
                      final estaSeleccionado = _productosAComprar.contains(prod);

                      return Dismissible(
                        key: UniqueKey(),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.redAccent,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [Icon(Icons.delete, color: Colors.white), SizedBox(width: 8), Text('Eliminar')],
                          ),
                        ),
                        onDismissed: (direction) {
                          _eliminarProducto(prod);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${prod.nombre} eliminado')));
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueGrey),
                              onPressed: () => _mostrarDialogoProducto(context, productoAEditar: prod),
                            ),
                            title: Text(prod.nombre),
                            subtitle: Text('Pasillo: ${prod.pasillo}'),
                            trailing: Icon(
                              estaSeleccionado ? Icons.check_box : Icons.check_box_outline_blank,
                              color: estaSeleccionado ? Colors.greenAccent : Colors.grey,
                            ),
                            onTap: () {
                              setState(() {
                                if (estaSeleccionado) {
                                  _productosAComprar.remove(prod);
                                } else {
                                  _productosAComprar.add(prod);
                                }
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60.0),
        child: FloatingActionButton(
          heroTag: 'add_prod',
          backgroundColor: Colors.blueGrey,
          onPressed: () => _mostrarDialogoProducto(context),
          child: const Icon(Icons.add_shopping_cart, color: Colors.white),
        ),
      ),
      bottomNavigationBar: _productosAComprar.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton.icon(
                onPressed: () async {
                  List<Producto> rutaOptimizada = List.from(_productosAComprar);
                  rutaOptimizada.sort((a, b) => a.pasillo.compareTo(b.pasillo));

                  final rutaActiva = RutaActiva(nombreTienda: widget.tienda.nombre, pendientes: rutaOptimizada, agregados: []);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('ruta_pendiente', jsonEncode(rutaActiva.toJson()));

                  if (context.mounted) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PantallaModoNavegacion(tiendaNombre: widget.tienda.nombre, rutaRestaurada: rutaActiva),
                      ),
                    );
                    setState(() {
                      _productosAComprar.clear(); // Limpiar al regresar si se finalizó
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.directions_run),
                label: Text('Iniciar Ruta Eficiente (${_productosAComprar.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          : null,
    );
  }

  void _mostrarDialogoProducto(BuildContext context, {Producto? productoAEditar}) {
    final nombreCtrl = TextEditingController(text: productoAEditar?.nombre ?? '');
    final pasilloCtrl = TextEditingController(text: productoAEditar?.pasillo.toString() ?? '');
    final esEdicion = productoAEditar != null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(esEdicion ? 'Editar Producto' : 'Registrar Producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del Producto'), autofocus: true),
            TextField(controller: pasilloCtrl, decoration: const InputDecoration(labelText: 'Número de Pasillo'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
              onPressed: () {
                final pasilloInt = int.tryParse(pasilloCtrl.text) ?? 0;
                if (nombreCtrl.text.isNotEmpty) {
                  if (esEdicion) {
                    _editarProducto(productoAEditar, nombreCtrl.text, pasilloInt);
                  } else {
                    _agregarProductoAlInventario(nombreCtrl.text, pasilloInt);
                  }
                }
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Guardar'))
        ],
      ),
    );
  }
}

// ==================== PANTALLA 3: MODO NAVEGACIÓN ====================
class PantallaModoNavegacion extends StatefulWidget {
  final String tiendaNombre;
  final RutaActiva rutaRestaurada;
  const PantallaModoNavegacion({super.key, required this.tiendaNombre, required this.rutaRestaurada});
  @override
  State<PantallaModoNavegacion> createState() => _PantallaModoNavegacionState();
}

class _PantallaModoNavegacionState extends State<PantallaModoNavegacion> {
  late List<Producto> _pendientes;
  late List<Producto> _agregados;

  @override
  void initState() {
    super.initState();
    _pendientes = widget.rutaRestaurada.pendientes;
    _agregados = widget.rutaRestaurada.agregados;
  }

  Future<void> _guardarProgreso() async {
    final prefs = await SharedPreferences.getInstance();
    final ruta = RutaActiva(nombreTienda: widget.tiendaNombre, pendientes: _pendientes, agregados: _agregados);
    await prefs.setString('ruta_pendiente', jsonEncode(ruta.toJson()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Comprando en: ${widget.tiendaNombre}'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // --- SECCIÓN PENDIENTES ---
                  const Text('Pendientes (Ordenados por Pasillo)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                  const SizedBox(height: 10),
                  if (_pendientes.isEmpty)
                    const Padding(padding: EdgeInsets.all(8.0), child: Text('¡No quedan productos pendientes! 🎉', style: TextStyle(color: Colors.grey)))
                  else
                    ..._pendientes.map((prod) => Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.blueAccent, child: Text('P${prod.pasillo}', style: const TextStyle(fontSize: 12, color: Colors.white))),
                            title: Text(prod.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                              onPressed: () {
                                setState(() {
                                  _pendientes.remove(prod);
                                  _agregados.add(prod);
                                });
                                _guardarProgreso();
                              },
                            ),
                          ),
                        )),

                  const Divider(height: 40, thickness: 2),

                  // --- SECCIÓN AGREGADOS ---
                  const Text('Agregados al Carrito', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),
                  if (_agregados.isEmpty)
                    const Padding(padding: EdgeInsets.all(8.0), child: Text('El carrito está vacío', style: TextStyle(color: Colors.grey)))
                  else
                    ..._agregados.map((prod) => Card(
                          color: Colors.grey[900],
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.shopping_cart, color: Colors.grey),
                            title: Text(prod.nombre, style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough)),
                            subtitle: Text('Pasillo ${prod.pasillo}', style: const TextStyle(color: Colors.grey)),
                            trailing: IconButton(
                              icon: const Icon(Icons.undo, color: Colors.amberAccent),
                              onPressed: () {
                                setState(() {
                                  _agregados.remove(prod);
                                  _pendientes.add(prod);
                                  _pendientes.sort((a, b) => a.pasillo.compareTo(b.pasillo)); // Reordenar al regresar
                                });
                                _guardarProgreso();
                              },
                            ),
                          ),
                        )),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // --- BOTÓN FINALIZAR ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                icon: const Icon(Icons.done_all),
                label: const Text('Finalizar Ruta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('ruta_pendiente'); // Eliminar de SharedPreferences
                  if (context.mounted) {
                    Navigator.pop(context); // Regresar
                  }
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}