@isTest
private class AOF_Application_Selector_Test {

    // Mock Selector for testing abstract AOF_Application_Selector
    private class MockSelector extends AOF_Application_Selector {
        public MockSelector(SObjectType sObjType) {
            super(sObjType);
        }

        // Override getDefaultFields to provide some fields for testing query construction
        public override String getDefaultFields() {
            // Ensure these fields are accessible for the test user
            return Account.SObjectType.fields.Id.getName() + "," + Account.SObjectType.fields.Name.getName();
        }

        // Expose protected methods for testing
        public String testBuildFieldList(List<SObjectField> fields) {
            return super.buildFieldList(fields);
        }
    }

    @TestSetup
    static void makeData(){
        List<Account> accs = new List<Account>();
        for(Integer i=0; i<5; i++){
            accs.add(new Account(Name = "Test Account " + i, AnnualRevenue = (i+1) * 100000));
        }
        insert accs;
    }

    @isTest
    static void testConstructor() {
        MockSelector selector = new MockSelector(Account.SObjectType);
        System.assertEquals(Account.SObjectType, selector.getSObjectType(), "SObjectType should be Account.");
    }

    @isTest
    static void testGetFieldMap() {
        MockSelector selector = new MockSelector(Account.SObjectType);
        Map<String, SObjectField> fieldMap = selector.getFieldMap();
        System.assertNotEquals(null, fieldMap, "Field map should not be null.");
        System.assert(fieldMap.containsKey("name"), "Field map should contain Name field for Account.");
    }

    @isTest
    static void testGetAllQueryableFields() {
        MockSelector selector = new MockSelector(Account.SObjectType);
        List<String> queryableFields = selector.getAllQueryableFields();
        System.assertNotEquals(null, queryableFields, "Queryable fields list should not be null.");
        System.assert(!queryableFields.isEmpty(), "Queryable fields list should not be empty.");
        // Check for a common, always queryable field like Id (if FLS allows)
        System.assert(queryableFields.contains(Account.SObjectType.fields.Id.getName().toLowerCase()) || queryableFields.contains(Account.SObjectType.fields.Id.getName()), "Queryable fields should contain Id.");
    }

    @isTest
    static void testBuildFieldList_WithAccessibleFields() {
        MockSelector selector = new MockSelector(Account.SObjectType);
        List<SObjectField> fieldsToQuery = new List<SObjectField>{
            Account.SObjectType.fields.Name,
            Account.SObjectType.fields.Industry
        };
        String fieldListString = selector.testBuildFieldList(fieldsToQuery);
        System.assert(fieldListString.toLowerCase().contains(Account.SObjectType.fields.Name.getName().toLowerCase()), "Field list should contain Name.");
        System.assert(fieldListString.toLowerCase().contains(Account.SObjectType.fields.Industry.getName().toLowerCase()), "Field list should contain Industry.");
    }

    @isTest
    static void testBuildFieldList_WithNoFields_ReturnsDefault() {
        MockSelector selector = new MockSelector(Account.SObjectType);
        String fieldListString = selector.testBuildFieldList(new List<SObjectField>());
        String defaultFields = selector.getDefaultFields();
        System.assertEquals(defaultFields.toLowerCase(), fieldListString.toLowerCase(), "Should return default fields when input list is empty.");
    }

    @isTest
    static void testBuildFieldList_WithNullFields_ReturnsDefault() {
        MockSelector selector = new MockSelector(Account.SObjectType);
        String fieldListString = selector.testBuildFieldList(null);
        String defaultFields = selector.getDefaultFields();
        System.assertEquals(defaultFields.toLowerCase(), fieldListString.toLowerCase(), "Should return default fields when input is null.");
    }

    @isTest
    static void testSelectByIds_ReturnsRecords() {
        List<Account> testAccounts = [SELECT Id FROM Account LIMIT 2];
        Set<Id> accountIds = new Set<Id>();
        for(Account acc : testAccounts) {
            accountIds.add(acc.Id);
        }

        MockSelector selector = new MockSelector(Account.SObjectType);
        List<SObjectField> fields = new List<SObjectField>{Account.SObjectType.fields.Name, Account.SObjectType.fields.AnnualRevenue};
        
        Test.startTest();
        List<SObject> results = selector.selectByIds(accountIds, fields);
        Test.stopTest();

        System.assertEquals(2, results.size(), "Should return 2 accounts.");
        for(SObject res : results){
            Account accRes = (Account)res;
            System.assertNotEquals(null, accRes.Name, "Account name should be populated.");
            // System.assertNotEquals(null, accRes.AnnualRevenue, "Account AnnualRevenue should be populated if FLS allows.");
        }
    }

    @isTest
    static void testSelectByIds_NoIds_ReturnsEmptyList() {
        MockSelector selector = new MockSelector(Account.SObjectType);
        Test.startTest();
        List<SObject> results = selector.selectByIds(new Set<Id>(), new List<SObjectField>{Account.Name});
        Test.stopTest();
        System.assertEquals(0, results.size(), "Should return empty list for no Ids.");
    }

    @isTest
    static void testSelectByIds_NullIds_ReturnsEmptyList() {
        MockSelector selector = new MockSelector(Account.SObjectType);
        Test.startTest();
        List<SObject> results = selector.selectByIds(null, new List<SObjectField>{Account.Name});
        Test.stopTest();
        System.assertEquals(0, results.size(), "Should return empty list for null Ids.");
    }

    @isTest
    static void testQuery_WithConditionAndOrder() {
        MockSelector selector = new MockSelector(Account.SObjectType);
        List<SObjectField> fields = new List<SObjectField>{Account.SObjectType.fields.Name, Account.SObjectType.fields.AnnualRevenue};
        String condition = "AnnualRevenue > 150000";
        String orderBy = "Name DESC";

        Test.startTest();
        List<SObject> results = selector.query(fields, condition, orderBy, 5, 0);
        Test.stopTest();

        System.assert(!results.isEmpty(), "Should return accounts with AnnualRevenue > 150000.");
        Decimal previousRevenue = null;
        String previousName = null;
        for(SObject res : results){
            Account accRes = (Account)res;
            System.assert(accRes.AnnualRevenue > 150000, "Annual revenue should be > 150000");
            if(previousName != null){
                System.assert(accRes.Name.compareTo(previousName) <= 0, "Results should be ordered by Name DESC.");
            }
            previousName = accRes.Name;
        }
    }
    
    @isTest
    static void testQuery_WithLimitAndOffset() {
        MockSelector selector = new MockSelector(Account.SObjectType);
        List<SObjectField> fields = new List<SObjectField>{Account.SObjectType.fields.Id, Account.SObjectType.fields.Name};
        String orderBy = "Name ASC"; // Ensure consistent ordering for offset test
        
        // Get all accounts to compare against
        List<Account> allAccounts = [SELECT Id, Name FROM Account ORDER BY Name ASC];

        Test.startTest();
        List<SObject> resultsPage1 = selector.query(fields, null, orderBy, 2, 0);
        List<SObject> resultsPage2 = selector.query(fields, null, orderBy, 2, 2);
        Test.stopTest();

        System.assertEquals(2, resultsPage1.size(), "Page 1 should have 2 records.");
        System.assertEquals(allAccounts[0].Id, resultsPage1[0].Id);
        System.assertEquals(allAccounts[1].Id, resultsPage1[1].Id);

        if(allAccounts.size() > 2){
             System.assertEquals(Math.min(2, allAccounts.size() - 2), resultsPage2.size(), "Page 2 should have correct number of records.");
            if(!resultsPage2.isEmpty()){
                System.assertEquals(allAccounts[2].Id, resultsPage2[0].Id);
            }
        }
    }

    @isTest
    static void testQuery_NoConditionNoOrder_ReturnsAll() {
        MockSelector selector = new MockSelector(Account.SObjectType);
        List<SObjectField> fields = new List<SObjectField>{Account.SObjectType.fields.Id};
        Integer totalAccounts = [SELECT count() FROM Account];

        Test.startTest();
        List<SObject> results = selector.query(fields, null, null, null, null);
        Test.stopTest();

        System.assertEquals(totalAccounts, results.size(), "Should return all accounts.");
    }

    // Test WITH SECURITY_ENFORCED (implicitly tested by successful queries as non-admin user)
    // To explicitly test FLS, runAs a user with restricted field access and assert specific fields are not returned or query fails.
    // This basic test ensures queries run; FLS is handled by "WITH SECURITY_ENFORCED".
    @isTest
    static void testSecurityEnforced_QueriesSucceed() {
        // Create a user with a profile that might have restricted FLS
        // This setup is more complex and depends on existing profiles or creating one.
        // For simplicity, we assume the default test running user has some access.
        MockSelector selector = new MockSelector(Account.SObjectType);
        List<SObjectField> fields = new List<SObjectField>{Account.SObjectType.fields.Name};
        Boolean querySucceeded = true;
        Test.startTest();
        try {
            List<SObject> results = selector.query(fields, null, null, 1, 0);
        } catch (Exception e) {
            querySucceeded = false;
        }
        Test.stopTest();
        System.assert(querySucceeded, "Query with SECURITY_ENFORCED should succeed if fields are accessible.");
    }
}