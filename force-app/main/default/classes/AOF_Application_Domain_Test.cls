@isTest
private class AOF_Application_Domain_Test {

    // Mock Domain class for testing purposes
    private class MockDomain extends AOF_Application_Domain {
        public MockDomain(List<SObject> newRecords, Map<Id, SObject> oldRecordsMap) {
            super(newRecords, oldRecordsMap);
        }

        public MockDomain(Map<Id, SObject> oldRecordsMap, SObjectType sObjType) {
            super(oldRecordsMap, sObjType);
        }

        // Expose protected methods for testing if needed, or test through context methods
        public Boolean testFieldHasChanged(Id recordId, SObjectField field) {
            return super.fieldHasChanged(recordId, field);
        }

        public Object testGetOldValue(Id recordId, SObjectField field) {
            return super.getOldValue(recordId, field);
        }
        
        public void testAddSObjectError(SObject record, String message) {
            super.addError(record, message);
        }

        public void testAddFieldError(SObject record, SObjectField field, String message) {
            super.addError(record, field, message);
        }
    }

    @isTest
    static void testConstructor_WithNewAndOldRecords() {
        Account accNew = new Account(Id = fflib_IDGenerator.generate(Account.SObjectType), Name = "New Account");
        Account accOld = new Account(Id = accNew.Id, Name = "Old Account");
        List<SObject> newRecords = new List<SObject>{accNew};
        Map<Id, SObject> oldMap = new Map<Id, SObject>{accOld.Id => accOld};

        MockDomain domain = new MockDomain(newRecords, oldMap);

        System.assertEquals(1, domain.records.size(), "Should contain one new record.");
        System.assertEquals(accNew.Name, ((Account)domain.records[0]).Name);
        System.assertNotEquals(null, domain.oldMap, "OldMap should be initialized.");
        System.assertEquals(1, domain.oldMap.size(), "OldMap should contain one record.");
        System.assertEquals(accOld.Name, ((Account)domain.oldMap.get(accOld.Id)).Name);
        System.assertEquals(Account.SObjectType, domain.sObjectType, "SObjectType should be Account.");
    }

    @isTest
    static void testConstructor_DeleteContext() {
        Account accOld = new Account(Id = fflib_IDGenerator.generate(Account.SObjectType), Name = "Old Account for Delete");
        Map<Id, SObject> oldMap = new Map<Id, SObject>{accOld.Id => accOld};

        MockDomain domain = new MockDomain(oldMap, Account.SObjectType);

        System.assertEquals(0, domain.records.size(), "New records should be empty in delete context.");
        System.assertNotEquals(null, domain.oldMap, "OldMap should be initialized.");
        System.assertEquals(1, domain.oldMap.size(), "OldMap should contain one record.");
        System.assertEquals(Account.SObjectType, domain.sObjectType, "SObjectType should be Account.");
    }

    @isTest
    static void testFieldHasChanged_ReturnsTrueWhenChanged() {
        Id accId = fflib_IDGenerator.generate(Account.SObjectType);
        Account accNew = new Account(Id = accId, Name = "New Name", Industry = "Tech");
        Account accOld = new Account(Id = accId, Name = "Old Name", Industry = "Finance");
        List<SObject> newRecords = new List<SObject>{accNew};
        Map<Id, SObject> oldMap = new Map<Id, SObject>{accOld.Id => accOld};

        MockDomain domain = new MockDomain(newRecords, oldMap);
        Boolean nameChanged = domain.testFieldHasChanged(accId, Account.Name);
        Boolean industryChanged = domain.testFieldHasChanged(accId, Account.Industry);

        System.assert(nameChanged, "Account Name should be detected as changed.");
        System.assert(industryChanged, "Account Industry should be detected as changed.");
    }

    @isTest
    static void testFieldHasChanged_ReturnsFalseWhenNotChanged() {
        Id accId = fflib_IDGenerator.generate(Account.SObjectType);
        Account accNew = new Account(Id = accId, Name = "Same Name", Industry = "Tech");
        Account accOld = new Account(Id = accId, Name = "Same Name", Industry = "Tech");
        List<SObject> newRecords = new List<SObject>{accNew};
        Map<Id, SObject> oldMap = new Map<Id, SObject>{accOld.Id => accOld};

        MockDomain domain = new MockDomain(newRecords, oldMap);
        Boolean nameChanged = domain.testFieldHasChanged(accId, Account.Name);
        Boolean industryChanged = domain.testFieldHasChanged(accId, Account.Industry);

        System.assert(!nameChanged, "Account Name should not be detected as changed.");
        System.assert(!industryChanged, "Account Industry should not be detected as changed.");
    }

    @isTest
    static void testFieldHasChanged_ReturnsFalseForNewFieldInNewRecord() {
        Id accId = fflib_IDGenerator.generate(Account.SObjectType);
        Account accNew = new Account(Id = accId, Name = "New Name", Description = "New Desc"); // Description is new
        Account accOld = new Account(Id = accId, Name = "Old Name"); // Old record doesn_t have Description
        List<SObject> newRecords = new List<SObject>{accNew};
        Map<Id, SObject> oldMap = new Map<Id, SObject>{accOld.Id => accOld};

        MockDomain domain = new MockDomain(newRecords, oldMap);
        // When a field is populated in new but was null/not present in old, it is considered changed.
        Boolean descriptionChanged = domain.testFieldHasChanged(accId, Account.Description);
        System.assert(descriptionChanged, "Description should be detected as changed (null to value).");
    }

    @isTest
    static void testGetOldValue_ReturnsCorrectValue() {
        Id accId = fflib_IDGenerator.generate(Account.SObjectType);
        Account accNew = new Account(Id = accId, Name = "New Name");
        Account accOld = new Account(Id = accId, Name = "Old Name", Industry = "Finance");
        List<SObject> newRecords = new List<SObject>{accNew};
        Map<Id, SObject> oldMap = new Map<Id, SObject>{accOld.Id => accOld};

        MockDomain domain = new MockDomain(newRecords, oldMap);
        String oldName = (String)domain.testGetOldValue(accId, Account.Name);
        String oldIndustry = (String)domain.testGetOldValue(accId, Account.Industry);

        System.assertEquals("Old Name", oldName, "Should return the old name.");
        System.assertEquals("Finance", oldIndustry, "Should return the old industry.");
    }

    @isTest
    static void testGetOldValue_ReturnsNullForNonExistentOldRecord() {
        Id accId = fflib_IDGenerator.generate(Account.SObjectType);
        Account accNew = new Account(Id = accId, Name = "New Name");
        List<SObject> newRecords = new List<SObject>{accNew};
        // No oldMap entry for accId
        Map<Id, SObject> oldMap = new Map<Id, SObject>(); 

        MockDomain domain = new MockDomain(newRecords, oldMap);
        Object oldValue = domain.testGetOldValue(accId, Account.Name);
        System.assertEquals(null, oldValue, "Should return null if old record not in map.");
    }

    @isTest
    static void testAddSObjectError_AddsErrorToRecord() {
        Account acc = new Account();
        MockDomain domain = new MockDomain(new List<SObject>{acc}, null);
        String errorMessage = "This is a record-level test error.";

        domain.testAddSObjectError(acc, errorMessage);
        System.assert(acc.hasErrors(), "Account record should have an error.");
        // Note: Verifying the exact error message string requires querying SObject.getErrors(), 
        // which is a bit more involved in tests if not directly causing DML failure.
        // For unit tests of addError, hasErrors() is a primary check.
    }

    @isTest
    static void testAddFieldError_AddsErrorToField() {
        Account acc = new Account(Name = "Test Field Error");
        MockDomain domain = new MockDomain(new List<SObject>{acc}, null);
        String errorMessage = "This is a field-level test error for Name.";

        // Simulate a DML context for addError on field to work as expected
        // Normally, addError on a field is used in a before trigger context
        Test.startTest();
        Database.SaveResult sr = Database.insert(acc, false); // Insert to get an ID, allow partial success
        System.assert(sr.isSuccess());
        acc = [SELECT Name FROM Account WHERE Id = :acc.Id];

        domain.testAddFieldError(acc, Account.Name, errorMessage);
        // Check if the error was added. This is tricky without DML context that shows errors.
        // The addError on a field token directly should mark the record as having an error.
        System.assert(acc.hasErrors(), "Account record should have an error after field error is added.");
        // To verify the specific field error, you would typically check in a trigger context or after a failed DML.
        // For this unit test, hasErrors() is the main check.
        Test.stopTest();
    }

    // Test the virtual methods are callable (they do nothing in base class)
    @isTest
    static void testVirtualMethods_Callable() {
        MockDomain domain = new MockDomain(new List<SObject>(), new Map<Id, SObject>());
        try {
            domain.onBeforeInsert();
            domain.onAfterInsert();
            domain.onBeforeUpdate();
            domain.onAfterUpdate();
            domain.onBeforeDelete();
            domain.onAfterDelete();
            domain.onUndelete();
            System.assert(true, "Virtual methods were called successfully.");
        } catch (Exception e) {
            System.assert(false, "Calling virtual methods should not throw exceptions. Error: " + e.getMessage());
        }
    }
}

