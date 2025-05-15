/**
 * @description Manages DML operations to ensure they are performed efficiently, in the correct order,
 * and within governor limits. It centralizes DML, helps manage transaction boundaries,
 * and reduces the number of DML statements.
 * Part of the Apex Orbit Framework (AOF).
 */
public class AOF_Application_UnitOfWork {

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
        // Default constructor
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
        if (record == null) return;
        if (this.scope == SObjectScope.PER_TYPE) {
            SObjectType sType = record.getSObjectType();
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
        if (records == null || records.isEmpty()) return;
        if (this.scope == SObjectScope.PER_TYPE) {
            for (SObject record : records) {
                registerNew(record); // Delegate to single record method for typed grouping
            }
        } else {
            this.newRecordsToInsert.addAll(records);
        }
    }

    /**
     * @description Registers a single SObject record as dirty (for update).
     * @param record The SObject record to update. Must have an Id.
     */
    public void registerDirty(SObject record) {
        if (record == null || record.Id == null) return;
        if (this.scope == SObjectScope.PER_TYPE) {
            SObjectType sType = record.getSObjectType();
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
        if (records == null || records.isEmpty()) return;
        if (this.scope == SObjectScope.PER_TYPE) {
            for (SObject record : records) {
                registerDirty(record); // Delegate to single record method for typed grouping
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
        if (record == null || record.Id == null) return;
        if (this.scope == SObjectScope.PER_TYPE) {
            SObjectType sType = record.getSObjectType();
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
            if(!found) typedRecordsToDelete.get(sType).add(record);
        } else {
            // Avoid adding duplicates if already registered by Id
            boolean found = false;
            for(SObject existing : this.recordsToDelete){
                if(existing.Id == record.Id){
                    found = true;
                    break;
                }
            }
            if(!found) this.recordsToDelete.add(record);
        }
    }

    /**
     * @description Registers a list of SObject records for deletion.
     * @param records The list of SObject records to delete. Each must have an Id.
     */
    public void registerDeleted(List<SObject> records) {
        if (records == null || records.isEmpty()) return;
        if (this.scope == SObjectScope.PER_TYPE) {
            for (SObject record : records) {
                registerDeleted(record); // Delegate to single record method for typed grouping
            }
        } else {
            for (SObject record : records) {
                if (record != null && record.Id != null) {
                     // Avoid adding duplicates if already registered by Id
                    boolean found = false;
                    for(SObject existing : this.recordsToDelete){
                        if(existing.Id == record.Id){
                            found = true;
                            break;
                        }
                    }
                    if(!found) this.recordsToDelete.add(record);
                }
            }
        }
    }

    /**
     * @description Commits all registered DML operations.
     *              Operations are performed in the order: inserts, updates, deletes.
     *              If an error occurs, it throws the DML exception, and the transaction will roll back.
     *              Consider adding partial success handling if required by specific use cases.
     */
    public void commitWork() {
        // Order of operations: Inserts, Updates, Deletes
        // This order is generally safest to avoid issues with relationships and dependencies.

        if (this.scope == SObjectScope.PER_TYPE) {
            // Process inserts by type
            for (SObjectType sType : typedNewRecords.keySet()) {
                List<SObject> toInsert = typedNewRecords.get(sType);
                if (toInsert != null && !toInsert.isEmpty()) {
                    Database.insert(toInsert, true); // allOrNone = true
                }
            }

            // Process updates by type
            for (SObjectType sType : typedDirtyRecords.keySet()) {
                Map<Id, SObject> typeDirtyMap = typedDirtyRecords.get(sType);
                if (typeDirtyMap != null && !typeDirtyMap.isEmpty()) {
                    Database.update(typeDirtyMap.values(), true);
                }
            }

            // Process deletes by type
            for (SObjectType sType : typedRecordsToDelete.keySet()) {
                List<SObject> toDelete = typedRecordsToDelete.get(sType);
                if (toDelete != null && !toDelete.isEmpty()) {
                    Database.delete(toDelete, true);
                }
            }
        } else {
            // Process all inserts together
            if (!this.newRecordsToInsert.isEmpty()) {
                Database.insert(this.newRecordsToInsert, true);
            }

            // Process all updates together
            if (!this.dirtyRecordsToUpdate.isEmpty()) {
                Database.update(this.dirtyRecordsToUpdate.values(), true);
            }

            // Process all deletes together
            if (!this.recordsToDelete.isEmpty()) {
                Database.delete(this.recordsToDelete, true);
            }
        }

        // Clear collections after commit
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

