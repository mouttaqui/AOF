# Usage Guide and Examples

This section provides practical examples of how to use the Apex Orbit Framework (AOF) to implement business logic for a specific SObject. We will use the `Account` SObject as an example, building upon the `AOF_AccountSelector.cls`, `AOF_AccountDomain.cls`, and `AccountTrigger.trigger` components that might have been provided as part of the framework examples.

## 1. Setting up a New SObject with AOF

To integrate a new SObject (e.g., `Contact`) with AOF, you would typically create the following components:

1.  **Trigger:** `ContactTrigger.trigger`
2.  **Domain Class:** `AOF_ContactDomain.cls` (extending `AOF_Application_Domain`)
3.  **Selector Class:** `AOF_ContactSelector.cls` (extending `AOF_Application_Selector`)
4.  **Service Class (Optional):** `AOF_ContactService.cls` (implementing `AOF_Application_Service` or a more specific interface if needed for complex, cross-object logic).

## 2. Example: Implementing Logic for the Account SObject

Let's walk through an example for the `Account` SObject.

### 2.1. Account Trigger (`AccountTrigger.trigger`)

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

### 2.2. Account Domain Class (`AOF_AccountDomain.cls`)

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

### 2.3. Account Selector Class (`AOF_AccountSelector.cls`)

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

### 2.4. Using Unit of Work (`AOF_Application_UnitOfWork`)

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

### 2.5. Error Handling Example

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

## 3. Using Service Layer (Conceptual)

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
