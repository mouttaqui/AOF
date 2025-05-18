@isTest
private class AOF_Application_UnitOfWork_Test {
    // Helper to create a Profile
    private static Id createProfile(String profileName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        if (p == null) {
            // For simplicity, we'll use Standard User if the specified profile isn't found
            try {
                p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            } catch(QueryException e){ // NOPMD: EmptyCatchBlock
                // If Standard User is not found, this test's RunAs part will be less effective
                
            }
        }
        return p.Id;
    }
    // Helper to create a User
    private static User createUser(String alias, Id profileId) {
        User u = new User(
            Alias = alias,
            Email = alias + '@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileId,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = alias + '@testorg.com' + System.currentTimeMillis()
        );
        return u;
    }
    @TestSetup
    static void makeData(){
        // Create a restricted user for permission testing
        Id restrictedProfileId = createProfile('Test Restricted Profile UoW');
        User restrictedUser = createUser('rstuser', restrictedProfileId);
        insert restrictedUser;

        // Setup data for general tests
        Account acc = new Account(Name = 'Initial Name UoW Dirty');
        insert acc;
        Account accToDelete = new Account(Name = 'To Be Deleted UoW');
        insert accToDelete;

        List<Account> multiAccounts = new List<Account>{
            new Account(Name = 'Initial Dirty Multi 1'),
            new Account(Name = 'Initial Dirty Multi 2')
        };
        insert multiAccounts;

        List<Account> multiDeleteAccounts = new List<Account>{
            new Account(Name = 'To Delete Multi 1'),
            new Account(Name = 'To Delete Multi 2')
        };
        insert multiDeleteAccounts;
    }
    @isTest
    static void testRegisterNew_SingleObject_CommitsSuccessfully() {
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        Account acc = new Account(Name = 'Test Account UoW New');

        Test.startTest();
        uow.registerNew(acc);
        uow.commitWork();
        Test.stopTest();

        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name = 'Test Account UoW New'];
        System.assertEquals(1, insertedAccounts.size(), 'Account should have been inserted.');
        System.assertEquals('Test Account UoW New', insertedAccounts[0].Name);
    }
    @isTest
    static void testRegisterNew_MultipleObjects_CommitsSuccessfully() {
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        List<Account> accountsToInsert = new List<Account>();
        accountsToInsert.add(new Account(Name = 'Test Account UoW Multi 1'));
        accountsToInsert.add(new Account(Name = 'Test Account UoW Multi 2'));

        Test.startTest();
        uow.registerNew(accountsToInsert);
        uow.commitWork();
        Test.stopTest();

        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account UoW Multi %' ORDER BY Name];
        System.assertEquals(2, insertedAccounts.size(), 'Two accounts should have been inserted.');
        System.assertEquals('Test Account UoW Multi 1', insertedAccounts[0].Name);
        System.assertEquals('Test Account UoW Multi 2', insertedAccounts[1].Name);
    }
    @isTest
    static void testRegisterDirty_SingleObject_CommitsSuccessfully() {
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Initial Name UoW Dirty' LIMIT 1];

        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        acc.Name = 'Updated Name UoW Dirty';
        
        Test.startTest();
        uow.registerDirty(acc);
        uow.commitWork();
        Test.stopTest();

        Account updatedAccount = [SELECT Id, Name FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Updated Name UoW Dirty', updatedAccount.Name, 'Account name should have been updated.');
    }
    @isTest
    static void testRegisterDirty_MultipleObjects_CommitsSuccessfully() {
        List<Account> accounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Initial Dirty Multi %' ORDER BY Name];

        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        accounts[0].Name = 'Updated Dirty Multi 1';
        accounts[1].Name = 'Updated Dirty Multi 2';

        Test.startTest();
        uow.registerDirty(accounts);
        uow.commitWork();
        Test.stopTest();

        List<Account> updatedAccounts = [SELECT Id, Name FROM Account WHERE Id IN :accounts ORDER BY Name];
        System.assertEquals(2, updatedAccounts.size());
        System.assertEquals('Updated Dirty Multi 1', updatedAccounts[0].Name);
        System.assertEquals('Updated Dirty Multi 2', updatedAccounts[1].Name);
    }
    @isTest
    static void testRegisterDeleted_SingleObject_CommitsSuccessfully() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'To Be Deleted UoW' LIMIT 1];

        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();

        Test.startTest();
        uow.registerDeleted(acc);
        uow.commitWork();
        Test.stopTest();

        List<Account> deletedAccounts = [SELECT Id FROM Account WHERE Id = :acc.Id];
        System.assertEquals(0, deletedAccounts.size(), 'Account should have been deleted.');
    }
    @isTest
    static void testRegisterDeleted_MultipleObjects_CommitsSuccessfully() {
        List<Account> accounts = [SELECT Id FROM Account WHERE Name LIKE 'To Delete Multi %'];

        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        
        Test.startTest();
        uow.registerDeleted(accounts);
        uow.commitWork();
        Test.stopTest();

        List<Account> deletedAccounts = [SELECT Id FROM Account WHERE Id IN :accounts];
        System.assertEquals(0, deletedAccounts.size(), 'Accounts should have been deleted.');
    }
    @isTest
    static void testMixedOperations_CommitsSuccessfullyInOrder() {
        Account accToUpdate = [SELECT Id, Name FROM Account WHERE Name = 'Initial Name UoW Dirty' LIMIT 1];
        Account accToDelete = [SELECT Id, Name FROM Account WHERE Name = 'To Be Deleted UoW' LIMIT 1];

        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();

        Account accToInsert = new Account(Name = 'UoW Mixed - New Insert');
        uow.registerNew(accToInsert);

        accToUpdate.Description = 'UoW Mixed - Updated Description';
        uow.registerDirty(accToUpdate);

        uow.registerDeleted(accToDelete);
        
        Test.startTest();
        uow.commitWork();
        Test.stopTest();

        List<Account> inserted = [SELECT Name FROM Account WHERE Name = 'UoW Mixed - New Insert'];
        System.assertEquals(1, inserted.size());

        Account updated = [SELECT Description FROM Account WHERE Id = :accToUpdate.Id];
        System.assertEquals('UoW Mixed - Updated Description', updated.Description);

        List<Account> deleted = [SELECT Name FROM Account WHERE Id = :accToDelete.Id];
        System.assertEquals(0, deleted.size());
    }
    @isTest
    static void testCommitWork_NoOperationsRegistered_DoesNothing() {
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        Integer dmlStatementsBefore = Limits.getDmlStatements();
        
        Test.startTest();
        uow.commitWork();
        Test.stopTest();
        
        Integer dmlStatementsAfter = Limits.getDmlStatements();
        System.assertEquals(dmlStatementsBefore, dmlStatementsAfter, 'No DML statements should have been used.');
    }
    @isTest
    static void testRegister_NullInputs_HandlesGracefully() {
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        Integer dmlStatementsBefore = Limits.getDmlStatements();

        Test.startTest();
        try {
            uow.registerNew((Account)null); 
            uow.registerNew((List<Account>)null); 
            uow.registerNew(new List<Account>{(Account)null});
            uow.registerDirty((Account)null);
            uow.registerDirty((List<Account>)null);
            uow.registerDirty(new List<Account>{(Account)null});
            uow.registerDeleted((Account)null);
            uow.registerDeleted((List<Account>)null);
            uow.registerDeleted(new List<Account>{(Account)null});
            uow.commitWork(); // Should not commit anything
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception for null inputs: ' + e.getMessage());
        }
        Test.stopTest();
        Integer dmlStatementsAfter = Limits.getDmlStatements();
        System.assertEquals(dmlStatementsBefore, dmlStatementsAfter, 'No DML statements should have been used for nulls.');
    }
    @isTest
    static void testCommitWork_DmlException_RollsBack() {
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        Account invalidAcc = new Account(); // Name is typically required
        Account validAcc = new Account(Name = 'Valid UoW Pre-Fail');

        uow.registerNew(validAcc);
        uow.registerNew(invalidAcc); 

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            uow.commitWork();
        } catch (DmlException e) {
            exceptionThrown = true;
            // Check for common DML exceptions related to required fields
            System.assert(e.getMessage().contains('REQUIRED_FIELD_MISSING') || 
                          e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION') || 
                          e.getMessage().contains('INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST'),
                          'Expected DML exception for missing required field or validation rule. Actual: ' + e.getMessage());
        } catch (Exception ex) {
             System.assert(false, 'Unexpected exception type: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'A DmlException should have been thrown.');
        
        List<Account> accounts = [SELECT Id FROM Account WHERE Name = 'Valid UoW Pre-Fail'];
        System.assertEquals(0, accounts.size(), 'The valid account should have been rolled back.');
    }
    // --- CRUD Permission Tests ---
    // Note: These tests now check for exceptions at commit time, not registration time

    private static User getTestRestrictedUser(){
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Test Restricted Profile UoW' LIMIT 1];
        User u = [SELECT Id FROM User WHERE ProfileId = :p.Id AND Alias = 'rstuser' LIMIT 1];
        if (u == null) {
            Id restrictedProfileId = createProfile('Test Restricted Profile UoW');
            if(restrictedProfileId == null) {
                 restrictedProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User'].Id;
            }
            u = createUser('rstuser', restrictedProfileId);
            insert u;
        }
        return u;
    }
    @isTest
    static void testCommitWork_NoCreatePermission_ThrowsSecurityException() {
        User restrictedUser = getTestRestrictedUser();
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        Account acc = new Account(Name = 'No Create Test'); 
        // To make this test effective, 'Test Restricted Profile UoW' must NOT have Create on Account.

        Boolean exceptionThrown = false;
        Test.startTest();
        System.runAs(restrictedUser) {
            try {
                // Registration should succeed
                uow.registerNew(acc);
                
                // Exception should be thrown at commit time
                uow.commitWork();
            } catch (AOF_SecurityException e) {
                exceptionThrown = true;
                System.assert(e.getMessage().contains('User does not have CREATE permission'), 
                             'Incorrect exception message: ' + e.getMessage());
            } catch (Exception ex){
                System.assert(false, 'Wrong exception type thrown: ' + ex.getMessage());
            }
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'AOF_SecurityException should have been thrown for no create permission.');
        
        // Verify no record was inserted
        List<Account> insertedAccounts = [SELECT Id FROM Account WHERE Name = 'No Create Test'];
        System.assertEquals(0, insertedAccounts.size(), 'Account should not have been inserted due to permission denial.');
    }
    @isTest
    static void testCommitWork_NoUpdatePermission_ThrowsSecurityException() {
        Account accToUpdate = new Account(Name = 'No Update Setup');
        insert accToUpdate; // Insert as admin user first

        User restrictedUser = getTestRestrictedUser();
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        accToUpdate.Description = 'Attempting Update'; 
        // To make this test effective, 'Test Restricted Profile UoW' must NOT have Update on Account.

        Boolean exceptionThrown = false;
        Test.startTest();
        System.runAs(restrictedUser) {
            try {
                // Re-query within runAs context if needed, though Id is stable
                Account accInRunAs = [SELECT Id, Name, Description FROM Account WHERE Id = :accToUpdate.Id];
                accInRunAs.Description = 'Attempting Update'; 
                
                // Registration should succeed
                uow.registerDirty(accInRunAs);
                
                // Exception should be thrown at commit time
                uow.commitWork();
            } catch (AOF_SecurityException e) {
                exceptionThrown = true;
                System.assert(e.getMessage().contains('User does not have UPDATE permission'), 
                             'Incorrect exception message: ' + e.getMessage());
            } catch (Exception ex){
                System.assert(false, 'Wrong exception type thrown: ' + ex.getMessage());
            }
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'AOF_SecurityException should have been thrown for no update permission.');
        
        // Verify record was not updated
        Account finalAccountState = [SELECT Description FROM Account WHERE Id = :accToUpdate.Id];
        System.assertNotEquals('Attempting Update', finalAccountState.Description, 'Account description should not have been updated.');
    }
    @isTest
    static void testCommitWork_NoDeletePermission_ThrowsSecurityException() {
        Account accToDelete = new Account(Name = 'No Delete Setup');
        insert accToDelete; // Insert as admin user first

        User restrictedUser = getTestRestrictedUser();
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        // To make this test effective, 'Test Restricted Profile UoW' must NOT have Delete on Account.

        Boolean exceptionThrown = false;
        Test.startTest();
        System.runAs(restrictedUser) {
            try {
                // Re-query within runAs context
                Account accInRunAs = [SELECT Id FROM Account WHERE Id = :accToDelete.Id];
                
                // Registration should succeed
                uow.registerDeleted(accInRunAs);
                
                // Exception should be thrown at commit time
                uow.commitWork();
            } catch (AOF_SecurityException e) {
                exceptionThrown = true;
                System.assert(e.getMessage().contains('User does not have DELETE permission'), 
                             'Incorrect exception message: ' + e.getMessage());
            } catch (Exception ex){
                System.assert(false, 'Wrong exception type thrown: ' + ex.getMessage());
            }
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'AOF_SecurityException should have been thrown for no delete permission.');
        
        // Verify record was not deleted
        List<Account> existingAccounts = [SELECT Id FROM Account WHERE Id = :accToDelete.Id];
        System.assertEquals(1, existingAccounts.size(), 'Account should still exist due to permission denial.');
    }
    @isTest
    static void testCommitWork_MixedPermissions_ThrowsEarly() {
        // This test assumes a custom object `AOF_Custom_Object__c` exists and the restricted user
        // has create permission on Account but NOT on AOF_Custom_Object__c.
        Schema.SObjectType customObjectType = Schema.getGlobalDescribe().get('AOF_Custom_Object__c');
        if (customObjectType == null) {
            // Skip test if object doesn't exist
            return;
        }

        User restrictedUser = getTestRestrictedUser();
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        
        // Register multiple object types
        Account acc = new Account(Name = 'Mixed Perm Test Acc');
        uow.registerNew(acc);
        
        SObject customObj = customObjectType.newSObject();
        uow.registerNew(customObj);

        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        Test.startTest();
        System.runAs(restrictedUser) {
            try {
                // Exception should be thrown at commit time
                uow.commitWork();
            } catch (AOF_SecurityException e) {
                exceptionThrown = true;
                exceptionMessage = e.getMessage();
            } catch (Exception ex){
                System.assert(false, 'Wrong exception type thrown: ' + ex.getMessage());
            }
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AOF_SecurityException should have been thrown.');
        System.assert(exceptionMessage.contains('User does not have CREATE permission on SObject: AOF_Custom_Object__c') || 
                     exceptionMessage.contains('User does not have CREATE permission on SObject: Account'), 
                     'Exception message should indicate permission issue. Actual: ' + exceptionMessage);
        
        // Verify no records were inserted due to transaction rollback
        List<Account> insertedAccounts = [SELECT Id FROM Account WHERE Name = 'Mixed Perm Test Acc'];
        System.assertEquals(0, insertedAccounts.size(), 'Account should not have been inserted.');
    }
    @isTest
    static void testClearRegistrations_ClearsAllLists() {
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        uow.registerNew(new Account(Name='Clear Test New'));
        
        Account accToUpdate = new Account(Id = fflib_IDGenerator.generate(Account.SObjectType), Name='Clear Test Dirty');
        uow.registerDirty(accToUpdate);

        Account accToDelete = new Account(Id = fflib_IDGenerator.generate(Account.SObjectType), Name='Clear Test Delete');
        uow.registerDeleted(accToDelete);

        uow.clearRegistrations();

        // Attempt to commit - should do nothing as lists are clear
        Integer dmlBefore = Limits.getDmlStatements();
        Test.startTest();
        uow.commitWork();
        Test.stopTest();
        Integer dmlAfter = Limits.getDmlStatements();
        System.assertEquals(dmlBefore, dmlAfter, 'No DML should occur after clearing registrations.');
    }
    // Test for SObjectScope.PER_TYPE
    @isTest
    static void testRegisterAndCommit_PerTypeScope_Success() {
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork(AOF_Application_UnitOfWork.SObjectScope.PER_TYPE);
        Account acc = new Account(Name = 'UoW PerType Acc');
        
        // Assuming a simple custom object AOF_Simple_Custom__c exists for this test
        Schema.SObjectType simpleCustomType = Schema.getGlobalDescribe().get('AOF_Simple_Custom__c');
        if (simpleCustomType == null) {
            // Skip this part of the test if object doesn't exist
            Test.startTest();
            uow.registerNew(acc);
            uow.commitWork();
            Test.stopTest();

            List<Account> insertedAccounts = [SELECT Id FROM Account WHERE Name = 'UoW PerType Acc'];
            System.assertEquals(1, insertedAccounts.size(), 'Account should be inserted with PER_TYPE scope.');
            return;
        }
        
        SObject customObj = simpleCustomType.newSObject();
        // Add required fields if needed

        Test.startTest();
        uow.registerNew(acc);
        uow.registerNew(customObj);
        uow.commitWork();
        Test.stopTest();

        List<Account> insertedAccounts = [SELECT Id FROM Account WHERE Name = 'UoW PerType Acc'];
        System.assertEquals(1, insertedAccounts.size(), 'Account should be inserted with PER_TYPE scope.');
    }
}