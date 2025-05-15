# Framework Architecture and Layers

The Apex Orbit Framework (AOF) is structured into distinct layers, each with a specific responsibility. This layered architecture promotes separation of concerns, making the framework modular, easier to understand, test, and maintain. The primary layers are: Trigger Handler, Service, Domain, Selector, Unit of Work, and Error Handling.

## 1. Trigger Handler Layer

**Component:** `AOF_TriggerHandler.cls`

*   **Purpose:** This is the entry point for all SObject trigger logic. AOF employs a **single trigger per SObject** pattern. Instead of writing complex logic directly within individual SObject triggers (e.g., `AccountTrigger.trigger`), these triggers will be minimal, primarily responsible for instantiating and invoking the `AOF_TriggerHandler`.
*   **Functionality:**
    *   Manages and provides access to trigger context variables (e.g., `Trigger.new`, `Trigger.oldMap`, `Trigger.operationType`).
    *   Orchestrates the execution flow by delegating calls to the appropriate methods in the Domain Layer or, for more complex cross-object logic, the Service Layer. The dispatch is based on the SObject type and the specific trigger context (e.g., `before insert`, `after update`).
    *   Includes a static bypass mechanism (e.g., `AOF_TriggerHandler.bypassAllTriggers = true;` or per-object bypass) to allow administrators or data migration processes to disable trigger logic temporarily.
    *   Ensures that all calls to subsequent layers are inherently bulk-safe because it operates on the collections of records provided by the trigger context.
    *   The base `AOF_TriggerHandler` contains virtual methods for each trigger event (e.g., `beforeInsert()`, `afterUpdate()`). These methods are intended to be called by the `run()` method. Concrete SObject-specific domain classes will implement the logic for these events.
*   **SObject-Specific Triggers** (e.g., `AccountTrigger.trigger`):
    *   Each SObject that requires trigger logic will have a single trigger file.
    *   This trigger file will contain minimal code, typically just one line to instantiate `AOF_TriggerHandler` and call its `run()` method.
    *   **Example (`AccountTrigger.trigger`):**
        ```apex
        trigger AccountTrigger on Account (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
            new AOF_TriggerHandler(Account.SObjectType, Trigger.operationType).run();
        }
        ```

## 2. Service Layer

**Component:** `AOF_Application_Service.cls` (Interface)

*   **Purpose:** The Service Layer encapsulates business logic that is not tied to a single SObject or that orchestrates operations across multiple SObjects or layers. It handles more complex business processes, integrations with external systems, or operations that require a broader scope than a single SObject domain.
*   **Functionality:**
    *   The `AOF_Application_Service` interface defines a contract for service classes. Concrete service classes will implement this interface (or extend an abstract base service class if common service utilities are identified).
    *   **SObject-Specific or Process-Specific Service Classes** (e.g., `AOF_AccountService.cls`, `AOF_OrderFulfillmentService.cls`) contain the actual business logic.
    *   Methods within service classes are designed to be bulkified, operating on lists or maps of SObjects or other relevant data structures.
    *   Services interact with the Selector Layer to query data and with the Unit of Work Layer to register DML operations.
    *   They can call methods in other service classes or in the Domain Layer for SObject-specific logic.
    *   Services can be responsible for managing transaction control for complex operations, although DML operations themselves are preferably delegated to the Unit of Work.

## 3. Domain Layer

**Component:** `AOF_Application_Domain.cls` (Abstract Class)

*   **Purpose:** The Domain Layer represents the SObject itself and contains logic that is specific to individual records or collections of records of that SObject type. This layer is responsible for record-level business rules, validations, calculations, and manipulations that directly pertain to the state of an SObject.
*   **Functionality:**
    *   The `AOF_Application_Domain` abstract class provides a base for SObject-specific domain classes.
    *   Its constructor typically accepts `List<SObject>` (from `Trigger.new` or records to be processed) and `Map<Id, SObject>` (from `Trigger.oldMap` for update/delete contexts).
    *   **SObject-Specific Domain Classes** (e.g., `AOF_AccountDomain.cls` extending `AOF_Application_Domain`) implement the concrete logic for a particular SObject.
    *   These classes take the relevant SObject records in their constructor.
    *   They provide overrides for context-specific methods defined in `AOF_Application_Domain` (e.g., `onBeforeInsert()`, `onAfterUpdate()`, `validate()`, `calculateRollups()`).
    *   All methods within domain classes are inherently bulkified as they operate on the collection of records passed into the domain class instance.
    *   The `AOF_TriggerHandler` delegates the execution of trigger context-specific logic to these domain methods.

## 4. Selector Layer

**Component:** `AOF_Application_Selector.cls` (Abstract Class)

*   **Purpose:** The Selector Layer is responsible for all SObject querying. It centralizes SOQL queries, making them reusable, optimized, and secure.
*   **Functionality:**
    *   The `AOF_Application_Selector` abstract class provides a base for SObject-specific selector classes.
    *   It includes base methods for common query needs, dynamic field selection, ordering, and pagination (if needed).
    *   A core responsibility of this layer is to enforce security: Field-Level Security (FLS) and CRUD (Create, Read, Update, Delete) permissions. Queries should use `WITH SECURITY_ENFORCED` or results should be processed with `Security.stripInaccessible()` to ensure users only see data they are permitted to access.
    *   The base class can provide utility methods to get the SObjectType, describe field information, and build dynamic queries safely.
    *   **SObject-Specific Selector Classes** (e.g., `AOF_AccountSelector.cls` extending `AOF_Application_Selector`) encapsulate all SOQL queries for a specific SObject.
    *   Methods in these classes return `List<SObject>` or `Map<Id, SObject>` and are named descriptively based on their query criteria (e.g., `selectByIds(Set<Id> ids)`, `selectActiveAccountsByType(String type)`).
    *   Selectors are optimized for performance by querying only necessary fields and using efficient `WHERE` clauses. They are inherently bulk-safe.

## 5. Unit of Work Layer

**Component:** `AOF_Application_UnitOfWork.cls` (Class)

*   **Purpose:** The Unit of Work (UoW) Layer manages DML (Data Manipulation Language) operations. It centralizes DML calls, ensuring they are performed efficiently, in the correct order, and within Salesforce governor limits by reducing the number of DML statements.
*   **Functionality:**
    *   The `AOF_Application_UnitOfWork` class provides methods to register records for DML operations without immediately executing them (e.g., `registerNew(SObject record)`, `registerDirty(SObject record)`, `registerDeleted(SObject record)`). It supports registering single records or lists of records.
    *   A `commitWork()` method is called (typically once, at the end of a logical transaction phase, often by the `AOF_TriggerHandler` or a controlling service method) to execute all registered DML operations in a bulkified manner (e.g., one `insert` call for all registered new records).
    *   The UoW can help manage transaction boundaries and can be configured to process DML operations grouped by SObject type if a specific order of operations is critical (e.g., insert Parent__c records before Child__c records).
    *   It helps in maintaining transaction integrity. By default, DML operations are performed with `allOrNone=true`, meaning if one record fails, the entire batch for that DML statement rolls back. More granular error handling for partial success can be built in if required, but often a full rollback on error simplifies logic.

## 6. Error Handling Framework

*   **Purpose:** To provide a robust, decoupled, and customizable mechanism for logging errors and exceptions that occur within the framework or application logic.
*   **Components:**
    *   **`ErrorLogEvent__e` (Platform Event):** A custom Platform Event defined to carry error details. Using a Platform Event decouples the error logging from the main transaction, meaning the error log can be saved even if the original transaction that caused the error is rolled back.
        *   **Recommended Fields:** `Timestamp__c` (DateTime), `TransactionId__c` (Text), `OriginatingClassName__c` (Text), `OriginatingMethodName__c` (Text), `LineNumber__c` (Number), `ErrorMessage__c` (Long Text Area), `StackTrace__c` (Long Text Area), `SObjectType__c` (Text, optional), `RecordIds__c` (Text, optional, comma-separated list of Ids involved in the error), `Severity__c` (Picklist: e.g., Critical, High, Medium, Low, Info).
    *   **`Error_Log__c` (Custom SObject):** A custom SObject used to persistently store error details captured by the Platform Event.
        *   **Fields:** Mirroring the Platform Event fields, plus additional fields for tracking and management, such as `ErrorLogName` (Auto Number), `Status__c` (Picklist: New, Investigating, Resolved, Ignored), `AssignedTo__c` (User Lookup), `ResolutionNotes__c` (Long Text Area).
    *   **`AOF_ErrorHandlerService.cls` (Utility Class):**
        *   Provides static utility methods (e.g., `logError(Exception ex, String className, String methodName, List<Id> recordIds, String sObjectTypeApiName, String severity)`) to easily publish `ErrorLogEvent__e` events from anywhere in the code.
        *   This service handles the instantiation and publishing of the Platform Event, ensuring it's done correctly and efficiently.
        *   It should include its own try-catch blocks to prevent the error logging mechanism itself from throwing unhandled exceptions.
    *   **Platform Event Subscriber (e.g., `ErrorLogEventTrigger` on `ErrorLogEvent__e`):
        *   An Apex trigger that subscribes to the `ErrorLogEvent__e` events.
        *   When an event is received, this trigger creates and inserts `Error_Log__c` records in a bulkified manner.
        *   This asynchronous processing ensures that the creation of the persistent error log record does not impact the performance or governor limits of the original transaction.

This layered architecture ensures that the Apex Orbit Framework is organized, scalable, and promotes best practices in Salesforce development.
