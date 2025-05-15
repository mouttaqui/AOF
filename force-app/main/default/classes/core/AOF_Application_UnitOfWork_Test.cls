@isTest
private class AOF_Application_UnitOfWork_Test {

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
        Account acc = new Account(Name = 'Initial Name UoW Dirty');
        insert acc;

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
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Initial Dirty Multi 1'),
            new Account(Name = 'Initial Dirty Multi 2')
        };
        insert accounts;

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
        Account acc = new Account(Name = 'To Be Deleted UoW');
        insert acc;

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
        List<Account> accounts = new List<Account>{
            new Account(Name = 'To Delete Multi 1'),
            new Account(Name = 'To Delete Multi 2')
        };
        insert accounts;

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
        // 1. Setup initial data for update and delete
        Account accToUpdate = new Account(Name = 'UoW Mixed - Initial Update');
        Account accToDelete = new Account(Name = 'UoW Mixed - To Delete');
        insert new List<Account>{accToUpdate, accToDelete};

        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();

        // 2. Register operations
        // New record
        Account accToInsert = new Account(Name = 'UoW Mixed - New Insert');
        uow.registerNew(accToInsert);

        // Update record
        accToUpdate.Description = 'UoW Mixed - Updated Description';
        uow.registerDirty(accToUpdate);

        // Delete record
        uow.registerDeleted(accToDelete);
        
        Test.startTest();
        uow.commitWork();
        Test.stopTest();

        // 3. Verify results
        // Verify insert
        List<Account> inserted = [SELECT Name FROM Account WHERE Name = 'UoW Mixed - New Insert'];
        System.assertEquals(1, inserted.size());

        // Verify update
        Account updated = [SELECT Description FROM Account WHERE Id = :accToUpdate.Id];
        System.assertEquals('UoW Mixed - Updated Description', updated.Description);

        // Verify delete
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
    static void testRegisterNew_NullObject_HandlesGracefully() {
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        Account acc = null;
        Integer dmlStatementsBefore = Limits.getDmlStatements();

        Test.startTest();
        try {
            uow.registerNew(acc); // Single null object
            uow.registerNew((List<Account>)null); // Null list
            uow.registerNew(new List<Account>{(Account)null}); // List with null object
            uow.commitWork();
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception for null inputs: ' + e.getMessage());
        }
        Test.stopTest();
        Integer dmlStatementsAfter = Limits.getDmlStatements();
        System.assertEquals(dmlStatementsBefore, dmlStatementsAfter, 'No DML statements should have been used for nulls.');
    }

    @isTest
    static void testRegisterDirty_NullObject_HandlesGracefully() {
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        Account acc = null;
        Integer dmlStatementsBefore = Limits.getDmlStatements();

        Test.startTest();
        try {
            uow.registerDirty(acc); // Single null object
            uow.registerDirty((List<Account>)null); // Null list
            uow.registerDirty(new List<Account>{(Account)null}); // List with null object
            uow.commitWork();
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception for null inputs: ' + e.getMessage());
        }
        Test.stopTest();
        Integer dmlStatementsAfter = Limits.getDmlStatements();
        System.assertEquals(dmlStatementsBefore, dmlStatementsAfter, 'No DML statements should have been used for nulls.');
    }

    @isTest
    static void testRegisterDeleted_NullObject_HandlesGracefully() {
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        Account acc = null;
        Integer dmlStatementsBefore = Limits.getDmlStatements();

        Test.startTest();
        try {
            uow.registerDeleted(acc); // Single null object
            uow.registerDeleted((List<Account>)null); // Null list
            uow.registerDeleted(new List<Account>{(Account)null}); // List with null object
            uow.commitWork();
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception for null inputs: ' + e.getMessage());
        }
        Test.stopTest();
        Integer dmlStatementsAfter = Limits.getDmlStatements();
        System.assertEquals(dmlStatementsBefore, dmlStatementsAfter, 'No DML statements should have been used for nulls.');
    }

    // Test for DML exception during commit (e.g., validation rule failure)
    @isTest
    static void testCommitWork_DmlException_RollsBack() {
        AOF_Application_UnitOfWork uow = new AOF_Application_UnitOfWork();
        // Account that will cause a DML exception (e.g., missing required field if one was defined by a validation rule)
        // For this test, we assume a validation rule exists that Name cannot be 'FAIL_VALIDATION'
        // Or, more simply, try to insert an Account without a Name if Name is required by default.
        Account invalidAcc = new Account(); // Name is typically required
        Account validAcc = new Account(Name = 'Valid UoW Pre-Fail');

        uow.registerNew(validAcc);
        uow.registerNew(invalidAcc); // This should cause the insert to fail

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            uow.commitWork();
        } catch (DmlException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('REQUIRED_FIELD_MISSING') || e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'), 
                          'Expected DML exception for missing required field or validation rule.');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'A DmlException should have been thrown.');
        
        // Verify that the valid account was also rolled back due to allOrNone=true default
        List<Account> accounts = [SELECT Id FROM Account WHERE Name = 'Valid UoW Pre-Fail'];
        System.assertEquals(0, accounts.size(), 'The valid account should have been rolled back.');
    }
}

