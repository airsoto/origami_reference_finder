# Verificación de entrega · 29 de octubre de 2026

## Ejecutado

- Compilación real de los seis archivos originales del motor y del adaptador
  nuevo con g++ y C++17, sin recurrir a -fpermissive.
- 17 casos de búsqueda en el mismo proceso: coordenadas exactas de tercios,
  referencia de borde, recta de tercios, esquina, raíz y coma decimal,
  coincidencia de los puntos de una recta, coordenada fuera del papel,
  división por cero, raíz negativa, set rechazado, identificador desconocido,
  papel rectangular, rango 2, rango 3, reconstrucción del rango 4,
  rango no admitido y papel no válido.
- Validación de cada SVG generado como XML; ausencia de valores nan/inf.
- Verificación del error prácticamente nulo de las construcciones exactas
  (tolerancia 1e-8) y del límite de rango solicitado.
- Lectura de codemagic.yaml y de ambos property lists; esquema compartido
  de Xcode verificado como XML.
- En una ejecución local, (1/3, 1/3) con rango máximo 4 produjo 16 325 puntos
  y 20 564 rectas. Mejor solución: rango 3, tres diagramas y error
  7.85046229342e-17. Esta medida no predice el rendimiento de un iPhone.

## Pendiente en macOS / Codemagic

- Compilar las fuentes SwiftUI, Objective-C++ y recursos con el SDK de Apple.
  No hay Xcode, simulador ni swiftc disponibles en el entorno Linux de entrega.
  Ejecutar primero el flujo ios-check incluido.
- Prueba de uso en simulador y dispositivo: teclado, navegación por diagramas,
  accesibilidad, Dynamic Type, rotación, cancelar e historial.
- Firmar con los certificados/perfiles de la cuenta del usuario y comprobar IPA.
- Resolver las condiciones de distribución de GPLv2 antes de entregar a Apple.

No se ha ejecutado un build en Codemagic, no se ha generado una IPA y no se ha
subido nada a GitHub, TestFlight ni App Store. El entregable es el proyecto fuente
con su configuración de compilación y las pruebas ejecutables.
