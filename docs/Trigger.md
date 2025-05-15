# Trigger Execution Flow

The Apex Orbit Framework (AOF) establishes a clear and predictable execution flow for trigger-based logic. Understanding this flow is crucial for developers working with the framework.

1.  **DML Operation Occurs:** A Data Manipulation Language (DML) operation (e.g., insert, update, delete) is performed on an SObject record, either through the Salesforce UI, an API call, or Apex code.
2.  **SObject Trigger Fires:** The single, dedicated trigger for that SObject (e.g., `AccountTrigger.trigger`) fires in response to the DML operation.
3.  **Instantiate `AOF_TriggerHandler`:** The SObject trigger contains minimal logic. Its primary responsibility is to instantiate the `AOF_TriggerHandler` class, passing the SObjectType of the current record(s) and the `Trigger.operationType`.
    ```apex
    // Example from AccountTrigger.trigger
    AOF_TriggerHandler handler = new AOF_TriggerHandler(Account.SObjectType, Trigger.operationType);
    ```
4.  **Invoke `AOF_TriggerHandler.run()`:** The SObject trigger then calls the `run()` method on the instantiated `AOF_TriggerHandler`.
    ```apex
    // Example from AccountTrigger.trigger
    handler.run();
    ```
5.  **`AOF_TriggerHandler.run()` Execution:** This central method orchestrates the main logic:
    *   **Bypass Check:** It first checks if any bypass mechanisms are active (either a global bypass for all triggers or a specific bypass for the current SObjectType). If a bypass is active, the handler exits, and no further framework logic is executed for this transaction context.
    *   **Context Determination:** The handler identifies the exact trigger context (e.g., `before insert`, `after update`) using the `Trigger.operationType` and other trigger context variables (`Trigger.isBefore`, `Trigger.isInsert`, etc.).
    *   **Domain/Service Layer Invocation:** Based on the SObjectType and the trigger context, the `AOF_TriggerHandler` dynamically instantiates the appropriate SObject-specific Domain class (e.g., `AOF_AccountDomain` for `Account.SObjectType`). It then calls the corresponding context-specific method on the Domain class instance (e.g., `domainInstance.onBeforeInsert()`, `domainInstance.onAfterUpdate()`).
        *   The Domain class constructor receives the relevant records from the trigger context (e.g., `Trigger.new`, `Trigger.oldMap`).
        *   For more complex operations that span multiple SObjects or involve external systems, the Domain class method might delegate to a method in a Service Layer class.
    *   **Bulkification Ensured:** All logic within the Domain and Service layers is designed to operate on collections of records, ensuring bulkification is maintained throughout the execution path.
6.  **Data Access and DML Registration:**
    *   **Selector Layer Usage:** When Domain or Service layer methods need to query additional data, they utilize methods from the SObject-specific Selector classes (e.g., `AOF_AccountSelector.selectActiveAccountsByType("Customer")`). Selector methods handle SOQL construction, FLS/CRUD enforcement, and return bulkified results.
    *   **Unit of Work Registration:** If any DML operations (insert, update, delete) are required as a result of the business logic, these operations are not performed immediately. Instead, the SObject records are registered with the `AOF_Application_UnitOfWork` instance associated with the current transaction (e.g., `uow.registerNew(newContact)`).
7.  **Commit DML Operations:**
    *   After all `before` and `after` logic for the current trigger context has been executed within the Domain and Service layers, and if no critical, unrecoverable errors have occurred (typically checked by `record.hasErrors()` in `before` contexts), the `AOF_TriggerHandler` (or a top-level service method if the flow is more complex) calls the `commitWork()` method on the `AOF_Application_UnitOfWork` instance.
    *   The `commitWork()` method then executes all registered DML operations in a bulkified manner (e.g., a single `insert` statement for all new records, a single `update` for all dirty records).
8.  **Error Handling:**
    *   Throughout the execution flow, if an exception occurs, it should be caught at an appropriate level (e.g., within a service method, a domain method, or the `AOF_TriggerHandler` itself).
    *   The `AOF_ErrorHandlerService.logError(...)` method is then called to publish an `ErrorLogEvent__e` Platform Event. This event contains details about the error (exception message, stack trace, class/method origin, involved records, etc.).
    *   The Platform Event is processed asynchronously by a subscriber trigger (`ErrorLogEventTrigger`), which creates a persistent `Error_Log__c` record. This ensures error logging even if the main transaction rolls back.
    *   For user-facing errors (e.g., validation rule failures), the `addError()` method should be used on the SObject record itself (e.g., `acc.Name.addError("Account Name cannot be blank.")`). This prevents the record from being saved and displays the error to the user in the UI.

This structured flow ensures that trigger logic is organized, manageable, bulk-safe, and adheres to Salesforce best practices.
