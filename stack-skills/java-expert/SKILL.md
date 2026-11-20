---
name: java-expert
description: "Use for any Java or Kotlin JVM work: Spring Boot architecture decisions (controller vs service vs repository), JPA/Hibernate query and performance issues (N+1, lazy loading, transaction boundaries, missing indexes), security review (injection, authorization, deserialization), Maven/Gradle dependency issues, testing strategy, and debugging JVM/Spring-specific errors. Applies across any Java/Kotlin project. Defers to a project's own CLAUDE.md for style/convention specifics (formatting, naming, package layout) — this skill is about correctness and design judgment, not house style."
---

# Java Expert

Domain judgment for Java/Kotlin + Spring work: what's actually wrong, and the boring, idiomatic way to fix it. A project's own CLAUDE.md always wins on style (formatting, naming, package layout) — this skill fills the gaps it doesn't cover.

## Diagnose before reaching for a pattern

Read the actual failure first: the root `Caused by:` at the bottom of the stacktrace (not the top wrapper), the bean/entity involved, and what triggered it (request, scheduled job, startup, test). Don't guess-fix. Spring startup failures name the missing or ambiguous bean; `spring.jpa.show-sql`/Hibernate SQL logging, `/actuator`, and a thread dump (`jstack`) tell you more than pattern-matching the symptom.

## JPA / Hibernate

- **N+1**: many near-identical SELECTs per request, usually from iterating a lazy collection. Fix with `JOIN FETCH` or `@EntityGraph` on the repository query that needs it — not by switching the mapping to `EAGER` (that makes every query slower).
- **`LazyInitializationException`**: the entity escaped its transaction. Fetch what you need inside the service transaction or map to a DTO there. Don't enable `open-in-view` or `enable_lazy_load_no_trans` as a fix.
- **Missing index**: `WHERE`/`JOIN`/`ORDER BY` columns with no index; check `EXPLAIN ANALYZE`. Add it in the migration tool (Flyway/Liquibase), never rely on `ddl-auto` outside local dev.
- **Validation vs constraints**: Bean Validation is UX; back uniqueness/not-null invariants with DB constraints since races bypass app checks.
- **`equals`/`hashCode`** on entities: don't use Lombok `@Data` or Kotlin `data class` for entities — base equality on a stable business key or ID-with-null-handling, and avoid touching lazy associations in `toString`.
- Bulk operations: use `@Modifying` JPQL or batch inserts (`hibernate.jdbc.batch_size`) instead of saving thousands of entities one by one.

## Transactions

- `@Transactional` on service methods, not controllers or repositories. It only works through the Spring proxy: self-invocation (`this.method()`) and private methods silently skip it.
- By default only unchecked exceptions roll back; set `rollbackFor` if checked exceptions should too.
- Don't send emails, HTTP calls, or publish messages inside the transaction — use `@TransactionalEventListener(phase = AFTER_COMMIT)` or an outbox, since a rollback can't undo them.
- `readOnly = true` for read paths; keep transactions short — no remote calls while holding a DB connection.

## Where does this logic go?

- **Controller**: HTTP only — request mapping, validation (`@Valid`), response shape. No business branching.
- **Service**: business logic and transaction boundaries. Most non-trivial code lives here.
- **Repository**: data access only. Spring Data derived queries or `@Query`; no business rules.
- Don't create an interface for a service with one implementation, or a mapper/factory/strategy layer for a one-off. Constructor injection, no field `@Autowired`.

## Security

- **SQL/JPQL injection**: never concatenate input into queries; use parameters (`:name`, `?1`, Criteria API). Same for `ORDER BY` — whitelist sort fields.
- **Mass assignment**: bind requests to dedicated DTOs, never directly to entities (users could set `id`, `role`, owner fields).
- **Authorization**: check ownership on every endpoint (`@PreAuthorize` or explicit checks in the service), not just in the UI. Don't disable CSRF for session-based apps to make a request "work".
- **Deserialization**: no Java native deserialization of untrusted data; no Jackson default typing on untrusted input.
- Don't return stacktraces or exception messages to clients; log them and return a generic error. Keep dependencies patched (OWASP dependency-check / Dependabot).

## Kotlin specifics

- Platform types from Java can be null — annotate or check at the boundary instead of trusting `!!`.
- JPA entities need the `kotlin-spring`/`kotlin-jpa` (allopen/no-arg) plugins; prefer `lateinit` or nullable IDs over fake defaults.
- Coroutines in Spring: don't call blocking JDBC from coroutines on the default dispatcher; use `Dispatchers.IO` or stay blocking.

## Testing (JUnit 5)

- Cover happy path, the invalid/empty case, and one boundary. Use slice tests (`@WebMvcTest`, `@DataJpaTest`) over `@SpringBootTest` when one layer is under test.
- Use Testcontainers with the real database rather than H2 when queries or constraints matter — H2 dialect differences hide real bugs.
- Mock at the boundary (HTTP clients, external services with Mockito/MockK or WireMock), not the class under test.

## Performance

- Fix queries (fetch joins, projections/DTOs, pagination, indexes) before adding a cache (`@Cacheable` adds invalidation problems).
- Size the connection pool (HikariCP) to the DB, not to thread count; long transactions starve it.
- Profile (JFR, async-profiler) before tuning GC flags or rewriting code. Stream large result sets instead of `findAll()`.

## Maven / Gradle

- Dependency conflicts: `mvn dependency:tree` / `gradle dependencies` before overriding versions. Let the Spring Boot BOM manage versions instead of pinning individual Spring libs.
- Don't add a library for what the JDK or an existing dependency already does.

## When training data is likely stale

Spring Boot 3 moved to `jakarta.*`, Java 21 brought virtual threads and records/pattern matching, Hibernate 6 changed query semantics. Check the actual Boot/Java/Kotlin versions in `pom.xml` or `build.gradle(.kts)` before asserting how something works.
