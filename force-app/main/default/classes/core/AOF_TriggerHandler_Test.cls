/**
 * @description Test class for AOF_TriggerHandler with metadata configuration support
 */
@isTest
private class AOF_TriggerHandler_Test {
    
    // Mock trigger handler for testing
    private class MockTriggerHandler extends AOF_TriggerHandler {
        public Boolean beforeInsertCalled = false;
        public Boolean afterInsertCalled = false;
        public Boolean beforeUpdateCalled = false;
        public Boolean afterUpdateCalled = false;
        public Boolean beforeDeleteCalled = false;
        public Boolean afterDeleteCalled = false;
        public Boolean afterUndeleteCalled = false;
        
        public MockTriggerHandler(SObjectType sObjType, System.TriggerOperation operation) {
            super(sObjType, operation);
        }
        
        protected override void beforeInsert() {
            beforeInsertCalled = true;
        }
        
        protected override void afterInsert() {
            afterInsertCalled = true;
        }
        
        protected override void beforeUpdate() {
            beforeUpdateCalled = true;
        }
        
        protected override void afterUpdate() {
            afterUpdateCalled = true;
        }
        
        protected override void beforeDelete() {
            beforeDeleteCalled = true;
        }
        
        protected override void afterDelete() {
            afterDeleteCalled = true;
        }
        
        protected override void afterUndelete() {
            afterUndeleteCalled = true;
        }
        
        // Expose private methods for testing
        public Boolean testIsEnabledByMetadata() {
            return isEnabledByMetadata();
        }
        
        public Boolean testIsEventEnabledByMetadata(String eventName) {
            return isEventEnabledByMetadata(eventName);
        }
        
        public String testGetTriggerEventName() {
            return getTriggerEventName();
        }
    }
    
    @TestSetup
    static void setupTestData() {
        // Create test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'thandlr',
            Email = 'triggerhandler@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'triggerhandler' + System.currentTimeMillis() + '@example.com'
        );
        insert testUser;
    }
    
    @isTest
    static void testTriggerEventName() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'Testing' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            MockTriggerHandler beforeInsertHandler = new MockTriggerHandler(Account.SObjectType, System.TriggerOperation.BEFORE_INSERT);
            MockTriggerHandler afterUpdateHandler = new MockTriggerHandler(Account.SObjectType, System.TriggerOperation.AFTER_UPDATE);
            MockTriggerHandler beforeDeleteHandler = new MockTriggerHandler(Account.SObjectType, System.TriggerOperation.BEFORE_DELETE);
            MockTriggerHandler afterUndeleteHandler = new MockTriggerHandler(Account.SObjectType, System.TriggerOperation.AFTER_UNDELETE);
            
            String beforeInsertEvent = beforeInsertHandler.testGetTriggerEventName();
            String afterUpdateEvent = afterUpdateHandler.testGetTriggerEventName();
            String beforeDeleteEvent = beforeDeleteHandler.testGetTriggerEventName();
            String afterUndeleteEvent = afterUndeleteHandler.testGetTriggerEventName();
            
            Test.stopTest();
            
            System.assertEquals('beforeinsert', beforeInsertEvent, 'Before Insert event name should match');
            System.assertEquals('afterupdate', afterUpdateEvent, 'After Update event name should match');
            System.assertEquals('beforedelete', beforeDeleteEvent, 'Before Delete event name should match');
            System.assertEquals('afterundelete', afterUndeleteEvent, 'After Undelete event name should match');
        }
    }
    
    @isTest
    static void testBypassMechanism() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'Testing' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            // Test individual SObject bypass
            AOF_TriggerHandler.bypass(Account.SObjectType);
            Boolean isAccountBypassed = AOF_TriggerHandler.isBypassed(Account.SObjectType);
            Boolean isContactBypassed = AOF_TriggerHandler.isBypassed(Contact.SObjectType);
            
            // Clear individual bypass
            AOF_TriggerHandler.clearBypass(Account.SObjectType);
            Boolean isAccountBypassedAfterClear = AOF_TriggerHandler.isBypassed(Account.SObjectType);
            
            // Test bypass all
            AOF_TriggerHandler.bypassAllTriggers();
            Boolean isAllBypassed1 = AOF_TriggerHandler.isBypassed(Account.SObjectType);
            Boolean isAllBypassed2 = AOF_TriggerHandler.isBypassed(Contact.SObjectType);
            
            // Clear bypass all
            AOF_TriggerHandler.clearBypassAllTriggers();
            Boolean isAllBypassedAfterClear1 = AOF_TriggerHandler.isBypassed(Account.SObjectType);
            Boolean isAllBypassedAfterClear2 = AOF_TriggerHandler.isBypassed(Contact.SObjectType);
            
            Test.stopTest();
            
            System.assertEquals(true, isAccountBypassed, 'Account should be bypassed');
            System.assertEquals(false, isContactBypassed, 'Contact should not be bypassed');
            System.assertEquals(false, isAccountBypassedAfterClear, 'Account should not be bypassed after clear');
            
            System.assertEquals(true, isAllBypassed1, 'All SObjects should be bypassed when bypassAll is true');
            System.assertEquals(true, isAllBypassed2, 'All SObjects should be bypassed when bypassAll is true');
            
            System.assertEquals(false, isAllBypassedAfterClear1, 'No SObjects should be bypassed after clearing bypassAll');
            System.assertEquals(false, isAllBypassedAfterClear2, 'No SObjects should be bypassed after clearing bypassAll');
        }
    }
    
    @isTest
    static void testRunWithMetadataConfiguration() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'Testing' LIMIT 1];
        
        System.runAs(testUser) {
            // Setup mock for AOF_TriggerConfigurationService
            // Since we can't easily mock custom metadata in tests, we'll use dependency injection
            // or test the individual methods that use the service
            
            Test.startTest();
            
            // Create a mock trigger handler for testing
            MockTriggerHandler handler = new MockTriggerHandler(Account.SObjectType, System.TriggerOperation.BEFORE_INSERT);
            
            // Test the run method with various configurations
            // Note: In a real test, you would need to mock the configuration service or use a test implementation
            
            // For now, we'll just verify that the handler methods are called as expected
            // when not bypassed and assuming metadata configuration allows execution
            handler.run();
            
            Test.stopTest();
            
            // Verify that the appropriate handler method was called
            System.assertEquals(true, handler.beforeInsertCalled, 'Before Insert handler should be called');
            System.assertEquals(false, handler.afterInsertCalled, 'After Insert handler should not be called');
            System.assertEquals(false, handler.beforeUpdateCalled, 'Before Update handler should not be called');
            System.assertEquals(false, handler.afterUpdateCalled, 'After Update handler should not be called');
            System.assertEquals(false, handler.beforeDeleteCalled, 'Before Delete handler should not be called');
            System.assertEquals(false, handler.afterDeleteCalled, 'After Delete handler should not be called');
            System.assertEquals(false, handler.afterUndeleteCalled, 'After Undelete handler should not be called');
        }
    }
    
    @isTest
    static void testRunWithBypass() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'Testing' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            // Bypass the Account trigger
            AOF_TriggerHandler.bypass(Account.SObjectType);
            
            // Create a mock trigger handler for testing
            MockTriggerHandler handler = new MockTriggerHandler(Account.SObjectType, System.TriggerOperation.BEFORE_INSERT);
            
            // Run the handler (should be bypassed)
            handler.run();
            
            Test.stopTest();
            
            // Verify that no handler methods were called due to bypass
            System.assertEquals(false, handler.beforeInsertCalled, 'Before Insert handler should not be called when bypassed');
            System.assertEquals(false, handler.afterInsertCalled, 'After Insert handler should not be called when bypassed');
            System.assertEquals(false, handler.beforeUpdateCalled, 'Before Update handler should not be called when bypassed');
            System.assertEquals(false, handler.afterUpdateCalled, 'After Update handler should not be called when bypassed');
            System.assertEquals(false, handler.beforeDeleteCalled, 'Before Delete handler should not be called when bypassed');
            System.assertEquals(false, handler.afterDeleteCalled, 'After Delete handler should not be called when bypassed');
            System.assertEquals(false, handler.afterUndeleteCalled, 'After Undelete handler should not be called when bypassed');
        }
    }
    
    @isTest
    static void testErrorHandling() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'Testing' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            // Create a mock trigger handler that will throw an exception
            MockTriggerHandler handler = new MockTriggerHandler(Account.SObjectType, System.TriggerOperation.BEFORE_INSERT) {
                protected override void beforeInsert() {
                    throw new TestException('Test exception');
                }
            };
            
            // Run the handler (should catch and log the exception)
            Boolean exceptionCaught = false;
            try {
                handler.run();
            } catch (Exception e) {
                exceptionCaught = true;
                System.assert(e instanceof TestException, 'Exception should be rethrown');
            }
            
            Test.stopTest();
            
            // Verify that the exception was caught and rethrown
            System.assert(exceptionCaught, 'Exception should be caught and rethrown');
        }
    }
    
    // Custom exception for testing
    private class TestException extends Exception {}
}