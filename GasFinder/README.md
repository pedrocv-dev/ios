# GasFinder

Aplicación iOS para encontrar las gasolineras más baratas de un municipio en España, filtrando por tipo de combustible (Diésel / Gasolina 95).

Los precios se obtienen en tiempo real del servicio público de Precios de Carburantes del Ministerio (MINETUR / datos.gob.es).

## Funcionalidades

### Búsqueda por municipio

- La primera pantalla ofrece un campo de texto para buscar por municipio contra la API de precios; los resultados se muestran en una lista con el rótulo, la dirección y el precio (€/L) de cada gasolinera.
- La resolución del municipio es exacta, ignorando mayúsculas y tildes: primero coincide el **nombre del municipio**; si no existe, el **nombre de la provincia**; si no, se muestra "municipio no encontrado". La búsqueda solo se lanza al pulsar el botón Buscar (siempre activo).
- Filtro por combustible: Diésel (Gasóleo A) o Gasolina 95 E5, con los resultados ordenados de más barato a más caro.

### Cancelación

- Si el usuario lanza una nueva búsqueda antes de que la anterior haya finalizado, la petición en curso se cancela y no se muestran resultados de búsquedas anteriores. La cancelación se propaga hasta las peticiones de red y los resultados obsoletos se descartan.

### Detalle de la estación

- Al seleccionar un elemento del listado, la app navega a una pantalla de detalle con la información relevante de la estación: rótulo, dirección, municipio, provincia, horario, precios de ambos combustibles y coordenadas.

### Cache

- El dataset de precios y el listado de municipios se almacenan en cache en memoria por consulta: si existe una entrada válida se devuelve sin llamada de red; si ha expirado, se obtiene de nuevo de la red y se actualiza la cache. Cambiar de combustible, repetir una búsqueda o consultar otro municipio no repite las descargas hasta que la cache expira.

## API

- `GET .../EstacionesTerrestres/` — dataset nacional con todas las estaciones de servicio y sus precios. La descarga y decodificación (~12 MB) se realizan fuera del hilo principal y se cachean en memoria con TTL de 2 minutos.
- Los municipios se consultan siempre a la API: `GET .../Listados/Provincias/` + `GET .../Listados/MunicipiosPorProvincia/{id}` (una petición por provincia, en paralelo). El listado completo (~8.100 municipios) se cachea en memoria con TTL de 5 minutos; la primera búsqueda tarda unos 2 s y las siguientes son instantáneas.
- **Excepción ATS**: el servidor del Ministerio solo ofrece cifrados TLS 1.2 sin *forward secrecy*, que App Transport Security rechaza por defecto (error -1200). `Info.plist` incluye una excepción limitada a `sedeaplicaciones.minetur.gob.es`.

## Arquitectura

- Separación clara en capas: **Domain** (modelos, protocolos de repositorio y caso de uso), **Data** (cliente HTTP, DTOs, repositorios con cache) y **Presentation** (pantallas SwiftUI y ViewModel):

```
Domain/    Modelos (GasStation, Municipality, FuelType), protocolos de
           repositorio (GasStationRepository, MunicipalityRepository) y caso
           de uso (SearchStationsUseCase: resolver municipio → obtener
           estaciones → filtrar por combustible → ordenar por precio).
Data/      Cliente HTTP (MineturClient) con DTOs y mapeo, repositorios con
           cache TTL (MineturGasStationRepository, MineturMunicipalityRepository)
           y cache genérica en memoria (QueryCache, actor con reloj inyectable).
Presentation/  Pantalla de búsqueda y de detalle en SwiftUI; SearchViewModel
           (@MainActor, @Observable) que cancela la búsqueda anterior al
           iniciar una nueva.
```

- Todas las pantallas están implementadas con **SwiftUI** (iOS 17+).
- Concurrencia con Swift 6 en modo *strict concurrency*: actor para la cache, `@Observable` + `@MainActor` en el ViewModel, `TaskGroup` para peticiones paralelas y decodificación del dataset grande fuera del hilo principal.
- 28 tests unitarios que cubren el dominio con repositorios mockeados, el comportamiento y la expiración del cache, y la capa de presentación.

## Tests

Tests unitarios, todos sin dependencia de la red real:

- **Domain**: el caso de uso con repositorios mockeados (filtrado por municipio y combustible, ordenación por precio, municipio no encontrado, errores propagados, consultas vacías sin llamadas).
- **Data**: comportamiento del cache (hit sin segunda llamada de red, expiración con reloj fake, refetch tras TTL), mapeo de las respuestas al modelo de dominio, errores HTTP, cancelación de las peticiones y resolución de municipios desde los listados de la API. Las respuestas se simulan con un `URLProtocol` mockeado.
- **Presentation**: cancelación de la búsqueda en curso, cambio de combustible sin re-llamada de red y estados del ViewModel (resultados, vacío, error).

## Entorno

- Xcode 16+
- iOS 17 o posterior

## Cómo ejecutar

### Desde Xcode

1. Abre `GasFinder.xcodeproj`.
2. Selecciona el esquema **GasFinder** y un simulador (o un dispositivo).
3. Pulsa **Run** (⌘R).

### Desde la línea de comandos

Compilar y arrancar en el simulador:

```bash
xcodebuild build \
  -project GasFinder.xcodeproj \
  -scheme GasFinder \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath build

xcrun simctl boot "iPhone 16"
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/GasFinder.app
xcrun simctl launch booted com.pcv.GasFinder
```

Ejecutar los tests:

```bash
xcodebuild test \
  -project GasFinder.xcodeproj \
  -scheme GasFinder \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
