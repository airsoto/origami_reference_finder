# Origami Reference Finder para iPhone y iPad

Nueva interfaz iOS para el motor original ReferenceFinder 4 de Robert J. Lang.
Subido para iOS por Ángel Soto. iOS 16 o posterior, SwiftUI + Objective-C++ + C++17.
Funciona sin conexión, sin cuentas ni servicios de pago y sin dependencias de
CocoaPods, npm, XcodeGen o paquetes Swift externos.

## Incluido

- Búsqueda de puntos (X, Y) y rectas definidas por dos puntos.
- Los siete axiomas del motor original, con hasta cinco soluciones.
- Expresiones como 1/3, sqrt(2)/2 y sin(deg2rad(30)); coma decimal admitida.
- Papel cuadrado o rectangular: dimensiones entre 0.25 y 2; proporción hasta 4:1.
- Rango 2–4 y límites de 100 000 puntos/rectas para uso móvil.
- Diagramas de cada paso con flechas, etiquetas y pliegues; instrucciones originales en inglés.
- Error de aproximación, complejidad de la construcción y compartir instrucciones.
- Doce búsquedas recientes locales, con opción de borrado.
- Pantalla Ayuda y créditos, licencia completa, icono aportado por el usuario y manifiesto de privacidad.
- Proyecto Xcode completo con esquema compartido y codemagic.yaml.

## Revisiones de los proyectos de partida

El ZIP histórico es una interfaz de 2009 para iPhone OS 3.0, usa gestión manual
de memoria y componentes UIKit antiguos, y referencia ../../source/model sin
incluir el motor en el ZIP. No es un proyecto autónomo compilable para iOS actual.
Esta app sustituye la interfaz, conserva el enfoque de navegación por soluciones
y utiliza fuentes del repositorio oficial del motor, con correcciones C++17.

HuxleyBerry es una web Vue 3/Vite. Su búsqueda recursiva usa transformaciones de
una referencia escalar desde 0.5 y no equivale al motor general de puntos y rectas
de Lang. La ramificación es de 32 operaciones por nivel. App.vue presupone que
existe la opción pedida y calcula columnas sin asegurar un mínimo de una, lo que
puede fallar con resultados vacíos/índices inválidos o contenedores muy estrechos.
No hay licencia explícita en la raíz revisada. No se reutilizó su código.

## Compilar primero sin firma en Codemagic

1. Descomprime este paquete y sube **el contenido de esta carpeta** a un repositorio
   `origami_reference_finder` de tu cuenta de GitHub. codemagic.yaml y
   OrigamiReference.xcodeproj deben quedar en la raíz de ese repositorio.
2. En Codemagic conecta tu cuenta de GitHub, selecciona `origami_reference_finder`
   y utiliza la configuración YAML incluida.
3. Ejecuta `ios-check`. Compila para simulador y ejecuta las pruebas del motor.
   No necesita certificados ni credenciales Apple. No genera una IPA instalable.
4. Conserva el log si aparece un error. La compilación de Swift/UIKit requiere
   Xcode/macOS y no ha podido ejecutarse en el entorno Linux de preparación.

## Generar la IPA con tu cuenta de desarrollador

1. Crea el identificador de la app en Apple Developer y la ficha en App Store Connect.
   Identificador inicial propuesto: `es.angelsoto.origamireferencefinder`.
2. En `codemagic.yaml`, sustituye `TU_INTEGRACION_APP_STORE_CONNECT` por el nombre
   exacto de la integración Apple que ya utilizas en Codemagic.
3. Comprueba certificados y perfiles App Store para ese identificador.
4. Si cambias el identificador, cambia tanto `environment.ios_signing.bundle_identifier`
   como `environment.vars.BUNDLE_ID`. El flujo regenerará el proyecto con ese valor.
   Para abrir localmente el proyecto con otro identificador, ejecuta:
   `BUNDLE_ID=tu.identificador python3 scripts/generate_project.py`.
5. Ejecuta `ios-release` para obtener `build/ios/ipa/*.ipa` como artefacto.
   El número de build usa BUILD_NUMBER_BASE + PROJECT_BUILD_NUMBER. Si ya tienes
   builds con un número mayor, sube BUILD_NUMBER_BASE antes de compilar.
6. Revisa y resuelve la licencia de distribución antes de entregar a Apple.
   El flujo no publica ni sube automáticamente a App Store Connect.
7. Prueba la app en un iPhone real: entrada y teclado, cancelar, rotación, modo
   oscuro, tamaño de texto, navegación por pasos y hoja de compartir. Después
   podrás subir la IPA a App Store Connect con tu procedimiento habitual.

No se han configurado tu Team ID, credenciales, perfiles ni integración real:
son propios de tu cuenta y no deben incluirse en el repositorio.

## Licencia antes de publicar

**Este paquete compila un motor GPLv2; no supone autorización adicional para App Store.**
La página oficial permite actualizar ReferenceFinder e invita a contactar con
Robert J. Lang para otras formas de redistribución. La FSF ha documentado
conflictos entre GPLv2 y las restricciones de App Store. Los créditos no resuelven
ese punto. Confirma un permiso compatible de los titulares correspondientes o
resuelve la distribución con asesoramiento específico antes de subir a Apple.
No se ha obtenido ninguna excepción en esta tarea.

El código fuente completo correspondiente está incluido. Si distribuyes una
versión modificada, conserva avisos/licencia y facilita el código correspondiente
conforme a las condiciones aplicables. Consulta THIRD_PARTY_NOTICES.md.

## Pruebas locales

`python3 scripts/test_engine.py`

Compila el motor y ejecuta 17 casos en el mismo proceso, incluyendo tercios
exactos, rectas, esquina, expresiones, entradas inválidas, rectángulo y cambios
de rango. Analiza los SVG y verifica resultados finitos. Requiere clang++ o g++.

El proyecto de Xcode ya se incluye. `python3 scripts/generate_project.py` permite
regenerarlo de forma determinista sin instalar herramientas adicionales.

## Privacidad y datos de App Store

La app no envía búsquedas ni historial a un servidor. UserDefaults almacena
únicamente las últimas búsquedas dentro del contenedor de la app; se declara el
motivo CA92.1 en PrivacyInfo.xcprivacy. Los SVG se generan y muestran localmente,
sin JavaScript ni recursos remotos. Los enlaces externos y compartir se activan
solo por acción del usuario. No incluye analítica, publicidad ni permisos de
cámara, ubicación o contactos.

Texto orientativo para la ficha: «Encuentra referencias de origami mediante
secuencias de pliegues. Busca puntos y rectas, compara aproximaciones y sigue
diagramas paso a paso. Cálculos sin conexión e historial local.»

## Fuentes consultadas

- https://github.com/HuxleyBerry/origami-reference-finder
- https://langorigami.com/article/referencefinder/
- https://github.com/bugfolder/ReferenceFinder
- https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/
- https://www.fsf.org/news/2010-05-app-store-compliance
- https://developer.apple.com/documentation/bundleresources/privacy_manifest_files

Consulta VALIDATION.md para distinguir las pruebas ejecutadas de las pendientes.
