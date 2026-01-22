# Guía de instalación y uso del proyecto BubleSplash

## Requisitos previos
- Tener instalado [Git](https://git-scm.com/)
- Tener instalado [Flutter](https://docs.flutter.dev/get-started/install)
- Tener instalado [Git LFS](https://git-lfs.github.com/)

## Clonar el repositorio
```
git clone https://github.com/crazykeyworker23/BubleSplash.git
cd BubleSplash
```

## Instalar dependencias de Flutter
```
flutter pub get
```

## Configurar Git LFS (solo la primera vez)
```
git lfs install
git lfs pull
```

## Ejecutar la app
```
flutter run
```

## Uso de Git LFS
Si agregas archivos grandes (por ejemplo, .exe, .zip, .rar), debes rastrearlos con LFS:
```
git lfs track "*.exe"
git lfs track "*.zip"
git lfs track "*.rar"
```
Luego agrega y haz commit normalmente:
```
git add .gitattributes
# Agrega tus archivos grandes
# git add archivo_grande.exe
# git commit -m "Agrego archivo grande con LFS"
# git push origin main
```

## Notas
- No subas archivos grandes directamente sin LFS.
- Si tienes problemas con archivos grandes ya subidos, consulta la sección de limpieza de historial en la documentación de Git LFS.

## Contacto
Para dudas técnicas, contacta al responsable del repositorio.
