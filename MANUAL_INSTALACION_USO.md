# Manual de Instalación y Uso de BubleSplash

## Requerimientos Previos

- **Flutter SDK** (recomendado: última versión estable)
- **Dart SDK** (incluido con Flutter)
- **Android Studio** o **VS Code** (con extensiones de Flutter y Dart)
- **Java JDK 8 o superior** (para compilación Android)
- **Xcode** (solo para desarrollo en MacOS/iOS)
- **Git**

## Instalación

1. **Clonar el repositorio:**
   ```bash
   git clone <URL_DEL_REPOSITORIO>
   cd BubleSplash
   ```

2. **Instalar dependencias:**
   ```bash
   flutter pub get
   ```

3. **Configurar plataformas:**
   - **Android:**
     - Abrir el proyecto en Android Studio y esperar a que sincronice.
     - Configurar un emulador o conectar un dispositivo físico.
   - **iOS:**
     - Abrir la carpeta `ios/` en Xcode y configurar un simulador o dispositivo físico.

4. **Configurar archivos necesarios:**
   - **Google Services:**
     - Android: Colocar `google-services.json` en `android/app/`.
     - iOS: Colocar `GoogleService-Info.plist` en `ios/Runner/`.

   - **Firebase:**
     1. Ingresa a [Firebase Console](https://console.firebase.google.com/).
     2. Crea un nuevo proyecto o selecciona uno existente.
     3. Agrega una nueva app Android:
        - Ingresa el nombre del paquete (ejemplo: `com.tuempresa.bublesplash`).
        - Descarga el archivo `google-services.json` y colócalo en `android/app/`.
     4. Agrega una nueva app iOS si es necesario:
        - Ingresa el Bundle ID correspondiente.
        - Descarga el archivo `GoogleService-Info.plist` y colócalo en `ios/Runner/`.
     5. Habilita los servicios necesarios (Auth, Firestore, Messaging, etc.) desde la consola de Firebase.

   - **Generar y configurar key.jks (firma Android):**
     1. Abre una terminal y ejecuta:
        ```bash
        keytool -genkey -v -keystore key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias bublesplash
        ```
        (Recuerda la contraseña y los datos ingresados, serán necesarios para el archivo de propiedades)
     2. Mueve el archivo `key.jks` a la carpeta `android/app/`.

   - **Crear y configurar key.properties:**
     1. En la carpeta `android/` crea un archivo llamado `key.properties` con el siguiente contenido:
        ```properties
        storePassword=TU_CONTRASEÑA_DEL_KEYSTORE
        keyPassword=TU_CONTRASEÑA_DE_LA_LLAVE
        keyAlias=bublesplash
        storeFile=../android/app/key.jks
        ```
     2. Asegúrate de que este archivo NO se suba al repositorio (agregado en `.gitignore`).

   - **Configurar build.gradle para firma:**
     1. En `android/app/build.gradle.kts` verifica que la sección de signingConfigs y buildTypes esté configurada para usar `key.properties`.
     2. Ejemplo de configuración:
        ```kotlin
        val keystoreProperties = Properties()
        val keystorePropertiesFile = rootProject.file("key.properties")
        if (keystorePropertiesFile.exists()) {
            keystoreProperties.load(FileInputStream(keystorePropertiesFile))
        }

        android {
            signingConfigs {
                create("release") {
                    storeFile = file(keystoreProperties["storeFile"])
                    storePassword = keystoreProperties["storePassword"] as String?
                    keyAlias = keystoreProperties["keyAlias"] as String?
                    keyPassword = keystoreProperties["keyPassword"] as String?
                }
            }
            buildTypes {
                getByName("release") {
                    signingConfig = signingConfigs.getByName("release")
                }
            }
        }
        ```

5. **Ejecutar la aplicación:**
   ```bash
   flutter run
   ```

## Uso Básico

- Al iniciar la app, sigue las instrucciones en pantalla para navegar entre las diferentes funcionalidades.
- Para pruebas, puedes ejecutar:
  ```bash
  flutter test
  ```

## Notas Adicionales

- Si tienes problemas con dependencias, ejecuta:
  ```bash
  flutter clean
  flutter pub get
  ```
- Para generar splash screen personalizado, edita `flutter_native_splash.yaml` y ejecuta:
  ```bash
  flutter pub run flutter_native_splash:create
  ```

## Generar archivo .aab para Play Console

Para publicar la aplicación en Google Play Console, es necesario generar el archivo `.aab` (Android App Bundle):

1. Asegúrate de haber configurado correctamente la firma (key.jks y key.properties).
2. Ejecuta el siguiente comando en la raíz del proyecto:
  ```bash
  flutter build appbundle --release
  ```
3. El archivo generado se encontrará en:
  ```
  build/app/outputs/bundle/release/app-release.aab
  ```
4. Sube este archivo a la Play Console para su publicación.

## Contacto

Para soporte, contacta al desarrollador principal o revisa el archivo `README.md` para más detalles.