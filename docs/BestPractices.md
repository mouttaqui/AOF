# Best Practices for Using AOF

Adhering to best practices when using the Apex Orbit Framework (AOF) will ensure your Salesforce application is robust, maintainable, scalable, and performs well.

1.  **Adhere to Layer Responsibilities:**
    *   **Triggers:** Keep them minimal. Only instantiate and run `AOF_TriggerHandler`.
    *   **`AOF_TriggerHandler`:** Focus on orchestrating calls to the Domain layer (or Service layer for complex cross-object logic). Manage the Unit of Work commit.
    *   **Domain Layer (`AOF_Application_Domain` extensions):** Place SObject-specific business logic, validations, and calculations here. Operate only on the records passed into the domain context.
    *   **Selector Layer (`AOF_Application_Selector` extensions):** All SOQL queries must go here. Ensure queries are selective, bulkified, and enforce FLS/CRUD (`WITH SECURITY_ENFORCED`).
    *   **Service Layer (`AOF_Application_Service` implementations):** Use for logic that spans multiple SObjects, interacts with external systems, or represents reusable business processes. Services can use multiple Selectors and coordinate Domain logic.
    *   **Unit of Work (`AOF_Application_UnitOfWork`):** Register all DML operations through the UoW instance provided by the `AOF_TriggerHandler`. Avoid direct DML in Domain or Service classes.

2.  **Embrace Bulkification:**
    *   Always write your Domain, Service, and Selector methods to operate on collections (`List`, `Set`, `Map`) of records, not single records.
    *   Avoid SOQL queries or DML statements inside loops.

3.  **Query Optimization (Selectors):**
    *   Query only the fields you need. Don't use `SELECT *` (which isn't valid SOQL anyway, but the principle applies to querying all fields unnecessarily).
    *   Use efficient `WHERE` clauses to filter data at the database level.
    *   Leverage indexed fields in your `WHERE` clauses where possible.

4.  **Unit of Work Management:**
    *   Obtain the `AOF_Application_UnitOfWork` instance from the `AOF_TriggerHandler` (it needs to be passed down or made accessible to Domain/Service layers).
    *   Register records for DML (`registerNew`, `registerDirty`, `registerDeleted`).
    *   Let the `AOF_TriggerHandler` call `commitWork()` at the end of the transaction. Avoid calling `commitWork()` multiple times within a single transaction path unless absolutely necessary and well understood.

5.  **Security First:**
    *   Use `WITH SECURITY_ENFORCED` in all Selector queries.
    *   Explicitly define sharing (`with sharing`, `without sharing`, `inherited sharing`) for all Apex classes.
    *   Validate user input, especially if it comes from client-side controllers or external systems.

6.  **Effective Error Handling:**
    *   Use `try-catch` blocks for operations that might fail.
    *   Log all caught exceptions using `AOF_ErrorHandlerService.logError()`.
    *   Use `SObject.addError()` for user-facing validation errors.

7.  **Code Reusability:**
    *   Place reusable utility methods in appropriate helper classes or within the base AOF classes if broadly applicable.
    *   Design Service layer methods to be reusable across different parts of your application.

8.  **Test Coverage:**
    *   Write comprehensive unit tests for all your AOF components (Domain, Selector, Service classes).
    *   Test bulk scenarios (e.g., processing 200 records).
    *   Test positive and negative scenarios, including error conditions.
    *   Verify DML operations by querying data after `Test.stopTest()` and asserting results.
    *   Test FLS/CRUD enforcement in Selectors by running tests as different users with varying permissions (using `System.runAs()`).

9.  **Governor Limit Awareness:**
    *   Be mindful of Salesforce governor limits (SOQL queries, DML statements, CPU time, heap size, etc.). AOF helps, but complex logic can still hit limits.
    *   Use asynchronous processing (Queueable, Batch, Future) via the Service layer for long-running or resource-intensive operations.

10. **Naming Conventions and Readability:**
    *   Follow consistent naming conventions for your classes and methods (e.g., `AOF_MyObjectDomain`, `AOF_MyObjectSelector`).
    *   Write clean, well-commented code that is easy for other developers to understand.

11. **Bypass Mechanisms:**
    *   Understand how to use the trigger bypass mechanisms (`AOF_TriggerHandler.bypass()`, `AOF_TriggerHandler.bypassAllTriggers()`) for scenarios like data migrations or specific test setups. Use them judiciously.

12. **Configuration over Code:**
    *   For configurable aspects of your logic (e.g., thresholds, feature flags, specific IDs), consider using Custom Settings or Custom Metadata Types instead of hardcoding values.

By following these best practices, you can leverage the full potential of the Apex Orbit Framework to build high-quality Salesforce applications.
