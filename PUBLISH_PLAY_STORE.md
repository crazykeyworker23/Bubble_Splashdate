# Firma y publicación en Google Play

Este documento recopila los pasos para generar la keystore, configurar la firma en el proyecto Flutter/Android, generar el AAB y subirlo a Google Play.

## Prerrequisitos
- Tener Java JDK instalado (para `keytool`).
- Tener `flutter` en PATH.
- Acceso a la Play Console y cuenta de desarrollador.

## 1) Generar la keystore
Ejecuta desde la raíz del proyecto (o donde quieras guardar la keystore). Aquí la guardamos en `android/app/key.jks`:

```bash
keytool -genkeypair -v -keystore android/app/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
```

Anota el `alias` y las contraseñas que introduzcas.

## 2) Crear `key.properties`
Crea el archivo `android/key.properties` con el siguiente contenido (no subir al repositorio):

```
storePassword=TU_STORE_PASSWORD
keyPassword=TU_KEY_PASSWORD
keyAlias=key
storeFile=app/key.jks
```

Añade `android/key.properties` y `android/app/key.jks` a tu `.gitignore` para no subirlos por error.

## 3) Configurar `android/app/build.gradle.kts` para firma
En la parte superior (antes del bloque `android {}`) añade la carga de propiedades:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}
```

Dentro de `android {}` añade/ajusta `signingConfigs` y `buildTypes`:

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String?
        keyPassword = keystoreProperties["keyPassword"] as String?
        storeFile = file(keystoreProperties["storeFile"] as String?)
        storePassword = keystoreProperties["storePassword"] as String?
    }
}

buildTypes {
    getByName("release") {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = false // o true si usas ProGuard/R8
    }
}
```

Adapta `alias` y rutas si usaste nombres distintos.

## 4) Construir el AAB
Limpia y construye el bundle de Play:

```bash
flutter clean
flutter build appbundle --release
```

El AAB resultante suele estar en `build/app/outputs/bundle/release/app-release.aab`.

## 5) Subir a Play Console
- Entra en Play Console > tu app (o crea nueva) > Releases > Producción > Crear release.
- Sube el `.aab` generado.
- Completa la ficha (contenido, capturas, política de privacidad, clasificación, precios/distribución).
- Revisa y publica.

## 6) Play App Signing (recomendado)
Play puede gestionar la firma final (App Signing). Al subir por primera vez puedes optar por que Play gestione la key. Si lo haces, Play te pedirá que uses una "upload key" (tu keystore local) y ellos usarán su key para distribuir la app.

## Buenas prácticas
- No comprometer `key.properties` ni el `.jks` en repositorios públicos.
- Guarda contraseñas en un gestor seguro.
- Mantén respaldos de la keystore en un lugar seguro.

---

Si quieres, puedo:
- Aplicar automáticamente el snippet en `android/app/build.gradle.kts`.
- Crear `android/key.properties` de ejemplo aquí (no con contraseñas reales).
- Generar la keystore localmente si me das el alias y las contraseñas (o te doy los comandos para hacerlo tú).
