/**
 * @description Base class for Selector layer logic. Selector classes are responsible for querying SObjects.
 * They ensure that queries are efficient, bulkified, and respect security (CRUD/FLS).
 * Runs with sharing to respect user's data visibility and sharing rules.
 * Part of the Apex Orbit Framework (AOF).
 */
public abstract with sharing class AOF_Application_Selector {

    protected SObjectType sObjectType;

    /**
     * @description Constructor for selector classes.
     * @param sObjType The SObjectType this selector will operate on.
     */
    public AOF_Application_Selector(SObjectType sObjType) {
        this.sObjectType = sObjType;
    }

    /**
     * @description Gets the SObjectType this selector is for.
     * @return SObjectType
     */
    public SObjectType getSObjectType() {
        return this.sObjectType;
    }

    /**
     * @description Gets the field map for the SObject.
     * @return Map<String, SObjectField> of field names to SObjectField tokens.
     */
    public Map<String, SObjectField> getFieldMap() {
        return this.sObjectType.getDescribe().fields.getMap();
    }

    /**
     * @description Gets a list of all queryable field API names for the SObject.
     *              This method respects FLS by checking isAccessible() and isQueryable().
     * @return List<String> of field API names.
     */
    public List<String> getAllQueryableFields() {
        List<String> fieldNames = new List<String>();
        Map<String, SObjectField> fieldMap = getFieldMap();
        
        for (String fieldName : fieldMap.keySet()) {
            DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
            if (fieldDescribe.isAccessible() && fieldDescribe.isQueryable()) {
                fieldNames.add(fieldName);
            }
        }
        return fieldNames;
    }

    /**
     * @description Selects records by a set of Ids. Enforces FLS and CRUD security using WITH SECURITY_ENFORCED.
     * @param recordIds Set of Ids to query.
     * @param fieldsToQuery List of SObjectField tokens to include in the query. If null or empty, queries a default set of fields.
     * @return List of SObjects.
     */
    public virtual List<SObject> selectByIds(Set<Id> recordIds, List<SObjectField> fieldsToQuery) {
        if (recordIds == null || recordIds.isEmpty()) {
            return new List<SObject>();
        }

        String fields = fieldsToQuery != null && !fieldsToQuery.isEmpty() ? buildFieldList(fieldsToQuery) : getDefaultFields();
        
        // Ensure Id is always queried if not explicitly included, as it's fundamental.
        if (!fields.toLowerCase().contains('id')) {
            fields = String.isNotBlank(fields) ? (
                'Id' + (fields.startsWith(',') ? fields : ',' + fields)
            ) : 'Id';
        }
        
        String query = String.format(
            'SELECT {0} FROM {1} WHERE Id IN :recordIds WITH SECURITY_ENFORCED',
            new List<String>{fields, this.sObjectType.getDescribe().getName()}
        );
        
        return Database.query(query);
    }

    /**
     * @description Builds a comma-separated string of field API names from a list of SObjectField tokens.
     *              Ensures fields are accessible and queryable before adding to the list.
     * @param fields List of SObjectField tokens.
     * @return Comma-separated string of field names.
     */
    protected String buildFieldList(List<SObjectField> fields) {
        if (fields == null || fields.isEmpty()) {
            return getDefaultFields();
        }
        
        List<String> fieldNames = new List<String>();
        for (SObjectField field : fields) {
            if (field == null) {
                continue;
            }
            
            DescribeFieldResult fieldDescribe = field.getDescribe();
            if (fieldDescribe.isAccessible() && fieldDescribe.isQueryable()) {
                fieldNames.add(fieldDescribe.getName());
            }
        }
        
        if (fieldNames.isEmpty()) {
            // Fallback to default fields if no accessible/queryable fields were provided
            return getDefaultFields();
        }
        
        return String.join(fieldNames, ', ');
    }

    /**
     * @description Defines a default set of fields to query if none are specified. 
     *              Concrete selectors should override this to provide meaningful defaults for their SObject.
     *              By default, it queries only the Id field.
     * @return Comma-separated string of default field names.
     */
    public virtual String getDefaultFields() {
        return 'Id';
    }

    /**
     * @description A utility method to construct a query string with optional WHERE, ORDER BY, LIMIT, and OFFSET clauses.
     *              Ensures security is enforced using WITH SECURITY_ENFORCED.
     * @param fieldsToQuery List of SObjectField tokens for the SELECT clause.
     * @param condition String for the WHERE clause (e.g., "Name = 'Test'"). Should be properly escaped if dynamic.
     * @param orderBy String for the ORDER BY clause (e.g., "CreatedDate DESC").
     * @param limitCount Integer for the LIMIT clause.
     * @param offsetCount Integer for the OFFSET clause.
     * @return List of SObjects matching the query.
     * @throws QueryException if the query is invalid or FLS/CRUD checks fail.
     */
    public List<SObject> query(
        List<SObjectField> fieldsToQuery, 
        String condition, 
        String orderBy, 
        Integer limitCount, 
        Integer offsetCount
    ) {
        String fieldList = buildFieldList(fieldsToQuery);
        
        // Ensure Id is always queried if not explicitly included
        if (!fieldList.toLowerCase().contains('id')) {
            fieldList = String.isNotBlank(fieldList) ? (
                'Id' + (fieldList.startsWith(',') ? fieldList : ',' + fieldList)
            ) : 'Id';
        }

        String queryString = String.format(
            'SELECT {0} FROM {1}',
            new List<String>{fieldList, this.sObjectType.getDescribe().getName()}
        );

        if (String.isNotBlank(condition)) {
            queryString += ' WHERE ' + condition;
        }
        
        if (String.isNotBlank(orderBy)) {
            queryString += ' ORDER BY ' + orderBy;
        }
        
        if (limitCount != null && limitCount > 0) {
            queryString += ' LIMIT ' + limitCount;
        }
        
        if (offsetCount != null && offsetCount > 0) {
            queryString += ' OFFSET ' + offsetCount;
        }
        
        queryString += ' WITH SECURITY_ENFORCED';

        return Database.query(queryString);
    }
}