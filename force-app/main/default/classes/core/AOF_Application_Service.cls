/**
 * @description Interface for Service layer classes. Service classes encapsulate business logic
 * that may span multiple SObjects or orchestrate calls to other layers.
 * Methods should be designed for bulk operations.
 * Part of the Apex Orbit Framework (AOF).
 */
public interface AOF_Application_Service {

    // As services are highly specific to the business process they handle,
    // this interface remains minimal. Concrete service classes will define their own methods.
    // Common service patterns might emerge that could be added here or in an abstract base class.

    /**
     * @description Example method signature. Concrete services would implement specific logic.
     * @param params A map of parameters for the service method.
     * @return A result object, or void if the operation doesn't return a value.
     * @throws AOF_Application_Service.ServiceException if an error occurs during processing.
     */
    // Object execute(Map<String, Object> params);

    /**
     * @description Custom exception class for service layer errors.
     */
    public class ServiceException extends Exception {}

}