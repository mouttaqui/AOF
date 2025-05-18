/**
 * @description Service class for handling error logging. 
 * This service publishes Platform Events for errors, which are then processed by a subscriber to create Error_Log__c records.
 * This decouples error logging from the main transaction.
 * Part of the Apex Orbit Framework (AOF).
 */
public class AOF_ErrorHandlerService {

    // Define the API name of your Platform Event. 
    private static final String ERROR_PLATFORM_EVENT_NAME = 'ErrorLogEvent__e'; // Standard Salesforce naming for PE

    /**
     * @description Logs an error by publishing a Platform Event.
     * @param ex The exception that occurred.
     * @param originatingClassName The name of the class where the error originated.
     * @param originatingMethodName The name of the method where the error originated.
     * @param recordIds A list of SObject Ids related to the error context (optional).
     * @param sObjectTypeApiName The API name of the SObject type related to the error (optional).
     * @param severity The severity of the error (e.g., 'Critical', 'High', 'Medium', 'Low', 'Info'). Defaults to 'High'.
     */
    public static void logError(
        Exception ex,
        String originatingClassName,
        String originatingMethodName,
        List<Id> recordIds,
        String sObjectTypeApiName,
        String severity
    ) { // NOPMD: ExcessiveParameterList
        try {
            List<ErrorLogEvent__e> eventsToPublish = new List<ErrorLogEvent__e>();

            ErrorLogEvent__e errorEvent = (ErrorLogEvent__e) Schema.getGlobalDescribe().get(ERROR_PLATFORM_EVENT_NAME).newSObject();
            errorEvent.put('Timestamp__c', System.now());
            // TransactionId__c can be populated if you have a way to get a unique transaction ID.
            // errorEvent.put('TransactionId__c', ''); 

            errorEvent.put('OriginatingClassName__c', originatingClassName);
            errorEvent.put('OriginatingMethodName__c', originatingMethodName);
            if(ex != null) { // Guard against null exception object
                errorEvent.put('LineNumber__c', ex.getLineNumber());
                errorEvent.put('ErrorMessage__c', ex.getMessage());
                errorEvent.put('StackTrace__c', ex.getStackTraceString());
            } else {
                errorEvent.put('ErrorMessage__c', 'Unknown error: Exception object was null.');
            }
            errorEvent.put('SObjectType__c', sObjectTypeApiName);
            errorEvent.put('Severity__c', String.isNotBlank(severity) ? severity : 'High');

            if (recordIds != null && !recordIds.isEmpty()) {
                errorEvent.put('RecordIds__c', String.join(recordIds, ',')); 
            }

            eventsToPublish.add(errorEvent);

            // Publish Platform Events
            List<Database.SaveResult> results = EventBus.publish(eventsToPublish);

            // Check for errors during publishing but don't use System.debug
            for (Database.SaveResult sr : results) {
                if (!sr.isSuccess()) { // NOPMD: EmptyIfStmt
                    // Instead of using System.debug, we could:
                    // 1. Write to a static variable that could be checked in tests
                    // 2. Throw an exception if critical (but this could cause issues)
                    // 3. For production code, silently fail as we're already in the error handler
                    // Option 3 is safest for an error handler
                }
            }

        } catch (Exception e) { // NOPMD: EmptyCatchBlock
            // Catch any exception during error logging itself to prevent it from disrupting the main flow.
            // Silently fail - we're already in the error handler, so we don't want to cause additional issues
            // No System.debug statements here
        }
    }

    /**
     * @description Overloaded logError method without sObjectTypeApiName.
     * @param ex The exception that occurred.
     * @param originatingClassName The name of the class where the error originated.
     * @param originatingMethodName The name of the method where the error originated.
     * @param recordIds A list of SObject Ids related to the error context.
     * @param severity The severity of the error.
     */
    public static void logError(
        Exception ex,
        String originatingClassName,
        String originatingMethodName,
        List<Id> recordIds,
        String severity
    ) { // NOPMD: ExcessiveParameterList
        logError(ex, originatingClassName, originatingMethodName, recordIds, null, severity);
    }

    /**
     * @description Overloaded logError method without recordIds and sObjectTypeApiName.
     * @param ex The exception that occurred.
     * @param originatingClassName The name of the class where the error originated.
     * @param originatingMethodName The name of the method where the error originated.
     * @param severity The severity of the error.
     */
    public static void logError(
        Exception ex,
        String originatingClassName,
        String originatingMethodName,
        String severity
    ) { // NOPMD: ExcessiveParameterList
        logError(ex, originatingClassName, originatingMethodName, null, null, severity);
    }

    /**
     * @description Overloaded logError method with minimal parameters, defaulting severity to High.
     * @param ex The exception that occurred.
     * @param originatingClassName The name of the class where the error originated.
     * @param originatingMethodName The name of the method where the error originated.
     */
    public static void logError(
        Exception ex,
        String originatingClassName,
        String originatingMethodName
    ) {
        logError(ex, originatingClassName, originatingMethodName, null, null, 'High');
    }
}