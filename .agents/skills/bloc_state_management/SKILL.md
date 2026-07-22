---
name: bloc-state-management
description: Guidelines for managing state using BLoC and Cubit in this Flutter project.
---

# BLoC & Cubit State Management Guidelines

This skill documents the rules, best practices, and anti-patterns for implementing state management using the `flutter_bloc` library in this project.

---

## When to Use
Use this skill when:
* Creating or modifying a `Cubit` or `Bloc`
* Writing state classes (using `freezed` or sealed classes)
* Orchestrating state transitions or writing UI interactions with `BlocBuilder`, `BlocListener`, or `BlocConsumer`

Do not use this skill when:
* Implementing pure widget UI details that do not affect the application state.

---

## Architecture Guidelines

### 1. Cubit as the Default
* Default to using `Cubit` for state management since it is a simpler state machine without event logs.
* Only switch to a full `Bloc` when:
  1. Event traceability is strictly required for analytics or compliance.
  2. You need event transformations (like `debounce` or `throttle`) for search-as-you-type or scroll-driven pagination.
  3. You need to coordinate complex concurrent event streams.

### 2. Sliced States & Responsibility
* Every Cubit/Bloc should manage **exactly one use-case or screen slice** (e.g., `LoginCubit` for login, `CreateTaskCubit` for creating tasks).
* Do not build monolithic feature Cubits (like `UsersMegaCubit` for listing, editing, creating, and deleting). Split them into separate slices.

### 3. State Shape Modeling
* Model states as a **sealed class structure** (preferably using `freezed` if available).
* Avoid mixing flags (like `bool isLoading = false; String? error;`) in a single record class. Instead, define separate states for each phase:
  * `initial()`
  * `loading()`
  * `success(data)`
  * `error(Failure failure)`
* Keep `Failure` objects in the error state rather than raw localized strings. Let the UI layer handle localization.

### 4. Communication Between Slices
* Communication between different state containers must go through the UI layer using `BlocListener`, not through direct imports or cross-Cubit references:
```dart
BlocListener<CreateUserCubit, CreateUserState>(
  listener: (context, state) {
    if (state is CreateUserSuccess) {
      context.read<ListUsersCubit>().refresh();
      context.router.pop();
    }
  },
  child: ...,
)
```

---

## Common Anti-patterns to Avoid
* ❌ **Calling APIs directly inside the Cubit:** The Cubit should only orchestrate and delegate network calls to use-cases/services.
* ❌ **Using setState inside a screen managed by BLoC:** Move the state into the Cubit or keep UI-only states local if completely necessary.
* ❌ **Nesting BlocBuilders:** Nesting `BlocBuilder` inside a `BlocConsumer.builder` introduces frame synchronization bugs. Derive local variables from the state instead of nesting.
* ❌ **Emitting states without await:** Emitting multiple states synchronously might lead to state coalescence, causing the UI to miss intermediate states (like loading states).
