# Apex Orbit Framework (AOF) - Comprehensive Documentation

## Table of Contents
* [Core Principles](CorePrinciples.md)
* [Framework Architecture and Layers](Architecture.md)
    *   [3.1. Trigger Handler Layer](Architecture.md#1-trigger-handler-layer)
    *   [3.2. Service Layer](Architecture.md#2-service-layer)
    *   [3.3. Domain Layer](Architecture.md#3-domain-layer)
    *   [3.4. Selector Layer](Architecture.md#4-selector-layer)
    *   [3.5. Unit of Work Layer](Architecture.md#5-unit-of-work-layer)
    *   [3.6. Error Handling Framework](Architecture.md#6-error-handling-framework)
* [Trigger Execution Flow](#4-trigger-execution-flow)
* [Scalability and Performance](#5-scalability-and-performance)
* [Security Considerations](#6-security-considerations)
* [Setup and Installation Guide](#7-setup-and-installation-guide)
* [Core Components In-Depth](#8-core-components-in-depth)
* [Usage Guide and Examples](#9-usage-guide-and-examples)
* [Error Handling In-Depth](#10-error-handling-in-depth)
* [Best Practices](#11-best-practices)
* [Customization and Extension](#12-customization-and-extension)
* [Glossary](#13-glossary)
* [References](References.md)


## 4. Trigger Execution Flow

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

## 5. Scalability and Performance

The Apex Orbit Framework (AOF) is designed with scalability and performance as primary considerations, especially for Salesforce organizations with a large user base (10,000+) and significant data volumes. Key aspects contributing to this are:

*   **Strict Bulkification:** Every layer of the framework, from the `AOF_TriggerHandler` to Domain, Service, and Selector classes, is designed to operate on collections of records (e.g., `List<SObject>`, `Map<Id, SObject>`). This is fundamental to avoiding governor limit exceptions related to DML statements, SOQL queries, and CPU time in a bulk processing context.
*   **Selective and Efficient Queries:**
    *   The Selector Layer promotes writing selective SOQL queries by encouraging the use of specific `WHERE` clauses and querying only the necessary fields required by the business logic. This reduces database load and improves query performance.
    *   The `AOF_Application_Selector` base class provides utilities to build field lists dynamically while respecting FLS, ensuring only accessible and queryable fields are included.
*   **Optimized Looping and Data Handling:**
    *   The framework design discourages SOQL queries or DML statements inside loops, a common cause of governor limit issues.
    *   Efficient use of `Map` collections is encouraged for accessing related data or comparing old and new record values, which significantly improves processing time for large datasets.
*   **Centralized DML with Unit of Work:** The `AOF_Application_UnitOfWork` component aggregates all DML operations and executes them in a minimal number of statements (e.g., one `insert` for all new records of a type). This drastically reduces DML statement consumption, a critical governor limit.
*   **Asynchronous Processing for Large Tasks:**
    *   The Service Layer is the appropriate place to orchestrate asynchronous operations (Batch Apex, Queueable Apex, Future methods) for processes that are too large, too long-running, or might consume excessive resources if run synchronously. This helps in offloading heavy processing and improving responsiveness for users.
    *   The error handling mechanism, utilizing Platform Events, is inherently asynchronous, ensuring that logging errors does not impact the performance of the primary transaction.
*   **Efficient Trigger Management:** The single trigger per SObject pattern, combined with the `AOF_TriggerHandler`, provides a streamlined and efficient way to manage trigger execution. It avoids the complexities and potential performance issues of multiple triggers on the same SObject vying for execution order or repeating logic.
*   **Custom Settings and Metadata for Configuration:** The framework encourages the use of Custom Settings or Custom Metadata Types for configurable parameters such as bypass flags, operational thresholds, feature toggles, or endpoint URLs. This allows for administrative control and modification of behavior without code changes, enhancing flexibility and maintainability.
*   **Governor Limit Awareness and Monitoring:** While the framework is designed to operate well within governor limits, the integrated error logging (via `AOF_ErrorHandlerService`) can capture and log limit exceptions if they occur. This provides valuable diagnostic information for identifying and addressing performance bottlenecks in complex implementations.
*   **Lightweight Design:** AOF avoids unnecessary overhead and complexity, focusing on providing a lean yet powerful set of tools. This contributes to better overall performance as there are fewer layers of abstraction or heavy objects to instantiate and manage for simple operations.

By adhering to these principles, AOF provides a robust foundation that can scale with the evolving needs of a large Salesforce organization, ensuring efficient processing and optimal performance.

## 6. Security Considerations

Security is a critical aspect of any Salesforce application. The Apex Orbit Framework (AOF) incorporates security best practices and provides mechanisms to help developers build secure applications.

*   **CRUD/FLS Enforcement (Selector Layer):**
    *   The Selector Layer is primarily responsible for enforcing Create, Read, Update, Delete (CRUD) and Field-Level Security (FLS) permissions.
    *   All SOQL queries executed through SObject-specific Selector classes (extending `AOF_Application_Selector`) should use the `WITH SECURITY_ENFORCED` clause in SOQL to ensure that queries only return records and fields the running user has access to. This is the recommended approach for FLS and object-level security enforcement on queries.
    *   Alternatively, or as a supplementary measure, results from queries can be processed using `Security.stripInaccessible()` before being returned or used. This method removes fields from SObject lists that the user cannot access.
    *   The `AOF_Application_Selector` base class provides helper methods to check field accessibility (`isAccessible()`, `isQueryable()`, `isUpdateable()`, `isCreateable()`) when dynamically building queries or processing results.
*   **Sharing Rules and Record Visibility (`with sharing` / `without sharing`):**
    *   Apex classes in AOF should explicitly declare their sharing behavior using `with sharing`, `without sharing`, or `inherited sharing` keywords.
    *   **`AOF_TriggerHandler`, `AOF_Application_Domain`, and SObject-specific Domain classes** typically run in the user's context and should generally be declared `with sharing` to respect the user's record visibility and sharing rules. This ensures that business logic operates only on data the user is supposed to see and modify.
    *   **`AOF_Application_Selector` and SObject-specific Selector classes** should also generally be declared `with sharing` to ensure that queries respect the user's data visibility.
    *   **`AOF_Application_Service` and concrete Service classes** sharing declaration depends on the nature of the service. If a service performs operations on behalf of a user, `with sharing` is appropriate. If a service needs to perform privileged operations across a wider set of data (e.g., system-level rollups or integrations), `without sharing` might be necessary, but this should be used judiciously and with a clear understanding of the security implications. Always document the reason for using `without sharing`.
    *   **`AOF_ErrorHandlerService`** and the Platform Event subscriber trigger for error logging might operate in a system context (`without sharing`) to ensure errors can always be logged, regardless of the running user's permissions on the `Error_Log__c` object. However, the data being logged should be carefully considered to avoid exposing sensitive information in logs if the running user didn't have access to it.
*   **Input Validation:**
    *   While Apex and the Salesforce platform provide strong typing and some built-in protections, it's crucial to validate inputs, especially those coming from user interfaces (Lightning Web Components, Aura, Visualforce pages) or external API calls before they are used in business logic, SOQL queries, or DML operations.
    *   The Service Layer is often a good place to perform such validation for complex inputs or business rule checks that go beyond simple data type validation.
    *   Domain layer methods (e.g., `onBeforeInsert`, `onBeforeUpdate`) are also critical for enforcing record-level validation rules using `addError()`.
*   **SOQL Injection Prevention:**
    *   AOF promotes the use of static SOQL queries or parameterized dynamic SOQL queries to prevent SOQL injection vulnerabilities.
    *   The Selector Layer encapsulates SOQL query construction. When building dynamic queries within Selector methods, always use `String.escapeSingleQuotes()` for any user-supplied input that is incorporated into the query string and bind variables wherever possible.
    *   Avoid directly concatenating unescaped user input into SOQL queries.
*   **Secure DML Operations:**
    *   The Unit of Work layer centralizes DML. Before registering records for DML, ensure that the data has been properly validated and that the running user has the necessary permissions (implicitly handled if the preceding logic runs `with sharing` and FLS checks were performed on data retrieval and modification).
*   **Protecting Sensitive Data in Logs:**
    *   When using the `AOF_ErrorHandlerService`, be mindful of not logging overly sensitive information (e.g., PII, financial details, access tokens) in the `Error_Log__c` records or Platform Events, especially if these logs are accessible to a broader audience than the user who experienced the error.
    *   Consider implementing a mechanism to mask or omit sensitive data from error messages or stack traces if necessary.
*   **Bypass Mechanism Security:**
    *   The trigger bypass mechanism (`AOF_TriggerHandler.bypassAllTriggers` or per-object bypass) should be protected. Access to modify bypass flags (e.g., via Custom Settings or other administrative controls) should be restricted to authorized administrators to prevent unauthorized disabling of critical business logic.
*   **Regular Security Reviews:**
    *   Code developed using AOF should undergo regular security reviews to identify and mitigate potential vulnerabilities, just like any other Apex code.

By embedding these security considerations into its design and promoting their use, AOF helps developers build more secure and robust Salesforce applications.

---




## 7. Setup and Installation Guide

Setting up the Apex Orbit Framework (AOF) in your Salesforce organization involves deploying its core components and configuring the necessary custom objects and platform events for error handling. This guide assumes you are familiar with Salesforce deployment tools such as Salesforce DX (SFDX), Ant Migration Tool, or Change Sets.

### Prerequisites

*   **Salesforce Org:** A Salesforce Developer Edition, Sandbox, or Enterprise Edition (or similar) org where you have administrative and deployment permissions.
*   **Deployment Tool:** Your preferred Salesforce deployment tool (SFDX CLI is recommended for modern development).
*   **Understanding of Apex and Salesforce Metadata:** Basic knowledge of Apex classes, triggers, custom objects, and platform events.

### Components to Deploy

The core AOF consists of the following Apex classes and metadata components that need to be deployed to your Salesforce org:

1.  **Core Apex Classes:**
    *   `AOF_TriggerHandler.cls`
    *   `AOF_Application_Domain.cls`
    *   `AOF_Application_Selector.cls`
    *   `AOF_Application_Service.cls` (Interface)
    *   `AOF_Application_UnitOfWork.cls`
    *   `AOF_ErrorHandlerService.cls`

2.  **Error Handling Metadata:**
    *   **Platform Event:** `ErrorLogEvent__e`
        *   **Fields (Recommended):**
            *   `Timestamp__c` (DateTime, Required)
            *   `TransactionId__c` (Text(255), Optional)
            *   `OriginatingClassName__c` (Text(255), Required)
            *   `OriginatingMethodName__c` (Text(255), Required)
            *   `LineNumber__c` (Number(10, 0), Optional)
            *   `ErrorMessage__c` (Long Text Area(131072), Required)
            *   `StackTrace__c` (Long Text Area(131072), Optional)
            *   `SObjectType__c` (Text(255), Optional)
            *   `RecordIds__c` (Long Text Area(10000), Optional) - Store comma-separated Ids
            *   `Severity__c` (Text(50), Required) - e.g., Critical, High, Medium, Low, Info
    *   **Custom SObject:** `Error_Log__c`
        *   **Label:** Error Log
        *   **Plural Label:** Error Logs
        *   **API Name:** `Error_Log__c`
        *   **Fields (to mirror Platform Event and add tracking):**
            *   `ErrorLogName` (Auto Number, e.g., `EL-{00000}`)
            *   `Timestamp__c` (DateTime, Required)
            *   `TransactionId__c` (Text(255), Optional, Indexed)
            *   `OriginatingClassName__c` (Text(255), Required, Indexed)
            *   `OriginatingMethodName__c` (Text(255), Required)
            *   `LineNumber__c` (Number(10, 0), Optional)
            *   `ErrorMessage__c` (Long Text Area(131072), Required)
            *   `StackTrace__c` (Long Text Area(131072), Optional)
            *   `SObjectType__c` (Text(255), Optional, Indexed)
            *   `RecordIds__c` (Long Text Area(10000), Optional)
            *   `Severity__c` (Picklist, Required) - Values: Critical, High, Medium, Low, Info
            *   `Status__c` (Picklist, Default: New) - Values: New, Investigating, Resolved, Ignored
            *   `AssignedTo__c` (Lookup(User), Optional)
            *   `ResolutionNotes__c` (Long Text Area(32768), Optional)
    *   **Apex Trigger for Platform Event:** `ErrorLogEventSubscriber.trigger` (or a similar name) on `ErrorLogEvent__e`.
        *   This trigger will subscribe to `ErrorLogEvent__e` and create `Error_Log__c` records.
        ```apex
        trigger ErrorLogEventSubscriber on ErrorLogEvent__e (after insert) {
            List<Error_Log__c> logsToCreate = new List<Error_Log__c>();
            for (ErrorLogEvent__e event : Trigger.New) {
                Error_Log__c log = new Error_Log__c(
                    Timestamp__c = event.Timestamp__c,
                    TransactionId__c = event.TransactionId__c,
                    OriginatingClassName__c = event.OriginatingClassName__c,
                    OriginatingMethodName__c = event.OriginatingMethodName__c,
                    LineNumber__c = event.LineNumber__c,
                    ErrorMessage__c = event.ErrorMessage__c,
                    StackTrace__c = event.StackTrace__c,
                    SObjectType__c = event.SObjectType__c,
                    RecordIds__c = event.RecordIds__c,
                    Severity__c = event.Severity__c,
                    Status__c = 'New' // Default status
                );
                logsToCreate.add(log);
            }
            if (!logsToCreate.isEmpty()) {
                // Consider error handling for DML on Error_Log__c itself, though it should be rare.
                // Using Database.insert with allOrNone=false can log partial successes if needed.
                Database.insert(logsToCreate, false); 
            }
        }
        ```

3.  **Example SObject Components (Optional, for reference):**
    *   `AOF_AccountSelector.cls`
    *   `AOF_AccountDomain.cls`
    *   `AccountTrigger.trigger`

### Deployment Steps (Using SFDX as an Example)

1.  **Organize Project Structure:**
    Ensure your project directory is structured correctly for SFDX. The core classes, platform event, custom object, and event trigger should be in their respective metadata folders (e.g., `force-app/main/default/classes/`, `force-app/main/default/platformEvents/`, `force-app/main/default/objects/`, `force-app/main/default/triggers/`).

    A conceptual directory structure:
    ```
    your-sfdx-project/
        force-app/main/default/
            classes/
                AOF_TriggerHandler.cls
                AOF_TriggerHandler.cls-meta.xml
                AOF_Application_Domain.cls
                AOF_Application_Domain.cls-meta.xml
                AOF_Application_Selector.cls
                AOF_Application_Selector.cls-meta.xml
                AOF_Application_Service.cls
                AOF_Application_Service.cls-meta.xml
                AOF_Application_UnitOfWork.cls
                AOF_Application_UnitOfWork.cls-meta.xml
                AOF_ErrorHandlerService.cls
                AOF_ErrorHandlerService.cls-meta.xml
                // Example Account classes (optional)
                AOF_AccountSelector.cls
                AOF_AccountSelector.cls-meta.xml
                AOF_AccountDomain.cls
                AOF_AccountDomain.cls-meta.xml
            triggers/
                ErrorLogEventSubscriber.trigger
                ErrorLogEventSubscriber.trigger-meta.xml
                // Example Account trigger (optional)
                AccountTrigger.trigger
                AccountTrigger.trigger-meta.xml
            platformEvents/
                ErrorLogEvent__e.platformEvent-meta.xml
            objects/
                Error_Log__c/
                    fields/
                        Timestamp__c.field-meta.xml
                        // ... other Error_Log__c fields
                    Error_Log__c.object-meta.xml
            // layouts, tabs, permissionsets (optional, for Error_Log__c management)
    ```

2.  **Define `ErrorLogEvent__e` Platform Event:**
    Create the `ErrorLogEvent__e.platformEvent-meta.xml` file with the field definitions as specified above. Ensure the `publishBehavior` is set to `PublishAfterCommit` (default) or `PublishImmediately` based on your requirements (PublishAfterCommit is generally safer).

3.  **Define `Error_Log__c` Custom Object:**
    Create the directory structure and XML files for the `Error_Log__c` custom object and its fields as detailed in the "Components to Deploy" section.

4.  **Create Apex Classes and Triggers:**
    Place the `.cls` and `.trigger` files (along with their corresponding `-meta.xml` files) in the `classes` and `triggers` directories.

5.  **Authorize Your Org and Deploy:**
    Use the SFDX CLI to authorize your target Salesforce org and deploy the components.
    ```bash
    # Authorize your org (if not already done)
    sfdx auth:web:login --setalias YourOrgAlias

    # Deploy the source code and metadata
    sfdx project deploy start --target-org YourOrgAlias
    ```
    Alternatively, if you have specific components in a package.xml:
    ```bash
    sfdx project deploy start --manifest path/to/your/package.xml --target-org YourOrgAlias
    ```

### Post-Deployment Configuration

1.  **Permissions for `Error_Log__c`:**
    *   Ensure relevant user profiles or permission sets have **Create** and **Read** access to the `Error_Log__c` object and its fields. Administrators or support personnel might need **Edit** and **Delete** permissions as well.
    *   The user context under which the `ErrorLogEventSubscriber.trigger` runs will need create permission on `Error_Log__c`. Platform Event triggers run as the `Automated Process` user by default, which usually has broad permissions, but it's good to be aware.

2.  **Platform Event Subscriber Status:**
    *   After deployment, the `ErrorLogEventSubscriber.trigger` should be active. You can verify its status in Setup under "Platform Event Triggers".

3.  **Tab and Layout for `Error_Log__c` (Optional):**
    *   For easier management of error logs, consider creating a Custom Tab for the `Error_Log__c` object and configuring its page layout.

4.  **Testing the Error Handling:**
    *   Intentionally cause an error in a test class or an anonymous Apex script that uses `AOF_ErrorHandlerService.logError(...)`.
    *   Verify that an `ErrorLogEvent__e` is published (can be checked via Streaming Monitor or Apex tests that publish events).
    *   Verify that a corresponding `Error_Log__c` record is created.

### Using the Framework

Once deployed and configured, you can start using the AOF by:

1.  Creating SObject-specific triggers that delegate to `AOF_TriggerHandler`.
2.  Developing SObject-specific Domain classes (extending `AOF_Application_Domain`) to house your record-level business logic.
3.  Developing SObject-specific Selector classes (extending `AOF_Application_Selector`) for all your SOQL queries.
4.  Optionally, creating Service classes (implementing `AOF_Application_Service`) for more complex, cross-object business logic.
5.  Using `AOF_Application_UnitOfWork` within your Domain or Service classes to manage DML operations.
6.  Calling `AOF_ErrorHandlerService.logError(...)` within your catch blocks to log exceptions.

Refer to the "Usage Guide and Examples" section for detailed instructions on how to build out these components for your SObjects.

---




## 8. Core Components In-Depth

This section provides a more detailed look at each core component of the Apex Orbit Framework (AOF), explaining their structure, key methods, and responsibilities.

### 8.1. `AOF_TriggerHandler.cls`

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

### 8.2. `AOF_Application_Domain.cls`

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

### 8.3. `AOF_Application_Selector.cls`

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

### 8.4. `AOF_Application_Service.cls` (Interface)

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

### 8.5. `AOF_Application_UnitOfWork.cls`

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

### 8.6. `AOF_ErrorHandlerService.cls`

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

---




## 9. Usage Guide and Examples

This section provides practical examples of how to use the Apex Orbit Framework (AOF) to implement business logic for a specific SObject. We will use the `Account` SObject as an example, building upon the `AOF_AccountSelector.cls`, `AOF_AccountDomain.cls`, and `AccountTrigger.trigger` components that might have been provided as part of the framework examples.

### 9.1. Setting up a New SObject with AOF

To integrate a new SObject (e.g., `Contact`) with AOF, you would typically create the following components:

1.  **Trigger:** `ContactTrigger.trigger`
2.  **Domain Class:** `AOF_ContactDomain.cls` (extending `AOF_Application_Domain`)
3.  **Selector Class:** `AOF_ContactSelector.cls` (extending `AOF_Application_Selector`)
4.  **Service Class (Optional):** `AOF_ContactService.cls` (implementing `AOF_Application_Service` or a more specific interface if needed for complex, cross-object logic).

### 9.2. Example: Implementing Logic for the Account SObject

Let's walk through an example for the `Account` SObject.

#### 9.2.1. Account Trigger (`AccountTrigger.trigger`)

As per the AOF pattern, the trigger itself is minimal and delegates to `AOF_TriggerHandler`.

```apex
// File: /home/ubuntu/AccountTrigger.trigger
trigger AccountTrigger on Account (
    before insert, after insert,
    before update, after update,
    before delete, after delete,
    after undelete
) {
    // Instantiate the generic trigger handler, passing the SObjectType and the trigger operation.
    AOF_TriggerHandler handler = new AOF_TriggerHandler(Account.SObjectType, Trigger.operationType);
    
    // Execute the handler logic
    handler.run();
}
```

**Note on `AOF_TriggerHandler` Dispatch:** The base `AOF_TriggerHandler` provided calls its own virtual methods (e.g., `this.beforeInsert()`). For this to work with `AOF_AccountDomain`, the `AOF_TriggerHandler`'s context-specific methods (or its `run` method) need to be adapted to instantiate and call the correct SObject Domain class. A common pattern is to use a factory or naming convention.

**Modified `AOF_TriggerHandler` (Conceptual Dispatch within virtual methods):**

One way to make the `AOF_TriggerHandler` truly generic and dispatch to SObject-specific domain classes is to modify its virtual context methods. For example, the `beforeInsert()` method in `AOF_TriggerHandler` could be modified or be part of a more sophisticated dispatch in the `run` method:

```apex
// Inside AOF_TriggerHandler.cls (Conceptual modification for dispatch)
// This is a simplified example; a robust solution might use a map or custom metadata for class resolution.
protected override void beforeInsert() {
    if (this.sObjectType == Account.SObjectType) {
        new AOF_AccountDomain(this.newRecords, this.oldMap).onBeforeInsert();
    } else if (this.sObjectType == Contact.SObjectType) {
        // new AOF_ContactDomain(this.newRecords, this.oldMap).onBeforeInsert();
    }
    // ... other SObjects
}
// Similar overrides for afterInsert, beforeUpdate, etc.
```
This dynamic instantiation based on `sObjectType` is crucial for the handler to correctly delegate to the specific domain logic (e.g., `AOF_AccountDomain`, `AOF_ContactDomain`). The `AOF_TriggerHandler` provided earlier will need this type of dispatch logic added to its virtual methods or its `run()` method to correctly call the SObject-specific domain classes like `AOF_AccountDomain`.

#### 9.2.2. Account Domain Class (`AOF_AccountDomain.cls`)

This class contains Account-specific business logic.

```apex
// File: /home/ubuntu/AOF_AccountDomain.cls
/**
 * @description Domain class for the Account SObject.
 * Contains SObject-specific logic for Accounts, such as validation rules or complex calculations.
 * Part of the Apex Orbit Framework (AOF).
 */
public with sharing class AOF_AccountDomain extends AOF_Application_Domain {

    public AOF_AccountDomain(List<Account> newRecords, Map<Id, Account> oldRecordsMap) {
        super(newRecords, oldRecordsMap);
    }

    public AOF_AccountDomain(Map<Id, Account> oldRecordsMap) {
        super(oldRecordsMap, Account.SObjectType); // Explicitly pass SObjectType for delete context
    }

    public override void onBeforeInsert() {
        List<Account> accountsToProcess = (List<Account>) this.records;
        for (Account acc : accountsToProcess) {
            // Example 1: Set a default description if it's blank
            if (String.isBlank(acc.Description)) {
                acc.Description = Account.SObjectType.getDescribe().getLabel() + " created via AOF Framework";
            }

            // Example 2: Validation - Ensure all new accounts have a Name
            if (String.isBlank(acc.Name)) {
                // Using the addError utility from AOF_Application_Domain
                // For field-specific error: addError(acc, Account.Name, "Account Name cannot be blank.");
                // For record-level error if field token not readily available or general error:
                acc.addError("Account Name cannot be blank (Record Level Error).");
            }

            // Example 3: Set a default value for a custom field if not provided
            // Assuming Active__c is a Picklist(Yes/No) or Checkbox
            // if (acc.Active__c == null) { 
            //     acc.Active__c = "Yes"; // Or true for a checkbox
            // }
        }
    }

    public override void onAfterInsert() {
        System.debug("AOF_AccountDomain: onAfterInsert called for " + this.records.size() + " accounts.");
        // Example: Create a follow-up Task for each new Account using UnitOfWork
        // This part requires the AOF_TriggerHandler to provide access to its UoW instance.
        // For this example, we'll assume UoW is obtained via a context or passed in.
        // See section 9.2.4 for a more detailed UoW example.
    }

    public override void onBeforeUpdate() {
        List<Account> updatedAccounts = (List<Account>) this.records;
        // oldMap is already available as this.oldMap from the base class constructor

        for (Account updatedAcc : updatedAccounts) {
            Account oldAcc = (Account)this.oldMap.get(updatedAcc.Id);

            // Example 1: Prevent updates to the AccountNumber field if it already has a value and is being changed.
            if (String.isNotBlank(oldAcc.AccountNumber) && updatedAcc.AccountNumber != oldAcc.AccountNumber) {
                updatedAcc.AccountNumber.addError("Account Number cannot be changed once set.");
            }

            // Example 2: If Industry changes from X to Y, update another field.
            // Using the fieldHasChanged utility from AOF_Application_Domain
            if (fieldHasChanged(updatedAcc.Id, Account.Industry)) {
                if (updatedAcc.Industry == "Technology" && oldAcc.Industry == "Agriculture") {
                    updatedAcc.Rating = "Hot"; // Example dependent field update
                }
            }
        }
    }

    public override void onAfterUpdate() {
        System.debug("AOF_AccountDomain: onAfterUpdate called for " + this.records.size() + " accounts.");
        // Example: If SLA Expiration Date changes, log a message or call a service
        for (SObject sObj : this.records) {
            Account updatedAcc = (Account)sObj;
            // Assuming SLAExpirationDate__c is a field on Account
            // if (fieldHasChanged(updatedAcc.Id, Account.SLAExpirationDate__c)) { 
            //     System.debug("SLA Expiration Date changed for Account: " + updatedAcc.Name + ".");
            //     // Potentially call: new AOF_NotificationService().notifySlaChange(updatedAcc.Id, updatedAcc.SLAExpirationDate__c);
            // }
        }
    }

    public override void onBeforeDelete() {
        // oldMap is available as this.oldMap
        System.debug("AOF_AccountDomain: onBeforeDelete called for " + this.oldMap.size() + " accounts.");
        // Example: Prevent deletion if Account has open Opportunities.
        // This requires querying Opportunities, so we'd use AOF_OpportunitySelector.

        Set<Id> accountIdsToDelete = this.oldMap.keySet();
        // AOF_OpportunitySelector oppSelector = new AOF_OpportunitySelector();
        // List<Opportunity> openOpps = oppSelector.selectOpenOpportunitiesForAccounts(accountIdsToDelete);
        
        // Map<Id, List<Opportunity>> openOppsByAccountId = new Map<Id, List<Opportunity>>();
        // for(Opportunity opp : openOpps){
        //     if(!openOppsByAccountId.containsKey(opp.AccountId)){
        //         openOppsByAccountId.put(opp.AccountId, new List<Opportunity>());
        //     }
        //     openOppsByAccountId.get(opp.AccountId).add(opp);
        // }

        // for (Id accId : accountIdsToDelete) {
        //     if (openOppsByAccountId.containsKey(accId) && !openOppsByAccountId.get(accId).isEmpty()) {
        //          ((Account)this.oldMap.get(accId)).addError("Cannot delete Account with open Opportunities.");
        //     }
        // }
        // The actual query and selector instantiation would be needed here.
    }

    // Other methods like onAfterDelete, onUndelete can be implemented similarly.
}
```

#### 9.2.3. Account Selector Class (`AOF_AccountSelector.cls`)

This class handles all SOQL queries for Accounts.

```apex
// File: /home/ubuntu/AOF_AccountSelector.cls
/**
 * @description Selector class for the Account SObject.
 * Responsible for all SOQL queries related to Accounts, ensuring FLS and CRUD checks.
 * Part of the Apex Orbit Framework (AOF).
 */
public with sharing class AOF_AccountSelector extends AOF_Application_Selector {

    public AOF_AccountSelector() {
        super(Account.SObjectType);
        // Optionally, define a default set of fields to query
        // this.fieldsToQuery.addAll(new List<String>{"Id", "Name", "AccountNumber", "Industry", "Type", "Description"});
        // Or build dynamically based on all queryable fields:
        // this.fieldsToQuery.addAll(getSObjectFields(Account.SObjectType, true)); 
    }

    /**
     * @description Selects Account records by a set of Ids.
     * @param ids Set of Account Ids.
     * @return List of Account records.
     */
    public List<Account> selectByIds(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) {
            return new List<Account>();
        }
        // Build query dynamically to include fields from this.fieldsToQuery
        // String soqlQuery = "SELECT " + String.join(getFieldsToQuery(Account.SObjectType), ",") + " FROM Account WHERE Id IN :ids WITH SECURITY_ENFORCED";
        // return (List<Account>) Database.query(soqlQuery);
        // Simplified for example, assuming fieldsToQuery is populated or using default fields
        return [SELECT Id, Name, AccountNumber, Industry, Type, Description 
                FROM Account WHERE Id IN :ids WITH SECURITY_ENFORCED];
    }

    /**
     * @description Selects active Account records of a specific type.
     * @param accountType The type of account (e.g., "Prospect", "Customer").
     * @return List of active Account records.
     */
    public List<Account> selectActiveAccountsByType(String accountType) {
        if (String.isBlank(accountType)) {
            return new List<Account>();
        }
        // String soqlQuery = "SELECT " + String.join(getFieldsToQuery(Account.SObjectType), ",") + " FROM Account WHERE Type = :accountType AND Active__c = 'Yes' WITH SECURITY_ENFORCED";
        // return (List<Account>) Database.query(soqlQuery);
        // Assuming Active__c is a field on Account
        return [SELECT Id, Name, AccountNumber, Industry, Type, Description 
                FROM Account WHERE Type = :accountType WITH SECURITY_ENFORCED]; // Add Active__c = 'Yes' if applicable
    }

    /**
     * @description Selects Accounts that have no parent Account.
     * @return List of parentless Account records.
     */
    public List<Account> selectParentlessAccounts() {
        // String soqlQuery = "SELECT " + String.join(getFieldsToQuery(Account.SObjectType), ",") + " FROM Account WHERE ParentId = null WITH SECURITY_ENFORCED";
        // return (List<Account>) Database.query(soqlQuery);
        return [SELECT Id, Name, ParentId FROM Account WHERE ParentId = null WITH SECURITY_ENFORCED];
    }
    
    // Add other specific query methods as needed.
}
```

#### 9.2.4. Using Unit of Work (`AOF_Application_UnitOfWork`)

Imagine in `AOF_AccountDomain.onAfterInsert()`, you want to create a related `Contact` for each new `Account` that is of type "Technology Partner".

```apex
// Inside AOF_AccountDomain.cls

public override void onAfterInsert() {
    List<Contact> contactsToCreate = new List<Contact>();
    // The AOF_TriggerHandler creates a UoW instance. This UoW instance needs to be made available
    // to the Domain class, typically by passing it into the Domain constructor or a specific method call.
    // For this example, let's assume the AOF_TriggerHandler has been modified to pass its `uow` 
    // instance when it calls the domain methods, or the domain class has a way to access it.
    // One common pattern: 
    // In AOF_TriggerHandler's run method or specific context methods:
    // AOF_AccountDomain domain = new AOF_AccountDomain(this.newRecords, this.oldMap);
    // domain.setUnitOfWork(this.uow); // Requires a setter in AOF_Application_Domain
    // domain.onAfterInsert();

    // For this example, we'll assume `this.uow` is accessible in the domain class after being set.
    // If AOF_Application_Domain has `protected AOF_Application_UnitOfWork uow;` and a setter.
    // This example assumes such a mechanism is in place.

    AOF_Application_UnitOfWork uowInstance = getUnitOfWorkFromHandler(); // Placeholder for actual UoW retrieval mechanism

    for (SObject sObj : this.records) {
        Account newAcc = (Account)sObj;
        if (newAcc.Type == 'Technology Partner') {
            Contact newPartnerContact = new Contact(
                LastName = newAcc.Name + ' Contact',
                AccountId = newAcc.Id,
                Email = 'contact@' + newAcc.Name.replaceAll('\\s+', '').toLowerCase() + '.com'
            );
            contactsToCreate.add(newPartnerContact);
        }
    }

    if (!contactsToCreate.isEmpty() && uowInstance != null) {
        uowInstance.registerNew(contactsToCreate);
        // The UoW.commitWork() will be called by the AOF_TriggerHandler at the end of the 'after' context.
    }
}

// Conceptual method to get UoW - actual implementation depends on how it's passed
private AOF_Application_UnitOfWork getUnitOfWorkFromHandler() {
    // This is highly conceptual. In a real scenario:
    // 1. UoW is passed to Domain constructor.
    // 2. UoW is passed to each domain method (e.g., onAfterInsert(AOF_Application_UnitOfWork uow)).
    // 3. Domain has a reference to the TriggerHandler and calls handler.getUnitOfWork().
    // The AOF_TriggerHandler already has `public AOF_Application_UnitOfWork getUnitOfWork()`. 
    // The challenge is for the Domain instance to get a reference to *that specific handler's* UoW.
    // Simplest is for the handler to pass it when calling domain methods.
    // If the handler calls `new AOF_AccountDomain(this.newRecords, this.oldMap, this.uow).onAfterInsert();`
    // then the domain constructor needs to accept and store `this.uow`.
    // For now, this is a placeholder for that mechanism.
    if(Trigger.handler instanceof AOF_TriggerHandler){
         return ((AOF_TriggerHandler)Trigger.handler).getUnitOfWork();
     }
     return null; 
}
```
**Important Note on UoW Access:** The example above uses a conceptual `getUnitOfWorkFromHandler()`. In the current AOF design, the `AOF_TriggerHandler` creates and owns the `AOF_Application_UnitOfWork` instance. To use it within Domain or Service classes, this UoW instance must be passed to them (e.g., via constructor, method parameter, or a setter). The `AOF_TriggerHandler` has a `public AOF_Application_UnitOfWork getUnitOfWork()` method. The dispatch mechanism in the handler would need to make this UoW instance available to the domain class methods.

#### 9.2.5. Error Handling Example

If an error occurs, use `AOF_ErrorHandlerService`.

```apex
// Inside AOF_AccountDomain.cls or AOF_AccountService.cls
try {
    // Some risky operation
    Integer riskyCalculation = 10 / 0; // This will throw a MathException
} catch (Exception e) {
    // Log the error using the service
    List<Id> accountIds = new List<Id>();
    // 'this.records' is from AOF_Application_Domain, available if in a domain method context
    if (this.records != null) { 
        for(SObject acc : this.records) {
            if(acc.Id != null) accountIds.add(acc.Id);
        }
    }
    AOF_ErrorHandlerService.logError(e, 'AOF_AccountDomain', 'performRiskyOperation', accountIds, Account.SObjectType.getDescribe().getName(), 'Critical');

    // Optionally, add a user-facing error if in a 'before' context and appropriate
    // if (Trigger.isBefore) { // This check is conceptual here, context is important
    //     for(SObject acc : this.records) {
    //         acc.addError('A critical error occurred while processing your request. Please contact support.');
    //     }
    // }
}
```

### 9.3. Using Service Layer (Conceptual)

If you have logic that spans multiple objects or is a reusable business process, you'd use a service.

**`AOF_AccountService.cls` (Conceptual)**
```apex
public with sharing class AOF_AccountService implements AOF_Application_Service {

    private AOF_Application_UnitOfWork uow;
    private AOF_AccountSelector accountSelector;
    // private AOF_ContactSelector contactSelector; // If interacting with Contacts

    public AOF_AccountService(AOF_Application_UnitOfWork uowInstance) {
        this.uow = uowInstance;
        this.accountSelector = new AOF_AccountSelector();
        // this.contactSelector = new AOF_ContactSelector();
    }

    // Example service method
    public void escalateHighValueAccounts(Set<Id> accountIds) {
        List<Account> accountsToEscalate = accountSelector.selectByIds(accountIds);
        List<Task> tasksToCreate = new List<Task>();

        for (Account acc : accountsToEscalate) {
            // Assuming AnnualRevenue and CustomerPriority__c are fields on Account
            // if (acc.AnnualRevenue > 1000000) { 
            //     acc.CustomerPriority__c = 'High'; // Mark for update
            //     this.uow.registerDirty(acc);

            //     Task escalationTask = new Task(
            //         Subject = 'Escalate High Value Account: ' + acc.Name,
            //         WhatId = acc.Id,
            //         OwnerId = UserInfo.getUserId(), // Assign to current user or a queue
            //         Status = 'Not Started',
            //         Priority = 'High'
            //     );
            //     tasksToCreate.add(escalationTask);
            // }
        }
        if(!tasksToCreate.isEmpty()){
            this.uow.registerNew(tasksToCreate);
        }
        // DML commit is handled by the caller (e.g., TriggerHandler or another service that calls commitWork)
    }
}
```
**Invoking the Service:**
The `AOF_TriggerHandler` or a Domain class method could instantiate and call this service. The `AOF_Application_UnitOfWork` instance would typically be passed from the handler to the service.

This concludes the basic usage examples. The key is to place logic in the correct layer:
*   **Triggers:** Minimal, delegate to `AOF_TriggerHandler`.
*   **`AOF_TriggerHandler`:** Orchestrates, dispatches to Domain (needs UoW passing logic).
*   **Domain Classes:** SObject-specific rules, validations, calculations.
*   **Selector Classes:** All SOQL queries.
*   **Service Classes:** Cross-object logic, complex processes, UoW interactions.
*   **`AOF_Application_UnitOfWork`:** Register all DML.
*   **`AOF_ErrorHandlerService`:** Log all exceptions.

---




## 10. Error Handling In-Depth

The Apex Orbit Framework (AOF) employs a robust and decoupled error handling mechanism designed to capture and log exceptions effectively without impacting the primary transaction flow. This section details the components and processes involved.

### 10.1. Components

1.  **`ErrorLogEvent__e` (Platform Event):**
    *   **Purpose:** Serves as the transport medium for error details. Publishing a platform event is an asynchronous operation that occurs after the successful completion of the current transaction (if `PublishAfterCommit` behavior is used, which is default and recommended) or immediately (if `PublishImmediately` is used).
    *   **Key Fields:** As defined in the Setup Guide (Timestamp, TransactionId, OriginatingClassName, ErrorMessage, StackTrace, Severity, etc.).
    *   **Benefit:** Decouples error logging from the transaction that caused the error. If the main transaction rolls back due to the error, the platform event (if published after commit and the commit point is reached, or if published immediately) can still be processed, ensuring the error is logged.

2.  **`Error_Log__c` (Custom SObject):**
    *   **Purpose:** Provides persistent storage for error details. This allows for querying, reporting, and tracking of errors over time.
    *   **Fields:** Mirrors the fields of `ErrorLogEvent__e` and adds fields for tracking and management (e.g., `Status__c`, `AssignedTo__c`, `ResolutionNotes__c`).

3.  **`AOF_ErrorHandlerService.cls` (Utility Class):**
    *   **Purpose:** Provides a centralized and easy-to-use way to publish `ErrorLogEvent__e` events from anywhere in the Apex code.
    *   **Key Methods:**
        *   `logError(Exception ex, String className, String methodName, List<Id> recordIds, String sObjectTypeApiName, String severity)`: For logging standard Apex exceptions.
        *   `logError(String message, String className, String methodName, List<Id> recordIds, String sObjectTypeApiName, String severity)`: For logging custom error messages.
    *   **Functionality:** Constructs the `ErrorLogEvent__e` payload and uses `EventBus.publish()` to send it. It includes its own internal try-catch to prevent the logging mechanism itself from throwing unhandled exceptions.

4.  **`ErrorLogEventSubscriber.trigger` (Apex Trigger on `ErrorLogEvent__e`):
    *   **Purpose:** Subscribes to the `ErrorLogEvent__e` platform events.
    *   **Functionality:** When an `ErrorLogEvent__e` is received, this trigger takes the event payload and creates a new `Error_Log__c` record, saving the error details to the database. This operation is bulkified to handle multiple events efficiently.

### 10.2. Error Logging Flow

1.  **Exception Occurs:** An exception is thrown and caught within a try-catch block in a Domain, Service, or Handler class.
2.  **Call `AOF_ErrorHandlerService`:** The catch block calls one of the static `logError` methods in `AOF_ErrorHandlerService.cls`, passing relevant details like the exception object, class/method name, involved record Ids, SObject type, and severity.
3.  **Publish Platform Event:** `AOF_ErrorHandlerService` creates an instance of `ErrorLogEvent__e`, populates its fields, and publishes it using `EventBus.publish()`.
4.  **Asynchronous Processing:** The platform event is added to the event bus.
5.  **Subscriber Trigger Fires:** The `ErrorLogEventSubscriber.trigger` (listening to `ErrorLogEvent__e`) fires asynchronously when the event is processed from the bus.
6.  **Create `Error_Log__c` Record:** The subscriber trigger extracts the data from the `ErrorLogEvent__e` payload and creates one or more `Error_Log__c` records, persisting the error details.

### 10.3. User-Facing Errors vs. System Errors

*   **User-Facing Errors (Validations):** For errors that need to be displayed directly to the user in the Salesforce UI (e.g., validation rule failures), use the `SObject.addError()` method (e.g., `myAccount.Name.addError('Account Name cannot be blank.')`). This prevents the record from being saved and shows the message to the user. These types of errors typically do *not* need to be logged via `AOF_ErrorHandlerService` unless there's a specific requirement to track validation failures.
*   **System Errors (Exceptions):** For unexpected exceptions or system-level errors that users should not directly see as raw exception messages, use the `AOF_ErrorHandlerService`. You can then use `addError()` with a generic message for the user (e.g., `myAccount.addError('An unexpected error occurred. Please contact support. Ref: ' + errorId);`) while the detailed error is logged in `Error_Log__c`.

### 10.4. Best Practices for Error Handling with AOF

*   **Catch Specific Exceptions:** Whenever possible, catch specific exception types (e.g., `DmlException`, `QueryException`, `MathException`) rather than just the generic `Exception` type. This allows for more targeted error handling if needed.
*   **Provide Context:** When calling `AOF_ErrorHandlerService.logError()`, provide as much context as possible: class name, method name, involved record Ids, SObject type. This greatly aids in debugging.
*   **Set Appropriate Severity:** Use the `severity` parameter to indicate the impact of the error (e.g., Critical, High, Medium, Low). This helps in prioritizing error investigation.
*   **Don't Swallow Exceptions:** After logging an error with `AOF_ErrorHandlerService`, decide whether to re-throw the exception or handle it gracefully. If the error should cause the current transaction to roll back (which is often the case for unexpected system errors), ensure it does, either by re-throwing or by using `addError()` if in a `before` trigger context.
*   **Test Error Logging:** Include scenarios in your Apex unit tests that specifically trigger exceptions and verify that `ErrorLogEvent__e` events are published correctly (using `Test.startTest()`, `Test.stopTest()` and checking event publishing, or by querying `Error_Log__c` if testing the subscriber trigger indirectly).
*   **Monitor `Error_Log__c`:** Regularly review the `Error_Log__c` records to identify recurring issues, performance problems, or bugs in your application.

## 11. Best Practices for Using AOF

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

## 12. Customization and Extension

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

## 13. Glossary

*   **AOF (Apex Orbit Framework):** The name of this Salesforce Apex framework.
*   **Bulkification:** Designing Apex code to efficiently process large sets of data (typically up to 200 records in a trigger context) to avoid hitting Salesforce governor limits.
*   **CRUD/FLS:** Create, Read, Update, Delete (CRUD) object-level permissions and Field-Level Security (FLS) field-level permissions in Salesforce.
*   **Domain Layer:** A layer in the AOF responsible for SObject-specific business logic, validations, and calculations. Represented by classes extending `AOF_Application_Domain`.
*   **DML (Data Manipulation Language):** Apex statements used to insert, update, delete, or undelete records in Salesforce (e.g., `insert`, `update`, `delete`).
*   **Governor Limits:** Salesforce platform limits that restrict resource consumption by Apex code (e.g., number of SOQL queries, DML statements, CPU time).
*   **Platform Event:** A type of Salesforce event used for asynchronous communication. In AOF, `ErrorLogEvent__e` is used for decoupled error logging.
*   **Selector Layer:** A layer in the AOF responsible for all SOQL queries. Represented by classes extending `AOF_Application_Selector`.
*   **Separation of Concerns (SoC):** A design principle that advocates for breaking down an application into distinct sections, each addressing a separate concern or responsibility.
*   **Service Layer:** A layer in the AOF that encapsulates business logic spanning multiple SObjects, complex processes, or interactions with external systems. Represented by classes implementing `AOF_Application_Service`.
*   **Single Trigger Per Object:** A design pattern where only one Apex trigger is created for each SObject to manage all trigger contexts, simplifying execution flow.
*   **SOQL (Salesforce Object Query Language):** The language used to query data from the Salesforce database.
*   **Trigger Context Variables:** Static variables in Apex triggers that provide information about the current DML operation (e.g., `Trigger.new`, `Trigger.oldMap`, `Trigger.isInsert`, `Trigger.isBefore`).
*   **Trigger Handler:** A component in AOF (`AOF_TriggerHandler`) that orchestrates trigger logic, delegating to Domain or Service layers.
*   **Unit of Work (UoW):** A design pattern and a component in AOF (`AOF_Application_UnitOfWork`) that manages DML operations by collecting them and executing them in a bulkified manner at the end of a transaction.
