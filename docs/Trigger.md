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
