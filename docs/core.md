# Core Components In-Depth

This section provides a more detailed look at each core component of the Apex Orbit Framework (AOF), explaining their structure, key methods, and responsibilities.

## 1. `AOF_TriggerHandler.cls`

**Purpose:** The central orchestrator for all trigger logic, ensuring a single point of entry and consistent execution flow for SObject triggers.

**Key Features & Structure:**

*   **Sharing Model:** Declared `with sharing` to enforce user record visibility.
*   **Constructor (`AOF_TriggerHandler(SObjectType sObjType, System.TriggerOperation operation)`):**
    *   Initializes with the SObjectType being processed and the current `Trigger.operationType`.
    *   Captures standard trigger context variables (`Trigger.new`, `Trigger.old`, `Trigger.newMap`, `Trigger.oldMap`).
    *   Instantiates a new `AOF_Application_UnitOfWork` instance for the current transaction.
*   **`run()` Method:**
    *   The main execution method called by the SObject-specific trigger.
    *   Checks bypass flags (`isBypassed()`).
    *   Determines the trigger context (e.g., `before insert`, `after update`).
    *   **Dispatch Logic (Conceptual - to be implemented via SObject-specific Domain instantiation):** The base `AOF_TriggerHandler` provides virtual methods for each context (e.g., `beforeInsert()`, `afterInsert()`). The `run()` method calls these. In a typical AOF implementation, the `run()` method (or these virtual methods if overridden in a more specialized base handler) would dynamically instantiate the correct SObject-specific Domain class (e.g., `AOF_AccountDomain` for `Account.SObjectType`) and invoke the corresponding method on the domain instance. For example:
        ```apex
        // Inside run() or a specific context method like beforeInsert()
        // This requires a factory or convention to get the Domain class name
        // String domainClassName = getDomainClassNameFor(this.sObjectType);
        // Type domainType = Type.forName(domainClassName);
        // if (domainType != null) {
        //     AOF_Application_Domain domainInstance = (AOF_Application_Domain) domainType.newInstance();
        //     // Need to pass records to domainInstance constructor or a setter method
        //     // Example for before insert:
        //     // domainInstance.setRecords(this.newRecords, this.oldMap); // Assuming a setter or adapting constructor
        //     // domainInstance.onBeforeInsert(); 
        // }
        ```
        The provided `AOF_TriggerHandler.cls` directly calls its own virtual methods like `this.beforeInsert()`. A concrete implementation would involve creating an SObject-specific domain class instance (e.g., `new AOF_AccountDomain(this.newRecords, this.oldMap).onBeforeInsert();`) within these virtual methods or directly in the `run()` method based on `sObjectType`.
    *   Calls `uow.commitWork()` after all `after` context logic is complete and if no fatal errors (checked by `hasFatalErrors()`) are present.
    *   Includes a global try-catch block to log any unhandled exceptions using `AOF_ErrorHandlerService`.
*   **Context-Specific Virtual Methods (`beforeInsert()`, `afterInsert()`, etc.):**
    *   These are placeholders intended to be the primary integration points for SObject-specific logic. The `AOF_TriggerHandler` itself calls these. The expectation is that developers will either:
        1.  Create a more specific base handler that overrides these to instantiate and call the correct SObject Domain class methods.
        2.  Modify the `run()` method or these virtual methods to include a dispatch mechanism (e.g., a map of SObjectType to Domain class Type) to instantiate and call the appropriate SObject Domain class (e.g., `AOF_AccountDomain`).
*   **Bypass Mechanism:**
    *   `bypass(SObjectType sObjType)`: Sets a bypass for a specific SObjectType.
    *   `clearBypass(SObjectType sObjType)`: Clears a bypass for a specific SObjectType.
    *   `isBypassed(SObjectType sObjType)`: Checks if a specific SObjectType is bypassed.
    *   `bypassAllTriggers()`: Sets a global bypass for all triggers using AOF.
    *   `clearBypassAllTriggers()`: Clears the global bypass.
    *   These are static methods allowing bypass control from other Apex code (e.g., test setup, data load scripts).
*   **Utility Methods:**
    *   `getRecordIdsFromContext()`: Collects record Ids from `Trigger.new` or `Trigger.old` for error logging.
    *   `getUnitOfWork()`: Provides access to the `AOF_Application_UnitOfWork` instance for the current transaction, allowing Domain or Service layers to register DML.
    *   `getClassName()`: Helper to get the actual class name for logging.
    *   `hasFatalErrors()`: Checks if `addError()` has been called on any records in `Trigger.new` during `before` contexts, which can be used to prevent `uow.commitWork()`.

## 2. `AOF_Application_Domain.cls`

**Purpose:** An abstract base class for SObject-specific domain logic. Domain classes encapsulate business rules, validations, and calculations directly related to an SObject.

**Key Features & Structure:**

*   **Sharing Model:** Declared `with sharing`.
*   **Protected Variables:**
    *   `records` (List<SObject>): Typically `Trigger.new`.
    *   `oldMap` (Map<Id, SObject>): Typically `Trigger.oldMap`.
    *   `newMap` (Map<Id, SObject>): A map representation of `records` (`Trigger.newMap`).
    *   `sObjectType` (SObjectType): The SObjectType being processed.
*   **Constructors:**
    *   `AOF_Application_Domain(List<SObject> newRecords, Map<Id, SObject> oldRecordsMap)`: Primary constructor for most trigger contexts.
    *   `AOF_Application_Domain(Map<Id, SObject> oldRecordsMap, SObjectType sObjType)`: Constructor for delete contexts or scenarios where only `oldMap` is relevant. Requires explicit `SObjectType`.
*   **Virtual Trigger Context Methods (`onBeforeInsert()`, `onAfterInsert()`, etc.):**
    *   Abstract or virtual methods that concrete SObject-specific domain classes (e.g., `AOF_AccountDomain`) will override to implement their logic for each trigger event.
*   **Common Utility Methods:**
    *   `getOldValue(Id recordId, SObjectField field)`: Retrieves a field value from the `oldMap` for a given record ID.
    *   `fieldHasChanged(Id recordId, SObjectField field)`: Checks if a specific field value has changed between `oldMap` and `newMap` for a given record ID.
    *   `addError(SObject record, String errorMessage)`: Adds an SObject-level error to a record.
    *   `addError(SObject record, SObjectField field, String errorMessage)`: Adds a field-specific error to a record. (Note: The implementation in the provided base class for field-specific errors has a slight issue; `record.SObject.getSObjectType()` should be `record.getSObjectType()`. It should be `record.getSObject(field).addError(errorMessage)` or more directly `record.addError(field, errorMessage)` if the API version supports it, or use the describe approach correctly for the field on the specific record instance.) A simpler and more direct way is `record.addError(fieldApiNameString, errorMessage)` or `sObj.getSObjectField(fieldToken).addError(message)` if you have the field token.

## 3. `AOF_Application_Selector.cls`

**Purpose:** An abstract base class for SObject-specific selector classes. Selectors are responsible for all SOQL queries, promoting reusability, optimization, and security.

**Key Features & Structure:**

*   **Sharing Model:** Typically declared `with sharing` (as in the example `AOF_AccountSelector`).
*   **Protected Variables:**
    *   `sObjectType` (SObjectType): The SObjectType this selector is for.
    *   `fieldsToQuery` (List<String>): A list of field API names to be included in queries. This can be dynamically built.
*   **Constructor (`AOF_Application_Selector(SObjectType sObjType)`):**
    *   Initializes the selector with its SObjectType.
    *   Often includes logic to build a default list of queryable fields for the SObject, respecting FLS.
*   **Core Querying Methods (Examples from `AOF_AccountSelector`):**
    *   `selectByIds(Set<Id> ids)`: Selects records by a set of Ids.
    *   `selectById(Id recordId)`: Selects a single record by Id.
    *   Concrete selector classes will implement various methods specific to their SObject query needs (e.g., `selectActiveAccountsByType(String type)`).
*   **Security Enforcement:**
    *   Queries should use `WITH SECURITY_ENFORCED` to respect FLS and object permissions.
    *   Alternatively, `Security.stripInaccessible()` can be used on query results.
    *   The base selector can provide helper methods to check field accessibility (`isAccessible()`, `isQueryable()`).
*   **Dynamic Query Building:**
    *   The base class can provide utilities for safely building dynamic SOQL queries, ensuring only accessible fields are included and bind variables are used.
*   **Field Management:**
    *   `getFields()`: Returns the list of fields to query.
    *   `includeFields(List<String> fieldNames)`: Adds additional fields to the query list, checking for FLS.

## 4. `AOF_Application_Service.cls` (Interface)

**Purpose:** Defines a contract for service layer classes. Service classes encapsulate business logic that may span multiple SObjects, involve complex operations, or orchestrate calls to other layers.

**Key Features & Structure:**

*   **Interface:** This is an `interface` and does not contain concrete implementations.
*   **Method Signatures:** It would declare method signatures that concrete service classes must implement. These methods represent specific business operations.
    *   Example: `void processOrder(Id orderId);`, `List<SObject> findRelatedOpportunities(Set<Id> accountIds);`
*   **No Sharing Keyword:** Interfaces themselves do not have sharing keywords; the implementing class declares its sharing behavior.
*   **Concrete Service Classes (e.g., `AOF_AccountService.cls`):**
    *   Implement `AOF_Application_Service` (or a more specific service interface).
    *   Declare their own sharing model (`with sharing` or `without sharing` based on their purpose).
    *   Contain methods that perform business logic, often interacting with Selector classes for data and Unit of Work for DML.

## 5. `AOF_Application_UnitOfWork.cls`

**Purpose:** Manages DML operations to ensure they are performed efficiently, in the correct order, and within governor limits by centralizing and bulkifying DML statements.

**Key Features & Structure:**

*   **Sharing Model:** Typically `with sharing` as it operates on records within the user's context.
*   **Internal Record Storage:** Uses private maps to store records registered for different DML operations (insert, update, delete), categorized by SObjectType.
    *   `recordsToInsertBySObjectType` (Map<SObjectType, List<SObject>>)
    *   `recordsToUpdateBySObjectType` (Map<SObjectType, List<SObject>>)
    *   `recordsToDeleteBySObjectType` (Map<SObjectType, List<SObject>>)
*   **Registration Methods:**
    *   `registerNew(SObject record)` / `registerNew(List<SObject> records)`
    *   `registerDirty(SObject record)` / `registerDirty(List<SObject> records)`
    *   `registerDeleted(SObject record)` / `registerDeleted(List<SObject> records)`
    *   These methods add records to the appropriate internal map without performing immediate DML.
*   **`commitWork()` Method:**
    *   The core method that executes all registered DML operations.
    *   Iterates through the internal maps and performs DML for each SObjectType in a bulkified manner (e.g., `Database.insert(allNewAccounts, true)`).
    *   The order of DML operations (inserts, then updates, then deletes) is generally followed, but can be customized if needed (e.g., by processing SObjectTypes in a specific sequence).
    *   Uses `Database` methods (e.g., `Database.insert`) with `allOrNone=true` by default, meaning if one record in a batch fails, the entire DML operation for that batch rolls back. This can be changed to `false` to allow partial success, but requires careful handling of `Database.SaveResult` or `Database.DeleteResult`.
*   **Error Handling:** The `commitWork` method itself should be wrapped in a try-catch. If a DML exception occurs, it should ideally be logged via `AOF_ErrorHandlerService` and potentially re-thrown to ensure the transaction rolls back.

## 6. `AOF_ErrorHandlerService.cls`

**Purpose:** A utility class providing static methods to publish `ErrorLogEvent__e` platform events for robust and decoupled error logging.

**Key Features & Structure:**

*   **Sharing Model:** Can be `without sharing` to ensure errors can always be logged, but be mindful of data passed into it.
*   **Static Methods:**
    *   `logError(Exception ex, String className, String methodName, List<Id> recordIds, String sObjectTypeApiName, String severity)`: The primary method for logging errors.
    *   `logError(String message, String className, String methodName, List<Id> recordIds, String sObjectTypeApiName, String severity)`: For logging custom error messages without an exception object.
*   **Functionality:**
    *   Constructs an `ErrorLogEvent__e` platform event instance, populating its fields with details from the parameters (exception message, stack trace, class/method origin, involved records, severity, etc.).
    *   Publishes the platform event using `EventBus.publish()`.
    *   Includes its own try-catch block around the `EventBus.publish()` call. If publishing the platform event itself fails (e.g., due to limits or misconfiguration), it should handle this gracefully (e.g., by logging to `System.debug` as a last resort) to prevent the error logging mechanism from causing further unhandled exceptions.
*   **Decoupling:** Publishing a platform event decouples the error logging from the main transaction. The actual creation of the persistent `Error_Log__c` record is handled by an asynchronous subscriber trigger (`ErrorLogEventSubscriber.trigger`).

Understanding these core components and their interactions is key to effectively using and extending the Apex Orbit Framework.
