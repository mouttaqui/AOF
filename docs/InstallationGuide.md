# Setup and Installation Guide

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
