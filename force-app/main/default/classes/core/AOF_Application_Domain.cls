/**
 * @description Base class for Domain layer logic. Domain classes encapsulate logic specific to an SObject.
 * It operates on a list of SObject records, ensuring bulkification.
 * Runs with sharing to respect user's data visibility and sharing rules.
 * Part of the Apex Orbit Framework (AOF).
 */
public abstract with sharing class AOF_Application_Domain {

    protected List<SObject> records;
    protected Map<Id, SObject> oldMap;
    protected Map<Id, SObject> newMap;
    protected SObjectType sObjectType;

    /**
     * @description Constructor for domain classes.
     * @param newRecords List of new SObject records from Trigger.new
     * @param oldRecordsMap Map of old SObject records from Trigger.oldMap
     */
    public AOF_Application_Domain(List<SObject> newRecords, Map<Id, SObject> oldRecordsMap) {
        this.records = newRecords != null ? newRecords : new List<SObject>();
        this.oldMap = oldRecordsMap != null ? oldRecordsMap : new Map<Id, SObject>();
        this.newMap = new Map<Id, SObject>();

        if (!this.records.isEmpty()) {
            this.sObjectType = this.records[0].getSObjectType();
            for (SObject record : this.records) {
                if (record.Id != null) {
                    this.newMap.put(record.Id, record);
                }
            }
        } else if (!this.oldMap.isEmpty()) {
            // Handle delete context where Trigger.new is empty
            // SObjectType needs to be derived from oldMap if records is empty
            SObject firstOldRecord = this.oldMap.values()[0];
            if (firstOldRecord != null) {
                this.sObjectType = firstOldRecord.getSObjectType();
            }
        }
    }

    /**
     * @description Constructor for delete context or scenarios where only oldMap is relevant.
     * @param oldRecordsMap Map of old SObject records from Trigger.oldMap
     * @param sObjectType The SObjectType being processed.
     */
    public AOF_Application_Domain(Map<Id, SObject> oldRecordsMap, SObjectType sObjType) {
        this.records = new List<SObject>(); // No new records in this context
        this.oldMap = oldRecordsMap != null ? oldRecordsMap : new Map<Id, SObject>();
        this.newMap = new Map<Id, SObject>();
        this.sObjectType = sObjType;
    }

    // --- Trigger Context Methods --- 
    // Concrete domain classes will override these methods to implement specific logic.

    /**
     * @description Logic to execute in before insert trigger context
     */
    public virtual void onBeforeInsert() { // NOPMD: EmptyStatementBlock
        // Implement in concrete domain classes
    }
    
    /**
     * @description Logic to execute in after insert trigger context
     */
    public virtual void onAfterInsert() { // NOPMD: EmptyStatementBlock
        // Implement in concrete domain classes
    }
    
    /**
     * @description Logic to execute in before update trigger context
     */
    public virtual void onBeforeUpdate() { // NOPMD: EmptyStatementBlock
        // Implement in concrete domain classes
    }
    
    /**
     * @description Logic to execute in after update trigger context
     */
    public virtual void onAfterUpdate() { // NOPMD: EmptyStatementBlock
        // Implement in concrete domain classes
    }
    
    /**
     * @description Logic to execute in before delete trigger context
     */
    public virtual void onBeforeDelete() { // NOPMD: EmptyStatementBlock
        // Implement in concrete domain classes
    }
    
    /**
     * @description Logic to execute in after delete trigger context
     */
    public virtual void onAfterDelete() { // NOPMD: EmptyStatementBlock
        // Implement in concrete domain classes
    }
    
    /**
     * @description Logic to execute in after undelete trigger context
     */
    public virtual void onUndelete() { // NOPMD: EmptyStatementBlock
        // Implement in concrete domain classes
    }

    // --- Common Utility Methods --- 

    /**
     * @description A utility method to get a specific field value from the old version of a record.
     * @param recordId The Id of the record.
     * @param field The API name of the field.
     * @return The value of the field from the old record, or null if not found.
     */
    protected Object getOldValue(Id recordId, SObjectField field) {
        if (recordId == null || field == null) {
            return null;
        }
        
        if (this.oldMap != null && this.oldMap.containsKey(recordId)) {
            return this.oldMap.get(recordId).get(field);
        }
        return null;
    }

    /**
     * @description Checks if a specific field has changed for a record during an update.
     * @param recordId The Id of the record.
     * @param field The API name of the field.
     * @return True if the field value has changed, false otherwise.
     */
    protected Boolean fieldHasChanged(Id recordId, SObjectField field) {
        if (recordId == null || field == null) {
            return false;
        }
        
        if (this.newMap.containsKey(recordId) && this.oldMap != null && this.oldMap.containsKey(recordId)) {
            SObject newRecord = this.newMap.get(recordId);
            SObject oldRecord = this.oldMap.get(recordId);
            
            Object newValue = newRecord.get(field);
            Object oldValue = oldRecord.get(field);
            
            // Handle null values properly
            if (newValue == null && oldValue == null) {
                return false;
            }
            if (newValue == null || oldValue == null) {
                return true;
            }
            
            return newValue != oldValue;
        }
        return false;
    }

    /**
     * @description Adds an SObject-level error.
     * @param record The SObject record to add the error to.
     * @param errorMessage The error message.
     */
    protected void addError(SObject record, String errorMessage) {
        if (record != null && String.isNotBlank(errorMessage)) {
            record.addError(errorMessage);
        }
    }

    /**
     * @description Adds a field-specific error.
     * @param record The SObject record to add the error to.
     * @param field The SObjectField to associate the error with.
     * @param errorMessage The error message.
     */
    protected void addError(SObject record, SObjectField field, String errorMessage) {
        if (record == null || String.isBlank(errorMessage)) {
            return;
        }
        
        if (field != null) {
            record.addError(field, errorMessage);
        } else {
            record.addError(errorMessage);
        }
    }
}