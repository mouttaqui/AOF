/**
 * @description Domain class for the Account SObject.
 * Contains SObject-specific logic for Accounts, such as validation rules or complex calculations.
 * Part of the Apex Orbit Framework (AOF).
 */
public with sharing class AOF_AccountDomain extends AOF_Application_Domain {

    /**
     * @description Constructor for Account domain logic.
     * @param newRecords List of new Account records from Trigger.new
     * @param oldRecordsMap Map of old Account records from Trigger.oldMap
     */
    public AOF_AccountDomain(List<Account> newRecords, Map<Id, Account> oldRecordsMap) {
        super(newRecords, oldRecordsMap);
    }

    /**
     * @description Constructor for Account domain logic in delete context.
     * @param oldRecordsMap Map of old Account records from Trigger.oldMap
     */
    public AOF_AccountDomain(Map<Id, Account> oldRecordsMap) {
        super(oldRecordsMap, Account.SObjectType);
    }

    /**
     * @description Logic to execute before new Account records are inserted.
     * Example: Set a default description if it's blank.
     */
    public override void onBeforeInsert() {
        List<Account> accountsToProcess = (List<Account>) this.records;
        for (Account acc : accountsToProcess) {
            if (String.isBlank(acc.Description)) {
                acc.Description = 'Account created via AOF Framework.';
            }
            // Example Validation: Ensure all new accounts have a Name
            if (String.isBlank(acc.Name)) {
                acc.Name.addError('Account Name cannot be blank.');
            }
        }
    }

    /**
     * @description Logic to execute after new Account records are inserted.
     * Example: Log a message or create a related task (using UnitOfWork).
     */
    public override void onAfterInsert() {
        // For example, if you needed to create a follow-up Task for each new Account:
        // AOF_Application_UnitOfWork uow = ((AOF_TriggerHandler)Trigger.handler).getUnitOfWork();
        // List<Task> tasksToCreate = new List<Task>();
        // for(Account acc : (List<Account>)this.records){
        //     Task newTask = new Task(
        //         Subject = 'Follow up on new Account: ' + acc.Name,
        //         WhatId = acc.Id,
        //         OwnerId = acc.OwnerId, // Or a default queue/user
        //         ActivityDate = System.today().addDays(7)
        //     );
        //     tasksToCreate.add(newTask);
        // }
        // if(!tasksToCreate.isEmpty()){
        //     uow.registerNew(tasksToCreate);
        // }
        System.debug('AOF_AccountDomain: onAfterInsert called for ' + this.records.size() + ' accounts.');
    }

    /**
     * @description Logic to execute before existing Account records are updated.
     * Example: Prevent updates to the AccountNumber field if it already has a value.
     */
    public override void onBeforeUpdate() {
        List<Account> updatedAccounts = (List<Account>) this.records;
        Map<Id, Account> oldAccountsMap = (Map<Id, Account>) this.oldMap;

        for (Account updatedAcc : updatedAccounts) {
            Account oldAcc = oldAccountsMap.get(updatedAcc.Id);
            // Example Validation: Prevent changing Account Number if it exists
            if (String.isNotBlank(oldAcc.AccountNumber) && updatedAcc.AccountNumber != oldAcc.AccountNumber) {
                updatedAcc.AccountNumber.addError('Account Number cannot be changed once set.');
            }

            // Example: If a certain field changes, update another field
            if (fieldHasChanged(updatedAcc.Id, Account.Type) && updatedAcc.Type == 'Prospect') {
                updatedAcc.Rating = 'Hot'; // Example dependent field update
            }
        }
    }

    /**
     * @description Logic to execute after existing Account records are updated.
     * Example: If Industry changes, notify an integration (conceptual).
     */
    public override void onAfterUpdate() {
        // List<Account> updatedAccounts = (List<Account>) this.records;
        // Map<Id, Account> oldAccountsMap = (Map<Id, Account>) this.oldMap;
        // for(Account acc : updatedAccounts){
        //     if(fieldHasChanged(acc.Id, Account.Industry)){
        //         System.debug('Account Industry changed for ' + acc.Name + '. Consider notifying external system.');
        //         // Potentially call a service here to handle the notification
        //     }
        // }
        System.debug('AOF_AccountDomain: onAfterUpdate called for ' + this.records.size() + ' accounts.');
    }

    /**
     * @description Logic to execute before Account records are deleted.
     * Example: Prevent deletion if Account has open Opportunities.
     */
    public override void onBeforeDelete() {
        // Map<Id, Account> accountsToDelete = (Map<Id, Account>) this.oldMap;
        // // Example: Query for open Opportunities related to these accounts
        // // This would typically use the AOF_OpportunitySelector if it existed
        // Set<Id> accountIdsWithOpenOpps = new Set<Id>(); 
        // /*
        // List<Opportunity> openOpps = [SELECT AccountId FROM Opportunity 
        //                               WHERE AccountId IN :accountsToDelete.keySet() AND IsClosed = false];
        // for(Opportunity opp : openOpps){
        //     accountIdsWithOpenOpps.add(opp.AccountId);
        // }
        // */
        // for(Id accId : accountsToDelete.keySet()){
        //     if(accountIdsWithOpenOpps.contains(accId)){
        //         accountsToDelete.get(accId).addError('Cannot delete Account with open Opportunities.');
        //     }
        // }
        System.debug('AOF_AccountDomain: onBeforeDelete called for ' + this.oldMap.size() + ' accounts.');
    }

    /**
     * @description Logic to execute after Account records are deleted.
     */
    public override void onAfterDelete() {
        System.debug('AOF_AccountDomain: onAfterDelete called for ' + this.oldMap.size() + ' accounts.');
    }

    /**
     * @description Logic to execute after Account records are undeleted.
     */
    public override void onUndelete() {
        System.debug('AOF_AccountDomain: onUndelete called for ' + this.records.size() + ' accounts.');
    }
}