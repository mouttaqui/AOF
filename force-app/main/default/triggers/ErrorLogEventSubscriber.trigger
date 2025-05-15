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
