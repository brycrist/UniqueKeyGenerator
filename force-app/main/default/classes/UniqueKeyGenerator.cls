/**
 * @description Generates unique keys based on definitions stored in the Unique Key Definitions CMDT
 * @author      Bryan Crist
 */
public without sharing class UniqueKeyGenerator {
    /**
     * @description Generates unique keys based on a provided prefix value
     * @param prefixList List of prefix values. These are mapped to individual CMDT definitions
     * @return List of unique keys
     */
    @InvocableMethod(
        label='Generate Unique Key'
        description='Generates a unique key based on a unique key definition'
        category='Utilities'
    )
    public static List<String> getUniqueKeys(List<Request> requests) {
        // Get all unique key definitions mapped by developer name
        Map<String, Unique_Key_Definition__mdt> definitionsByDevName = Unique_Key_Definition__mdt.getAll();

        List<String> finalKeys = new List<String>();
        String definitionUsed;
        List<String> generatedKeys = new List<String>();
        List<String> usedKeys = new List<String>();

        for (Request req : requests) {
            // Get the definition information
            String definitionName = req.definitionName;
            Unique_Key_Definition__mdt definition = definitionsByDevName.get(definitionName);

            // Loop until we find a match
            Boolean success = false;
            while (success == false) {
                /**
                 * Check if we need to generate a new list of keys. If we still have potentially valid keys for the
                 * unique key definition, keep using them. Helps reduce queries.
                 */
                if (generatedKeys.size() == 0 || definitionName != definitionUsed) {
                    // Set the definition used to generate the keys
                    definitionUsed = definitionName;

                    /**
                     * Generate ten new keys. Reduces the number of times we need to generate keys, run queries,
                     * and compare if being run in bulk or existing matches are found.
                     */
                    generatedKeys = generateNewKeys(Integer.valueOf(definition.Length__c), definition.Prefix__c);
                    // Find existing instances of the generated keys being used
                    usedKeys = getUsedKeys(
                        definition.Object_Developer_Name__c,
                        definition.Field_Developer_Name__c,
                        generatedKeys
                    );
                }

                // Loop through the generated keys until an unused key is found
                String key = findUniqueKey(generatedKeys, usedKeys);
                if (key != null) {
                    // Use the key and move on
                    finalKeys.add(key);
                    success = true;
                    break;
                }
            }
        }

        return finalKeys;
    }

    /**
     * @description Generates a new list of prefixed keys
     * @param length Length of the generated keys
     * @param prefix Prefix for the keys
     * @return List of keys
     */
    public static List<String> generateNewKeys(Integer length, String prefix) {
        Integer genLength = length - prefix.length();
        List<String> generatedKeys = new List<String>();
        // Generate ten keys. Reduces the number of times we need to generate keys, run queries, and compare.
        while (generatedKeys.size() < 10) {
            String key = prefix;
            for (Integer i = 0; i < genLength; i++) {
                key = key + String.valueof(Integer.valueOf(Math.random() * 10));
            }
            // Make sure the generated key isn't a duplicate
            if (!generatedKeys.contains(key)) {
                generatedKeys.add(key);
            }
        }
        return generatedKeys;
    }

    /**
     * @description Searches a specified object and field for existing matches to the generated keys
     * @param keyObject Object the keys are associated with
     * @param keyField Field on the object where unique keys are stored
     * @param generatedKeys List of generated keys to look for
     * @return List of used keys
     */
    public static List<String> getUsedKeys(String keyObject, String keyField, List<String> generatedKeys) {
        // Get all existing records with matching keys
        String query = String.format(
            'SELECT Id, {0} FROM {1} WHERE {0} IN :generatedKeys',
            new List<String>{ keyField, keyObject }
        );
        List<SObject> records = Database.query(query);

        // Create a list of the used keys
        List<String> usedKeys = new List<String>();
        for (SObject record : records) {
            usedKeys.add((String) record.get(keyField));
        }
        return usedKeys;
    }

    /**
     * @description Checks for an unused key in a list of generated keys
     * @param generatedKeys List of generated keys to check for uniqueness
     * @param usedKeys List of keys that have already been used
     * @return Unique key or null if no generated keys were unique
     */
    public static String findUniqueKey(List<String> generatedKeys, List<String> usedKeys) {
        // Loop through the generated keys until an unused key is found
        while (generatedKeys.size() > 0) {
            // Get the key and remove it from the list. We're either going to use it or it's not unique.
            String key = generatedKeys[0];
            generatedKeys.remove(0);

            if (!usedKeys.contains(key)) {
                // Use the key and move on
                return key;
            }
        }
        return null;
    }

    /**
     * @description Request inputs. Only used to improve action's property editor UX in flow.
     */
    public class Request {
        @InvocableVariable(
            label='Definition Name'
            description='Developer name of the Unique Key Definition record the key will be generated from'
            required=true
        )
        public String definitionName;
    }
}
