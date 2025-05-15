# Error Handling In-Depth

The Apex Orbit Framework (AOF) employs a robust and decoupled error handling mechanism designed to capture and log exceptions effectively without impacting the primary transaction flow. This section details the components and processes involved.

## 1. Components

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

## 2. Error Logging Flow

1.  **Exception Occurs:** An exception is thrown and caught within a try-catch block in a Domain, Service, or Handler class.
2.  **Call `AOF_ErrorHandlerService`:** The catch block calls one of the static `logError` methods in `AOF_ErrorHandlerService.cls`, passing relevant details like the exception object, class/method name, involved record Ids, SObject type, and severity.
3.  **Publish Platform Event:** `AOF_ErrorHandlerService` creates an instance of `ErrorLogEvent__e`, populates its fields, and publishes it using `EventBus.publish()`.
4.  **Asynchronous Processing:** The platform event is added to the event bus.
5.  **Subscriber Trigger Fires:** The `ErrorLogEventSubscriber.trigger` (listening to `ErrorLogEvent__e`) fires asynchronously when the event is processed from the bus.
6.  **Create `Error_Log__c` Record:** The subscriber trigger extracts the data from the `ErrorLogEvent__e` payload and creates one or more `Error_Log__c` records, persisting the error details.

## 3. User-Facing Errors vs. System Errors

*   **User-Facing Errors (Validations):** For errors that need to be displayed directly to the user in the Salesforce UI (e.g., validation rule failures), use the `SObject.addError()` method (e.g., `myAccount.Name.addError('Account Name cannot be blank.')`). This prevents the record from being saved and shows the message to the user. These types of errors typically do *not* need to be logged via `AOF_ErrorHandlerService` unless there's a specific requirement to track validation failures.
*   **System Errors (Exceptions):** For unexpected exceptions or system-level errors that users should not directly see as raw exception messages, use the `AOF_ErrorHandlerService`. You can then use `addError()` with a generic message for the user (e.g., `myAccount.addError('An unexpected error occurred. Please contact support. Ref: ' + errorId);`) while the detailed error is logged in `Error_Log__c`.

## 4. Best Practices for Error Handling with AOF

*   **Catch Specific Exceptions:** Whenever possible, catch specific exception types (e.g., `DmlException`, `QueryException`, `MathException`) rather than just the generic `Exception` type. This allows for more targeted error handling if needed.
*   **Provide Context:** When calling `AOF_ErrorHandlerService.logError()`, provide as much context as possible: class name, method name, involved record Ids, SObject type. This greatly aids in debugging.
*   **Set Appropriate Severity:** Use the `severity` parameter to indicate the impact of the error (e.g., Critical, High, Medium, Low). This helps in prioritizing error investigation.
*   **Don't Swallow Exceptions:** After logging an error with `AOF_ErrorHandlerService`, decide whether to re-throw the exception or handle it gracefully. If the error should cause the current transaction to roll back (which is often the case for unexpected system errors), ensure it does, either by re-throwing or by using `addError()` if in a `before` trigger context.
*   **Test Error Logging:** Include scenarios in your Apex unit tests that specifically trigger exceptions and verify that `ErrorLogEvent__e` events are published correctly (using `Test.startTest()`, `Test.stopTest()` and checking event publishing, or by querying `Error_Log__c` if testing the subscriber trigger indirectly).
*   **Monitor `Error_Log__c`:** Regularly review the `Error_Log__c` records to identify recurring issues, performance problems, or bugs in your application.
