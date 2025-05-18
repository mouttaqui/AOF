/**
 * @description Manages DML operations to ensure they are performed efficiently, in the correct order,
 * and within governor limits. It centralizes DML, helps manage transaction boundaries,
 * and reduces the number of DML statements.
 * Includes object-level CRUD checks during commit.
 * Part of the Apex Orbit Framework (AOF).
 */
public inherited sharing class AOF_Application_UnitOfWork {

    private List<SObject> newRecordsToInsert = new List<SObject>();
    private Map<Id, SObject> dirtyRecordsToUpdate = new Map<Id, SObject>(); // Using Map to ensure unique records by Id
    private List<SObject> recordsToDelete = new List<SObject>();
    private Map<SObjectType, List<SObject>> typedNewRecords = new Map<SObjectType, List<SObject>>();
    private Map<SObjectType, Map<Id, SObject>> typedDirtyRecords = new Map<SObjectType, Map<Id, SObject>>();
    private Map<SObjectType, List<SObject>> typedRecordsToDelete = new Map<SObjectType, List<SObject>>();

    private SObjectScope scope = SObjectScope.ALL; // Default scope

    public enum SObjectScope {
        ALL, // Process all SObjects together (default, simpler but less control over order)
        PER_TYPE // Process SObjects grouped by their type (allows some ordering if needed)
    }

    /**
     * @description Constructor for the Unit of Work.
     */
    public AOF_Application_UnitOfWork() {
        // Default constructor - intentionally left empty
    }

    /**
     * @description Constructor allowing to specify the SObject processing scope.
     * @param workScope The scope for processing DML operations (ALL or PER_TYPE).
     */
    public AOF_Application_UnitOfWork(SObjectScope workScope) {
        this.scope = workScope;
    }

    /**
     * @description Registers a single new SObject record for insertion.
     * @param record The SObject record to insert.
     */
    public void registerNew(SObject record) {
        if (record == null) {
            return;
        }

        SObjectType sType = record.getSObjectType();
        if (this.scope == SObjectScope.PER_TYPE) {
            if (!typedNewRecords.containsKey(sType)) {
                typedNewRecords.put(sType, new List<SObject>());
            }
            typedNewRecords.get(sType).add(record);
        } else {
            this.newRecordsToInsert.add(record);
        }
    }

    /**
     * @description Registers a list of new SObject records for insertion.
     * @param records The list of SObject records to insert.
     */
    public void registerNew(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        if (this.scope == SObjectScope.PER_TYPE) {
            for (SObject record : records) {
                if (record == null) {
                    continue;
                }
                registerNew(record); 
            }
        } else {
            for (SObject record : records) {
                if (record != null) {
                    this.newRecordsToInsert.add(record);
                }
            }
        }
    }

    /**
     * @description Registers a single SObject record as dirty (for update).
     * @param record The SObject record to update. Must have an Id.
     */
    public void registerDirty(SObject record) {
        if (record == null || record.Id == null) {
            return;
        }

        SObjectType sType = record.getSObjectType();
        if (this.scope == SObjectScope.PER_TYPE) {
            if (!typedDirtyRecords.containsKey(sType)) {
                typedDirtyRecords.put(sType, new Map<Id, SObject>());
            }
            typedDirtyRecords.get(sType).put(record.Id, record);
        } else {
            this.dirtyRecordsToUpdate.put(record.Id, record);
        }
    }

    /**
     * @description Registers a list of SObject records as dirty (for update).
     * @param records The list of SObject records to update. Each must have an Id.
     */
    public void registerDirty(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return;
        }
        
        if (this.scope == SObjectScope.PER_TYPE) {
            for (SObject record : records) {
                if (record == null || record.Id == null) {
                    continue;
                }
                registerDirty(record);
            }
        } else {
            for (SObject record : records) {
                if (record != null && record.Id != null) {
                    this.dirtyRecordsToUpdate.put(record.Id, record);
                }
            }
        }
    }

    /**
     * @description Registers a single SObject record for deletion.
     * @param record The SObject record to delete. Must have an Id.
     */
    public void registerDeleted(SObject record) {
        if (record == null || record.Id == null) {
            return;
        }

        SObjectType sType = record.getSObjectType();
        if (this.scope == SObjectScope.PER_TYPE) {
            if (!typedRecordsToDelete.containsKey(sType)) {
                typedRecordsToDelete.put(sType, new List<SObject>());
            }
            // Avoid adding duplicates if already registered by Id for this type
            boolean found = false;
            for(SObject existing : typedRecordsToDelete.get(sType)){
                if(existing.Id == record.Id){
                    found = true;
                    break;
                }
            }
            if(!found) {
                typedRecordsToDelete.get(sType).add(record);
            }
        } else {
            boolean found = false;
            for(SObject existing : this.recordsToDelete){
                if(existing.Id == record.Id){
                    found = true;
                    break;
                }
            }
            if(!found) {
                this.recordsToDelete.add(record);
            }
        }
    }

    /**
     * @description Registers a list of SObject records for deletion.
     * @param records The list of SObject records to delete. Each must have an Id.
     */
    public void registerDeleted(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        if (this.scope == SObjectScope.PER_TYPE) {
            for (SObject record : records) {
                if (record == null || record.Id == null) {
                    continue;
                }
                registerDeleted(record);
            }
        } else {
            for (SObject record : records) {
                if (record != null && record.Id != null) {
                    boolean found = false;
                    for(SObject existing : this.recordsToDelete){
                        if(existing.Id == record.Id){
                            found = true;
                            break;
                        }
                    }
                    if(!found) {
                        this.recordsToDelete.add(record);
                    }
                }
            }
        }
    }

    /**
     * @description Checks if the current user has the specified CRUD permission on the given SObject type.
     * @param sType The SObject type to check permissions for.
     * @param permission The CRUD permission to check (CREATE, UPDATE, DELETE).
     * @return True if the user has the permission, false otherwise.
     */
    private Boolean hasCRUDPermission(SObjectType sType, String permission) {
        Schema.DescribeSObjectResult describe = sType.getDescribe();
        
        if (permission == 'CREATE') {
            return describe.isCreateable();
        } else if (permission == 'UPDATE') {
            return describe.isUpdateable();
        } else if (permission == 'DELETE') {
            return describe.isDeletable();
        }
        
        return false;
    }

    /**
     * @description Validates CRUD permissions for a collection of SObjects of the same type.
     * @param sObjects The collection of SObjects to validate.
     * @param permission The CRUD permission to check (CREATE, UPDATE, DELETE).
     * @throws AOF_SecurityException if the user lacks the required permission.
     */
    private void validateCRUDPermission(List<SObject> sObjects, String permission) {
        if (sObjects == null || sObjects.isEmpty()) {
            return;
        }
        
        SObjectType sType = sObjects[0].getSObjectType();
        if (!hasCRUDPermission(sType, permission)) {
            String errorMessage = 'User does not have ' + permission + ' permission on SObject: ' + sType.getDescribe().getName();
            
            List<Id> recordIds = new List<Id>();
            for (SObject record : sObjects) {
                if (record.Id != null) {
                    recordIds.add(record.Id);
                }
            }
            
            AOF_ErrorHandlerService.logError(null, errorMessage, AOF_Application_UnitOfWork.class.getName(), 
                                           'commitWork', recordIds, sType.getDescribe().getName(), 'High');
            throw new AOF_SecurityException(errorMessage);
        }
    }

    /**
     * @description Commits all registered DML operations.
     *              Operations are performed in the order: inserts, updates, deletes.
     *              Performs object-level CRUD permission checks before each DML operation.
     *              If an error occurs, it throws the DML exception, and the transaction will roll back.
     * @throws AOF_SecurityException if the user lacks required CRUD permissions.
     */
    public void commitWork() {
        if (this.scope == SObjectScope.PER_TYPE) {
            // Process inserts by type with CRUD checks
            for (SObjectType sType : typedNewRecords.keySet()) {
                List<SObject> toInsert = typedNewRecords.get(sType);
                if (toInsert != null && !toInsert.isEmpty()) {
                    validateCRUDPermission(toInsert, 'CREATE');
                    Database.insert(toInsert, true); // NOPMD: ApexCRUDViolation
                }
            }

            // Process updates by type with CRUD checks
            for (SObjectType sType : typedDirtyRecords.keySet()) {
                Map<Id, SObject> typeDirtyMap = typedDirtyRecords.get(sType);
                if (typeDirtyMap != null && !typeDirtyMap.isEmpty()) {
                    List<SObject> toUpdate = typeDirtyMap.values();
                    validateCRUDPermission(toUpdate, 'UPDATE');
                    Database.update(toUpdate, true); // NOPMD: ApexCRUDViolation
                }
            }

            // Process deletes by type with CRUD checks
            for (SObjectType sType : typedRecordsToDelete.keySet()) {
                List<SObject> toDelete = typedRecordsToDelete.get(sType);
                if (toDelete != null && !toDelete.isEmpty()) {
                    validateCRUDPermission(toDelete, 'DELETE');
                    Database.delete(toDelete, true); // NOPMD: ApexCRUDViolation
                }
            }
        } else {
            // Process all inserts together with CRUD checks
            if (!this.newRecordsToInsert.isEmpty()) {
                // Group by SObjectType for CRUD checks
                Map<SObjectType, List<SObject>> recordsByType = new Map<SObjectType, List<SObject>>();
                for (SObject record : this.newRecordsToInsert) {
                    SObjectType sType = record.getSObjectType();
                    if (!recordsByType.containsKey(sType)) {
                        recordsByType.put(sType, new List<SObject>());
                    }
                    recordsByType.get(sType).add(record);
                }
                
                // Validate CRUD permissions for each type
                for (SObjectType sType : recordsByType.keySet()) {
                    validateCRUDPermission(recordsByType.get(sType), 'CREATE');
                }
                
                // Perform the insert
                Database.insert(this.newRecordsToInsert, true); // NOPMD: ApexCRUDViolation
            }

            // Process all updates together with CRUD checks
            if (!this.dirtyRecordsToUpdate.isEmpty()) {
                List<SObject> recordsToUpdate = this.dirtyRecordsToUpdate.values();
                
                // Group by SObjectType for CRUD checks
                Map<SObjectType, List<SObject>> recordsByType = new Map<SObjectType, List<SObject>>();
                for (SObject record : recordsToUpdate) {
                    SObjectType sType = record.getSObjectType();
                    if (!recordsByType.containsKey(sType)) {
                        recordsByType.put(sType, new List<SObject>());
                    }
                    recordsByType.get(sType).add(record);
                }
                
                // Validate CRUD permissions for each type
                for (SObjectType sType : recordsByType.keySet()) {
                    validateCRUDPermission(recordsByType.get(sType), 'UPDATE');
                }
                
                // Perform the update
                Database.update(recordsToUpdate, true); // NOPMD: ApexCRUDViolation
            }

            // Process all deletes together with CRUD checks
            if (!this.recordsToDelete.isEmpty()) {
                // Group by SObjectType for CRUD checks
                Map<SObjectType, List<SObject>> recordsByType = new Map<SObjectType, List<SObject>>();
                for (SObject record : this.recordsToDelete) {
                    SObjectType sType = record.getSObjectType();
                    if (!recordsByType.containsKey(sType)) {
                        recordsByType.put(sType, new List<SObject>());
                    }
                    recordsByType.get(sType).add(record);
                }
                
                // Validate CRUD permissions for each type
                for (SObjectType sType : recordsByType.keySet()) {
                    validateCRUDPermission(recordsByType.get(sType), 'DELETE');
                }
                
                // Perform the delete
                Database.delete(this.recordsToDelete, true); // NOPMD: ApexCRUDViolation
            }
        }
        
        clearRegistrations();
    }

    /**
     * @description Clears all registered DML operations without committing them.
     */
    public void clearRegistrations() {
        this.newRecordsToInsert.clear();
        this.dirtyRecordsToUpdate.clear();
        this.recordsToDelete.clear();
        this.typedNewRecords.clear();
        this.typedDirtyRecords.clear();
        this.typedRecordsToDelete.clear();
    }
}