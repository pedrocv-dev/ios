# MiniTasks

Aplicación iOS sencilla para practicar Swift 6, SwiftUI, MVVM, Clean Architecture, concurrencia, persistencia y testing.

## Funcionalidades

- Crear tareas.
- Marcar tareas como completadas o pendientes.
- Eliminar tareas mediante el gesto de la lista.
- Persistencia local en un archivo JSON.
- Mensajes de error básicos.

## Requisitos

- Xcode 16+
- iOS 17 o posterior

## Estructura

- `Domain`: modelo, protocolo de repositorio y casos de uso.
- `Data`: implementación de persistencia JSON aislada con `actor`.
- `Presentation`: pantalla SwiftUI y ViewModel `@MainActor`.
- `MiniTasksTests`: tests unitarios de los casos de uso.
