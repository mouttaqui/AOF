# Customization and Extension

The Apex Orbit Framework (AOF) is designed to be extensible. Developers can customize its behavior and extend its functionality to meet specific application requirements.

1.  **Extending Base Classes:**
    *   **Domain Classes:** Create new SObject-specific domain classes by extending `AOF_Application_Domain`. Override the virtual context methods (`onBeforeInsert`, `onAfterUpdate`, etc.) to implement your business logic.
    *   **Selector Classes:** Create new SObject-specific selector classes by extending `AOF_Application_Selector`. Implement methods that encapsulate your SOQL queries, ensuring they use `WITH SECURITY_ENFORCED` and are bulkified.

2.  **Implementing Service Interfaces:**
    *   Create new service classes by implementing the `AOF_Application_Service` interface (or more specific service interfaces you define). These classes will house your cross-object business logic or reusable processes.

3.  **Customizing `AOF_TriggerHandler` Dispatch:**
    *   The base `AOF_TriggerHandler` calls its own virtual methods (e.g., `beforeInsert()`). To make it dispatch to your SObject-specific domain classes (e.g., `AOF_AccountDomain`), you need to implement the dispatch logic. This can be done by:
        *   **Modifying `AOF_TriggerHandler`:** Add a dispatch mechanism (e.g., a map of SObjectType to Domain Class Type, or a series of if-else statements based on `this.sObjectType`) within the `run()` method or within each virtual context method (e.g., `protected override void beforeInsert() { if(this.sObjectType == Account.SObjectType) new AOF_AccountDomain(...).onBeforeInsert(); ... }`).
        *   **Creating a Subclass of `AOF_TriggerHandler`:** If you prefer not to modify the core `AOF_TriggerHandler`, you could create an abstract subclass that implements the dispatch logic, and then your SObject triggers would call this subclass.

4.  **Modifying Unit of Work Behavior:**
    *   The `AOF_Application_UnitOfWork` class can be extended or modified if you need different DML processing behavior (e.g., specific order of SObject DML, different error handling for partial success by using `Database.insert(records, false)` and processing `Database.SaveResult`).

5.  **Enhancing Error Handling:**
    *   **Custom Fields:** Add more custom fields to `ErrorLogEvent__e` and `Error_Log__c` if you need to capture additional contextual information with errors.
    *   **Notification Mechanisms:** Extend the `ErrorLogEventSubscriber.trigger` to include notifications (e.g., email alerts, Chatter posts) when critical errors are logged.
    *   **Custom Error Severities:** Modify the `Severity__c` picklist values on `Error_Log__c` and use them consistently in `AOF_ErrorHandlerService`.

6.  **Adding New Framework Utilities:**
    *   If you identify common patterns or utility functions needed across multiple AOF components, consider creating new abstract base classes or static utility classes within the framework's namespace/structure.

7.  **Integrating with Other Frameworks/Libraries:**
    *   AOF can be used alongside other utility libraries. For example, if you have a preferred mocking framework for testing, it can be used to test AOF components.

8.  **Configuration via Custom Metadata/Settings:**
    *   For aspects of the framework or your application logic that need to be configurable without code changes (e.g., feature toggles, specific parameters for service classes, error severity thresholds for notifications), leverage Custom Metadata Types or Custom Settings.

When customizing or extending AOF, always ensure that your changes adhere to the core principles of the framework (Separation of Concerns, Bulkification, Security, etc.) and that you write appropriate unit tests for any new or modified functionality.
