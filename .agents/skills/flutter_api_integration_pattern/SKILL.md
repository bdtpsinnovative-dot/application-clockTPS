---
name: flutter-api-integration-pattern
description: Add or review API integration using Dio and clean data mapping patterns.
---

# Flutter API Integration Pattern (Dio & Clean Data Mapping)

This skill provides guidelines and checklists for implementing, refactoring, and reviewing API integrations in Flutter using the Dio client and clean data mapping patterns.

---

## When to Use
* Adding a new API endpoint or query
* Reviewing remote datasource or API client design
* Improving error handling, token management, or pagination

Do not use this skill when:
* Exposing transport-level DTOs directly to presentation layer (unless the repository structure explicitly mandates it).

---

## Architecture Assumptions
* **Network Client:** Dio
* **Data Mapping:** DTO (Data Transfer Object) -> Domain Entity/Model

---

## Instructions

### 1. Define Request/Response Contracts First
Before writing code, verify:
* Endpoints, query parameters, headers, and request body format
* Successful JSON response keys and types
* Error response formats (e.g., `{ "error": "message" }`)

### 2. Remote Datasource Implementation
* Keep remote datasources focused purely on sending HTTP requests and receiving raw response data.
* Do not embed presentation or UI logic here.
* Use clean serialization (e.g., using `fromJson` methods in model classes).

### 3. Handle Errors and Gaps Safely
* Map Dio exceptions (`DioExceptionType.connectionTimeout`, `badResponse`, etc.) into clear, application-level custom exceptions (e.g., `NetworkException`, `ServerException`, `AuthException`).
* Avoid exposing raw HTTP status codes or Dio objects directly to UI layers.
* Always check `context.mounted` if performing actions across asynchronous network requests.

### 4. Auth & Interceptors
* Use Dio Interceptors to attach Authorization headers (JWT tokens) automatically.
* Implement token refresh flows within the interceptor loop, handling 401 Unauthorized responses gracefully.

### 5. Code Review checklist
* Are request and response schemas modeled as proper classes rather than raw `Map<String, dynamic>`?
* Are HTTP timeouts set appropriately (e.g., 10-15s connect timeout)?
* Does the code catch DioExceptions specifically instead of general Exceptions?
