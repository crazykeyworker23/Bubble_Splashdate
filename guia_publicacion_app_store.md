# Guía Definitiva y Detallada: Migración de Android a iOS y Publicación en Apple App Store (Flutter)

Esta guía documenta el proceso completo paso a paso, sin omitir ningún detalle, para tomar un proyecto de Flutter que actualmente está desarrollado únicamente para Android, configurarle soporte para iOS, preparar las firmas y perfiles de Apple Developer, integrar Firebase, configurar permisos de sistema, completar los formularios de App Store Connect y finalmente publicarlo en la Apple App Store.

---

## 🗺️ Índice de Contenidos
1. [Fase 1: Preparación del Entorno macOS y CocoaPods](#fase-1-preparación-del-entorno-macos-y-cocoapods)
2. [Fase 2: Agregar Soporte iOS a un Proyecto Android-Only](#fase-2-agregar-soporte-ios-a-un-proyecto-android-only)
3. [Fase 3: Registro y Configuración en Apple Developer Portal](#fase-3-registro-y-configuración-en-apple-developer-portal)
4. [Fase 4: Creación de Claves Privadas e Identificadores de Apple (.p8)](#fase-4-creación-de-claves-privadas-e-identificadores-de-apple-p8)
5. [Fase 5: Configuración de Firebase para iOS](#fase-5-configuración-de-firebase-para-ios)
6. [Fase 6: Configuración del Proyecto en Xcode (Entitlements y Permisos)](#fase-6-configuración-del-proyecto-en-xcode-entitlements-y-permisos)
7. [Fase 7: Compilación del Archivo IPA para Producción](#fase-7-compilación-del-archivo-ipa-para-producción)
8. [Fase 8: Subida a App Store Connect (Uso de Transporter y Xcode Organizer)](#fase-8-subida-a-app-store-connect-uso-de-transporter-y-xcode-organizer)
9. [Fase 9: Lista de Metadatos y Formularios a completar en App Store Connect](#fase-9-lista-de-metadatos-y-formularios-a-completar-en-app-store-connect)
10. [Fase 10: Selección de Compilación y Envío a Revisión de Apple](#fase-10-selección-de-compilación-y-envío-a-revisión-de-apple)
11. [Fase 11: Solución Detallada a Errores Comunes](#fase-11-solución-detallada-a-errores-comunes)

---

## 💻 Fase 1: Preparación del Entorno macOS y CocoaPods

Para poder compilar y firmar apps de iOS, es obligatorio usar una computadora Mac (macOS).

### 1. Instalar Xcode y Herramientas de Línea de Comandos
1. Abre tu Mac y ve a la **App Store**.
2. Busca **Xcode** e instálalo.
3. Una vez instalado, abre Xcode y acepta los términos de licencia iniciales.
4. Abre la terminal de tu Mac (`Terminal.app` o la que prefieras) y ejecuta el siguiente comando para instalar las herramientas del compilador:
   ```bash
   xcode-select --install
   ```
   *Si ya están instaladas, la terminal te indicará que ya se encuentran disponibles.*

### 2. Instalar Homebrew (Gestor de Paquetes para macOS)
Requerido para instalar CocoaPods de forma segura sin romper la versión del sistema de Ruby.
1. Ejecuta en tu terminal el instalador oficial de Homebrew:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
2. Sigue las instrucciones de pantalla al final de la instalación para agregar Homebrew al PATH (ejecutar los comandos `echo` que indica el script).

### 3. Instalar CocoaPods
1. Ejecuta en tu terminal:
   ```bash
   brew install cocoapods
   ```
2. Verifica que se haya instalado correctamente consultando su versión:
   ```bash
   pod --version
   ```

---

## 📱 Fase 2: Agregar Soporte iOS a un Proyecto Android-Only

Si tu proyecto de Flutter fue creado originalmente sin soporte para iOS (no tiene la carpeta `/ios`), debes generarla de forma limpia.

### 1. Verificar el Package Name original de Android
1. Abre tu archivo `android/app/build.gradle` en tu editor de código.
2. Localiza la línea que contiene `applicationId` (ej: `com.finatech.bubblesplash`). Este es tu identificador único. Lo usaremos para configurar iOS.

### 2. Generar la estructura de archivos iOS en Flutter
1. Abre tu terminal y navega hasta la raíz de tu proyecto Flutter.
2. Ejecuta el comando de creación especificando tu misma organización:
   ```bash
   flutter create --org com.finatech --platforms ios .
   ```
   *Nota: El punto final `.` es obligatorio, le indica a Flutter que inicialice los archivos en el directorio actual.*
3. Este comando creará la carpeta `/ios` en tu proyecto.
4. Ejecuta la descarga de las dependencias nativas del Podfile:
   ```bash
   flutter pub get
   cd ios
   pod install
   cd ..
   ```

---

## 🔑 Fase 3: Registro y Configuración en Apple Developer Portal

### 1. Iniciar sesión en Xcode con tu Cuenta de Desarrollador
1. Abre Xcode.
2. En la barra de menú superior, haz clic en **Xcode > Settings (o Preferences)**.
3. Ve a la pestaña **Accounts**.
4. Haz clic en el botón de **`+`** (abajo a la izquierda) y selecciona **Apple ID**.
5. Ingresa el correo y contraseña de tu cuenta de Apple Developer (ej: `joze.arbildo@gmail.com`).
6. Al autenticarse, aparecerá tu nombre y los nombres de los equipos vinculados (ej: `FINATECH SAC` con su Team ID `9266R33AGX`).

### 2. Registrar el App ID en el Apple Developer Portal
1. Abre tu navegador e inicia sesión en el [Apple Developer Portal](https://developer.apple.com/account/).
2. Haz clic en la sección **Certificates, Identifiers & Profiles**.
3. En la barra lateral izquierda, haz clic en **Identifiers**.
4. Haz clic en el botón azul de **`+`** al lado del título.
5. Selecciona **App IDs** y haz clic en **Continue**.
6. Selecciona el tipo **App** y haz clic en **Continue**.
7. Rellena el formulario:
   * **Description**: Nombre de tu aplicación (ej: `Bubble Splash`).
   * **Bundle ID**: Selecciona **Explicit** e introduce el ID de tu paquete exacto (ej: `com.finatech.bubblesplash`).
8. En la sección inferior **Capabilities** (Capacidades), marca las casillas de:
   * **Sign in with Apple** (Requerido para la autenticación de usuarios de Apple).
   * **Push Notifications** (Requerido si usas notificaciones instantáneas).
9. Haz clic en **Continue** arriba a la derecha.
10. Revisa los datos y haz clic en **Register**.

---

## 🔑 Fase 4: Creación de Claves Privadas e Identificadores de Apple (.p8)

Si usas el inicio de sesión nativo de Apple o integraciones como Firebase Auth, debes generar una clave de autenticación para que Firebase pueda verificar las firmas de los tokens.

### 1. Generar la Clave Privada (.p8) en Apple Developer
1. Dentro de [Apple Developer Portal > Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/authkeys/list), ve a la pestaña **Keys** en el menú izquierdo.
2. Haz clic en el botón de **`+`** junto al título.
3. Llena los datos:
   * **Key Name**: Nombre identificatorio (ej: `Firebase Apple Auth Key`).
   * Marca la casilla **Sign in with Apple**.
4. Haz clic en el botón **Configure** que está al lado de *Sign in with Apple*.
5. Selecciona tu **Primary App ID** en el menú desplegable: **`com.finatech.bubblesplash`**.
6. Haz clic en **Save** y luego en **Continue**.
7. Haz clic en **Register**.
8. **Descargar la clave (.p8)**:
   * Haz clic en **Download**. Guarda el archivo `.p8` en un lugar seguro.
   * *IMPORTANTE: Este archivo solo se puede descargar una única vez. Si lo pierdes, tendrás que revocar la clave y crear una nueva.*
   * Copia y anota el **Key ID** (un código alfanumérico de 10 caracteres, ej: `V96KJ74NGS`).

### 2. Registrar el Services ID (Solo necesario para autenticación web/Android)
Si requieres autenticación de Apple en Android o Web además de iOS:
1. Ve a la pestaña **Identifiers** del portal de desarrolladores de Apple.
2. Haz clic en **`+`** y selecciona **Services IDs**. Haz clic en **Continue**.
3. Rellena los datos:
   * **Description**: Nombre descriptivo (ej: `Bubble Splash Web`).
   * **Identifier**: El bundle ID añadiendo un sufijo (ej: `com.finatech.bubblesplash.sid`).
4. Haz clic en **Register**.
5. Selecciona el Services ID creado de la lista.
6. Marca **Sign in with Apple** y haz clic en **Configure**.
7. En **Primary App ID**, selecciona `com.finatech.bubblesplash`.
8. En **Domains and Subdomains**, escribe el dominio del servidor de autenticación (ej: `bubble-splash-36aa6.firebaseapp.com`).
9. En **Return URLs**, escribe el enlace de respuesta de Firebase:
   `https://bubble-splash-36aa6.firebaseapp.com/__/auth/handler`
10. Haz clic en **Next**, luego en **Done** y finalmente en **Continue** y **Save**.

---

## 🔥 Fase 5: Configuración de Firebase para iOS

### 1. Registrar tu app iOS en Firebase Console
1. Entra a tu proyecto en [Firebase Console](https://console.firebase.google.com/).
2. Haz clic en el icono de **Configuración (engranaje)** > **Configuración del proyecto**.
3. En la pestaña **General**, desplázate a la sección **Tus apps** y haz clic en **Agregar app**. Selecciona el icono de **iOS**.
4. Introduce tus datos:
   * **ID del paquete de iOS**: `com.finatech.bubblesplash`.
   * **Apodo de la app**: `Bubble Splash iOS`.
5. Haz clic en **Registrar app**.

### 2. Descargar e Integrar `GoogleService-Info.plist`
1. Descarga el archivo de configuración `GoogleService-Info.plist` que te da Firebase.
2. Abre tu espacio de trabajo de Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
3. En el panel izquierdo de Xcode, localiza la carpeta raíz llamada **Runner**.
4. Arrastra el archivo `GoogleService-Info.plist` desde tu Finder y **suéltalo dentro de la carpeta Runner en Xcode**.
5. En la ventana flotante que se abre en Xcode, marca la casilla **"Copy items if needed"**, selecciona **"Create groups"** y asegúrate de que el target **Runner** esté marcado. Haz clic en **Finish**.

> [!IMPORTANT]
> Debes arrastrar el archivo dentro de la interfaz de Xcode. Si solo copias el archivo en la carpeta física usando el Finder, Xcode no lo incluirá en los recursos de compilación y la app fallará al iniciar.

---

## 🛠️ Fase 6: Configuración del Proyecto en Xcode (Entitlements y Permisos)

### 1. Configurar la Firma Automática (Signing)
1. Con Xcode abierto, haz clic en el nodo raíz **Runner** en el árbol de archivos (esquina superior izquierda).
2. Selecciona el target llamado **Runner** (bajo la sección *Targets*).
3. Haz clic en la pestaña **Signing & Capabilities** (Firma y Capacidades).
4. Asegúrate de marcar **Automatically manage signing**.
5. En **Team**, selecciona tu cuenta de desarrollo empresarial: **`FINATECH SAC`** (Team ID `9266R33AGX`).
6. Xcode creará y descargará automáticamente los certificados de aprovisionamiento necesarios.

### 2. Configurar Capabilities (Sign in with Apple y Notificaciones)
Si las capacidades no se reflejan automáticamente en Xcode:
1. En la pestaña **Signing & Capabilities**, haz clic en el botón de **`+ Capability`** en la esquina superior izquierda.
2. Escribe **Sign in with Apple** y haz doble clic para añadirlo.
3. Haz clic de nuevo en **`+ Capability`**, escribe **Push Notifications** y haz doble clic.
4. Esto creará el archivo `Runner.entitlements` en tu carpeta del proyecto.

### 3. Configurar los Permisos de Sistema en `Info.plist`
Apple exige por ley que cualquier acceso al hardware o datos del usuario esté justificado con un texto descriptivo. De lo contrario, la app será rechazada de la tienda inmediatamente.

Abre el archivo [ios/Runner/Info.plist](file:///Users/finatech/Bubble_Splashdate/ios/Runner/Info.plist) con tu editor de código y pega las siguientes claves dentro de la etiqueta `<dict>` principal:

```xml
<!-- Permiso de Cámara (ej: para tomar fotos de perfil o escanear códigos QR) -->
<key>NSCameraUsageDescription</key>
<string>Requerimos acceso a la cámara para poder tomar la foto de perfil y escanear los códigos QR de las sucursales.</string>

<!-- Permiso de Galería de Fotos (ej: para cargar imágenes existentes) -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Requerimos acceso a tu galería de fotos para que puedas seleccionar tu imagen de perfil.</string>

<!-- Permiso de Ubicación (Cuando la app está en uso - ej: para ubicar tiendas cercanas) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Requerimos tu ubicación para poder mostrarte las sucursales físicas más cercanas a ti en tiempo real.</string>

<!-- Permiso de Notificaciones Push (iOS 10+) -->
<key>PermissionGroupNotification</key>
<string>Permite que te enviemos actualizaciones sobre tus pedidos y promociones exclusivas.</string>
```

---

## 📦 Fase 7: Compilación del Archivo IPA para Producción

Una vez configurado todo el entorno y los permisos nativos, estamos listos para compilar.

1. Abre tu terminal y ve a la raíz de tu proyecto Flutter.
2. Limpia todos los archivos de caché del compilador y temporales:
   ```bash
   flutter clean
   flutter pub get
   ```
3. Navega al directorio `/ios`, borra dependencias rotas e instálalas de forma limpia:
   ```bash
   cd ios
   rm -rf Pods Podfile.lock Runner.xcworkspace
   pod install
   cd ..
   ```
4. Genera la compilación oficial de producción en formato `.ipa`:
   ```bash
   flutter build ipa
   ```
   *Este comando compilará el código de Dart a código nativo de Apple en modo Release, generará el archivo de distribución y guardará el archivo resultante en `build/ios/ipa/Runner.ipa`.*

---

## 🚀 Fase 8: Subida a App Store Connect

Una vez que tengas el archivo `.ipa`, debes entregarlo a Apple.

### Método A: Usar la aplicación Apple Transporter (El método recomendado)
1. Descarga la aplicación **Transporter** de la Mac App Store.
2. Abre Transporter e ingresa las credenciales de tu Apple ID de desarrollador.
3. Arrastra tu archivo `.ipa` compilado (ubicado en `build/ios/ipa/Runner.ipa`) y suéltalo en la interfaz de Transporter.
4. Haz clic en **Entregar (Deliver)**. 
5. Transporter validará la app contra los servidores de Apple y la subirá automáticamente. Verás un check verde cuando haya concluido.

### Método B: Usar Xcode Organizer
1. Abre tu proyecto en Xcode (`open ios/Runner.xcworkspace`).
2. En la barra de dispositivos de Xcode (parte superior), selecciona **Any iOS Device (arm64)**.
3. Ve a la barra de menú superior de Xcode y selecciona **Product > Archive**.
4. Espera a que termine la compilación. Se abrirá la ventana del **Organizer**.
5. Selecciona la compilación que acabas de generar y haz clic en **Distribute App** en la columna derecha.
6. Selecciona la opción **App Store Connect** y haz clic en **Next**.
7. Elige **Upload** (Subir) y sigue los pasos automatizados para firmar y entregar.

---

## 📋 Fase 9: Lista de Metadatos y Formularios a completar en App Store Connect

Una vez que el archivo `.ipa` se haya cargado, debes configurar la ficha de la App Store en el sitio web de [App Store Connect](https://appstoreconnect.apple.com/).

### 1. Capturas de Pantalla (Screenshots) Obligatorias
Apple te exige subir imágenes de tu app funcionando. Los tamaños obligatorios para iPhone son:
* **Pantallas de 6.5 pulgadas (iPhone 11/12/13/14 Pro Max)**: 
  * Resoluciones válidas: **1284 x 2778 px** o **1242 x 2688 px**. (Sube al menos 3 imágenes).
* **Pantallas de 5.5 pulgadas (iPhone 8/7/6s Plus)**: 
  * Resolución obligatoria: **1242 x 2208 px**. (Sube al menos 3 imágenes).

*Nota: Si no cuentas con dispositivos de estos tamaños físicos, puedes abrir el simulador en Xcode (ej: iPhone 14 Pro Max e iPhone 8 Plus) y tomar las capturas desde el simulador usando la combinación `Command + S`.*

### 2. Información General de la App
Completa el formulario en la pestaña de administración:
* **Nombre de la App**: El título comercial visible (máximo 30 caracteres).
* **Subtítulo**: Breve lema que aparece debajo del nombre (máximo 30 caracteres).
* **Categoría Principal**: Selecciona una categoría (ej: *Comida y bebida* o *Compras*).
* **URL de Política de Privacidad**: Enlace a la web de tu política de datos.

### 3. Información de la Versión
* **Texto promocional**: Texto de 170 caracteres para captar la atención de tus clientes.
* **Descripción**: Explicación completa del funcionamiento de la app (máximo 4000 caracteres).
* **Palabras clave (Keywords)**: Términos para el motor de búsqueda de Apple separados por comas.
* **URL de soporte técnico**: Enlace web para ayuda o contacto de soporte.

### 4. Ficha de Privacidad de la App (App Privacy)
Responde al cuestionario de seguridad y privacidad:
* Indica si tu app recopila datos (como correos, nombres o datos de analíticas).
* Si utilizas Firebase Analytics, debes marcar que recopilas **Datos de Identificación (correo)**, **Identificadores (ID de dispositivo)** y **Datos de Diagnóstico (Crashlogs)**.
* Indica que estos datos se asocian a la identidad del usuario y si se usan con fines de rastreo (Tracking).

### 5. Clasificación por Edad (Age Rating)
* Haz clic en el botón de edición y responde el cuestionario acerca de la frecuencia con la que tu app expone contenidos de violencia, drogas, apuestas o humor crudo.
* Apple asignará la clasificación de edad de forma automática (ej: 4+, 9+, 12+, 17+).

---

## 📝 Fase 10: Selección de Compilación y Envío a Revisión de Apple

1. Ve a la versión en preparación en tu menú lateral de App Store Connect.
2. Baja a la sección **Compilación (Build)**.
3. Haz clic en el botón de **`+`** o selecciona la compilación que subiste mediante Transporter/Xcode (si no aparece, dale unos minutos ya que Apple realiza un escaneo de seguridad antes de liberarla).
4. **Información de Inicio de Sesión de Prueba (Mandatorio)**:
   * Apple rechaza las apps que no permiten el acceso completo a los revisores. Configura la cuenta demo:
     * **Usuario**: `paul@gmail.com`
     * **Contraseña**: `12345678`
5. **Notas de revisión**:
   * Escribe un mensaje aclaratorio al revisor de Apple detallando las correcciones y cómo validar la app:
     > *"Se ha implementado el inicio de sesión nativo con Apple en cumplimiento con la Guideline 4.8. Adicionalmente, se ha habilitado un flujo de 'Continuar como invitado' para permitir la navegación libre del catálogo de productos sin obligación de registro inicial (en cumplimiento con la Guideline 5.1.1(v)). Las credenciales demo adjuntas permiten el acceso completo para verificar el flujo de compra y pasarela de pago."*
6. Haz clic en **Guardar** y luego en **Enviar para revisión (Submit for Review)**.

---

## 🔍 Fase 11: Solución Detallada a Errores Comunes

### 1. Error `[firebase_auth/invalid-credential] Invalid OAuth response from apple.com`
* **Causa**: Discrepancia del nonce guardado en caché o clave privada `.p8` configurada incorrectamente.
* **Solución**:
  1. Usa el inicio de sesión integrado en Firebase: `FirebaseAuth.instance.signInWithProvider(AppleAuthProvider())` en tu código Dart en lugar de manejar el token manualmente.
  2. Si deseas utilizar el método con clave privada en Firebase Console > Authentication > Apple, el campo **ID de servicios** debe contener tu **Bundle ID exacto** (`com.finatech.bubblesplash`) y no el Services ID (`.sid`).

### 2. Error en Xcode: `"Personal development teams do not support Sign In with Apple"`
* **Causa**: Xcode está firmando temporalmente la app con tu Apple ID personal gratuito en lugar de la membresía empresarial de pago.
* **Solución**: Abre **Xcode > Runner > Signing & Capabilities** y en el campo **Team** selecciona tu equipo de pago corporativo (ej: `FINATECH SAC` - `9266R33AGX`).

### 3. Error en terminal: `zsh: no matches found`
* **Causa**: Al intentar vaciar perfiles obsoletos, el comando wildcard `*` falla si la carpeta está vacía.
* **Solución**: Elimina el directorio completo en su lugar y Xcode lo volverá a generar de forma limpia:
  ```bash
  rm -rf ~/Library/MobileDevice/Provisioning\ Profiles
  ```

### 4. La app se congela al arrancar en iOS (Crasheos repentinos en Firebase)
* **Causa**: Falta la inicialización o vinculación del archivo `GoogleService-Info.plist` en Xcode.
* **Solución**: Elimina el archivo `GoogleService-Info.plist` en Xcode y vuelve a arrastrarlo dentro de la carpeta Runner usando la interfaz gráfica de Xcode, asegurándote de marcar "Copy items if needed".
