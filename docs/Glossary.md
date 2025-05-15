# Glossary

*   **AOF (Apex Orbit Framework):** The name of this Salesforce Apex framework.
*   **Bulkification:** Designing Apex code to efficiently process large sets of data (typically up to 200 records in a trigger context) to avoid hitting Salesforce governor limits.
*   **CRUD/FLS:** Create, Read, Update, Delete (CRUD) object-level permissions and Field-Level Security (FLS) field-level permissions in Salesforce.
*   **Domain Layer:** A layer in the AOF responsible for SObject-specific business logic, validations, and calculations. Represented by classes extending `AOF_Application_Domain`.
*   **DML (Data Manipulation Language):** Apex statements used to insert, update, delete, or undelete records in Salesforce (e.g., `insert`, `update`, `delete`).
*   **Governor Limits:** Salesforce platform limits that restrict resource consumption by Apex code (e.g., number of SOQL queries, DML statements, CPU time).
*   **Platform Event:** A type of Salesforce event used for asynchronous communication. In AOF, `ErrorLogEvent__e` is used for decoupled error logging.
*   **Selector Layer:** A layer in the AOF responsible for all SOQL queries. Represented by classes extending `AOF_Application_Selector`.
*   **Separation of Concerns (SoC):** A design principle that advocates for breaking down an application into distinct sections, each addressing a separate concern or responsibility.
*   **Service Layer:** A layer in the AOF that encapsulates business logic spanning multiple SObjects, complex processes, or interactions with external systems. Represented by classes implementing `AOF_Application_Service`.
*   **Single Trigger Per Object:** A design pattern where only one Apex trigger is created for each SObject to manage all trigger contexts, simplifying execution flow.
*   **SOQL (Salesforce Object Query Language):** The language used to query data from the Salesforce database.
*   **Trigger Context Variables:** Static variables in Apex triggers that provide information about the current DML operation (e.g., `Trigger.new`, `Trigger.oldMap`, `Trigger.isInsert`, `Trigger.isBefore`).
*   **Trigger Handler:** A component in AOF (`AOF_TriggerHandler`) that orchestrates trigger logic, delegating to Domain or Service layers.
*   **Unit of Work (UoW):** A design pattern and a component in AOF (`AOF_Application_UnitOfWork`) that manages DML operations by collecting them and executing them in a bulkified manner at the end of a transaction.
