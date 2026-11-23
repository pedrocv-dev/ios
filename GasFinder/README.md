# GasFinder

Aplicación iOS para la búsqueda de gasolineras baratas por **municipio** contra la API pública de precios de carburantes del Ministerio (MINETUR / datos.gob.es), con filtro por tipo de combustible (**Diésel / Gasolina 95**), SwiftUI, Swift 6, MVVM + Clean Architecture, concurrencia con cancelación, cache en memoria con TTL y testing.

## Funcionalidades

- Búsqueda por municipio: el usuario escribe el nombre y pulsa **Buscar** (la búsqueda solo se lanza al pulsar el botón, que está siempre activo). La resolución del nombre es exacta, ignorando mayúsculas y tildes: primero coincide el **nombre del municipio**; si no existe, el **nombre de la provincia**; si no, se muestra "municipio no encontrado". Los municipios se obtienen siempre de la API del Ministerio y se cachean en memoria con TTL.
- Filtro por combustible: Diésel (Gasóleo A) o Gasolina 95 E5.
- Resultados ordenados de más barato a más caro (€/L).
- Cancelación: si el usuario lanza una nueva búsqueda, la petición en curso se cancela y sus resultados se descartan.
- Pantalla de detalle con la información de la estación (rótulo, dirección, municipio, provincia, horario, precios y coordenadas).
- Cache en memoria por municipio con TTL de 2 minutos: cambiar de combustible o repetir búsqueda no repite la llamada de red; expirado el TTL, los precios se refrescan.

## API

- `GET .../EstacionesTerrestres/` — dataset nacional con todas las estaciones de servicio y sus precios. La descarga y decodificación (~12 MB) se realizan fuera del hilo principal y se cachean en memoria con TTL de 2 minutos.
- Los municipios se consultan siempre a la API: `GET .../Listados/Provincias/` + `GET .../Listados/MunicipiosPorProvincia/{id}` (una petición por provincia, en paralelo). El listado completo (~8.100 municipios) se cachea en memoria con TTL de 1 hora; la primera búsqueda tarda unos 2 s y las siguientes son instantáneas.
- **Excepción ATS**: el servidor del Ministerio solo ofrece cifrados TLS 1.2 sin *forward secrecy*, que App Transport Security rechaza por defecto (error -1200). `Info.plist` incluye una excepción limitada a `sedeaplicaciones.minetur.gob.es`.

## Requisitos

- Xcode 16+
- iOS 17 o posterior

## Estructura

- `Domain`: modelos (`GasStation`, `Municipality`, `FuelType`), protocolos de repositorio (`GasStationRepository`, `MunicipalityRepository`) y caso de uso (`SearchStationsUseCase`: resolver municipio → obtener estaciones → filtrar por combustible → ordenar por precio).
- `Data`: cliente HTTP (`MineturClient`) con DTOs y mapeo, repositorio con cache TTL (`MineturGasStationRepository`) y repositorio de municipios incluido en el bundle (`BundledMunicipalityRepository`).
- `Presentation`: pantalla de búsqueda (con sugerencias y filtro de combustible) y de detalle en SwiftUI; `SearchViewModel` (`@MainActor`) que cancela la búsqueda anterior al iniciar una nueva.
- `GasFinderTests`: tests de Domain (repositorios mockeados), de Data (comportamiento y expiración del cache con `URLProtocol` mockeado y reloj inyectable, mapeo de DTOs, resolución de municipios) y de Presentation (cancelación, cambio de combustible sin re-llamada de red y estados del ViewModel).


