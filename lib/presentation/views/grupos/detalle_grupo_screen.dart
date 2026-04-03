import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/grupo_ruta_model.dart';
import '../../../data/models/miembro_grupo_model.dart';
import '../../../data/models/sesion_ruta_activa_model.dart';
import '../../../data/repositories/grupo_repository.dart';
import '../../blocs/auth/auth/auth_bloc.dart';
import '../../blocs/grupos/detalle_grupo/detalle_grupo_bloc.dart';
import '../../widgets/grupos/solicitudes_grupo_dialog.dart';
import 'editar_grupo_screen.dart';
import 'mapa_compartido_screen.dart';
import '../../blocs/grupos/mapa_compartido/sesion/mapa_sesion_bloc.dart';
import '../../blocs/grupos/mapa_compartido/sesion/mapa_sesion_event.dart';
import '../../blocs/grupos/mapa_compartido/tracking/mapa_tracking_bloc.dart';
import '../../blocs/grupos/mapa_compartido/tracking/mapa_tracking_event.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../services/location_tracking_service.dart';

/// Pantalla de detalle de un grupo
///
/// Patrón: MVVM + BLoC
/// - View solo dispara eventos y consume estados
/// - DetalleGrupoBloc maneja toda la lógica de negocio
///
/// NOTA: Supabase.instance.client se usa solo para obtener el userId actual
/// para lógica de presentación (determinar si mostrar "Tú" badge y permisos
/// de expulsión). Esto es aceptable según el patrón — no es lógica de negocio.
class DetalleGrupoScreen extends StatelessWidget {
  final GrupoRutaModel grupo;

  const DetalleGrupoScreen({
    super.key,
    required this.grupo,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DetalleGrupoBloc(
        grupoRepository: context.read<GrupoRepository>(),
        grupoId: grupo.id,
      )..add(const DetalleGrupoLoadRequested()),
      child: _DetalleGrupoScreenBody(grupo: grupo),
    );
  }
}

class _DetalleGrupoScreenBody extends StatefulWidget {
  final GrupoRutaModel grupo;

  const _DetalleGrupoScreenBody({required this.grupo});

  @override
  State<_DetalleGrupoScreenBody> createState() => _DetalleGrupoScreenBodyState();
}

class _DetalleGrupoScreenBodyState extends State<_DetalleGrupoScreenBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _tabActual = 0;
  late GrupoRutaModel _grupoActual;

  @override
  void initState() {
    super.initState();
    _grupoActual = widget.grupo;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _tabActual = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DetalleGrupoBloc, DetalleGrupoState>(
      listener: (context, state) {
        // Manejar acciones puntuales
        switch (state.actionStatus) {
          case DetalleGrupoActionStatus.sesionCreada:
            if (state.sesionCreada != null) {
              _abrirMapaCompartido(state.sesionCreada!);
            }
            break;
          case DetalleGrupoActionStatus.sesionFinalizada:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sesión finalizada correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            break;
          case DetalleGrupoActionStatus.miembroExpulsado:
            if (state.actionMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.actionMessage!),
                  backgroundColor: Colors.green,
                ),
              );
            }
            break;
          case DetalleGrupoActionStatus.grupoSalido:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Has salido del grupo'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
            break;
          case DetalleGrupoActionStatus.grupoEliminado:
            Navigator.pop(context, true);
            break;
          case DetalleGrupoActionStatus.codigoRegenerado:
            if (state.nuevoCodigo != null) {
              setState(() {
                _grupoActual = _grupoActual.copyWith(
                  codigoInvitacion: state.nuevoCodigo,
                );
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Nuevo código: ${state.nuevoCodigo}'),
                  backgroundColor: Colors.green,
                  action: SnackBarAction(
                    label: 'COPIAR',
                    textColor: Colors.white,
                    onPressed: () => _copiarCodigo(state.nuevoCodigo!),
                  ),
                ),
              );
            }
            break;
          case DetalleGrupoActionStatus.error:
            if (state.actionErrorMessage != null) {
              // Detectar si es error de sesión activa existente
              final errorMsg = state.actionErrorMessage!;
              if (errorMsg.contains('Ya tienes una sesión activa')) {
                _mostrarDialogoSesionExistente(errorMsg);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $errorMsg'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
            break;
          default:
            break;
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_grupoActual.nombre),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<DetalleGrupoBloc>().add(
                  const DetalleGrupoLoadRequested(),
                ),
              ),
              // Badge de solicitudes pendientes (solo admin)
              if (state.esAdmin && state.solicitudesPendientes > 0)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person_add),
                      onPressed: _mostrarSolicitudes,
                      tooltip: 'Solicitudes pendientes',
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '${state.solicitudesPendientes}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              // Menú de opciones
              PopupMenuButton<String>(
                onSelected: (value) => _onMenuSelected(value, state),
                itemBuilder: (context) => [
                  if (state.esAdmin) ...[
                    const PopupMenuItem(
                      value: 'solicitudes',
                      child: Row(
                        children: [
                          Icon(Icons.person_add),
                          SizedBox(width: 8),
                          Text('Solicitudes pendientes'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Editar grupo'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar grupo', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  if (!state.esAdmin)
                    const PopupMenuItem(
                      value: 'salir',
                      child: Row(
                        children: [
                          Icon(Icons.exit_to_app, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Salir del grupo', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Miembros', icon: Icon(Icons.people)),
                Tab(text: 'Sesiones', icon: Icon(Icons.route)),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildMiembrosTab(state),
              _buildSesionesTab(state),
            ],
          ),
          floatingActionButton: _tabActual == 1
              ? FloatingActionButton.extended(
                  onPressed: _iniciarSesion,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar Sesión'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildMiembrosTab(DetalleGrupoState state) {
    if (state.status == DetalleGrupoStatus.loading ||
        state.status == DetalleGrupoStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DetalleGrupoBloc>().add(const DetalleGrupoLoadRequested());
      },
      child: Column(
        children: [
          _buildGrupoInfo(state),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
              itemCount: state.miembros.length,
              itemBuilder: (context, index) {
                final miembro = state.miembros[index];
                return _buildMiembroCard(miembro, state);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrupoInfo(DetalleGrupoState state) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_grupoActual.fotoUrl != null) ...[
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(_grupoActual.fotoUrl!),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_grupoActual.descripcion != null &&
                _grupoActual.descripcion!.isNotEmpty) ...[
              Text(
                _grupoActual.descripcion!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                const Icon(Icons.vpn_key, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Código: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _grupoActual.codigoInvitacion,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _copiarCodigo(_grupoActual.codigoInvitacion),
                  tooltip: 'Copiar código',
                ),
                if (state.esAdmin)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _regenerarCodigo,
                    tooltip: 'Regenerar código',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people, size: 20),
                const SizedBox(width: 8),
                Text('${state.miembros.length} miembros'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiembroCard(MiembroGrupoModel miembro, DetalleGrupoState state) {
    final authState = context.read<AuthBloc>().state;
    final miUsuarioId = authState is AuthAuthenticated ? authState.user.id : null;
    final esUsuarioActual = miembro.usuarioId == miUsuarioId;
    final puedeExpulsar = state.esAdmin && !esUsuarioActual && !miembro.esAdmin;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: miembro.fotoPerfilUsuario != null
              ? NetworkImage(miembro.fotoPerfilUsuario!)
              : null,
          child: miembro.fotoPerfilUsuario == null
              ? Text(miembro.nombreUsuario?.substring(0, 1).toUpperCase() ?? 'U')
              : null,
        ),
        title: Row(
          children: [
            Expanded(child: Text(miembro.nombreUsuario ?? 'Usuario')),
            if (esUsuarioActual)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Tú',
                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (miembro.apodoUsuario != null) Text('Apodo: ${miembro.apodoUsuario}'),
            Text(
              'Unido: ${_formatFecha(miembro.fechaUnion)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (miembro.esAdmin)
              Chip(
                label: const Text(
                  'Admin',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
                backgroundColor: Colors.blue,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            if (puedeExpulsar)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'expulsar') {
                    _confirmarExpulsion(miembro);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'expulsar',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Expulsar', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSesionesTab(DetalleGrupoState state) {
    if (state.status == DetalleGrupoStatus.loading ||
        state.status == DetalleGrupoStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.sesionesActivas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('No hay sesiones activas'),
            const SizedBox(height: 8),
            const Text(
              'Inicia una sesión para comenzar a compartir ubicaciones en tiempo real',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DetalleGrupoBloc>().add(const DetalleGrupoLoadRequested());
      },
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 80),
        itemCount: state.sesionesActivas.length,
        itemBuilder: (context, index) {
          final sesion = state.sesionesActivas[index];
          return _buildSesionCard(sesion, state);
        },
      ),
    );
  }

  Widget _buildSesionCard(SesionRutaActivaModel sesion, DetalleGrupoState state) {
    final authState = context.read<AuthBloc>().state;
    final miUsuarioId = authState is AuthAuthenticated ? authState.user.id : null;
    final esLiderDeSesion = sesion.iniciadaPor == miUsuarioId;
    final puedeFinalizarSesion = esLiderDeSesion || state.esAdmin;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: sesion.estaActiva ? Colors.green : Colors.orange,
          child: Icon(
            sesion.estaActiva ? Icons.navigation : Icons.pause,
            color: Colors.white,
          ),
        ),
        title: Text(
          sesion.nombreSesion,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sesion.descripcion != null) Text(sesion.descripcion!),
            Text(
              'Iniciada: ${_formatFecha(sesion.fechaInicio)}',
              style: const TextStyle(fontSize: 12),
            ),
            if (sesion.duracion != null)
              Text(
                'Duración: ${_formatDuracion(sesion.duracion!)}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (puedeFinalizarSesion && sesion.estaActiva)
              IconButton(
                icon: const Icon(Icons.stop_circle, color: Colors.red),
                onPressed: () => _finalizarSesionDesdeLista(sesion),
                tooltip: 'Finalizar sesión',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            if (puedeFinalizarSesion && sesion.estaActiva)
              const SizedBox(width: 8),
            Icon(
              sesion.estaActiva ? Icons.arrow_forward_ios : Icons.history,
              size: 16,
            ),
          ],
        ),
        onTap: () => _abrirMapaCompartido(sesion),
      ),
    );
  }

  // ========================================
  // HELPERS DE FORMATO (pura presentación)
  // ========================================

  String _formatFecha(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    if (diferencia.inDays > 0) {
      return 'Hace ${diferencia.inDays} días';
    } else if (diferencia.inHours > 0) {
      return 'Hace ${diferencia.inHours} horas';
    } else if (diferencia.inMinutes > 0) {
      return 'Hace ${diferencia.inMinutes} minutos';
    } else {
      return 'Ahora';
    }
  }

  String _formatDuracion(Duration duracion) {
    final horas = duracion.inHours;
    final minutos = duracion.inMinutes % 60;
    if (horas > 0) {
      return '$horas h $minutos min';
    }
    return '$minutos min';
  }

  void _copiarCodigo(String codigo) {
    Clipboard.setData(ClipboardData(text: codigo));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado al portapapeles')),
    );
  }

  // ========================================
  // ACCIONES — Delegan al BLoC
  // ========================================

  Future<void> _iniciarSesion() async {
    final nombreController = TextEditingController();
    final descripcionController = TextEditingController();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar Sesión'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la sesión *',
                  hintText: 'Ej: Ruta al Volcán',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nombreController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa un nombre')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('INICIAR'),
          ),
        ],
      ),
    );

    if (resultado == true && mounted) {
      context.read<DetalleGrupoBloc>().add(
        DetalleGrupoSesionInitRequested(
          nombreSesion: nombreController.text.trim(),
          descripcion: descripcionController.text.trim().isEmpty
              ? null
              : descripcionController.text.trim(),
        ),
      );
    }

    nombreController.dispose();
    descripcionController.dispose();
  }

  void _abrirMapaCompartido(SesionRutaActivaModel sesion) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => MapaSesionBloc(
                grupoRepository: context.read<GrupoRepository>(),
                authRepository: context.read<AuthRepository>(),
              )..add(MapaSesionInicializar(sesion: sesion, grupo: widget.grupo)),
            ),
            BlocProvider(
              create: (context) => MapaTrackingBloc(
                grupoRepository: context.read<GrupoRepository>(),
                trackingService: context.read<LocationTrackingService>(),
              )..add(MapaTrackingIniciar(sesion.id)),
            ),
          ],
          child: MapaCompartidoScreen(
            sesion: sesion,
            grupo: widget.grupo,
          ),
        ),
      ),
    ).then((_) {
      if (mounted) {
        context.read<DetalleGrupoBloc>().add(const DetalleGrupoLoadRequested());
      }
    });
  }

  void _onMenuSelected(String value, DetalleGrupoState state) {
    switch (value) {
      case 'editar':
        _editarGrupo();
        break;
      case 'eliminar':
        _eliminarGrupo();
        break;
      case 'solicitudes':
        _mostrarSolicitudes();
        break;
      case 'salir':
        _confirmarSalida();
        break;
    }
  }

  void _mostrarSolicitudes() {
    showDialog(
      context: context,
      builder: (context) => SolicitudesGrupoDialog(
        grupoId: widget.grupo.id,
        grupoNombre: _grupoActual.nombre,
      ),
    ).then((_) {
      if (mounted) {
        context.read<DetalleGrupoBloc>().add(const DetalleGrupoLoadRequested());
      }
    });
  }

  void _mostrarDialogoSesionExistente(String errorMsg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sesión Activa Existente'),
        content: Text(errorMsg.replaceAll('Exception: ', '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarSalida() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salir del Grupo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de que deseas salir de "${_grupoActual.nombre}"?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Si sales, no podrás reingresar directamente. Deberás solicitar permiso al líder.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SALIR'),
          ),
        ],
      ),
    );

    if (confirmacion == true && mounted) {
      context.read<DetalleGrupoBloc>().add(const DetalleGrupoSalidaRequested());
    }
  }

  Future<void> _confirmarExpulsion(MiembroGrupoModel miembro) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Expulsar Miembro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de expulsar a "${miembro.nombreUsuario ?? 'este miembro'}"?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El usuario no podrá reingresar directamente. Deberá solicitar permiso.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('EXPULSAR'),
          ),
        ],
      ),
    );

    if (confirmacion == true && mounted) {
      context.read<DetalleGrupoBloc>().add(
        DetalleGrupoMiembroExpulsadoRequested(
          usuarioId: miembro.usuarioId,
          nombreUsuario: miembro.nombreUsuario,
        ),
      );
    }
  }

  void _editarGrupo() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarGrupoScreen(grupo: widget.grupo),
      ),
    );

    if (resultado == true && mounted) {
      context.read<DetalleGrupoBloc>().add(const DetalleGrupoLoadRequested());
    }
  }

  void _regenerarCodigo() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerar Código'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Estás seguro de regenerar el código de invitación?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El código anterior dejará de funcionar inmediatamente.',
                      style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REGENERAR'),
          ),
        ],
      ),
    );

    if (confirmacion == true && mounted) {
      context.read<DetalleGrupoBloc>().add(const DetalleGrupoCodigoRegenerado());
    }
  }

  Future<void> _finalizarSesionDesdeLista(SesionRutaActivaModel sesion) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Sesión'),
        content: Text(
          '¿Estás seguro de que deseas finalizar la sesión "${sesion.nombreSesion}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('FINALIZAR'),
          ),
        ],
      ),
    );

    if (confirmacion == true && mounted) {
      context.read<DetalleGrupoBloc>().add(
        DetalleGrupoSesionFinalizada(sesion.id),
      );
    }
  }

  Future<void> _eliminarGrupo() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Grupo'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este grupo? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirmacion == true && mounted) {
      context.read<DetalleGrupoBloc>().add(const DetalleGrupoEliminado());
    }
  }
}
