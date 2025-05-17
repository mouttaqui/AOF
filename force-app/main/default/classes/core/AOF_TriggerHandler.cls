/**
 * @description A trigger handler that all SObject triggers delegate to.
 * It manages trigger context and orchestrates logic execution by calling appropriate methods
 * in the Domain or Service layers. Runs with sharing to respect user context.
 * Part of the Apex Orbit Framework (AOF).
 */
public with sharing class AOF_TriggerHandler {

    // --- Trigger Context Variables ---
    protected SObjectType sObjectType;
    protected List<SObject> newRecords;
    protected Map<Id, SObject> newMap;
    protected List<SObject> oldRecords;
    protected Map<Id, SObject> oldMap;
    protected System.TriggerOperation triggerOperation;

    // --- Bypass Mechanism ---
    private static Map<SObjectType, Boolean> bypassMap = new Map<SObjectType, Boolean>();
    public static Boolean bypassAll = false;

    // --- Unit of Work ---
    protected AOF_Application_UnitOfWork uow;

    /**
     * @description Constructor for the trigger handler.
     * @param sObjType The SObjectType being processed.
     * @param operation The current trigger operation type.
     */
    public AOF_TriggerHandler(SObjectType sObjType, System.TriggerOperation operation) {
        this.sObjectType = sObjType;
        this.triggerOperation = operation;
        this.newRecords = Trigger.new;
        this.newMap = (Map<Id, SObject>)Trigger.newMap;
        this.oldRecords = Trigger.old;
        this.oldMap = (Map<Id, SObject>)Trigger.oldMap;
        this.uow = new AOF_Application_UnitOfWork(); // Initialize a UoW instance for this transaction
    }

    /**
     * @description Main method to execute the trigger logic based on context.
     *              This method should be called from the SObject-specific trigger.
     */
    public void run() {
        if (isBypassed(this.sObjectType)) {
            return;
        }

        try {
            // The instantiation and dispatch to SObject-specific domain logic
            // would typically occur here. For a truly generic handler, this might involve
            // a factory pattern or a configurable dispatch mechanism (e.g., Custom Metadata)
            // to resolve the appropriate domain class for the SObjectType.
            // The virtual methods below serve as extension points for concrete handlers
            // or for a more sophisticated dispatch within this run method.

            if (this.triggerOperation == System.TriggerOperation.BEFORE_INSERT) {
                this.beforeInsert();
            } else if (this.triggerOperation == System.TriggerOperation.AFTER_INSERT) {
                this.afterInsert();
            } else if (this.triggerOperation == System.TriggerOperation.BEFORE_UPDATE) {
                this.beforeUpdate();
            } else if (this.triggerOperation == System.TriggerOperation.AFTER_UPDATE) {
                this.afterUpdate();
            } else if (this.triggerOperation == System.TriggerOperation.BEFORE_DELETE) {
                this.beforeDelete();
            } else if (this.triggerOperation == System.TriggerOperation.AFTER_DELETE) {
                this.afterDelete();
            } else if (this.triggerOperation == System.TriggerOperation.AFTER_UNDELETE) {
                this.afterUndelete();
            }

            // Commit DML operations registered with the Unit of Work
            // This should typically happen at the very end of all processing for the context (e.g., after all 'after' logic)
            // and only if the transaction is not already marked for rollback by adding errors to records.
            if (Trigger.isAfter && !hasFatalErrors()) { // Check if there are errors that should prevent commit
                 this.uow.commitWork();
            }

        } catch (Exception e) {
            AOF_ErrorHandlerService.logError(e, this.getClassName(), 'run', getRecordIdsFromContext(), this.sObjectType.getDescribe().getName(), 'Critical');
            // If an exception reaches here, it's an unexpected error.
            // Decide on re-throw strategy. If record.addError() was used for all foreseeable issues,
            // an exception here is truly unexpected and should probably cause a rollback.
            // However, to prevent users from seeing unhandled exception pages, ensure all user-facing errors
            // are added via record.addError().
            // For now, we let the error be logged. If no record.addError() was called, the transaction might still commit (bad).
            // A robust handler might add a generic error to all records in Trigger.new if an unhandled exception occurs in a before context.
            if(Trigger.isBefore && newRecords != null && !hasFatalErrors()){
                for(SObject record : newRecords){
                    // Add a generic error if one isn't already there from a more specific catch block
                    if(!record.hasErrors()) {
                        record.addError('An unexpected error occurred. Please contact your administrator. Error ID: ' + System.now().getTime()); // Provide a unique marker
                    }
                }
            }
            // Re-throwing the exception ensures the DML operation is rolled back by Salesforce if not already handled by addError.
            throw e; // Re-throw to ensure transaction rollback if not handled by addError
        }
    }

    // --- Context-Specific Methods (to be overridden or called by a dispatch mechanism) ---
    // These methods are intended to be the integration points for SObject-specific logic,
    // typically by invoking methods on a corresponding SObject Domain class.

    /**
     * @description Handler for before insert trigger context
     */
    protected virtual void beforeInsert() {
        // Implement in SObject-specific handler or dispatch to Domain
    }
    
    /**
     * @description Handler for after insert trigger context
     */
    protected virtual void afterInsert() {
        // Implement in SObject-specific handler or dispatch to Domain
    }
    
    /**
     * @description Handler for before update trigger context
     */
    protected virtual void beforeUpdate() {
        // Implement in SObject-specific handler or dispatch to Domain
    }
    
    /**
     * @description Handler for after update trigger context
     */
    protected virtual void afterUpdate() {
        // Implement in SObject-specific handler or dispatch to Domain
    }
    
    /**
     * @description Handler for before delete trigger context
     */
    protected virtual void beforeDelete() {
        // Implement in SObject-specific handler or dispatch to Domain
    }
    
    /**
     * @description Handler for after delete trigger context
     */
    protected virtual void afterDelete() {
        // Implement in SObject-specific handler or dispatch to Domain
    }
    
    /**
     * @description Handler for after undelete trigger context
     */
    protected virtual void afterUndelete() {
        // Implement in SObject-specific handler or dispatch to Domain
    }

    // --- Bypass Logic ---
    /**
     * @description Bypasses trigger execution for a specific SObject type
     * @param sObjType The SObject type to bypass
     */
    public static void bypass(SObjectType sObjType) {
        bypassMap.put(sObjType, true);
    }

    /**
     * @description Clears bypass for a specific SObject type
     * @param sObjType The SObject type to clear bypass for
     */
    public static void clearBypass(SObjectType sObjType) {
        bypassMap.put(sObjType, false);
    }

    /**
     * @description Checks if trigger execution is bypassed for a specific SObject type
     * @param sObjType The SObject type to check
     * @return True if bypassed, false otherwise
     */
    public static Boolean isBypassed(SObjectType sObjType) {
        if (bypassAll) {
            return true;
        }
        return bypassMap.containsKey(sObjType) && bypassMap.get(sObjType);
    }

    /**
     * @description Bypasses trigger execution for all SObject types
     */
    public static void bypassAllTriggers() {
        bypassAll = true;
    }

    /**
     * @description Clears bypass for all SObject types
     */
    public static void clearBypassAllTriggers() {
        bypassAll = false;
    }

    // --- Utility Methods ---
    /**
     * @description Gets record IDs from the current trigger context
     * @return List of record IDs
     */
    private List<Id> getRecordIdsFromContext() {
        List<Id> recordIds = new List<Id>();
        if (this.newRecords != null) {
            for (SObject sObj : this.newRecords) {
                if (sObj.Id != null) {
                    recordIds.add(sObj.Id);
                }
            }
        }
        // If new is empty (e.g. delete) or no Ids found yet, check old records
        if (recordIds.isEmpty() && this.oldRecords != null) { 
            for (SObject sObj : this.oldRecords) {
                if (sObj.Id != null) {
                    recordIds.add(sObj.Id);
                }
            }
        }
        return recordIds;
    }

    /**
     * @description Provides access to the UnitOfWork instance for this transaction.
     * @return The AOF_Application_UnitOfWork instance.
     */
    public AOF_Application_UnitOfWork getUnitOfWork() {
        return this.uow;
    }

    /**
     * @description Helper to get the actual class name for logging purposes, useful if this class is extended.
     * @return The class name
     */
    private String getClassName() {
        return String.valueOf(this).substring(0,String.valueOf(this).indexOf(':'));
    }

    /**
     * @description Checks if any records in the current context (Trigger.new for before triggers)
     *              have errors added to them. This can be used to prevent UoW commit.
     * @return True if fatal errors are present, false otherwise.
     */
    private Boolean hasFatalErrors() {
        if (Trigger.isBefore && this.newRecords != null) {
            for (SObject record : this.newRecords) {
                if (record.hasErrors()) {
                    return true;
                }
            }
        }
        // For after triggers, errors on Trigger.new might not prevent commit of already successful DML,
        // but an exception caught by the handler would be the primary rollback mechanism.
        return false;
    }
}