// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class LEs extends L {
  LEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'SANSLAB IoT Server';

  @override
  String get navOverview => 'Resumen';

  @override
  String get navManage => 'Gestionar';

  @override
  String get navApps => 'Aplicaciones';

  @override
  String get navBuild => 'Construir';

  @override
  String get navDashboard => 'Panel';

  @override
  String get navProjects => 'Proyectos';

  @override
  String get navOrders => 'Pedidos';

  @override
  String get navCustomers => 'Clientes';

  @override
  String get navProducts => 'Productos';

  @override
  String get navInbox => 'Bandeja';

  @override
  String get navBoard => 'Tablero';

  @override
  String get navCalendar => 'Calendario';

  @override
  String get navChat => 'Chat';

  @override
  String get navComponents => 'Componentes';

  @override
  String get navForms => 'Formularios';

  @override
  String get navWizard => 'Asistente';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get navProfile => 'Perfil';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionRefresh => 'Actualizar';

  @override
  String get actionExport => 'Exportar';

  @override
  String get actionSearch => 'Buscar';

  @override
  String get actionClear => 'Limpiar';

  @override
  String get actionPrevious => 'Anterior';

  @override
  String get actionNext => 'Siguiente';

  @override
  String get actionSignIn => 'Iniciar sesión';

  @override
  String get actionSignOut => 'Cerrar sesión';

  @override
  String get signInTitle => 'Iniciar sesión';

  @override
  String get signInSubtitle =>
      'Cualquier correo sirve — es el proveedor simulado.';

  @override
  String get fieldEmail => 'Correo';

  @override
  String get fieldPassword => 'Contraseña';

  @override
  String get fieldName => 'Nombre';

  @override
  String get forgotPassword => '¿Olvidaste la contraseña?';

  @override
  String get noAccount => '¿Sin cuenta? Crea una';

  @override
  String get lightMode => 'Modo claro';

  @override
  String get darkMode => 'Modo oscuro';

  @override
  String get language => 'Idioma';

  @override
  String get theme => 'Tema';

  @override
  String get accent => 'Acento';

  @override
  String get emptyTitle => 'Nada coincide con esos filtros';

  @override
  String get emptyMessage =>
      'Prueba a limpiar la búsqueda o elegir otro estado.';

  @override
  String get errorTitle => 'Algo salió mal';

  @override
  String get errorRetry => 'Reintentar';

  @override
  String pageOf(int page, int pages) {
    return 'Página $page de $pages';
  }

  @override
  String rangeOfTotal(int first, int last, int total) {
    return '$first–$last de $total';
  }

  @override
  String get accountInfo => 'Información de la cuenta';

  @override
  String get accountSubtitle =>
      'Ver detalles de identidad y sesión activa para esta cuenta.';

  @override
  String get accountIdentityTitle => 'Información de identidad';

  @override
  String get accountUserId => 'ID de usuario (UUID)';

  @override
  String get accountEmail => 'Correo electrónico';

  @override
  String get accountFullName => 'Nombre completo';

  @override
  String get accountRole => 'Rol de puerta de enlace';

  @override
  String get accountRoleUnassigned => 'Sin rol asignado';

  @override
  String get accountRoleNote =>
      'Los permisos se verifican dinámicamente por puerta de enlace en el backend.';

  @override
  String get accountSessionTitle => 'Sesión y seguridad';

  @override
  String get accountSessionStatus => 'Estado de la sesión';

  @override
  String get accountStatusActive => 'Activa';

  @override
  String get accountAuthMethod => 'Método de autenticación';

  @override
  String get accountAuthMethodValue =>
      'Supabase Auth (GoTrue) · Verificación local HS256';

  @override
  String get accountAdminNoteTitle => 'Política de gestión de cuentas';

  @override
  String get accountAdminNote =>
      'Las cuentas se gestionan de forma centralizada por los administradores.';

  @override
  String get accountCopyId => 'Copiar ID';

  @override
  String get accountCopiedId => 'ID de usuario copiado al portapapeles';

  @override
  String get accountBackToDashboard => 'Volver al panel';

  @override
  String get navGateways => 'Pasarelas';

  @override
  String get gatewayListTitle => 'Pasarelas';

  @override
  String get gatewayListSubtitle =>
      'Lista de pasarelas accesibles en la plataforma.';

  @override
  String get gatewayId => 'ID de pasarela';

  @override
  String get gatewayName => 'Nombre';

  @override
  String get gatewayDescription => 'Descripción';

  @override
  String get gatewayRole => 'Rol';

  @override
  String get gatewayCreatedAt => 'Fecha de creación';

  @override
  String get gatewaySearchPlaceholder =>
      'Buscar por ID, nombre o descripción...';

  @override
  String get gatewayEmptyTitle => 'No hay pasarelas';

  @override
  String get gatewayEmptyMessage =>
      'Su cuenta aún no tiene acceso a ninguna pasarela.';

  @override
  String get gatewaySearchEmptyTitle => 'Sin coincidencias';

  @override
  String get gatewaySearchEmptyMessage =>
      'Ninguna pasarela coincide con su búsqueda.';

  @override
  String get gatewayRoleOwner => 'Propietario';

  @override
  String get gatewayRoleOperator => 'Operador';

  @override
  String get gatewayRoleViewer => 'Visualizador';

  @override
  String get gatewayActionDetail => 'Detalles';

  @override
  String get gatewayDetailTitle => 'Detalles de la Pasarela';

  @override
  String get gatewayDetailSubtitle =>
      'Descripción general de la estación y sensores asociados.';

  @override
  String get gatewayNotFoundTitle => 'Pasarela no encontrada';

  @override
  String get gatewayNotFoundMessage =>
      'No se encontró la pasarela solicitada o no tiene permisos de acceso.';

  @override
  String get gatewayInvalidIdMessage =>
      'Identificador de pasarela no válido o reservado.';

  @override
  String get gatewayBackToList => 'Volver a Pasarelas';

  @override
  String get gatewaySectionMetadata => 'Información de la Pasarela';

  @override
  String get gatewaySectionSensors => 'Catálogo de Sensores';

  @override
  String get sensorId => 'ID de Sensor';

  @override
  String get sensorName => 'Nombre del Sensor';

  @override
  String get sensorUnit => 'Unidad';

  @override
  String get sensorCreatedAt => 'Fecha de creación';

  @override
  String get sensorEmptyTitle => 'No hay sensores configurados';

  @override
  String get sensorEmptyMessage =>
      'Aún no se han configurado sensores para esta pasarela.';

  @override
  String get sensorSearchPlaceholder =>
      'Buscar sensores por ID, nombre o unidad...';

  @override
  String get sensorSearchEmptyTitle => 'Sin coincidencias de sensores';

  @override
  String get sensorSearchEmptyMessage =>
      'Ningún sensor coincide con su búsqueda.';

  @override
  String get sensorErrorTitle => 'Error al cargar sensores';

  @override
  String get sensorErrorRetry => 'Reintentar cargar sensores';

  @override
  String get gatewayReadOnlyNotice =>
      'Modo de solo lectura (Fase 2). El control remoto no está activo.';
}
