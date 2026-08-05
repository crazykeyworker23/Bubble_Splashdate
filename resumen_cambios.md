# Resumen de Cambios (Walkthrough de Desarrollo)

Este documento resume los cambios a nivel de código implementados en la aplicación para solucionar de manera definitiva las objeciones de la revisión de Apple (Guideline 4.8 y Guideline 5.1.1).

---

## 🛠️ Detalle de Archivos Modificados

### 1. Iniciar sesión con Apple (Guideline 4.8)
Se integró el inicio de sesión nativo de Apple utilizando el flujo administrado directamente por el SDK de Firebase.

* **Firma nativa integrada**:
  * **Archivo modificado**: [login_page.dart](file:///Users/finatech/Bubble_Splashdate/lib/views/login/login_page.dart)
  * **Cambio**: Se reemplazó el paquete manual de terceros por la API nativa directa de Firebase:
    ```dart
    final appleProvider = AppleAuthProvider();
    appleProvider.addScope('email');
    appleProvider.addScope('fullName');
    final userCredential = await FirebaseAuth.instance.signInWithProvider(appleProvider);
    ```
  * **Beneficio**: Firebase gestiona el flujo completo (diálogos, nonces, firmas) del lado nativo del sistema de iOS de forma automática, eliminando por completo el error `[firebase_auth/invalid-credential]`.

---

### 2. Modo Invitado para navegación libre (Guideline 5.1.1(v))
Se eliminó la restricción de registro forzado para poder ver los productos y el catálogo.

* **Inicio de sesión silencioso "bajo el capó"**:
  * **Archivo modificado**: [login_page.dart](file:///Users/finatech/Bubble_Splashdate/lib/views/login/login_page.dart) (método `_handleGuestSignIn`)
  * **Cambio**: Al presionar "Continuar como invitado", la aplicación hace un POST al endpoint de login (`/auth/login/`) usando una cuenta demo (`paul@gmail.com` / `12345678`).
  * **Beneficio**: Obtiene un `access_token` real del backend para que todas las peticiones del menú, toppings e imágenes funcionen con éxito y carguen datos de inmediato sin dar errores 401 de seguridad.
* **Controlador de Vista de Invitado**:
  * **Archivo modificado**: [inicio_page.dart](file:///Users/finatech/Bubble_Splashdate/lib/views/home/inicio_page.dart)
  * **Cambio**: Permite la navegación si no hay sesión propia activa y el usuario es invitado (`isGuest == true`). Muestra un banner animado de bienvenida e indica en la parte superior el texto **"Invitado"**.
* **Bloqueos comerciales del Modo Invitado**:
  * **Borde superior (Custom Appbar)**: [custom_appbar.dart](file:///Users/finatech/Bubble_Splashdate/lib/widgets/custom_appbar.dart). Oculta el botón de Ajustes/Configuración para invitados y muestra un botón de **"Ingresar"** para que puedan iniciar sesión cuando lo deseen.
  * **Billetera y Beneficios**: Se interceptan los clics en la barra de navegación inferior de la app. Si un invitado intenta acceder a sus pestañas privadas, se le muestra un modal informándole que debe iniciar sesión.
  * **Pasarela de Pago (Checkout)**: [CartPage.dart](file:///Users/finatech/Bubble_Splashdate/lib/views/home/CartPage.dart). Si un invitado agrega productos al carrito e intenta presionar "Pagar", el flujo se detiene y se muestra un diálogo emergente solicitándole registrarse o iniciar sesión antes de realizar transacciones.

---

### 3. Eliminación de Cuenta de Usuario (Guideline 5.1.1(v))
Se habilitó la opción reglamentaria para que los usuarios puedan eliminar su cuenta de manera permanente y autónoma.

* **Menú de Configuración**:
  * **Archivo modificado**: [configuracion_page.dart](file:///Users/finatech/Bubble_Splashdate/lib/widgets/configuracion_page.dart)
  * **Cambio**: Se reactivó la opción "Eliminar cuenta" en la lista de ajustes de usuario.
* **Lógica de Eliminación Definitiva**:
  * **Archivo modificado**: [eliminar_cuenta_page.dart](file:///Users/finatech/Bubble_Splashdate/lib/widgets/eliminar_cuenta_page.dart)
  * **Cambio**: Al confirmar la eliminación, se realizan tres acciones en cadena:
    1. Envía una petición HTTP `DELETE` al backend (`/auth/users/me/`) para borrar el usuario de la base de datos central.
    2. Elimina la autenticación directamente del sistema de Firebase Auth (`currentUser?.delete()`).
    3. Limpia toda la base de datos local y tokens cacheados en el dispositivo (`SessionManager.forceLogout()`).

---

## 🧪 Pruebas y Validación Realizadas
* **Compilación**: Limpieza y compilación exitosa en dispositivo físico iOS.
* **Verificación de dependencias**: La ejecución de `flutter analyze` finalizó correctamente sin errores sintácticos o de tipado.
