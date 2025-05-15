/**
 * @description Service class for handling error logging. 
 * This service publishes Platform Events for errors, which are then processed by a subscriber to create Error_Log__c records.
 * This decouples error logging from the main transaction.
 * Part of the Apex Orbit Framework (AOF).
 */
public class AOF_ErrorHandlerService {

    // Define the API name of your Platform Event. 
    // It's good practice to use a Custom Label or Constant for this in a real org.
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
    ) {
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

            // Check for errors during publishing (optional, but good practice)
            for (Database.SaveResult sr : results) {
                if (!sr.isSuccess()) {
                    System.debug(LoggingLevel.ERROR, 'AOF_ErrorHandlerService: Failed to publish error event: ' + sr.getErrors()[0].getMessage());
                }
            }

        } catch (Exception e) {
            // Catch any exception during error logging itself to prevent it from disrupting the main flow.
            System.debug(LoggingLevel.ERROR, 'CRITICAL ERROR IN AOF_ErrorHandlerService: ' + e.getMessage() + '\nStackTrace: ' + e.getStackTraceString());
        }
    }

    /**
     * @description Overloaded logError method without sObjectTypeApiName.
     */
    public static void logError(
        Exception ex,
        String originatingClassName,
        String originatingMethodName,
        List<Id> recordIds,
        String severity
    ) {
        logError(ex, originatingClassName, originatingMethodName, recordIds, null, severity);
    }

    /**
     * @description Overloaded logError method without recordIds and sObjectTypeApiName.
     */
    public static void logError(
        Exception ex,
        String originatingClassName,
        String originatingMethodName,
        String severity
    ) {
        logError(ex, originatingClassName, originatingMethodName, null, null, severity);
    }

    /**
     * @description Overloaded logError method with minimal parameters, defaulting severity to High.
     */
    public static void logError(
        Exception ex,
        String originatingClassName,
        String originatingMethodName
    ) {
        logError(ex, originatingClassName, originatingMethodName, null, null, 'High');
    }
}

