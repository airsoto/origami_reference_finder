# Créditos y procedencia

## ReferenceFinder 4

Robert J. Lang, creador del programa y del motor de búsqueda y geometría.
Copyright ©1999–2007 Robert J. Lang. Se conservan los avisos de cada archivo.
Motor distribuido bajo GNU GPL versión 2: véase LICENSE.txt.

Los archivos ReferenceFinder.cpp, ReferenceFinder.h, lexer.cpp, lexer.h,
parser.cpp y parser.h proceden de:
https://github.com/bugfolder/ReferenceFinder/tree/main/source/model

La revisión utilizada y los identificadores originales de cada archivo se
registran en ENGINE_PROVENANCE.json. No hay descargas de código durante la
compilación; todas las fuentes necesarias están incluidas.

Cambios locales de compatibilidad, 29 de octubre de 2026:
- ReferenceFinder.cpp: calificación this-> en reserve y push_back del contenedor
  plantilla, requerida por compiladores C++ actuales.
- parser.cpp y parser.h: retirada de especificaciones dinámicas throw(Status),
  eliminadas del estándar C++17.
- lexer.cpp: retirada del especificador register obsoleto.
- MobileEngine.*: nuevo adaptador, validación, límites móviles, serialización,
  cancelación y representación SVG. No modifica los axiomas del motor.

## Analizador de expresiones

Carlos A. Furuti (C.A. Furuti), copyright ©2003, 2006.
Se conservan los avisos del analizador original. Distribución bajo las mismas
condiciones que ReferenceFinder.

## Corrección del motor

La página oficial de Robert J. Lang acredita a Mu-Tsun Tsai por una corrección
de un error histórico incorporada al repositorio oficial en 2024:
https://langorigami.com/article/referencefinder/

## Adaptación histórica para iPhone

Jérôme Laheurte desarrolló ReferenceFinder 4 para iPhone en 2009.
El ZIP proporcionado por el usuario se estudió para entender el flujo original
de búsqueda, configuración, soluciones y diagramas. No se incluyen sus fuentes
Objective-C, XIB, iconos ni imágenes en el ejecutable ni en este proyecto nuevo.
Por tanto, este reconocimiento histórico no atribuye a Laheurte la nueva interfaz.
Fuente: https://langorigami.com/wp-content/uploads/2015/09/ReferenceFinder_4_iphone.zip

## Repositorio web revisado

HuxleyBerry/origami-reference-finder, aplicación Vue/TypeScript:
https://github.com/HuxleyBerry/origami-reference-finder

Se revisaron App.vue y utils/calc.ts y la estructura del proyecto. No había una
licencia explícita en la raíz revisada. No se copiaron fuentes, fórmulas de esa
implementación, recursos ni dependencias de ese repositorio al proyecto nuevo.

## Nueva versión

Subido para iOS por Ángel Soto.
El código nuevo de este paquete se distribuye bajo GPL-2.0 para mantener las
condiciones del conjunto derivado. Sin garantía. El icono ha sido aportado por el usuario para esta versión y se ha convertido
a PNG de 1024 × 1024 píxeles sin modificar el diseño. No se reutilizan los
recursos históricos.

## Distribución por App Store

La licencia GPLv2 del motor debe respetarse. Entregar créditos no sustituye la
licencia ni la entrega del código fuente correspondiente. La compatibilidad de
la GPL con restricciones de distribución de App Store debe resolverse antes de
distribuir esta aplicación por App Store o TestFlight. No se ha obtenido ninguna
excepción ni permiso adicional en esta tarea. La página oficial invita a contactar
con Robert J. Lang para otras formas de redistribución. Conservar cualquier permiso
escrito y confirmar su alcance, incluidos los demás titulares de derechos.
