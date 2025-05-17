/**
 * @description Interface for Service layer classes. Service classes encapsulate business logic
 * that may span multiple SObjects or orchestrate calls to other layers.
 * Methods should be designed for bulk operations.
 * Part of the Apex Orbit Framework (AOF).
 */
public interface AOF_Application_Service {

    /**
     * @description Custom exception class for service layer errors.
     */
    public class ServiceException extends Exception {}

}