# Security Considerations

Security is a critical aspect of any Salesforce application. The Apex Orbit Framework (AOF) incorporates security best practices and provides mechanisms to help developers build secure applications.

*   **CRUD/FLS Enforcement (Selector Layer):**
    *   The Selector Layer is primarily responsible for enforcing Create, Read, Update, Delete (CRUD) and Field-Level Security (FLS) permissions.
    *   All SOQL queries executed through SObject-specific Selector classes (extending `AOF_Application_Selector`) should use the `WITH SECURITY_ENFORCED` clause in SOQL to ensure that queries only return records and fields the running user has access to. This is the recommended approach for FLS and object-level security enforcement on queries.
    *   Alternatively, or as a supplementary measure, results from queries can be processed using `Security.stripInaccessible()` before being returned or used. This method removes fields from SObject lists that the user cannot access.
    *   The `AOF_Application_Selector` base class provides helper methods to check field accessibility (`isAccessible()`, `isQueryable()`, `isUpdateable()`, `isCreateable()`) when dynamically building queries or processing results.
*   **Sharing Rules and Record Visibility (`with sharing` / `without sharing`):**
    *   Apex classes in AOF should explicitly declare their sharing behavior using `with sharing`, `without sharing`, or `inherited sharing` keywords.
    *   **`AOF_TriggerHandler`, `AOF_Application_Domain`, and SObject-specific Domain classes** typically run in the user's context and should generally be declared `with sharing` to respect the user's record visibility and sharing rules. This ensures that business logic operates only on data the user is supposed to see and modify.
    *   **`AOF_Application_Selector` and SObject-specific Selector classes** should also generally be declared `with sharing` to ensure that queries respect the user's data visibility.
    *   **`AOF_Application_Service` and concrete Service classes** sharing declaration depends on the nature of the service. If a service performs operations on behalf of a user, `with sharing` is appropriate. If a service needs to perform privileged operations across a wider set of data (e.g., system-level rollups or integrations), `without sharing` might be necessary, but this should be used judiciously and with a clear understanding of the security implications. Always document the reason for using `without sharing`.
    *   **`AOF_ErrorHandlerService`** and the Platform Event subscriber trigger for error logging might operate in a system context (`without sharing`) to ensure errors can always be logged, regardless of the running user's permissions on the `Error_Log__c` object. However, the data being logged should be carefully considered to avoid exposing sensitive information in logs if the running user didn't have access to it.
*   **Input Validation:**
    *   While Apex and the Salesforce platform provide strong typing and some built-in protections, it's crucial to validate inputs, especially those coming from user interfaces (Lightning Web Components, Aura, Visualforce pages) or external API calls before they are used in business logic, SOQL queries, or DML operations.
    *   The Service Layer is often a good place to perform such validation for complex inputs or business rule checks that go beyond simple data type validation.
    *   Domain layer methods (e.g., `onBeforeInsert`, `onBeforeUpdate`) are also critical for enforcing record-level validation rules using `addError()`.
*   **SOQL Injection Prevention:**
    *   AOF promotes the use of static SOQL queries or parameterized dynamic SOQL queries to prevent SOQL injection vulnerabilities.
    *   The Selector Layer encapsulates SOQL query construction. When building dynamic queries within Selector methods, always use `String.escapeSingleQuotes()` for any user-supplied input that is incorporated into the query string and bind variables wherever possible.
    *   Avoid directly concatenating unescaped user input into SOQL queries.
*   **Secure DML Operations:**
    *   The Unit of Work layer centralizes DML. Before registering records for DML, ensure that the data has been properly validated and that the running user has the necessary permissions (implicitly handled if the preceding logic runs `with sharing` and FLS checks were performed on data retrieval and modification).
*   **Protecting Sensitive Data in Logs:**
    *   When using the `AOF_ErrorHandlerService`, be mindful of not logging overly sensitive information (e.g., PII, financial details, access tokens) in the `Error_Log__c` records or Platform Events, especially if these logs are accessible to a broader audience than the user who experienced the error.
    *   Consider implementing a mechanism to mask or omit sensitive data from error messages or stack traces if necessary.
*   **Bypass Mechanism Security:**
    *   The trigger bypass mechanism (`AOF_TriggerHandler.bypassAllTriggers` or per-object bypass) should be protected. Access to modify bypass flags (e.g., via Custom Settings or other administrative controls) should be restricted to authorized administrators to prevent unauthorized disabling of critical business logic.
*   **Regular Security Reviews:**
    *   Code developed using AOF should undergo regular security reviews to identify and mitigate potential vulnerabilities, just like any other Apex code.

By embedding these security considerations into its design and promoting their use, AOF helps developers build more secure and robust Salesforce applications.
