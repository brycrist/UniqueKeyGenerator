/**
 * @description Unit test for the UniqueKeyGenerator class
 * @author      Bryan Crist
 */
@isTest
private class UniqueKeyGeneratorTest {
    /**
     * @description Confirms that right number of keys are generated with the correct length and prefix
     */
    @isTest
    static void generateNewKeys_CreateKeys_KeysReturned() {
        String prefix = 'YARP';
        Integer length = 9;

        Test.startTest();
        List<String> keys = UniqueKeyGenerator.generateNewKeys(length, prefix);
        Test.stopTest();

        Assert.areEqual(10, keys.size(), 'Incorrect number of keys generated');
        for (String key : keys) {
            Assert.isTrue(key.startsWith(prefix), 'Prefix not set');
            Assert.areEqual(length, key.length(), 'Incorrect key length');
        }
    }

    /**
     * @description Confirms that getUsedKeys correctly runs the dynamic query and returns matched keys
     */
    @isTest
    static void getUsedKeys_WithMatchedAndUnmatchedKeys_MatchedKeysReturned() {
        List<QuickText> quickTexts = new List<QuickText>{
            new QuickText(Name='KEY1', Message='something'),
            new QuickText(Name='KEY3', Message='goes'),
            new QuickText(Name='KEY5', Message='here')
        };
        
        List<String> generatedKeys = new List<String>{'KEY1', 'KEY2', 'KEY3', 'KEY4'};

        Test.startTest();
        List<String> usedKeys = UniqueKeyGenerator.getUsedKeys('QuickText', 'Name', generatedKeys);
        Test.stopTest();

        List<String> expectedKeys = new List<String>{'KEY1', 'KEY3'};
        Assert.areEqual(expectedKeys, usedKeys, 'Existing keys not matched correctly');
    }

    /**
     * @description Confirms that non-unique keys are skipped and first unique key is returned
     */
    @isTest
    static void findUniqueKey_WithMatchedAndUnmatchedKeys_FirstUniqueKeyReturned() {
        List<String> generatedKeys = new List<String>{'KEY1', 'KEY2', 'KEY3', 'KEY4'};
        List<String> usedKeys = new List<String>{'KEY1', 'KEY4'};

        Test.startTest();
        String key = UniqueKeyGenerator.findUniqueKey(generatedKeys, usedKeys);
        Test.stopTest();

        Assert.areEqual('KEY2', key, 'Incorrect key returned');
    }

    /**
     * @description Confirms that null is returned if no keys are unique
     */
    @isTest
    static void findUniqueKey_NoUniqueKeys_ReturnNull() {
        List<String> generatedKeys = new List<String>{'KEY1', 'KEY2', 'KEY3'};
        List<String> usedKeys = new List<String>(generatedKeys);

        Test.startTest();
        String key = UniqueKeyGenerator.findUniqueKey(generatedKeys, usedKeys);
        Test.stopTest();

        Assert.isNull(key, 'Returned non-unique key: ' + key);
    }

     /**
     * @description Confirms method properly switches between different key formats when definition changes
     */
    @isTest
    static void getUniqueKeys_MultipleDefinitions_CorrectFormatting() {
        Unique_Key_Definition__mdt example = Unique_Key_Definition__mdt.getInstance('Example');
        Unique_Key_Definition__mdt membership = Unique_Key_Definition__mdt.getInstance('Membership_Number');

        UniqueKeyGenerator.Request r1 = new UniqueKeyGenerator.Request();
        r1.definitionName = clawback.DeveloperName;
        UniqueKeyGenerator.Request r2 = new UniqueKeyGenerator.Request();
        r2.definitionName = membership.DeveloperName;
        List<UniqueKeyGenerator.Request> requests = new List<UniqueKeyGenerator.Request>{r1, r2, r1};

        Test.startTest();
        List<String> uniqueKeys = UniqueKeyGenerator.getUniqueKeys(requests);
        Test.stopTest();

        Assert.isTrue(uniqueKeys[0].startsWith(example.Prefix__c), 'Prefix does not match Example prefix');
        Assert.isTrue(uniqueKeys[1].startsWith(membership.Prefix__c), 'Prefix does not match Membership Number prefix');
        Assert.isTrue(uniqueKeys[2].startsWith(example.Prefix__c), 'Prefix does not match Example prefix');
    }

    /**
     * @description Confirms that all generated keys are used before generating more for a recurring definition
     */
    @isTest
    static void getUniqueKeys_SingleDefinition_UseAllGeneratedKeys() {
        // Set up request for definition
        Unique_Key_Definition__mdt membership = Unique_Key_Definition__mdt.getInstance('Membership_Number');
        UniqueKeyGenerator.Request req = new UniqueKeyGenerator.Request();
        req.definitionName = membership.DeveloperName;
        
        // Add 11 requests to the list to ensure the method needs to generate a second group of keys
        Integer requestSize = 11;
        List<UniqueKeyGenerator.Request> requests = new List<UniqueKeyGenerator.Request>();
        while (requests.size() < requestSize) {
            requests.add(req);
        }

        Test.startTest();
        List<String> uniqueKeys = UniqueKeyGenerator.getUniqueKeys(requests);
        Integer queryCount = Limits.getQueries();
        Test.stopTest();

        // Confirm correct number of keys were returned with no duplicates 
        Assert.areEqual(requestSize, uniqueKeys.size(), 'Incorrect number of keys created');
        Set<String> uniqueKeysSet = new Set<String>(uniqueKeys);
        Assert.areEqual(uniqueKeys.size(), uniqueKeysSet.size(), 'Returned keys included duplicate values');

        // Use query count as surrogate for times keys were generated. Each instance generates keys and queries matches.
        Assert.areEqual(2, queryCount, 'Should have generated keys and queried matches twice.');
    }
}
