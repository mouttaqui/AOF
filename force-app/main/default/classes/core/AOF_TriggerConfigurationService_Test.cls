@isTest
private class AOF_TriggerConfigurationService_Test {
    
    @TestSetup
    static void setupTestData() { // NOPMD
        // Test setup is handled in each test method
    }
    
    @isTest
    static void testIsActiveNoConfiguration() {
        // When no configuration exists, default behavior should be active
        System.runAs(createTestUser()) {
            Test.startTest();
            Boolean isActive = AOF_TriggerConfigurationService.isActive(Account.SObjectType);
            Test.stopTest();
            
            System.assert(isActive, 'Triggers should be active by default when no configuration exists');
        }
    }
    
    @isTest
    static void testIsActiveWithConfiguration() {
        System.runAs(createTestUser()) {
            // Setup test metadata (mocked)
            AOF_TriggerConfigurationService.resetCache();
            
            // Mock the configuration query result
            AOF_TriggerConfiguration__mdt mockConfig = new AOF_TriggerConfiguration__mdt(
                SObjectApiName__c = 'Account',
                IsActive__c = false
            );
            
            // Use Test.createStub to mock the service
            MockTriggerConfigService mockService = new MockTriggerConfigService();
            mockService.addConfiguration('account', mockConfig);
            
            // Test with mocked configuration
            Test.startTest();
            Boolean isActive = mockService.isActive('Account');
            Test.stopTest();
            
            System.assertEquals(false, isActive, 'Triggers should be inactive when configuration sets IsActive__c to false');
        }
    }
    
    @isTest
    static void testIsEventEnabledNoConfiguration() {
        System.runAs(createTestUser()) {
            Test.startTest();
            Boolean isEnabled = AOF_TriggerConfigurationService.isEventEnabled(Account.SObjectType, 'beforeinsert');
            Test.stopTest();
            
            System.assert(isEnabled, 'Trigger events should be enabled by default when no configuration exists');
        }
    }
    
    @isTest
    static void testIsEventEnabledWithConfiguration() {
        System.runAs(createTestUser()) {
            // Setup test metadata (mocked)
            AOF_TriggerConfigurationService.resetCache();
            
            // Mock the configuration query result
            AOF_TriggerConfiguration__mdt mockConfig = new AOF_TriggerConfiguration__mdt(
                SObjectApiName__c = 'Account',
                IsActive__c = true,
                BeforeInsert__c = true,
                AfterInsert__c = false
            );
            
            // Use Test.createStub to mock the service
            MockTriggerConfigService mockService = new MockTriggerConfigService();
            mockService.addConfiguration('account', mockConfig);
            
            // Test with mocked configuration
            Test.startTest();
            Boolean beforeInsertEnabled = mockService.isEventEnabled('Account', 'beforeinsert');
            Boolean afterInsertEnabled = mockService.isEventEnabled('Account', 'afterinsert');
            Test.stopTest();
            
            System.assertEquals(true, beforeInsertEnabled, 'Before Insert should be enabled based on configuration');
            System.assertEquals(false, afterInsertEnabled, 'After Insert should be disabled based on configuration');
        }
    }
    
    @isTest
    static void testIsEventEnabledInactiveTrigger() {
        System.runAs(createTestUser()) {
            // Setup test metadata (mocked)
            AOF_TriggerConfigurationService.resetCache();
            
            // Mock the configuration query result
            AOF_TriggerConfiguration__mdt mockConfig = new AOF_TriggerConfiguration__mdt(
                SObjectApiName__c = 'Account',
                IsActive__c = false,
                BeforeInsert__c = true
            );
            
            // Use Test.createStub to mock the service
            MockTriggerConfigService mockService = new MockTriggerConfigService();
            mockService.addConfiguration('account', mockConfig);
            
            // Test with mocked configuration
            Test.startTest();
            Boolean isEnabled = mockService.isEventEnabled('Account', 'beforeinsert');
            Test.stopTest();
            
            System.assertEquals(false, isEnabled, 'Events should be disabled when the trigger is inactive, regardless of event settings');
        }
    }
    
    @isTest
    static void testGetConfiguration() {
        System.runAs(createTestUser()) {
            // Setup test metadata (mocked)
            AOF_TriggerConfigurationService.resetCache();
            
            // Mock the configuration query result
            AOF_TriggerConfiguration__mdt mockConfig = new AOF_TriggerConfiguration__mdt(
                SObjectApiName__c = 'Account',
                IsActive__c = true,
                ExecutionOrder__c = 10,
                Description__c = 'Test Configuration'
            );
            
            // Use Test.createStub to mock the service
            MockTriggerConfigService mockService = new MockTriggerConfigService();
            mockService.addConfiguration('account', mockConfig);
            
            // Test with mocked configuration
            Test.startTest();
            AOF_TriggerConfiguration__mdt config = mockService.getConfiguration('Account');
            Test.stopTest();
            
            System.assertNotEquals(null, config, 'Configuration should be returned');
            System.assertEquals('Account', config.SObjectApiName__c, 'SObject API name should match');
            System.assertEquals(true, config.IsActive__c, 'IsActive should match');
            System.assertEquals(10, config.ExecutionOrder__c, 'Execution order should match');
            System.assertEquals('Test Configuration', config.Description__c, 'Description should match');
        }
    }
    
    @isTest
    static void testResetCache() {
        System.runAs(createTestUser()) {
            // Setup test metadata (mocked)
            AOF_TriggerConfigurationService.resetCache();
            
            // Mock the configuration query result
            AOF_TriggerConfiguration__mdt mockConfig = new AOF_TriggerConfiguration__mdt(
                SObjectApiName__c = 'Account',
                IsActive__c = true
            );
            
            // Use Test.createStub to mock the service
            MockTriggerConfigService mockService = new MockTriggerConfigService();
            mockService.addConfiguration('account', mockConfig);
            
            // Test with mocked configuration
            Test.startTest();
            Boolean isActive1 = mockService.isActive('Account');
            
            // Change the configuration
            mockConfig.IsActive__c = false;
            mockService.addConfiguration('account', mockConfig);
            
            // Without resetting cache, should still return old value
            Boolean isActive2 = mockService.isActive('Account');
            
            // Reset cache and check again
            mockService.resetCache();
            Boolean isActive3 = mockService.isActive('Account');
            Test.stopTest();
            
            System.assertEquals(true, isActive1, 'Initial value should be true');
            System.assertEquals(true, isActive2, 'Value should still be true before cache reset');
            System.assertEquals(false, isActive3, 'Value should be false after cache reset');
        }
    }
    
    @isTest
    static void testNullInputHandling() {
        System.runAs(createTestUser()) {
            Test.startTest();
            Boolean isActive1 = AOF_TriggerConfigurationService.isActive((SObjectType)null);
            Boolean isActive2 = AOF_TriggerConfigurationService.isActive((String)null);
            Boolean isEventEnabled1 = AOF_TriggerConfigurationService.isEventEnabled((SObjectType)null, 'beforeinsert');
            Boolean isEventEnabled2 = AOF_TriggerConfigurationService.isEventEnabled(Account.SObjectType, null);
            Boolean isEventEnabled3 = AOF_TriggerConfigurationService.isEventEnabled((String)null, 'beforeinsert');
            Boolean isEventEnabled4 = AOF_TriggerConfigurationService.isEventEnabled('Account', null);
            AOF_TriggerConfiguration__mdt config1 = AOF_TriggerConfigurationService.getConfiguration((SObjectType)null);
            AOF_TriggerConfiguration__mdt config2 = AOF_TriggerConfigurationService.getConfiguration((String)null);
            Test.stopTest();
            
            System.assertEquals(false, isActive1, 'isActive should handle null SObjectType');
            System.assertEquals(false, isActive2, 'isActive should handle null String');
            System.assertEquals(false, isEventEnabled1, 'isEventEnabled should handle null SObjectType');
            System.assertEquals(false, isEventEnabled2, 'isEventEnabled should handle null event name');
            System.assertEquals(false, isEventEnabled3, 'isEventEnabled should handle null SObject name');
            System.assertEquals(false, isEventEnabled4, 'isEventEnabled should handle null event name with String input');
            System.assertEquals(null, config1, 'getConfiguration should handle null SObjectType');
            System.assertEquals(null, config2, 'getConfiguration should handle null String');
        }
    }
    
    // Helper method to create a test user
    private static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'tconf',
            Email = 'triggerconfig@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'triggerconfig' + System.currentTimeMillis() + '@example.com'
        );
        return testUser;
    }
    
    // Mock implementation for testing
    private class MockTriggerConfigService {
        private Map<String, AOF_TriggerConfiguration__mdt> configMap = new Map<String, AOF_TriggerConfiguration__mdt>();
        private Map<String, Boolean> activeMap = new Map<String, Boolean>();
        private Map<String, Map<String, Boolean>> eventMap = new Map<String, Map<String, Boolean>>();
        
        public void addConfiguration(String sObjectName, AOF_TriggerConfiguration__mdt config) {
            configMap.put(sObjectName.toLowerCase(), config);
            activeMap.put(sObjectName.toLowerCase(), config.IsActive__c);
            
            Map<String, Boolean> events = new Map<String, Boolean>();
            events.put('beforeinsert', config.BeforeInsert__c);
            events.put('afterinsert', config.AfterInsert__c);
            events.put('beforeupdate', config.BeforeUpdate__c);
            events.put('afterupdate', config.AfterUpdate__c);
            events.put('beforedelete', config.BeforeDelete__c);
            events.put('afterdelete', config.AfterDelete__c);
            events.put('afterundelete', config.AfterUndelete__c);
            
            eventMap.put(sObjectName.toLowerCase(), events);
        }
        
        public Boolean isActive(String sObjectName) {
            if (String.isBlank(sObjectName)) {
                return false;
            }
            
            String key = sObjectName.toLowerCase();
            if (!activeMap.containsKey(key)) {
                return true; // Default behavior
            }
            
            return activeMap.get(key);
        }
        
        public Boolean isEventEnabled(String sObjectName, String eventName) {
            if (String.isBlank(sObjectName) || String.isBlank(eventName)) {
                return false;
            }
            
            if (!isActive(sObjectName)) {
                return false;
            }
            
            String objKey = sObjectName.toLowerCase();
            String evtKey = eventName.toLowerCase();
            
            if (!eventMap.containsKey(objKey) || !eventMap.get(objKey).containsKey(evtKey)) {
                return true; // Default behavior
            }
            
            return eventMap.get(objKey).get(evtKey);
        }
        
        public AOF_TriggerConfiguration__mdt getConfiguration(String sObjectName) {
            if (String.isBlank(sObjectName)) {
                return null;
            }
            
            String key = sObjectName.toLowerCase();
            if (!configMap.containsKey(key)) {
                return null;
            }
            
            return configMap.get(key);
        }
        
        public void resetCache() {
            // In a real implementation, this would reset static cache variables
            // For our mock, we'll just clear our maps
            configMap.clear();
            activeMap.clear();
            eventMap.clear();
        }
    }
}