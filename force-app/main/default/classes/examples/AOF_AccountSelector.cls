/**
 * @description Selector class for the Account SObject.
 * Responsible for all SOQL queries related to Accounts, ensuring security and bulkification.
 * Part of the Apex Orbit Framework (AOF).
 */
public with sharing class AOF_AccountSelector extends AOF_Application_Selector {

    /**
     * @description Constructor.
     */
    public AOF_AccountSelector() {
        super(Account.SObjectType);
    }

    /**
     * @description Defines the default fields to query for Accounts if none are specified.
     * @return Comma-separated string of default Account field names.
     */
    public override String getDefaultFields() {
        List<String> defaultFields = new List<String>{
            String.valueOf(Account.Id),
            String.valueOf(Account.Name),
            String.valueOf(Account.AccountNumber),
            String.valueOf(Account.Type),
            String.valueOf(Account.Industry),
            String.valueOf(Account.OwnerId),
            String.valueOf(Account.CreatedDate),
            String.valueOf(Account.LastModifiedDate)
        };
        // Filter fields based on FLS accessibility before joining
        List<String> accessibleFields = new List<String>();
        Map<String, SObjectField> fieldMap = getFieldMap();
        for(String fieldName : defaultFields){
            SObjectField fieldToken = fieldMap.get(fieldName.toLowerCase()); // fieldMap keys are lowercase
            if(fieldToken != null && fieldToken.getDescribe().isAccessible() && fieldToken.getDescribe().isQueryable()){
                accessibleFields.add(fieldName);
            }
        }
        return String.join(accessibleFields, ", ");
    }

    /**
     * @description Selects Account records by a set of Ids.
     * @param recordIds Set of Account Ids to query.
     * @return List of Account SObjects.
     */
    public List<Account> selectAccountsByIds(Set<Id> recordIds) {
        return (List<Account>) selectByIds(recordIds, null); // Uses default fields
    }

    /**
     * @description Selects Account records by a set of Ids, querying specified fields.
     * @param recordIds Set of Account Ids to query.
     * @param fieldsToQuery List of SObjectField tokens for Account fields to include in the query.
     * @return List of Account SObjects.
     */
    public List<Account> selectAccountsByIds(Set<Id> recordIds, List<SObjectField> fieldsToQuery) {
        return (List<Account>) selectByIds(recordIds, fieldsToQuery);
    }

    /**
     * @description Selects Account records with a specific Type.
     * @param accountType The Type of accounts to query.
     * @return List of Account SObjects.
     */
    public List<Account> selectAccountsByType(String accountType) {
        if (String.isBlank(accountType)) {
            return new List<Account>();
        }
        String condition = String.format(
            "Type = \'{0}\\'",
            new List<String>{String.escapeSingleQuotes(accountType)}
        );
        return (List<Account>) query(null, condition, null, null, null); // Uses default fields
    }

    /**
     * @description Selects Account records with a specific Industry and orders them by Name.
     * @param industry The Industry of accounts to query.
     * @return List of Account SObjects.
     */
    public List<Account> selectAccountsByIndustryOrderedByName(String industry) {
        if (String.isBlank(industry)) {
            return new List<Account>();
        }
        String condition = String.format(
            "Industry = \'{0}\\'",
            new List<String>{String.escapeSingleQuotes(industry)}
        );
        String orderBy = "Name ASC";
        return (List<Account>) query(null, condition, orderBy, null, null); // Uses default fields
    }
    
    /**
     * @description Selects all active Account records.
     *              This is an example and assumes an "Active__c" checkbox field exists.
     *              Modify as per your actual schema.
     * @return List of active Account SObjects.
     */
    /* // Uncomment and adapt if you have an Active__c field
    public List<Account> selectActiveAccounts() {
        // Ensure Active__c field is added to your Account SObject and is queryable
        // For this example, let's assume Active__c is a Checkbox field
        List<SObjectField> fields = new List<SObjectField>{
            Account.Id, Account.Name, Account.Active__c // Add other fields as needed
        };
        String condition = "Active__c = true";
        return (List<Account>) query(fields, condition, "Name ASC", null, null);
    }
    */
}

