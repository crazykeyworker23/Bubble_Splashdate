# Año de la Esperanza y el Fortalecimiento de la Democracia

**INFORME CONSOLIDADO N.º 004-FINTOUR-BUBBLE-2026**

**A:** Ing. José Enrique Arroyo Castillo (GERENTE GENERAL – FINATECH)  
**DE:** Pedro Alexander Nashnato Curitima (Programador Backend / Frontend)  
**ASUNTO:** Plataformas FINTOUR y Bubble Splashdate – Reporte Mensual Consolidado de Desarrollo  
**FECHA:** 1 - 30 de junio de 2026  

---

## E1. INFORME MENSUAL CONSOLIDADO – DESARROLLO UNIFICADO

Este documento presenta el informe mensual consolidado de desarrollo de las plataformas **FINTOUR** (Backend NestJS / Panel Web React) y **Bubble Splashdate** (Aplicación Móvil Flutter) correspondiente al mes de junio de 2026, estructurado cronológicamente semana a semana.

---

### SEMANA 1 (01 de junio al 07 de junio de 2026)

#### 1. Avances realizados (resumen)
*   **FINTOUR (Backend & Web):**
    *   **Autenticación Base y Persistencia:** Implementación de la arquitectura base de sesión agnóstica para soportar tanto clientes móviles como la aplicación web SPA. Creación del sistema de persistencia y renovación de tokens (refresh tokens) seguros.
    *   **Módulo de Chat con IA y Navegación Básica:** Maquetación de la barra de navegación inferior y el botón para interactuar con el agente de Inteligencia Artificial. Habilitación del ruteo hacia temas y detalles del catálogo.
*   **Bubble Splashdate (Mobile App):**
    *   **Configuración y Arranque del Proyecto:** Inicialización y arranque de servicios base de Firebase y Flutter.
    *   **Ajuste de Lanzamiento:** Remoción de la persistencia nativa del splash para dar paso al splash animado interno en `app.dart`. Estructuración inicial de rutas de acceso.

#### 2. Tareas completadas (detalle)
*   **Módulo Auth (Backend NestJS):** Creación de base de datos inicial para autenticación y carga de semillas con roles por defecto. Configuración del mecanismo de persistencia y rotación de tokens de refresco. Integración de Google OAuth y sincronización automática de cuentas a través del correo verificado.
*   **Estructura Auth & Chat (Frontend React):** Implementación del hook `useAuth` y middlewares de redirección. Creación del flujo de navegación y persistencia de sesión local. Integración de interfaz de chat impulsada por IA y ruteo a detalles de tours.
*   **Mobile Shell (Flutter):** Limpieza de directivas heredadas e inicialización del WidgetsBinding para control directo de transiciones en el primer frame pintado.

#### 3. Cambios y Commits Realizados (Unificado)
| Fecha | Plataforma | Autor | Rama | Mensaje de commit / Cambios |
| :--- | :--- | :--- | :--- | :--- |
| 2026-06-02 | FINTOUR | devfintour | devfintour | add: module auth whit seed data b2b-saas agnostic auth |
| 2026-06-03 | FINTOUR | devfintour | development | add: token percistence and refresh |
| 2026-06-05 | FINTOUR | devfintour | b2b-saas | add: oauth for google and sync email |
| 2026-06-06 | FINTOUR | devfintour | b2b-saas | middlewares for auth, auth with user and password |
| 2026-06-06 | FINTOUR | devfintour | development | implements useAuth, add session auth, add navigation to topics |
| 2026-06-06 | FINTOUR | devfintour | development | add chat with ai and navigation button |
| 2026-06-06 | FINTOUR | devfintour | development | change prefix modules for booking and catalogs |

---

### SEMANA 2 (08 de junio al 14 de junio de 2026)

#### 1. Avances realizados (resumen)
*   **FINTOUR (Backend & Web):**
    *   **Capa de Almacenamiento y Carga de Imágenes (StorageModule):** Diseño del backend de subida de imágenes con validaciones robustas y límites de tamaño. Configuración de almacenamiento local y esqueleto para AWS S3 en backend.
    *   **Dashboard de Administración y Recomendaciones:** Creación de las vistas iniciales de administración del panel web. Implementación del backend para el motor de recomendaciones personalizadas.
*   **Bubble Splashdate (Mobile App):**
    *   **Optimización de Vistas de Acceso:** Rediseño estético y pulido de la pantalla de inicio de sesión (`login_page.dart`) y vista de inicio (`inicio_page.dart`).

#### 2. Tareas completadas (detalle)
*   **Módulo Storage (Backend NestJS):** Creación del puerto `StoragePort`, la entidad de archivos guardados y la definición de excepciones de dominio. Desarrollo de `UploadFileUseCase` bajo TDD para validar mimetypes y tamaños. Creación de controlador de subida con Multer regulando el límite de DoS a 25 MiB y el límite de negocio a 5 MiB.
*   **Prisma & Seed (Backend NestJS):** Migración física y lógica de `AuthIdentity` aplicada y verificada con Docker.
*   **Frontend Admin & UI (React):** Ajuste de cabecera superior y enlaces de accesos rápidos. Creación de vistas de administración y enrutamiento del perfil de restaurantes. Implementación de la visualización dinámica del nombre del usuario en sesión y manejo del logout en UI.

#### 3. Cambios y Commits Realizados (Unificado)
| Fecha | Plataforma | Autor | Rama | Mensaje de commit / Cambios |
| :--- | :--- | :--- | :--- | :--- |
| 2026-06-08 | FINTOUR | devfintour | actions | atomic for bottom header and quick development recommendations module |
| 2026-06-11 | FINTOUR | devfintour | development | fix migration and seed new rules for docker |
| 2026-06-11 | FINTOUR | devfintour | b2b-saas | new view for admin and fix logout, show name user |
| 2026-06-12 | FINTOUR | devfintour | development | feat(storage): add StoragePort, StoredFile entity, and domain errors |
| 2026-06-12 | FINTOUR | devfintour | development | feat(storage): add UploadFileUseCase with mimetype/size validation (TDD) |
| 2026-06-12 | FINTOUR | devfintour | development | feat(storage): add LocalStorageAdapter, S3 skeleton, and provider factory |
| 2026-06-12 | FINTOUR | devfintour | development | feat(storage): add RestJwtAuthGuard, RolesGuard, and Roles decorator |
| 2026-06-12 | FINTOUR | devfintour | development | feat(storage): add upload controller with Multer and error mapping |
| 2026-06-12 | FINTOUR | devfintour | development | fix(storage): move 5 MiB business rule to use-case only; Multer is DoS guard |
| 2026-06-12 | FINTOUR | devfintour | development | merge imageupload feature into development branch |
| 2026-06-13 | FINTOUR | devfintour | b2b-saas | fix: user data for log session, admin dashboard, logout user |
| 2026-06-13 | FINTOUR | devfintour | b2b-saas | feat(auth): add Google Sign-In, real Google id_token & refresh-current-user |

---

### SEMANA 3 (15 de junio al 21 de junio de 2026)

#### 1. Avances realizados (resumen)
*   **FINTOUR (Backend & Web):**
    *   **Capa de Escritura de Catálogo y Seguridad de Roles:** Implementación del CRUD propietario para Tour, Guide, Restaurant y Experience a nivel de base de datos y GraphQL. Creación de un guardián de autorización GraphQL (`GqlRolesGuard`) para interceptar operaciones mediante metadatos de roles.
    *   **Eliminación Lógica (Soft-Delete):** Introducción del campo `isActive` para desactivar elementos en lugar de eliminarlos físicamente, resguardando compras y reservas pasadas.
*   **Bubble Splashdate (Mobile App):**
    *   **Restricciones de Interfaz en Producción:** Ocultamiento controlado de botones no funcionales o en fase de pruebas ("Escanear QR" y "Recargar") en la pantalla principal.
    *   **Sincronización Automática en background:** Preparación del servicio para mapeo de sucursales automáticas.

#### 2. Tareas completadas (detalle)
*   **Seguridad y Catálogos (Backend NestJS):** Guardián `GqlRolesGuard` integrado con `GqlExecutionContext`. Integración en `TourService.create` para vincular automáticamente el `guideId` a partir del token JWT de sesión. Sincronización del enum de roles (`UserRole`) y mapeo limpio de excepciones del negocio para ocultar trazas de Prisma.
*   **Frontend Dashboard SaaS B2B:** Maquetación del layout administrativo protegido (`AdminLayout.tsx`). Creación de formularios CRUD de edición y creación de perfiles para Guías (`GuideForm.tsx`), Restaurantes (`RestaurantForm.tsx`) y Experiencias (`ExperienceForm.tsx`).

#### 3. Cambios y Commits Realizados (Unificado)
| Fecha | Plataforma | Autor | Rama | Mensaje de commit / Cambios |
| :--- | :--- | :--- | :--- | :--- |
| 2026-06-15 | FINTOUR | devfintour | development | fix: render login ssr |
| 2026-06-16 | FINTOUR | devfintour | development | feat(auth): add web Google login via OAuth auth-code flow |
| 2026-06-17 | FINTOUR | devfintour | b2b-saas | feat(auth): use custom on-brand Google button via OAuth auth-code flow |
| 2026-06-19 | FINTOUR | devfintour | development | feat: add configurable domain support with secure CORS and cookies |
| 2026-06-20 | FINTOUR | devfintour | development | feat(catalog): add GQL roles guard and domain error mapper |
| 2026-06-20 | FINTOUR | devfintour | development | feat(catalog): add owner-scoped CRUD write for Tour, Guide, Restaurant, Experience |

---

### SEMANA 4 (22 de junio al 30 de junio de 2026) – *Semana Actual*

#### 1. Avances realizados (resumen)
*   **FINTOUR (Backend & Web):**
    *   **Integración de Suscripciones SaaS y Panel B2B:** Implementación de la Landing Page de SaaS para la adquisición de planes. Diseño del flujo de control de límites de catálogos basado en el plan contratado.
    *   **Soporte de Roles de Comercio (Merchant) y Despliegue:** Integración del rol `merchant` para agencias de tours y administradores comerciales. Preparación de un despliegue simplificado unificando el frontend y el backend en un solo contenedor Docker.
*   **Bubble Splashdate (Mobile App):**
    *   **Módulo de Notificaciones Push & In-App Premium:** Módulo para la recepción de alertas en primer plano mediante un banner animado translúcido flotante (`InAppNotificationBanner`) y receptor en background con notificaciones estilizadas nativas.
    *   **Menú de Alta Performance y Carga Asíncrona (Caché Híbrido):** Carga inmediata de menús usando caché local en `SharedPreferences` con refresco pasivo en segundo plano. Precarga asíncrona de imágenes de red (`precacheImage`) para evitar parpadeos, y visualización de un esqueleto de carga animado (`_MenuSkeletonLoader`).
    *   **Módulo Premium de Canje de Puntos:** Implementación del canje de cupones/códigos en tiempo real contra la API, refresco en caliente de puntos en UI, y animaciones lúdicas (efecto confeti y contador dinámico).
    *   **Perfil de Usuario Animado y Háptico:** Panel de actualización de perfil con vibraciones táctiles al entrar en edición y barra deslizante interactiva.
    *   **Resiliencia en Conectividad y HTTP:** Interceptor inteligente que evita cerrar la sesión del usuario ante caídas temporales de red y despliega un diálogo emergente premium de reintento.

#### 2. Tareas completadas (detalle)
*   **Despliegue & DevOps (Backend NestJS):** Configuración final del contenedor único Docker para servir tanto la API GraphQL como los estáticos compilados del frontend en entornos de piloto.
*   **Frontend SaaS & B2B Dashboards:** Creación de la página informativa de planes (`SubscriptionPricing.tsx`) y beneficios comerciales (`SaaSLandingPage.tsx`). Configuración final del rol merchant, aplicando límites de reservas y limpiando selectores simulados en la pantalla de inicio de sesión.
*   **Asociación de Sucursal Automática (Flutter):** Al iniciar la sesión, se evalúa si el usuario carece de tienda asignada (`srv_int_id == null` o `0`). De ser así, se le vincula a la sucursal por defecto (`srv_int_id: 1`) de forma transparente en background mediante PATCH.
*   **Sign-Out Concurrente Optimizado (Flutter):** El proceso de deslogueo realiza la llamada a Firebase y Google Sign-Out en paralelo con un timeout de 500ms, y limpia la persistencia local de forma concurrente (`Future.wait`) para evitar retrasos por llamadas a canales nativos.
*   **Notificaciones Inteligentes (Flutter):** Creación del helper `_extractTitleAndBody` para procesar notificaciones con estructuras de datos variables. Integración del banner elástico in-app e inicialización de alertas de segundo plano para Android en isolates separados con branding institucional (fondo azul `#0B3D4A` y logo a color).

#### 3. Cambios y Commits Realizados (Unificado)
| Fecha | Plataforma | Autor | Rama | Mensaje de commit / Cambios |
| :--- | :--- | :--- | :--- | :--- |
| 2026-06-22 | FINTOUR | devfintour | development | feat: single container Docker config |
| 2026-06-22 | FINTOUR | devfintour | b2b-saas | feat: implement SaaS landing page and B2B dashboard integration |
| 2026-06-29 | FINTOUR | devfintour | b2b-saas | fix: resolve temporal reference error (TDZ) in LayoutDashboard |
| 2026-06-29 | FINTOUR | devfintour | development | feat(saas): integrate merchant role, guides reservation limits, and clean up bypass |
| 2026-06-30 | BUBBLE | crazykeyworker23 | main | feat(init): remove native splash, add internal SessionGate auto-bootstrap |
| 2026-06-30 | BUBBLE | crazykeyworker23 | main | feat(branch): background store auto-association for user accounts |
| 2026-06-30 | BUBBLE | crazykeyworker23 | main | feat(notifications): add foreground banner, background handling and Android custom branding |
| 2026-06-30 | BUBBLE | crazykeyworker23 | main | feat(menu): add category/product caching, images pre-caching and _MenuSkeletonLoader |
| 2026-06-30 | BUBBLE | crazykeyworker23 | main | feat(redemption): build Real-time Points Redemption with confetti and animated counter |
| 2026-06-30 | BUBBLE | crazykeyworker23 | main | feat(profile): enhance edit UI with save animations, haptic feedback and education field |
| 2026-06-30 | BUBBLE | crazykeyworker23 | main | feat(http): protect HTTP refresh flow to keep session active on poor connection |

---

## E2. EVIDENCIAS TÉCNICAS

### Módulos y Componentes Clave Modificados

| Plataforma | Módulo / Componente | Archivo principal | Propósito y funcionalidad clave |
| :--- | :--- | :--- | :--- |
| **FINTOUR** | Controlador de Acceso | `gql-roles.guard.ts` | Filtro de roles de usuario en GraphQL para denegar peticiones no autorizadas en resolvers protegidos. |
| **FINTOUR** | Servicio de Catálogos | `tour.service.ts` | Capa de escritura de tours controlando autoría (ownership) y baja lógica mediante bandera `isActive`. |
| **FINTOUR** | Caso de Uso de Carga | `upload-file.use-case.ts` | Reglas de validación de mimetype y tamaño (máximo 5 MiB) para subida de recursos multimedia. |
| **FINTOUR** | Almacenamiento | `local-storage.adapter.ts` | Persistencia local de imágenes subidas en el sistema de archivos del servidor. |
| **FINTOUR** | Enrutamiento Seguro | `_authenticated.tsx` | Ruteador de TanStack Router que valida sesión activa en el cliente antes de cargar los dashboards. |
| **FINTOUR** | Precios Suscripción | `SubscriptionPricing.tsx` | Vista de planes de suscripción de la plataforma con límites detallados por nivel. |
| **BUBBLE** | Inicializador de App | [app_init.dart](file:///Users/finatech/Bubble_Splashdate/lib/services/app_init.dart) | Registra receptores de notificaciones push, personaliza notificaciones nativas en Android, y gestiona notificaciones flotantes. |
| **BUBBLE** | Gestor de Sesiones | [session_manager.dart](file:///Users/finatech/Bubble_Splashdate/lib/services/session_manager.dart) | Cierra sesiones en paralelo contra APIs locales y Firebase/Google con protección ante retardos de red. |
| **BUBBLE** | Vista de Menú | [menu_page.dart](file:///Users/finatech/Bubble_Splashdate/lib/views/home/menu_page.dart) | Implementa la visualización instantánea con caché offline, precarga de imágenes de productos y skeleton animado. |
| **BUBBLE** | Canje de Puntos | [canjear_puntos_page.dart](file:///Users/finatech/Bubble_Splashdate/lib/widgets/canjear_puntos_page.dart) | Formulario de redención de códigos contra backend, refresco automático de puntajes y efectos festivos. |
| **BUBBLE** | Perfil de Usuario | [mi_perfil_page.dart](file:///Users/finatech/Bubble_Splashdate/lib/widgets/mi_perfil_page.dart) | Formulario con feedback háptico, barra deslizante animada para guardado, y pulso de edición en avatar. |
| **BUBBLE** | Cliente HTTP | [app_http.dart](file:///Users/finatech/Bubble_Splashdate/lib/services/app_http.dart) | Interceptor que previene desloguear al usuario ante problemas pasajeros de red durante el refresh del token. |
| **BUBBLE** | Alerta de Red | [connection_error_dialog.dart](file:///Users/finatech/Bubble_Splashdate/lib/widgets/connection_error_dialog.dart) | Diálogo emergente premium que aparece si falla la conexión a internet, ofreciendo reintento manual. |
| **BUBBLE** | Banner Notificaciones | [in_app_notification_banner.dart](file:///Users/finatech/Bubble_Splashdate/lib/widgets/in_app_notification_banner.dart) | Componente translúcido de alerta superior animado con elasticidad y soporte para descarte con deslizamiento vertical. |

---

## E3. PENDIENTES, RIESGOS Y COMPROMISOS

### 1. Pendientes
*   **Validaciones Avanzadas en Inputs (FINTOUR & BUBBLE):** Implementar reglas de validación en frontend para bloquear coordenadas geográficas erróneas y precios negativos en la web, así como validaciones finas en los campos de edición de perfil móvil.
*   **Testing de Integración en Carga (FINTOUR):** Expandir las pruebas automatizadas del flujo de subida de imágenes simulando cargas simultáneas y caídas del almacenamiento local.
*   **Refresco de Caché en Apollo (FINTOUR):** Configurar la actualización automática del caché de Apollo Client en mutaciones críticas para evitar datos desactualizados en el Panel Web.
*   **Pruebas de Red en Zonas de Baja Señal (BUBBLE):** Validar el comportamiento de las notificaciones locales en segundo plano ante reconexión tardía de red.

### 2. Riesgos
*   **Inconsistencia de Almacenamiento Local (FINTOUR):** Si el servidor en un único contenedor de Docker se reinicia sin volúmenes persistentes vinculados, las imágenes subidas por los comercios podrían perderse. Se mitiga configurando volúmenes compartidos en el host o migrando a AWS S3.
*   **Dependencia de APIs Externas (BUBBLE):** El módulo de canje y progreso depende del tiempo de respuesta del backend B2B. Si el servidor Fintour entra en mantenimiento, la experiencia de canje presentará retrasos mitigados en parte por el nuevo modal de error.

### 3. Compromisos para el Siguiente Periodo (Julio 2026)
*   **Módulo de Pagos e Inscripción SaaS:** Iniciar el modelado y flujos de cobro de suscripción SaaS y transacciones de reservas mediante pasarelas piloto en FINTOUR.
*   **AWS S3 en Producción:** Configurar y migrar la subida de imágenes en NestJS hacia un bucket de AWS S3 seguro para producción.
*   **Despliegue y Publicación de App Móvil:** Preparación de certificados de Google Play Store y Apple App Store para el piloto cerrado de la aplicación móvil Bubble Splashdate.

---
*Fin del informe unificado.*
