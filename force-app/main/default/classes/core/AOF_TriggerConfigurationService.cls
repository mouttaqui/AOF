/**
 * @description Service class for managing trigger configuration via custom metadata.
 * This class provides methods to retrieve and cache trigger configuration settings.
 * Part of the Apex Orbit Framework (AOF).
 */
public with sharing class AOF_TriggerConfigurationService {
    
    // Cache of trigger configurations by SObject type
    private static Map<String, AOF_TriggerConfiguration__mdt> configurationByObjectName;
    
    // Cache of active status by SObject type
    private static Map<String, Boolean> activeStatusByObjectName;
    
    // Cache of event enablement by SObject type and event
    private static Map<String, Map<String, Boolean>> eventEnablementByObjectAndEvent;
    
    /**
     * @description Initialize the configuration cache
     */
    private static void initializeCache() {
        if (configurationByObjectName == null) {
            configurationByObjectName = new Map<String, AOF_TriggerConfiguration__mdt>();
            activeStatusByObjectName = new Map<String, Boolean>();
            eventEnablementByObjectAndEvent = new Map<String, Map<String, Boolean>>();
            
            // Query all trigger configurations
            List<AOF_TriggerConfiguration__mdt> configurations = [
                SELECT Id, SObjectApiName__c, IsActive__c, 
                       BeforeInsert__c, AfterInsert__c, 
                       BeforeUpdate__c, AfterUpdate__c, 
                       BeforeDelete__c, AfterDelete__c, 
                       AfterUndelete__c, ExecutionOrder__c, 
                       Environment__c, Description__c
                FROM AOF_TriggerConfiguration__mdt
                ORDER BY ExecutionOrder__c ASC
            ];
            
            // Process configurations
            for (AOF_TriggerConfiguration__mdt config : configurations) {
                String objectName = config.SObjectApiName__c.toLowerCase();
                
                // Store the configuration
                configurationByObjectName.put(objectName, config);
                
                // Store active status
                activeStatusByObjectName.put(objectName, config.IsActive__c);
                
                // Store event enablement
                Map<String, Boolean> eventMap = new Map<String, Boolean>();
                eventMap.put('beforeinsert', config.BeforeInsert__c);
                eventMap.put('afterinsert', config.AfterInsert__c);
                eventMap.put('beforeupdate', config.BeforeUpdate__c);
                eventMap.put('afterupdate', config.AfterUpdate__c);
                eventMap.put('beforedelete', config.BeforeDelete__c);
                eventMap.put('afterdelete', config.AfterDelete__c);
                eventMap.put('afterundelete', config.AfterUndelete__c);
                
                eventEnablementByObjectAndEvent.put(objectName, eventMap);
            }
        }
    }
    
    /**
     * @description Check if triggers are active for a specific SObject type
     * @param sObjectType The SObject type to check
     * @return True if triggers are active, false otherwise
     */
    public static Boolean isActive(SObjectType sObjectType) {
        if (sObjectType == null) {
            return false;
        }
        
        return isActive(sObjectType.getDescribe().getName());
    }
    
    /**
     * @description Check if triggers are active for a specific SObject API name
     * @param sObjectName The SObject API name to check
     * @return True if triggers are active, false otherwise
     */
    public static Boolean isActive(String sObjectName) {
        if (String.isBlank(sObjectName)) {
            return false;
        }
        
        initializeCache();
        
        String objectKey = sObjectName.toLowerCase();
        
        // If no configuration exists, default to active
        if (!activeStatusByObjectName.containsKey(objectKey)) {
            return true;
        }
        
        return activeStatusByObjectName.get(objectKey);
    }
    
    /**
     * @description Check if a specific trigger event is enabled for an SObject type
     * @param sObjectType The SObject type to check
     * @param triggerEvent The trigger event (e.g., beforeinsert, afterupdate)
     * @return True if the event is enabled, false otherwise
     */
    public static Boolean isEventEnabled(SObjectType sObjectType, String triggerEvent) {
        if (sObjectType == null || String.isBlank(triggerEvent)) {
            return false;
        }
        
        return isEventEnabled(sObjectType.getDescribe().getName(), triggerEvent);
    }
    
    /**
     * @description Check if a specific trigger event is enabled for an SObject API name
     * @param sObjectName The SObject API name to check
     * @param triggerEvent The trigger event (e.g., beforeinsert, afterupdate)
     * @return True if the event is enabled, false otherwise
     */
    public static Boolean isEventEnabled(String sObjectName, String triggerEvent) {
        if (String.isBlank(sObjectName) || String.isBlank(triggerEvent)) {
            return false;
        }
        
        // If triggers are not active for this object, no events are enabled
        if (!isActive(sObjectName)) {
            return false;
        }
        
        initializeCache();
        
        String objectKey = sObjectName.toLowerCase();
        String eventKey = triggerEvent.toLowerCase();
        
        // If no configuration exists for this object or event, default to enabled
        if (!eventEnablementByObjectAndEvent.containsKey(objectKey) || 
            !eventEnablementByObjectAndEvent.get(objectKey).containsKey(eventKey)) {
            return true;
        }
        
        return eventEnablementByObjectAndEvent.get(objectKey).get(eventKey);
    }
    
    /**
     * @description Get the configuration for a specific SObject type
     * @param sObjectType The SObject type
     * @return The trigger configuration metadata, or null if not found
     */
    public static AOF_TriggerConfiguration__mdt getConfiguration(SObjectType sObjectType) {
        if (sObjectType == null) {
            return null;
        }
        
        return getConfiguration(sObjectType.getDescribe().getName());
    }
    
    /**
     * @description Get the configuration for a specific SObject API name
     * @param sObjectName The SObject API name
     * @return The trigger configuration metadata, or null if not found
     */
    public static AOF_TriggerConfiguration__mdt getConfiguration(String sObjectName) {
        if (String.isBlank(sObjectName)) {
            return null;
        }
        
        initializeCache();
        
        String objectKey = sObjectName.toLowerCase();
        
        if (!configurationByObjectName.containsKey(objectKey)) {
            return null;
        }
        
        return configurationByObjectName.get(objectKey);
    }
    
    /**
     * @description Reset the configuration cache
     * This is primarily used for testing or when configurations may have changed
     */
    public static void resetCache() {
        configurationByObjectName = null;
        activeStatusByObjectName = null;
        eventEnablementByObjectAndEvent = null;
    }
}