trigger AccountTrigger on Account (
    before insert, after insert,
    before update, after update,
    before delete, after delete,
    after undelete
) {
    // Instantiate the generic trigger handler, passing the SObjectType and the trigger operation.
    // The AOF_TriggerHandler will then dispatch to the appropriate AOF_AccountDomain methods.
    AOF_TriggerHandler handler = new AOF_TriggerHandler(Account.SObjectType, Trigger.operationType);
    
    // Execute the handler logic
    handler.run();
}