defmodule Brama.DecoratorTest do
  use Brama.TestCase
  require Logger

  # Define a test module that uses the decorator
  # credo:disable-for-this-file
  defmodule TestService do
    use Brama.Decorator
    require Logger

    @decorate circuit_breaker(identifier: "test_service")
    def normal_function(arg) do
      {:ok, arg}
    end

    @decorate circuit_breaker(identifier: "failing_service")
    def failing_function(_arg) do
      {:error, :service_error}
    end

    @decorate circuit_breaker(identifier: "exception_service")
    # Function deliberately raises an exception to test error handling.
    # Suppress dialyzer warning about unreachable code from decorator.
    @dialyzer {:nowarn_function, exception_function: 1}
    def exception_function(_arg) do
      # This function intentionally raises an exception for testing
      # the circuit breaker's exception handling
      raise "Service exception"
    end

    @decorate circuit_breaker(
                identifier: "custom_service",
                error_handler: fn
                  {:ok, _} -> :success
                  {:partial, _} -> :ignore
                  {:error, reason} -> {:failure, reason}
                end
              )
    def custom_handler_function(result_type) do
      case result_type do
        :success -> {:ok, "success"}
        :partial -> {:partial, "partial"}
        :failure -> {:error, "failure"}
      end
    end
  end

  setup do
    # Ensure all connections are registered before each test
    Brama.register("test_service")
    Brama.register("failing_service")
    Brama.register("exception_service")
    Brama.register("custom_service")
    Brama.register("fallback_service")
    :ok
  end

  describe "circuit breaker decorator" do
    test "wraps function with circuit breaker" do
      assert {:ok, :test} = TestService.normal_function(:test)

      # Check that the connection was registered
      assert {:ok, status} = Brama.status("test_service")
      assert status.state == :closed
    end

    test "reports success on successful function call" do
      TestService.normal_function(:test)

      # Check that success was reported
      assert {:ok, %{failure_count: 0}} = Brama.status("test_service")
    end

    test "reports failure on error result" do
      TestService.failing_function(:test)

      # Check that failure was reported
      assert {:ok, %{failure_count: 1}} = Brama.status("failing_service")
    end

    test "reports failure on exception" do
      assert_raise RuntimeError, "Service exception", fn ->
        TestService.exception_function(:test)
      end

      # Check that failure was reported
      assert {:ok, %{failure_count: 1}} = Brama.status("exception_service")
    end

    test "uses custom error handler" do
      # Success case
      TestService.custom_handler_function(:success)
      assert {:ok, %{failure_count: 0}} = Brama.status("custom_service")

      # Ignore case
      TestService.custom_handler_function(:partial)
      assert {:ok, %{failure_count: 0}} = Brama.status("custom_service")

      # Failure case
      TestService.custom_handler_function(:failure)
      assert {:ok, %{failure_count: 1}} = Brama.status("custom_service")
    end
  end
end
