# Core Principles

The Apex Orbit Framework is built upon several core principles that guide its architecture and promote best practices in Salesforce development:

*   **Separation of Concerns:** Each layer of the framework (Trigger Handling, Service, Domain, Selector, Unit of Work) has a distinct and well-defined responsibility. This separation makes the codebase easier to understand, maintain, test, and evolve. Changes in one area are less likely to impact others, leading to a more robust system.
*   **Bulkification:** This is a paramount principle. All operations, from data retrieval to DML, are designed to handle collections of records efficiently. This is crucial for avoiding Salesforce governor limits, ensuring the framework performs well under load, and scales with growing data volumes.
*   **Scalability:** The architecture is designed to support growth in data volume, transaction complexity, and user base. It is specifically engineered to be suitable for organizations with 10,000+ users, ensuring long-term viability.
*   **Reusability:** Common logic is encapsulated within abstract classes, interfaces, and service methods. This promotes code reuse, reduces redundancy, and ensures consistency across different parts of an application.
*   **Testability:** Components are designed with testability in mind. Clear interfaces, dependency injection (where appropriate), and separation of concerns make it easier to write focused and effective unit tests, leading to higher code quality.
*   **Lightweight and Simplicity:** AOF avoids unnecessary complexity and focuses on providing core functionalities essential for robust and efficient application development. The goal is to be powerful yet easy to understand and use.
*   **Generic Applicability:** The framework is designed to be applicable to any SObject within Salesforce. This promotes a consistent development pattern across the organization, making it easier for developers to switch between different areas of the application.
*   **Single Trigger Per SObject:** This pattern simplifies trigger management, makes the order of execution predictable, and provides a single point of entry for all trigger-based logic on an SObject.
*   **Customizable and Decoupled Error Handling:** AOF utilizes Platform Events for asynchronous error logging to a dedicated custom SObject. This ensures that error logging is robust and that failures in the main transaction do not prevent error details from being captured. This mechanism is also customizable to fit specific organizational needs.
*   **Inspired by Proven Patterns (Not a Clone):** While AOF leverages well-established and proven design patterns for its structure (such as those seen in fflib for Domain, Selector, and Unit of Work layers), it is implemented as a custom, streamlined solution. This allows it to be tailored to the specific goals of being lightweight and easy to adopt while still benefiting from industry best practices.

Adherence to these principles ensures that the Apex Orbit Framework provides a reliable, efficient, and maintainable foundation for Salesforce application development.
